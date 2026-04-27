---
title: "Fact: VLM 2.5B RL NPU Rollout Timing Constraints"
tags: [status/stable, category/fact]
last_updated: 2026-04-27
source: "outputs/logs/vlm_bs_128_0426_203707.log"
confidence: high
status: active
open_questions: []
contradictions: []
---

# Fact: VLM 2.5B RL NPU Rollout 阶段的真实耗时约束

## 1. 核心事实 (Core Fact)
在 Ascend 910 NPU 集群（16 Ranks）上进行 VLM 2.5B 的 RL 训练时，当配置 `bsz=128`, `generation_n=8`（即单次 Rollout 下发 1024 条请求），且最大生成长度 `max_new_tokens=2048` 的情况下，首个 Rollout 过程的真实物理耗时约为 **54 分钟**，完成完整 Step 1 耗时约 60 分钟。该耗时显著超出了先前错误预估的“25 分钟”。

## 2. 设计背景 (Background & Rationale)
- NPU 的计算和调度模型下，`bsz=128` 会大量吞噬算力并对 XLLM Engine 造成高负载。为了避免 KV Cache Thrashing，我们提高了 Scheduler Block 的限制（`XLLM_MODEL_NUM_BLOCKS: 768`），这换来了系统的稳定性（0 次 Crash），但这并不意味着能将庞大的计算任务瞬间完成。
- Rollout 阶段生成长文本序列本身是 Compute-Bound（计算密集型）。由于多模态 prompt 也占用较长 Context，系统并行打满时吞吐率稳定在正常水平，但绝对耗时无法被线性压缩。

## 3. 应用场景与约束 (Constraints)
- **绝对禁止臆测耗时**：AI Agent 和人类开发者在监控测试进程时，**绝对不能**通过早期的 token 生成速度或者请求入队数量，随意臆测（Extrapolate）最终完成时间。
- **验证为王**：任何“耗时预估”都必须建立在实际打印的 `[0.20%] Training. global_step=1` 或确切的 `train/timing/data` 监控数据基础上。没有看到 `global_step=1` 之前，禁止宣布“测试成功闭环”或“达到耗时目标”。
- **长时等待预期**：在进行端到端性能摸底与对齐验证时，需有长达 1 小时的观察期准备，中途不能随意中止（除非出现 Traceback 崩溃）。

## 4. 相关配置或引用 (References)
```yaml
# 相关的耗时日志证据 (outputs/logs/vlm_bs_128_0426_203707.log)
train/timing/data: 3257.95        # Rollout 耗时约 54 分钟
train/timing/step: 3482.72        # 整个 Step 耗时约 58 分钟
train/rollout/response_length.mean: 1269.67 # 平均生成长度高达 1269 tokens
```

## 5. 沉淀与关联
- 关联知识点: [[wiki/01_architecture/xllm_engine_scheduling.md]]
