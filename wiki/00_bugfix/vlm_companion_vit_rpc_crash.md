---
title: "Bugfix: VLM Companion ViT RPC 连接失败与环境变量断层"
tags: [status/resolved, priority/high, category/communication]
last_updated: 2026-04-22
source: [maas_finetune/trainer/rl/rollout/xllm_backend]
confidence: high
status: closed
open_questions: []
contradictions: []
---

# Bugfix Report: VLM Companion ViT RPC 连接失败与环境变量断层

## 1. 现象描述 (Symptoms)
- **环境**: Ascend NPU, VLM 2.5B RL, DP16EP16 并发架构
- **报错信息**:
  在切换到图文数据集（MathVerse）并启动 RL 训练时，主引擎（LLM xworker）在初始化连接 Companion（ViT 视觉编码器）时抛出以下严重错误：
  ```text
  EncodeRejected: encoder|unix:dp_0.sock|RPCError('RpcErrorCode: 20002, message: create channel error, remote: dp_0.sock:0')
  ```
- **复现方式**: 在配置了 `companion` 视觉编码器的节点上，使用 `unix://dp_0.sock` 进行进程间通信时必然触发崩溃。

## 2. 根本原因分析 (Root Cause)
报错的根本原因在于主引擎与副引擎（Companion）的通信协议解析及环境映射出现了两处断层：

1. **RPC 协议解析错误**：主引擎（LLM xworker）尝试通过 Unix Domain Socket 连接 Companion 时，底层 RPC 客户端未能正确识别 `unix://` 前缀。由于环境变量 `COMPANION_XLLM_DRIVER_PROXY_WRAPPER_CONFIG__METHOD` 缺失或不匹配，RPC 客户端将其错误识别为 TCP 地址，从而画蛇添足地追加了 `:0` 端口号（变成 `dp_0.sock:0`），导致 Socket Channel 创建失败。
2. **权重路径环境变量丢失**：Companion 引擎在独立进程（`ark_serve`）拉起时，由于环境变量隔离，未能继承主引擎配置的物理路径，尝试加载缺省 `_model_dir` 导致模型加载失败。

## 3. 解决方案 (Solution)
### 终极方案 (Fix)
针对通信层与架构层的修改已固化到 `m8_vlm_xg` 分支，包括以下关键步骤：

- [x] **纠正通信配置前缀**：在 `maas_finetune/trainer/rl/rollout/xllm_backend/engine.py` 及 `launch_envs.py` 中，显式注入 `COMPANION_XLLM_DRIVER_PROXY_WRAPPER_CONFIG__METHOD="veturborpc"`，确保底层 RPC 正确切入 Unix Socket 代理逻辑。
- [x] **修复环境变量继承**：在 `3rdparty/xllm/xllm/service/rpc/ark/serve.py` 中，为 Companion 进程显式回填 `MAAS_MODEL_DIR` 环境变量：
  ```python
  companion_model_dir = os.environ.get("MAAS_MODEL_DIR", self._model_dir)
  self._companion_launcher = ArkLauncher(companion_model_dir, self._companion_driver_type, yaml_file)
  ```
- [x] **放大 C++ 握手超时**：在 `xllm/backend/driver/routing/routing_policy.py` 中，将硬编码的 `timeout=1` 更改为环境变量驱动的超时配置 `timeout=XLLM_ENV.REMOTE_DRIVER_REQUEST_TIMEOUT_SECONDS`，防止并发启动时响应过慢导致误杀。

## 4. 验证结果 (Verification)
修复后：
1. `unix://dp_{rank}.sock` 被正常识别并绑定。
2. `[SUCCESS] Both LLM and VLM Stress Tests Passed Successfully!` 单测完全通过，训推图文特征无断崖下跌。
3. RL 奖励收敛正常，无死锁情况发生。

## 5. 沉淀与关联
- 关联知识点: [[wiki/04_frameworks/veturborpc_unix_socket]] (如果存在)
