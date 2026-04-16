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
- **方案描述**:
  1. 在 `verl/workers/rollout/vllm_rollout/vllm_rollout_spmd.py` 对假权重执行覆写强灌操作。加入 `process_weights_after_loading` 接力，打破原先对 `in-place` 覆写的完全依赖。
  2. 修复产生指针解耦现象的 `view()` 并摒弃损害连续性的 `.contiguous()`，强行与 GPU 执行同一组切分方式。
- **特征调试模块** (`CompareWeight` 打桩器，用于甄别新 Sharding 污染范围):
  ```python
  class CompareWeight:
      @staticmethod
      def dump_CustomDeepseekV2DecoderLayer(path_for_save: Path, layer):
          # Dump 当前层中切分敏感权重
          dict_tensor = {
              "self_attn.mla_attn.impl.W_UV": layer.self_attn.mla_attn.impl.W_UV,
              "self_attn.mla_attn.impl.W_UK_T": layer.self_attn.mla_attn.impl.W_UK_T
          }
          for name, param in dict_tensor.items():
              torch.save(param.cpu(), path_for_save.joinpath(f"{name}.pt"))
  ```
  在落盘比对时：若 `safetensors` 分支吐字正常，而 `dummy` 分支提取的数据（基于纯净随机数据再覆盖）存在差异，即实锤证明 Sharding 指针有漏网之鱼。

## 4. 对齐验证 (Validation)
- **验证手段**: 运行 `dummy` 模式的 MLA 成功吐字。

## 5. 关联知识
- [[wiki/04_frameworks/vllm_npu|vLLM Sharding 及权重同步机制]]
