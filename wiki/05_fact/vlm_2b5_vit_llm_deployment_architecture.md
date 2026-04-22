---
title: "Fact: VLM 2B5 VIT与LLM的混合部署架构约束"
tags: [status/stable, category/fact, priority/high]
last_updated: 2026-04-22
source: [outputs/logs/vlm_0422_142434.log, srv_dp16ep16.sh]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Fact: VLM 2B5 VIT与LLM的混合部署架构约束

## 1. 核心事实 (Core Fact)
在 VLM 2B5 RL 推理及单测全链路部署中，底层计算采用了“**主引擎 (LLM)** + **伴随引擎 (Companion ViT Encoder)**”的非对称物理架构设计。其中主引擎 LLM 负责承担动态 W8A8 量化的 MoE 文本及图文推理（受限于 2.5B 模型参数规模，必须且只能为 **16 DP / 16 EP / 1 TP**），而 Companion 负责处理冻结权重 (Frozen Weights) 的纯视觉特征提取。两者在本地节点 (NPU) 上强依赖基于 `unix://` (Unix Domain Socket) 的 IPC 进程间通信。

## 2. 设计背景 (Background & Rationale)
- **参数隔离与安全**：在 PPO/GRPO 训练中，由于视觉编码器 (ViT) 权重是冻结的，不产生梯度，将它与频繁更新的 LLM Actor 剥离开来（即分为两个并行进程 `xworker` 与 `ark_serve`）能够显著节约显存开销，并且在 `update_weights` 阶段不会产生死锁或错位同步。
- **IPC 高效通信**：在同一台 NPU 物理机上，通过 Unix Domain Socket 进行序列化的特征传递，相比 gRPC/TCP 网络栈能够最大化吞吐，并彻底绕开 Ascend 节点下 Fork 机制导致的 Socket Bind 端口冲突问题。
- **EP16 刚性依赖**：2B5 的 MoE 模型包含大量 Expert，由于 NPU 显存墙和计算密度的原因，现行基线物理切分配置强制锁死为 EP16。必须要有足额的 16 Rank 才能完成完整的图文流转。

## 3. 应用场景与约束 (Constraints)
- **硬件约束**：必须基于 16x NPU 卡池，不可在少于 16 卡的设备上强行拉起或降维运行（例如 DP8EP8 将直接导致模型并行失效）。
- **进程编排**：Companion 进程由底层框架拉起时，无法自动继承外层的全部路径指针，必须由主引擎显式向下层发包透传环境变量（如 `MAAS_MODEL_DIR` 以载入 Companion 模型）。
- **RPC 代理约束**：因为采用了 `unix://dp_{rank}.sock` 格式通信，主引擎必须配置 `COMPANION_XLLM_DRIVER_PROXY_WRAPPER_CONFIG__METHOD="veturborpc"` 来开启定制协议解析，否则框架会自动降级到 TCP 探测而引发连接报错。

## 4. 相关配置或引用 (References)
部署核心配置拓扑特征：
```yaml
# 核心通信与隔离层
"COMPANION_XLLM_DRIVER_PROXY_WRAPPER_CONFIG__METHOD": "veturborpc"
"MAAS_MODEL_DIR": "/data01/model_weights/2b5_saften"

# DP16/EP16
DP=16, EP=16, TP=1
```

## 5. 沉淀与关联
- 关联知识点: [[wiki/00_bugfix/vlm_companion_vit_rpc_crash|Bugfix: VLM Companion ViT RPC 连接失败与环境变量断层]]
- 关联知识点: [[wiki/05_fact/vlm_2b5_inference_service_golden_config|VLM 2B5 推理服务化部署黄金配置]]
