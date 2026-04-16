---
title: "Precision: Ring-mini TE+ETP1 梯度爆炸"
tags: [status/resolved, category/overflow]
last_updated: 2026-04-16
source: [raw/docs/rl_precision_case.pdf]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Precision Alignment Report: MOE Shared Expert Overlap 导致多流内存踩踏

## 1. 差异现象 (Deviation Symptoms)
- **现象**: 在 asys 框架下训练 ring-mini，开启 TE 且 etp=1 后，大概率在第一步出现梯度爆炸。
- **数据类型**: BF16 / FP32

## 2. 定位过程 (Debugging Process)
- **使用工具**: mstt monitor 工具、`_sanitizer` 流同步检测工具。
- **可疑算子/模块**: `layers.6.mlp.share_experts.linear_fc1.weight` (MOE 模块多流同步失效)
- **排查逻辑**:
  1. 通过 `skip_rollout=True` 打桩确定是由训练侧反演导致，设置 `task_queue_enable=0`（切断主异步特性）不爆发揭示出存在多流覆写异常。
  2. 启用 NPU 专有的流同步污染探针 `npu_sanitizer` 检测内存竞争:
     ```python
     from torch_npu.npu import _sanitizer
     _sanitizer.enable_npu_sanitizer() # 在主引擎中执行，监测到跨流 Data Race 会直接终止并抛出栈警告
     ```
  3. `sanitizer` 拦截到 `npu_matmul_add_fp32` 算子 (受 `gradient_accumulation_fusion` 驱动) 与反向计算流发生互斥修改踩踏。
  4. 截取 profile 事件分析后确证，MOE共享专家层 (`moe_shared_expert_overlap`) 的反向执行游离于计算主流(stream 2)外，触发了异步生命周期管控漏洞。

## 3. 修复方案 (Alignment Fix)
- **方案描述**: 关闭 `moe_shared_expert_overlap` 选项以切断重叠计算影响，规避在 NPU 侧的异步内存错误踩踏行为。
- **代码实现**:
  ```yaml
  # 修改训练启动配置、禁用 overlap 模块
  moe_shared_expert_overlap: false
  ```

## 4. 对齐验证 (Validation)
- **验证手段**: 关闭配置选项后，重复跑实验第一步梯度爆炸情况不再复现。

## 5. 关联知识
- [[wiki/03_tuning/overflow_handling|NaN / Overflow 问题排查]]
- [[wiki/02_precision/rl_debug_tools_guide|NPU 框架级调试工具指南]]
