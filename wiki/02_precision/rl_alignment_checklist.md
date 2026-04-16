---
title: "Methodology: RL 精度对齐排查前置清单 (Alignment Checklist)"
tags: [methodology, checklist, alignment]
last_updated: "2026-04-16"
source: [raw/docs/rl_precision_case.pdf]
confidence: high
status: active
open_questions: []
contradictions: []
---

# RL 精度对齐排查前置确认清单 (Golden Checklist)

在怀疑框架 C++ 内部或算子实现发生崩溃前，约有 70% 的精度偏差其实来源于外围环境及任务超参的微弱差异被长程放大。正式深度 Debug 前，请严格逐项验证以下四大块（GPU vs NPU）。

## 1. 模型结构与基建包版本 (Environment & Weights)

- [ ] **底层框架/编译器一致**：`torch_npu`、`VeRL` 分支环境的 Commit 是否在同个时代周期。`tensordict` 是否 >= `0.10.0` （防止其原生由于旧环境缺少 `.is_initialized` 保护进而引发 `tensordict.to()` 异步内存交叉踩踏）。
- [ ] **权重 `md5` 强制查验**：切勿想当然！对 `model-00001-of-00002.safetensors` 文件执行 `md5` 比对，保证无缝拉取。
- [ ] **配置文件查重**：比较 `tokenizer_config.json` 是否有一端缺失或被篡改了 `chat_template` 导致缺失了特定的 (e.g. `<think>`) 上下文引导标签！

## 2. 数据输入与乱序开关 (Data & Loaders)

为了将强化学习这头随机的野兽锁定到唯一路径：
- [ ] **关闭数据扰动**：设定 `data.shuffle=False` 保证输入次序确定。
- [ ] **调度锁死**：关闭动态平衡（`trainer.balance_batch=False`），否则因长度自适应在多卡重排样本会导致 DP 内的切片乱序。
- [ ] **截断处理同步**：超长控制 `max_prompt_length`，抛除截断控制 `filter_overlong_prompts` 两端对齐一致。

## 3. RL PPO 特定超参 (Hyperparameters)

使用 `diff` 或肉眼严格核对 `ppo_trainer.yaml`：
- [ ] **全局 Batch 相关**：`train_batch_size` 影响着采样后总体的优化窗口及探索范围估算池。
- [ ] **微批次切分控制 (Micro-batch & Dynamic BS)**：检查由 `actor_rollout_ref.*.ppo_micro_batch_size_per_gpu` 以及动态开关 `use_dynamic_bsz` 指定的控制规则！
- [ ] **分布式映射体系**：保证 `rollout` 的 DP/TP/PP 架构和后端相匹配：
  `actor_rollout_ref.rollout.tensor_model_parallel_size` 同构对于推理生成算子具有底层分布定势。
- [ ] **算法层干扰项过滤**：临时关闭特殊的过滤器，如 DAPO 等为了对齐一律设 `algorithm.filter_groups.enable=False`。

## 4. 全局确定性 (Randomness Freezing)

如果在环境全一致后**连第一步**都无法重复出现，请激活“决定论宇宙”模式：
- [ ] 使用 `msprobe.seed_all()`（内置接管各项 CANN 确定性变量：`HCCL_DETERMINISTIC`，关闭 Shuffle-K），**非常重要：此语句必须插桩到 Worker 类的进程体内（如 `megatron_workers.py` 中）**，因 Ray 启动环境后采用只读快照机制剥离环境变量传播！(详见对应实战案例: [[wiki/02_precision/verl_randomness_fixing|Ray 多进程下 VeRL 确定性无法透传问题]])
- [ ] VLLM Scheduler 在多并发时会被时间扰动切碎请求 batch 序，强行采用单卡控制流：`VLLM_ENABLE_V1_MULTIPROCESSING=0`。
- [ ] vLLM 推理采样 `temperature=1.0, top_k=-1, top_p=1.0`。

## 5. 关联知识
- [[wiki/02_precision/rl_troubleshooting_workflow|五阶段大盘定位排查主流程 (Workflow)]]
