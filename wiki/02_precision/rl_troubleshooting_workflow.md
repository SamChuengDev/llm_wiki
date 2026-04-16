---
title: "Methodology: RL 五阶段大盘定位排查法 (Troubleshooting Flow)"
tags: [methodology, workflow, debug]
last_updated: "2026-04-16"
source: [raw/docs/rl_precision_case.pdf]
confidence: high
status: active
open_questions: []
contradictions: []
---

# RL 五阶段精度异常定位标准流程

面对强化学习这种反馈延迟极高、多引擎跳变（Actor-Sampler-Ref 混合）的场景，切忌单凭报错或曲线瞎撞。务必遵循如下标准推进流水线。

## 阶段一：前置约束与随机性收缩
- 首先通篇阅读并落实 [[wiki/02_precision/rl_alignment_checklist|RL 精度对齐排查前置清单]]。
- 若算法包含了 DAPO，为了缩减随机裁剪干扰请关闭 `algorithm.filter_groups.enable=False`。
- 使能并在所有的隔离 worker 内插入 `seed_all` 获取确定性时空。

## 阶段二：成本收拢压测 (Scaling Down)
不要在漫长周期的 235B 等巨物上纠结：
- 将测试回滚到同构的小同胞模型上（如用 Qwen3-30B 代规 Qwen3-235B）。
- 下放 `train_prompt_bsz` 和序列长度。但需注意缩小 DP 会膨胀内存甚至引发 FSDP OOM 问题。

## 阶段三：推理第一步健康初切 (Inference First-Step Dump)
对框架执行第一回合干预：
- **检查生成的文字本身**：直观翻看 GPU 与 NPU 第一步输出字符串：是不是在输出多语种乱码或 `"\u0000"` 噪音？（若是，必定是权重 Resharding 错配问题）。
- **Dummy 初始化断层流检查**：配置 `vllm: load_format=dummy` 后，验证是否在推理后端由于 `view()` 把张量（比如 MLA 中的 `W_UK_T`）隔离导致了权重未能在框架里如期刷新（如 DeepSeek 典型的 Sharding 漏更新脱序故障）。

## 阶段四：训练打桩跳传验证 (Skip & Stake Rollout)
如果你确信前面的 VLLM 推断能力完全和 GPU 匹配或乱码未出现，那么我们需要通过 **打桩绕行(Stake)** 将 NPU 的推断动作“静音”：
- 启用 `actor_rollout_ref.rollout.skip_rollout=True` 与配套的 `skip_dump_dir` (使用**绝对路径避开 Ray /tmp 截断**)。
- 我们直接抛入 GPU 高质量导出的 1:1 Prompt 回答集去启动 Actor 进行 Reward 及 Loss 训练！
  - 如果此时长跑 `grad_norm` 依然出现无征兆发散、NaN，或者 N/G 机器上 Reward 和 Loss 第一步就呈现撕裂（差距>1%），这就是百分百纯粹的 **[训练侧框架算子误差/前反向量爆/踩踏]**！
  - 请针对出现漂移的第一梯队 Layer 利用 `Monitor` 工具抓捕参数，寻找类似 `moe_shared_expert_overlap` 等引发的多流重叠冲刷踩踏。另外关注如 `RMSNorm/eps` 等基础对齐是否匹配。

## 阶段五：深度下潜定界溯源 (Deep Diagnostic Dive)
如果连 GPU 的推理预制桩都喂不坏这套训练，但一旦切回完全自动化的大循环，RL 就是跑不对，此时我们进入幽暗的机制区：
- **首 Token logits 内探比对**：抓取生成侧 `forward` 层面的最根本输出层 `lm_head`。利用 `Cosine Similarity` 比对看是否超过 `99.9%`。如果没超过就可能撞上了类似 NPU DSA 硬件执行 `torch.exponential_` 所存在的非纯数学拟合硬伤等奇难杂症。
- **训推异步裂痕**：跳转诊断 [[wiki/02_precision/rl_off_policy_inconsistency|Off-Policy 训推概率严重分崩问题]]（利用 IS/RS 技术或检查是否开了 NZ 加速扰乱排布）。
