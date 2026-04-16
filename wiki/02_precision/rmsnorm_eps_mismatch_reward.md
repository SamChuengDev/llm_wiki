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
- **可疑算子/模块**: `RMSNorm` (`mindspeed-rl` 默认超参与 HuggingFace 参数错配)
- **排查逻辑**: 
  1. 使用相同权重在 GPU 与 NPU 上跑离线评测脚本，推理一致，锁定训练侧框架。
  2. 利用 PyTorch 标准 Hook (`register_forward_hook`) 在 rollout 之后拦截：
     ```python
     def hook_fn(module, input, output):
         torch.save(output.cpu(), f"/tmp/dump_{module.__class__.__name__}.pt")
     model.model.layers[0].input_layernorm.register_forward_hook(hook_fn)
     ```
  3. 分析各算子 Dump 数值，发现在 Layernorm 后产出差异。
  4. 对比组件代码：`mindspeed-rl` 的 `rms_norm_eps` 默认值未设置时采用硬编码 `1e-6`，而本次实验客户基础模型 (HuggingFace) 初始默认为 `1e-7`，由于超参极小尺度的偏移引发百步后的奖励崩塌。

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
