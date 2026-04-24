---
title: "Bugfix: OOM 导致 MoeDistributeDispatchV2 算子死锁"
tags: [status/resolved, priority/high, category/oom]
last_updated: 2026-04-24
source: [maas_engine_vlm2b5/outputs/logs/vlm_bs_16_0423_222341.log, plog.err]
confidence: high
status: resolved
open_questions: []
contradictions: []
---

# Bugfix Report: OOM 导致 MoeDistributeDispatchV2 算子死锁与集群崩溃

## 1. 现象描述 (Symptoms)
- **环境**: NPU (Ascend 910B 64GB), VLM 2.5B RL 训练
- **报错信息**:
  - `plog.err` 在 Rollout 运行期间频繁出现物理显存分配失败 (全集群高达 200+ 次):
    ```text
    [ERROR] RUNTIME(3717568,r.update):2026-04-23-23:34:33.485.417 [npu_driver.cc:6926]3746335 MallocPhysical:[drv api]halMemCreate failed drvRetCode=6, size=20971520(bytes), flags=0, ErrCode=207001, desc=[driver error:out of memory], InnerCode=0x7020016
    [ERROR] RUNTIME(3717565,r.update):2026-04-23-23:34:43.616.490 [npu_driver.cc:6926]3746293 MallocPhysical:[drv api]halMemCreate failed drvRetCode=6, size=20971520(bytes), flags=0, ErrCode=207001, desc=[driver error:out of memory], InnerCode=0x7020016
    ```
  - 应用层 `vlm_*.log` 最终抛出致命崩溃，显示 gRPC 连接不可用，xworker 被杀：
    ```text
    grpc.aio._call.AioRpcError: <AioRpcError of RPC that terminated with:
    status = StatusCode.UNAVAILABLE
    details = "Cancelling all calls"
    ```
    或者是 Actor 侧在执行 PPO 更新的 `optimizer.step()` 时报出 PyTorch OOM：
    ```text
    RuntimeError: NPU out of memory. Tried to allocate 66.00 MiB (NPU 1; 61.28 GiB total capacity...)
    ```
- **复现条件**: `n=8` (每个 prompt 生成 8 个 trajectory) 且 `batch_size=16`，总并发生成请求达 128 个。

## 2. 根本原因分析 (Root Cause)
起初日志中 `MoeDistributeDispatchV2` 算子的 AlltoAll 通信超时与死锁极具迷惑性。
经结合底层 `plog` 排查，**根本原因是并发负载过高导致的单卡 64GB 物理显存 OOM**。
- VLM 架构中，Actor（训练进程）和 Rollout（推理进程 xworker）共享同一批物理 NPU。
- 在 `n=8, bs=16`（128 个并发请求）的高负载下，推理端的 KV Cache 池与中间激活值极其庞大。
- 此时单张 NPU 上，PyTorch (Actor 侧) 预留约 30GB，推理侧 (XLLM) 也吞噬约 30GB，物理总显存濒临极限。
- 在生成阶段的中后期，推理侧在执行 MoE 算子 `MoeDistributeDispatchV2` 时，试图向系统申请 20MB 临时 Buffer 失败，导致算子挂起；进而在 **18 分钟**（即 **MOE 算子内部 HCCL 集合通信的默认超时时间**）后触发致命超时，导致 RPC 连接断开，进程被 OS 强杀。
- **关键时序证据**: 底层 `plog.err` 记录的最早密集 OOM 报错时间为 `23:34`，而应用层最终崩溃、抛出 RPC Terminated 异常的时间为 `23:52`。两者时间差恰好为 18 分钟。这证明了：算子在 `23:34` 遇到 OOM 僵死，集群挂起硬抗了 18 分钟后，最终触达 **HCCL 默认超时上限**而崩溃。
- **因果倒置**: 算子死锁与长达 18 分钟的挂起超时只是底层物理显存 OOM 导致的下游连带后果。

## 3. 解决方案 (Solution)
### 临时方案 (Workaround)
- **降配总负载**：将 `batch_size` 减半至 `8` 并保持 `n=4`（或者 `batch_size=16` 配合 `n=2`），让总并发降低至 32。这能确保 KV Cache 和 Actor 的前反向传播激活值保持在 NPU 的安全水位，杜绝此类伪死锁问题。

### 终极方案 (Fix)
- **开启 PyTorch 反碎片化**：通过设置环境变量开启按需动态扩展，缓解连续空间不足的伪 OOM。
  ```bash
  export PYTORCH_NPU_ALLOC_CONF="expandable_segments:True"
  ```
- **架构剥离 (Future)**：将 推理 与 训练 资源拆分到异构/独立的集群，消除显存分时复用的互相踩踏隐患。

## 4. 验证结果 (Verification)
修改参数为 `batch_size=8, n=4` 并在脚本中加入 `PYTORCH_NPU_ALLOC_CONF` 后：
1. 观察到 `global_step=1` 正常触发。
2. Rollout 生成 32 轨迹平稳落地，未见任何 `AioRpcError` 与 `terminated`。
3. `ActorWorker` 在反向传播与 Adam 状态分配（`torch.zeros_like`）时顺畅通过。
4. `plog.err` 侧再无 `207001` (halMemCreate failed) 报错。

## 5. 沉淀与关联
- 关联知识点: VLM RL 架构显存分时共享约束
