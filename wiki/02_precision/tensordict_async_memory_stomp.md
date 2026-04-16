---
title: "Precision: Tensordict 原生不适配导致异步内存踩踏"
tags: [status/resolved, category/diff]
last_updated: 2026-04-16
source: [raw/docs/rl_precision_case.pdf]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Precision Alignment Report: Tensordict 在 NPU 的异步错误

## 1. 差异现象 (Deviation Symptoms)
- **现象**: Qwen 长跑流程极度不稳，且 `grad_norm` 频发极高的尖刺并长期高于 GPU 基线。
- **数据类型**: 通用 (Memory Address Issue)

## 2. 定位过程 (Debugging Process)
- **使用工具**: 开启确定性，打桩排查前向与反向输入数据内存地址 (`tensor.data_ptr`)。
- **可疑算子/模块**: `tensordict.to()` 及其异步实现盲区
- **排查逻辑**: 
  1. 通过使用 `skip_rollout` 特性强行将验证打桩数据灌注反演，报错规避，证明出在 CPU 与 NPU 的流交互脱节！
  2. 提取 `tensor.data_ptr()` 校验内存块栈。惊人发现 `ref_logp` (参考输出)与前置保留数据的 `old_logp` 分配了分毫无差指向一致的内存段基地址。
  3. `tensordict.to()` 原本使用 `torch.cuda.is_initialized()` 等 CUDA 测探器来管控流阻断与 sync 同步。当时 `torch.npu` 对接层欠缺对应的拦截处理（或者 `torch.cuda.is_initialized` 固定判为 False），致使系统隐晦地判定无需上锁或进行流等待。
  4. 最终导致：Actor 还在运作时，未阻塞好的其它 worker 的运算结果错乱覆盖回了共享内存，引爆脏数据雪崩。

## 3. 修复方案 (Alignment Fix)
- **方案描述**: 推进升级已补全 NPU 同步行为和钩子的包版本。
- **代码实现**:
  ```bash
  # 升级至包含 NPU Native Support 的版本
  pip install tensordict==0.10.0
  ```

## 4. 对齐验证 (Validation)
- **验证手段**: 运行过程被同步隔离干净，不再出现同地址重复映射，梯度无尖刺。

## 5. 关联知识
- [[wiki/00_bugfix/index|环境修复与排错]]
- [[wiki/02_precision/rl_off_policy_inconsistency|训推架构 Off-Policy 异构发散诱因与对策]]
