---
title: "Methodology: NPU 大杀器及框架级调试工具指南 (NPU Debug Tools)"
tags: [methodology, debug, toolchain, npu]
last_updated: "2026-04-16"
source: [raw/docs/rl_precision_case.pdf]
confidence: high
status: active
open_questions: []
contradictions: []
---

# NPU 与框架深度调试探测工具链

抛弃古老的粗略 print 与散乱的 save。下面这套集成的全流程深潜工具足以帮助我们提取从 `Parameter` 栈直至多线程异步通信底座的全部真相。

## 1. msprobe: 探针之眼 (Precision Debugger)

通过植入在训练/推理流循环管道内部的全自动 `Dump` 黑匣子，可以将庞大网络拆解为逐个 `nn.Module` 的细密切片与运算度量。

- **工作量级划分**：
  - `L1`: 轻量查探，只打出算子名称及最大最小值、均值、方差。发现异状的先导兵。
  - `L0`: 重核导出全息备份！无死角 Dump 每层 `tensor`。并配给 `construct.json` 用于全景复盘可视化模型计算结构拓扑（仅限需要找寻根因且有足够磁盘容量存储特征时使用）。
- **实装与召唤**：
  - 初始化与配装 JSON（定义层级 `data_mode["all"]`）。
  - 在大模型循环 `ModelRunner` 内插桩：
    ```python
    from msprobe.pytorch import PrecisionDebugger
    self.debugger = PrecisionDebugger("/path/to/config.json")
    ```

## 2. Monitor: 轻量训练生命体量测器

Monitor 设计在于，不在物理端拦截推断时间流，且仅附带极少的时间与算力磨损（通常微乎其微），主要面向**反向期**抓取极度核心的**通信中转体**与**模型更新瞬时状态**。
这包括：每一次优化的 **激活波、各层的权重动态梯度** (能极速查明是哪层哪块 `share_expert` 的微矩阵被 OOM 或是梯暴填满的)。

## 3. npu_sanitizer: 多流时空的破局幽光 (Sync & Memory Validator)

对标 NVIDIA CUDA Sanitizer，处于原型先遣阶段的 `npu_sanitizer` 可以完美监控并穿透各类 `async`/`wait` 壁垒，它负责检测在复杂的并行 `Stream` / 同步运算（如梯度累加和共享叠加）中内核之间的：
- **资源未加锁重用**。
- **数据竞态与覆写内存地址重叠踩踏（Data Race & Stomp）**。

> [!TIP] 这个特性无比好用！
> 对于 Ring-Moe 或者含有如 `moe_shared_expert_overlap` 等跨越算力队列与通讯操作的应用来说，`npu_sanitizer` 一旦检测到了非法交叠共享缓冲操作，会立于原点触发 Python 层的警告并且中断拦截崩溃进程。(案例: [[wiki/02_precision/moe_shared_expert_overlap_grad|MOE Shared Expert Overlap 多流内存踩踏与梯度爆炸]])

**激活动能**：
于主程序前置挂载即可覆盖进程内上下文。
```python
from torch_npu.npu import _sanitizer
_sanitizer.enable_npu_sanitizer()
```
