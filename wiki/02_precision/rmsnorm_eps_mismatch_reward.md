---
title: "Precision: RMSNorm 超参 eps 未对齐导致 reward 下降"
tags: [status/resolved, category/diff]
last_updated: 2026-04-16
source: [raw/docs/rl_precision_case.pdf]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Precision Alignment Report: Qwen2.5-7b RMSNorm EPS 未对齐

## 1. 差异现象 (Deviation Symptoms)
- **现象**: Qwen2.5-7b 训练 1000 步后，训练 reward 缓慢下降并显著低于 GPU，产生精度分叉。
- **数据类型**: 通用大模型训练精度组合。

## 2. 定位过程 (Debugging Process)
- **使用工具**: 替换权重推理对比，在 rollout 打桩并使用 hook 截取 dump tensor 打印对比。
- **可疑算子/模块**: `RMSNorm`
- **排查逻辑**: 使用相同权重离线评测推理一致，说明是训练侧精度问题。排查前反向精度，发现经过 Layernorm 后 dump 结果发生差异。追溯发现 `mindspeed-rl` 的 `rms_norm_eps` 默认值(1e-6)与客户(1e-7)不同。

## 3. 修复方案 (Alignment Fix)
- **方案描述**: 手工在 `yaml` 配置中将 `rms_norm_eps` 指定设定为与基线一致的 1e-7。
- **代码实现**:
  ```yaml
  # yaml 配置修复
  rms_norm_eps: 1e-7
  ```

## 4. 对齐验证 (Validation)
- **验证手段**: 长跑 4000 步训练 loss 和 GPU 对齐，缓慢上升且不发生下降散网。

## 5. 关联知识
- 无
