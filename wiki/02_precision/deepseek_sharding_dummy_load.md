---
title: "Precision: Deepseek dummy 初始化的 Sharding 脱序"
tags: [status/resolved, category/diff]
last_updated: 2026-04-16
source: [raw/docs/rl_precision_case.pdf]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Precision Alignment Report: Deepseek W_UV / W_UK_T 的地址视图打断

## 1. 差异现象 (Deviation Symptoms)
- **现象**: 对 Deepseek-671b 或 Moonlight-16B 设置 VLLM `load_format=dummy`（随机假权重进行显存测评）时，NPU 模型一直输出崩溃乱码，而 GPU 下可成功推演结果。
- **数据类型**: BF16 / Safetensors

## 2. 定位过程 (Debugging Process)
- **使用工具**: Checkpoint 落库对比器 (CustomDeepseekV2DecoderLayer 逐层 dump)。
- **可疑算子/模块**: MLA (Multi-head Latent Attention) 中的 `W_UV`, `W_UK_T`
- **排查逻辑**: 确定 `dummy` 下非 MLA 模型皆可正常载入；进而逐行追踪前向 `kv_b` 的运算与 Sharding 更新逻辑，最终发现在参数分割后 `W_UV` 等通过 `.view` 切割所得的数据地址发生变化从源头脱轨，导致更新引擎给老权重做 inplace 操作时，脱钩的这批 `W_UV` 张量保留了假权重的初始噪音。

## 3. 修复方案 (Alignment Fix)
- **方案描述**: 加载与 Sharding 完成后直接追加一层强制的全量参数映射重建 （通过 `process_weights_after_loading`），并摒弃有隐患的 `view()` / `.contiguous()` 割裂操作以贴近 GPU 同等运行姿态。
- **代码实现**: 已合并进入 verl 的 Actor-Engine 权重覆写模块中。

## 4. 对齐验证 (Validation)
- **验证手段**: 运行 `dummy` 模式的 MLA 成功吐字。

## 5. 关联知识
- [[wiki/04_frameworks/vllm_npu|vLLM Sharding 及权重同步机制]]
