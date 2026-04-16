---
title: "Methodology: 强化学习精度核心监控指标 (RL Metrics Guide)"
tags: [methodology, metrics, rl]
last_updated: "2026-04-16"
source: [raw/docs/rl_precision_case.pdf]
confidence: high
status: active
open_questions: []
contradictions: []
---

# RL 精度核心监控指标体系指南

大模型强化学习（RL）的影响因素众多，包含算法动态随机性与底层算子的多重耦合。观察并解读特定的训练全景日志指标，对定位发散根因至关重要。

## 1. 策略分布健康度 (Policy Distribution)

- **`entropy` (策略熵)**：量化探险性，代表了策略分布的随机程度。
  - **偏大**：概率分布平缓，模型存在强“犹豫”感，但探索多样性极高。
  - **持续走低/极小**：模型逐渐自信。一旦过早坍塌至 `~0`，宣告策略 **“熵崩 (Entropy Collapse)”**。此时单一 token 将长期霸占 99% 采样概率，永远阻断其它的求解空间。
- **`pg_loss` (Policy Gradient 损失)**：代表新旧分布游走的幅差。
  - 差值剧烈跳闪暗示新旧策略偏转过界。通常由于训推异步、异常的大梯度或异构导致。
- **`ppo_kl` (KL 散度)**：衡量 RL 更新时被牵引的幅度。第一步在数学上应当处于 `~0`，在 VeRL 等框架实现中允许微小跳变，若异常跳升暗示 Off-Policy 失控。

## 2. 奖励对齐体系 (Reward & Sequence)

- **`reward`**：价值网或环境模拟器（Rule-based Sandbox或打分模型）给出的评价指标，反映了“最终结果正确性”或“偏好性”。如果环境是 Math500 规则，通常结合 `acc` 图表同步上攀。
- **`response length`**：大发散常常伴随着语言功能损坏。该指标断崖式下行说明幻觉生成中断（极度碎片化回退），或者上攀卡死于 `max_len` 表明极左循环重复（啰嗦胡言）。

## 3. 数值防溢防爆 (Numerical Safeties)

- **`grad_norm`**：
  - **消失 (趋零)**：说明 Actor 被彻底冻结。
  - **突刺 / NaN 爆炸**：由于 FP16 溢出或底层如 `moe_shared_expert_overlap` 在特定时序下的流复用内存踩踏等极其危险的框架逻辑引发，需要用 `npu_sanitizer` 或缩小层数隔离抓取倒数第一层的反向梯度。
- **`clip_ratio`**：频繁触顶截断保护圈（如 `1±ε`），说明模型随时处在梯度被“拉扯”至超负荷状态的危险边缘。

## 4. 训推一致化观测 (Actor vs Rollout)

- **`log_ppl_diff` & `ppl_ratio`**：衡量采样侧预言与参数更新前反向预言的一致性差距。（数学上等于 `mean(log_ppl_rollout - log_ppl_training)`）。开启此指标需要在 Rollout 加入 `actor_rollout_ref.rollout.calculate_log_probs=True`。

## 5. 快速日志分析流 (Log Parsers)

对于云端脱密环境可接入 `wandb` (`trainer.logger='["console","wandb"]'`) 自动绘制；也可将日志全拷贝使用静态分析打点网址（如 TrainingLogParser），配合配置正则表达式（`"critic/rewards/mean:"`、`"actor/grad_norm:"` 等）拉取 csv。
