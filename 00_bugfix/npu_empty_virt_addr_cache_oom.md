---
title: "Bugfix: empty_virt_addr_cache 导致 NPU 物理显存未归还引发 OOM"
tags: [status/resolved, priority/critical, category/oom]
last_updated: 2026-05-06
source: [outputs/logs/vlm_0506_201101.log, torch_npu/csrc/core/npu/NPUCachingAllocator.cpp]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Bugfix Report: empty_virt_addr_cache 导致多进程架构下 NPU 物理显存泄露 OOM

## 1. 现象描述 (Symptoms)
- **环境**: NPU 61GB, VLM 2.5B RL 训练框架 (EngineWorker + ActorWorker 多进程同卡架构), 开启 `expandable_segments:True`
- **报错信息**:
  ```text
  RuntimeError: NPU out of memory. Tried to allocate 194.00 MiB (NPU 3; 61.28 GiB total capacity; ... 117.27 MiB free; 27.33 GiB reserved in total by PyTorch)
  ```
- **复现场景**: RL 训练的 ActorWorker 在执行 `optimizer.step()` 时稳定触发 OOM。从日志监控发现，EngineWorker (Rollout) 虽然进行了大量的 Python 层面对象回收 (如清理 MoE Workspace 和隐藏状态)，但是 `npu-smi` 显存依然居高不下。

## 2. 根本原因分析 (Root Cause)
在开启了 PyTorch 虚拟显存特性 (`expandable_segments:True`) 后：
1. `torch.npu.empty_virt_addr_cache()` 底层对应 C++ 实现中的 `emptyCacheImpl(check_error, false)`，其中的 `free_physical=false`。这导致 NPUCachingAllocator 只调用了 `AclrtUnmapMem` 解除虚拟地址映射，而将物理显存句柄强行扣留在当前进程的 `free_physical_handles_` 缓存池中，**并没有向 NPU 操作系统底层释放物理内存**。
2. 由于 EngineWorker 与 ActorWorker 分属不同的独立进程，EngineWorker 即使释放了大量的 PyTorch Tensor，但只要使用了 `empty_virt_addr_cache()`，这高达数十 GB 的物理显存依然被 EngineWorker 进程私吞。
3. 导致 ActorWorker 在接手进行训练计算（前向、反向、特别是 Adam 优化器）时，无法从 NPU 操作系统获取足够的物理显存页，从而引发假性的 `NPU out of memory`。

## 3. 解决方案 (Solution)
### 终极方案 (Fix)
在**所有**调用 `torch.npu.empty_virt_addr_cache()` 的地方，紧随其后增加一行 `torch.npu.empty_cache()`：
```python
torch.npu.empty_virt_addr_cache()
torch.npu.empty_cache()  # 必须添加，强制归还物理句柄
```
`empty_cache()` 在 C++ 底层会将 `free_physical` 置为 `true`，从而不仅解绑虚拟地址，还会调用 `AclrtFreePhysical(handle)` 彻底将物理内存所有权交还给 NPU 驱动层，使得其它进程 (ActorWorker) 能够成功申请。

## 4. 验证结果 (Verification)
在修正之后运行的 `vlm_0506_201101.log` 中：
1. EngineWorker 在 `empty_cache()` 执行后，显存占用瞬间从 ~18GB 暴降到 `6.62GB`。
2. ActorWorker 启动前的内存探针显示：`[Actor Memory Probe] Before Step Loop: 33.33 GB Free / 61.28 GB Total.`。成功接手了从 EngineWorker 吐出来的物理显存。
3. 优化器步骤完美穿透：`[Actor Memory Probe] Before optimizer step: alloc=15.97 GB, reserved=16.05 GB`。不仅未触发 OOM，还剩下了接近一倍的显存冗余。

## 5. 沉淀与关联
- 关联知识点: 多进程显存管理, PyTorch 可扩展段 (Expandable Segments) 的坑。
