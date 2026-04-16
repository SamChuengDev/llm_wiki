---
title: "Methodology: RL 训推架构与 Off-Policy 不一致性深潜 (Off-Policy Inconsistencies)"
tags: [methodology, inference, off-policy, theory]
last_updated: "2026-04-16"
source: [raw/docs/rl_precision_case.pdf]
confidence: high
status: active
open_questions: []
contradictions: []
---

# RL 从 On-Policy 沦为 Off-Policy 的训推暗流陷阱

强化学习通常以极端“自我修正”的 On-Policy 路径设计（如 PPO），要求推演数据采样的**采样策略** ($\pi_{sampler}$) 时时刻刻应该和用于反向梯度下降更新计算的**目标策略** ($\pi_{learner}$) **保持同一具化状态**（即绝对吻合），这样梯度的偏估才能指向最陡的无偏优化空间。

> [!WARNING] 失控警报
> 大模型的高效训练使得我们将环境分割开来并行加速（如采样交由极限算子 vLLM，更新交由长尾 FSDP/Megatron）。虽然模型结构参数互通，但量化精度（如一侧 BF16、一侧 FP32）、硬件存储格式转换（NPU 的 NZ 格式与常规张量格式等）、不同后端的 `lm_head` 取舍、异步环境更新钩子不到位，导致实际上两边**出现了离散与版本断层**。
> **结果：模型不知不觉滑入了非标准未补偿的 Off-Policy 幽暗地带，梯度算出来的完全是扭曲的目标。最终表现出突然暴毙 (Reward 崩溃倒下)、长尾拒不收敛、`grad norm` 猛然起飞。**

## 1. 一致性量化雷达：Off-Policy Diagnostic Metrics

在 VeRL 系统中，我们可以开启 `actor_rollout_ref.rollout.calculate_log_probs=True` 参数来收集多项对标探测：
- **`log_ppl_diff`** 与 **`ppl_ratio`**：直击灵魂的核心差度。数值代表了模型同一具象但在“生成一瞬间”脑海中的自信度，与“被按在案板上训练”那瞬间的自信度的偏差。由于 $ppl = exp(-log\_prob)$，这是直接度量序列分布破裂大小。
- **`chi2_token` / `chi2_seq` (卡方分化)**：用于诊断采用 IS 权重校正操作时的抽样偏差方差幅度，越偏说明越难以用重要性采样纠正误差。
- **`k3_kl`**：针对小散度微调下稳定的 KL 指数距离验证探针。
- **`rollout_actor_probs_pearson_corr` (皮尔森系数)**：趋近于 1 则表明分歧未开始，仍处于强强拥抱的吻合姿态。

## 2. 硬件与精度维度的异化重组案例

过去排查中导致产生巨大的 `logp_diff` 而让 RL 策略坠崖的幽灵多出于非显像层：
- **数据阵列变形 (NZ format)**：如在推算加速引擎中，强制推行针对算力硬件立方块 Cube 所优化的专用构型排版 `VLLM_ASCEND_ENABLE_NZ`。此种构型为了高效将原本的数据在内存在揉搓重分布后直接计算；然而一旦该细小排布精度差被长程循环的强化算法嗅到，就会无限雪球为重型误差。对策：RL 推荐暂时关闭 NZ 的转化：`VLLM_ASCEND_ENABLE_NZ=0`。(详见对应实战: [[wiki/02_precision/ring_mini_nz_format_diff|NZ 数据排布导致的 Off-Policy 激化]])
- **异步交叠复制**：通信时针由于未能阻塞（Tensordict `tensor.to` 在没有勾住的后台并行拷贝），导致参考引擎取到的内存地址是旧动作的数据源，酿成不同轮次、不同步骤下模型的自回交配（引用互踩），产生庞大的虚空训练。(详见对应实战: [[wiki/02_precision/tensordict_async_memory_stomp|Tensordict 缺原生NPU支持导致异步显存重叠复制]])

## 3. 防护墙修复：Rollout Correction 回旋拉扯法则

当受制于当前架构就是存在硬性 Off-policy 环境不可避免缝隙时，可以使用修正法（Correction）：
- **重要性采样纠偏 (IS, Importance Sampling)**：
  在 `algorithm.rollout_correction` 中激活 `rollout_is: token`（或 `sequence`），赋予偏移策略极高惩罚约束（需设定 `rollout_is_threshold` 限宽保护）。
- **拒绝剔除法 (RS, Rejection Sampling)**：
  激活 `rollout_rs` 与上/下阈值裁决（`rollout_rs_threshold_lower`）。当 `Logp` 偏差剧烈偏离正道时，选择在当前批次硬性阻拦斩杀这轮采样而不予其参与更新反馈。

## 4. 关联知识
- [[wiki/02_precision/rl_troubleshooting_workflow|五阶段大盘定位排查主流程 (Workflow)]]
