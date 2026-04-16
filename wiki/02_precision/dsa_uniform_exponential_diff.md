---
title: "Precision: DSA uniform 带来的指数分布差异"
tags: [status/resolved, category/diff]
last_updated: 2026-04-16
source: [raw/docs/rl_precision_case.pdf]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Precision Alignment Report: NPU 硬件随机数实现异构导致的分布偏差

## 1. 差异现象 (Deviation Symptoms)
- **现象**: vLLM 采样推断环节，虽然随机数 seed 一致且开启了确定性计算，NPU 与 GPU（基于 `curand_uniform`）产出的首个 Token 分布依然严重倾斜，无法达成逐词级拟合。
- **数据类型**: FP32/UINT32 (分布采样数)

## 2. 定位过程 (Debugging Process)
- **使用工具**: 数值分布验证、底层指令层剥离比对。
- **可疑算子/模块**: `torch.exponential_` / NPU DSA Uniform 生成器
- **排查逻辑**: 引擎内采用了 torch 侧的 `exponential_` 算子；在 GPU 上是直接调动 `curand_uniform` 随后处理。但在 NPU 上，首先通过 DSA 电路吐出 `UINT32` 伪随机数在转型为 `FP32`，其中累积加上 torch 基于不同边界区间设定的 increment，导致与 GPU 产生了严重的对齐差异。

## 3. 修复方案 (Alignment Fix)
- **方案描述**: 将这部分的计算完全替换为在 AICore 上的前向纯软件模拟（模拟 `curand_uniform` 的具体行径与生成）。然而这样性能损伤 10 倍以上，于是修改为由 `vllm-ascend` 分配一条独立的推算流异步预先计算好指数分布掩盖运行负荷。
- **代码实现**: 目前位于 `vllm-ascend` C++ 后端。

## 4. 对齐验证 (Validation)
- **验证手段**: 更新 vllm-ascend 解决该算子后，在 Math500 测试集的 500 道测题上，首个 token 对齐率从 73/500 大跨步跃升至 498/500。

## 5. 关联知识
- [[wiki/01_operators/index|Ascend NPU DSA 设计]]
