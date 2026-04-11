---
title: "Precision: VLM RL Actor 概率输出不一致 (The Missing -100)"
tags: [status/resolved, category/diff, module/xllm, module/rl]
last_updated: 2026-04-11
source: [/Users/samcheung/codes/work_summary/强化学习/mass_engine/vlm_rl_root_cause_analysis.md]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Precision Alignment Report: VLM RL `logprobs_diff` 发散根因排查

## 1. 差异现象 (Deviation Symptoms)
- **现象**: 在 NPU 集群上使用 XLLM(vLLM-Ascend) 作为推理引擎跑 VLM PPO 强化学习时，`logprobs_diff` 居高不下 (长期恒定在 `~0.52 - 0.58` 的量级，正常要求 `< 0.02`)。
- **关联异常**: Rollout 侧的 PPL 在正常的 `1.09`，而在接收同样数据计算的 Actor 侧 PPL 却飙升至 `1.78 ~ 2.1`。
- **灾难后果**: Actor 无法复刻 Rollout 对图文生成的逻辑解释，新旧策略偏差导致截断紊乱，Reward 无法收敛并迅速崩溃。
- **数据类型**: 属于架构级的 **索引序列对齐精度丢失** (而非简单的浮点数数值抖动)。

## 2. 定位过程 (Debugging Process)
- **使用工具**: 绕开标准输出，在 `actor.py`/`functional.py` 深处植入底层本地日志 (`outputs/actor_diag.txt`)，全量截获 `input_ids` 以及 `image_mask` 的张量总和状态。
- **可疑算子/模块**: RPC 通信链路（RL Master 与 Worker 之间），被怀疑是视觉张量传入失败或是 2D RoPE 错位。
- **核心真相**: 发现到达 Actor 视角的 `image_mask = (input_ids == -100)` 的求和结果变成了毫无意义的 **`0`**！由于底层 XLLM 引擎为了兼容 Ascend 且避免出现 `<0` 引起的 C++ CUDA Invalid Argument，**粗暴地将所有长达 256 块的图文填位符 `-100` 全部硬性篡改为了掩码 `1`**。不仅如此，推理结束后原样将全是 `1` 的假文本返回给了 RL 引擎，使得 Actor "瞎了"，只看得到文本却丢弃了所有传入的视觉 `vit_embeds`。

## 3. 修复方案 (Alignment Fix)
- **方案描述**: 既然前向引擎的“消毒修改”机制不可逆，则在 `VanillaRollout` 进行返回构建的前一瞬打拦截补丁。利用 `input_processor` 留下的定点指纹（`image_token_indices`）执行原位的逆向缝合手术。
- **代码实现** (`maas_finetune/trainer/rl/rollout/ray_driver.py`):
  ```python
  # CRITICAL FIX for VLM RL: Restore -100 image tokens for PyTorch Actor alignment
  actor_aligned_token_ids = list(input_token_ids)
  import numpy as np
  if hasattr(generation_inputs, "multi_modal_data") and generation_inputs.multi_modal_data.image_data is not None:
      indices = generation_inputs.multi_modal_data.image_data.image_token_indices
      if indices is not None:
          for idx in np.array(indices).flatten():
              if idx < len(actor_aligned_token_ids):
                  actor_aligned_token_ids[idx] = -100 # 原装位置定点归传 -100
  ```
另外，在 `template.py` 中将原本因为断言报错被屏蔽的数量一致性检查 `assert total_image_tokens == total_image_token_ids` 全盘解封。

## 4. 对齐验证 (Validation)
- 验证手段：大盘重新运行 100~200 Steps 的监控。
- **PPL 回撤**: Actor 指标从 `1.78` 砸落到 `1.102`，与 Rollout 端精确同源。
- **`logprobs_diff` 收缩**: 断崖式收敛至 `0.0204`，达到了纯文本的安全训练标准。

## 5. 关联知识
- [[wiki/00_bugfix/index|环境启动与多进程异常排查]]
- 本案表明：多模态 RL 联合部署时，底层加速引擎（如 vLLM-Ascend）的 Token 静默强转操作极易引发分布式精度塌陷。
