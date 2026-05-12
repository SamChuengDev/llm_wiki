---
title: "Bugfix: 宿主机 OOM 与 SYS 物理内存持续增长 (glibc malloc arena 碎片化)"
tags: [status/resolved, priority/high, category/oom, host, memory]
last_updated: 2026-05-09
source: [vlm_0508_190211.log]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Bugfix Report: 宿主机 OOM 与 SYS 物理内存持续增长 (glibc malloc arena 碎片化)

## 1. 现象描述 (Symptoms)
- **环境**: NPU 910B (16 卡), PyTorch, Ray Distributed RL 集群, xpu_gpt/xLLM
- **报错信息**: 
  长跑训练 (RL) 过程中发生 Host 物理内存 (SYS) 被耗尽，引发 OOM 导致节点崩溃或 Ray worker 被系统强制驱逐 (OOM-killer)。
  即使监控显示每个进程内部的 Python 层显存 (如 `ActorWorker`, `xLLM XWorker`) 似乎处于平稳状态或涨幅有限，系统的全局 `SYS` 使用量依然以平均每步 `4GB~15GB` 的速度不可逆地持续增长，缺口高达 `150GB+`。
- **复现场景**: 启动 `ray.sh` 进行端到端 RL 训练长跑。由于系统孵化了 33+ 个长期存活的 Python 进程 (16 x `ActorWorker`, 16 x `xLLM XWorker`, `Trainer` 等)。

## 2. 根本原因分析 (Root Cause)
引发 OOM 的并非单一泄漏，而是由框架层到底层的**连环叠加导致**：

1. **Python 框架层泄漏**:
   - `xLLM::DriverCoordinator` 的 `_request_id_to_driver` 字典以及 `ZMQ ResponseManager` 积压了过期的请求上下文，导致强引用无法被 GC 释放。
   - RL Actor 在处理 microbatch 时，缓存的 `mb`, `non_tensor_mb` 变量被长线持有，导致每步都会累加。
   - `to_empty` 参数 offload 在 CPU 产生两份冗余显存映射。

2. **C 运行时底层碎片化 (Glibc Malloc Arena) [最隐蔽且影响最大的主因]**:
   - C 标准库 `glibc` 默认会为每个多线程进程分配 `8 × CPU_CORES` 个独立的内存池 (Arena)，以减少多线程情况下的 `malloc` 锁竞争。
   - 对于诸如 128 核的高配服务器，单进程可分配超过 1000 个 Arena。
   - 我们的 Ray 架构启动了 **30+ 个独立的大型 Python 进程**。在模型做频繁的 offload/load 和多线程网络 IO (gRPC/ZMQ) 时，每个进程的虚拟内存空间被高度切片。`glibc` 倾向于将这些内存保留给进程以防重新分配开销，**绝不轻易归还给 OS (Linux Kernel)**。
   - 这意味着尽管 Python 层的 `gc.collect()` 声称已回收内存，底层仍然持有庞大的 `malloc` 碎片空间，导致每个进程凭空额外占据 `~4-5GB`，33 个进程叠加后造成了高达 **154GB+** 的 "黑洞" 泄漏。

## 3. 解决方案 (Solution)
### 临时方案 (Workaround)
- [x] 在 `xLLM` driver 层显式调用 `clear_stale_entries()` 定期清空过期 ZMQ/gRPC 字典。
- [x] 在 Actor 微批次结束时调用 `del mb` 并显式触发 `gc.collect()`。
- [x] 大幅裁剪过度的并发配置：将 `XLLM_ROLLOUT_SERVER_PROCS`, `MAAS_ROLLOUT_GRPC_CHANNEL_POOL_SIZE`, `SPLITWISE_KV_TRANSFER_NUM_WORKERS` 从 64 砍至 16/32。

### 终极方案 (Fix)
- [x] **根治 Arena 碎片化**: 在 `runtime_env.yaml` 中为所有 Ray 进程（不仅是 Driver 进程，最关键的是 Actor 和 Rollout Workers）配置 `MALLOC_ARENA_MAX` 环境变量限制。这不仅消除 OOM，还能减轻 OS 内核级页表 (TLB) 的负担。
```yaml
env_vars:
  # ... 其他变量 ...
  # 【Host OOM 根治】限制 glibc malloc arena 数量，防止几十个 Python 进程碎片化
  "MALLOC_ARENA_MAX": "2"
```

## 4. 验证结果 (Verification)
加入修复后，通过注入 `[HOST MEM PROBE]` 跟踪各个进程 RSS 和总 `SYS`。
- xLLM Worker 在第 5 步后物理内存绝对锁死。
- Actor Worker 在第 40 步后物理内存达到上限不再涨。
- 全局 `SYS` 在经过初期 PyTorch Cache 和通信域暖机分配后，成功进入平稳巡航态，不再单调上升，系统拥有超过 `500GB+` 安全可用物理空间。

## 5. 沉淀与关联
- 关联知识点: [[wiki/00_bugfix/pytorch_to_empty_libc_leak_and_precision|PyTorch to_empty() 精度丢失与 libc 碎片化泄漏连环坑]]
