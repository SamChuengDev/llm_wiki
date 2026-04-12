# Map of Content (知识入口)

欢迎来到 LLM-WIKI。这里是异构计算 Infra 知识的索引核心。
LLM 在执行 Query 时应首先读取本文件定位相关页面。

---

## 🏛️ 知识目录

### 0. [[wiki/00_bugfix/index|常规排错 (Bugfix)]]
- [[wiki/00_bugfix/vlm_grpc_companion_routing_deadlock|VLM Companion Encoder gRPC 路由死锁与地址错配]]
- [[wiki/00_bugfix/veturborpc_env_override|强行禁用 veturborpc_ext 及 xLLM 环境映射机制]]
- 日常环境异常与框架启动报错
- 业务逻辑层的 Bug 修复复盘与 Workaround

### 1. [[wiki/01_operators/index|算子迁移 (Operators)]]
- GPU (CUDA) -> NPU (CANN) 算子映射表
- 算子规避与自定义算子实现
- `torch_npu` 特有算子库

### 2. [[wiki/02_precision/index|精度对齐 (Precision)]]
- [[wiki/02_precision/vlm_rl_actor_blind_diff|VLM RL 架构级概率不一致发散 (XLLM -100 Token 丢失)]]
- FP16/BF16 溢出排查
- NaN/Inf 问题诊断
- 逐层结果对齐工具与方法

### 3. [[wiki/03_tuning/index|性能调优 (Tuning)]]
- HCCL 并发与通信优化
- 显存复用与 OOM 解决
- 算子融合 (Operator Fusion) 策略
- Profiling 结果分析

### 4. [[wiki/04_frameworks/index|框架适配 (Frameworks)]]
- **vLLM**: NPU Backend 改造点
- **Megatron-LM**: 昇腾适配版分析
- **DeepSpeed**: 加速库适配

---

## ⚙️ 操作指南

本 Wiki 遵循 [Karpathy llm-wiki 模式](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)，核心操作有三种：

| 操作 | 触发方式 | 说明 |
|------|---------|------|
| **Ingest** | `/ingest-bugfix`, `/ingest-precision`, `/ingest-tuning` | 吸收新的原始资料，提炼为 wiki 页面 |
| **Query** | `/query-wiki` 或直接提问 | 基于 wiki 知识回答问题，有价值的回答回写 |
| **Lint** | `/lint-wiki` | 健康检查：死链、孤立页、矛盾、陈旧、缺页 |

---

## 📋 日志与索引

- [[log|操作时间线]] — 按时间倒序记录所有 Ingest/Query/Lint 操作
- 快速查看最近操作: `grep "^## \[" log.md | tail -5`

---

## 🕒 最近更新

- `[2026-04-12]` 排错: [[wiki/00_bugfix/vlm_grpc_companion_routing_deadlock|VLM Companion Encoder gRPC 路由死锁与地址错配]]
- `[2026-04-11]` 排错: [[wiki/00_bugfix/veturborpc_env_override|Pydantic 拦截与 xLLM 环境映射机制]]
- `[2026-04-11]` 精度对齐: [[wiki/02_precision/vlm_rl_actor_blind_diff|VLM RL logprobs_diff 发散根因]]
- `[2026-04-11]` 初始架构构建
