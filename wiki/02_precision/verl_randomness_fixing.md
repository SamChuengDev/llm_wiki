---
title: "Precision: VeRL 训练随机性无法固定"
tags: [status/resolved, category/diff]
last_updated: 2026-04-16
source: [raw/docs/rl_precision_case.pdf]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Precision Alignment Report: Ray 多进程下确定性无法透传问题

## 1. 差异现象 (Deviation Symptoms)
- **现象**: Qwen2.5-72B GRPO 训练过程中 reward 出现尖刺，单次前反向实验在入口开启了 deterministic 计算仍无法固定输入输出，尤其是最后一层 FA 算子。
- **数据类型**: FP16/BF16/FP32 均受随机性影响。

## 2. 定位过程 (Debugging Process)
- **使用工具**: msprobe 收集整网 dump 及 plog 确定性状态查询、ray 分布式观察。
- **可疑算子/模块**: FA (FlashAttention) 算子、Ray Actor 分布式调度系统
- **排查逻辑**: 框架侧在 pretrain 入口设置了 `seed_all` 但 plog 显示 worker 侧 FA 算子未使用确定性实现。由于 Ray 集群在启动后环境变量为快照只读，且需要在进程创建时通过 `runtime_env` 显式覆盖。

## 3. 修复方案 (Alignment Fix)
- **方案描述**: 需要绕过入口的环境变量快照设定，直接在 Ray Worker 内（进行前反向计算的进程）执行 `seed_all` 获取彻底的硬件确定性计算。
- **代码实现**:
  ```python
  # 在 verl/workers/fsdp_workers.py 或 megatron_workers.py Worker 开头添加：
  from msprobe.pytorch import seed_all
  seed_all(seed=1234, mode=True)
  ```

## 4. 对齐验证 (Validation)
- **验证手段**: 20步长跑测 grad 结果能够达到完全一致。

## 5. 关联知识
- [[wiki/04_frameworks/ray_tuning|Ray 分布式框架]]
