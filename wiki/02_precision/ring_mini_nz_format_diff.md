---
title: "Precision: ring mini 开 NZ 训推算子不一致"
tags: [status/resolved, category/diff]
last_updated: 2026-04-16
source: [raw/docs/rl_precision_case.pdf]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Precision Alignment Report: NZ 数据排布导致的 Off-Policy 激化

## 1. 差异现象 (Deviation Symptoms)
- **现象**: model 推理近 100 步左右后，出现明显异常的训推不统一特征：
  - `rollout_probs_diff_mean` 从容差逼近发散界线；
  - `training/rollout_actor_probs_pearson_corr`（分布空间皮尔森系数）从理想的 `>99.9%` 下跌崩溃。
  导致 reward 急剧倒下后触发满盘梯度爆炸。与标杆环境比较，GPU 在 400 步后才面临收敛天花板，且可动用 ICEPOP 从 400 托底挣扎至 1200 步；但 NPU 跑线极短。
- **数据类型**: NZ-Format / FP32

## 2. 定位过程 (Debugging Process)
- **使用工具**: logp 计算、ICEPOP 排查工具。
- **可疑算子/模块**: VLLM-Ascend 矩阵算子、NZ 格式支持
- **排查逻辑**: NZ 是 NPU 的 Cube 运算单元要求的一种特殊加速排布格式。由于推理被强制作了 NZ 维度排布加速，与训练使用的算子无法严格咬合一致，引起了训推之间的推断方差被扩大成了重度 Off-Policy 不一致而致使强化学习迅速崩盘。

## 3. 修复方案 (Alignment Fix)
- **方案描述**: 直接停用推理框架 vllm-ascend 的 NZ 全局环境变量排布。
- **代码实现**:
  ```bash
  # 禁用推理中的 NZ cast 格式转换
  export VLLM_ASCEND_ENABLE_NZ="0"
  ```

## 4. 对齐验证 (Validation)
- **验证手段**: 环境配置后，能够安全突破到 300+ 乃至 1000 step 而不触发早期的 reward 爆开口现象。

## 5. 关联知识
- [[wiki/02_precision/index|On/Off-Policy 方差分析]]
- [[wiki/02_precision/rl_off_policy_inconsistency|训推架构 Off-Policy 异构发散诱因与对策]]
