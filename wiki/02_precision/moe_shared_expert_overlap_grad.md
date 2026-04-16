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
- **可疑算子/模块**: `layers.6.mlp.share_experts.linear_fc1.weight` (MOE 模块) 
- **排查逻辑**: 打桩 rollout 输出确认系训练侧问题，关闭 `task_queue_enable=0` 后不复现，指明为多流同步或内存踩踏。利用 `_sanitizer` 检测发现 `npu_matmul_add_fp32` 算子和反向流之间发生内存踩踏。结合 profile 数据诊断出系 `moe_shared_expert_overlap` 在特定时序下引发主流与其它流的异常覆盖。

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
