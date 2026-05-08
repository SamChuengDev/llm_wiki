---
title: "Bugfix: PyTorch to_empty() 精度丢失与 libc 碎片化泄漏连环坑"
tags: [status/resolved, priority/critical, category/memory, category/precision]
last_updated: 2026-05-08
source: [maas_engine_vlm2b5/outputs/logs/vlm_0508_190211.log]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Bugfix Report: PyTorch to_empty() 精度丢失与 libc 碎片化泄漏

## 1. 现象描述 (Symptoms)
- **环境**: xpu_gpt/xllm 混合推理框架, VLM 2.5B (ViT Adapter), PyTorch
- **问题一（内存黑洞）**：在 RL 训练的 Actor Rollout 轮转中，执行 `offload_weights()` 后，Host 端物理内存 (SYS RAM) 出现每步约 2GB 的硬性泄露，最终导致 Linux OOM Killer 杀死 `EngineWorker` 进程。
- **问题二（精度雪崩）**：尝试用 `to_empty()` 修复内存泄漏后，模型能够跑通，但 `logprobs_diff` 从 0.08 飙升至 0.24，模型 PPL 扩大 10 倍，图文特征彻底崩溃。

## 2. 根本原因分析 (Root Cause)
这是一起典型的底层机制冲突连环案：

1. **`to('cpu')` 导致的 libc 碎片化泄漏**：
   原始代码为了释放 NPU 显存，直接 `self.vit_model.to('cpu')`。这会在 Host 端分配 2GB 的 CPU Tensors。然而，`glibc` 对频繁的大尺寸 Tensor (由大量零散小块组成) 进行 `malloc`/`free` 时，由于内存竞技场（Arena）碎片化和 `M_TRIM_THRESHOLD` 限制，这 2GB 内存无法及时归还给操作系统内核，表现为 RSS 持续膨胀的虚假内存泄漏。

2. **`to_empty()` 与 `persistent=False` 导致的未初始化污染**：
   为解决上述问题，使用了 `self.vit_model.to('meta')` + `self.vit_model.to_empty('npu')` 实现**零 CPU 分配**的权重转储，并配以 `load_state_dict()` 填补权重。
   **大坑**：PyTorch 的 `load_state_dict()` 会默认**跳过**被声明为 `persistent=False` 的 buffers（例如 `SeedViT` 中计算 RoPE 必须的 `inv_freq` 张量）。这导致 `inv_freq` 保留了 `to_empty()` 刚刚在 NPU 上分配的“随机未初始化内存垃圾”，引起位置编码全盘错乱，精度雪崩。

3. **重新实例化模型导致的重复泄漏**：
   尝试用 `self.vit_model = None` 销毁并重新 `SeedVLForConditionalGenerationNPU()` 来恢复初始态。但这导致底层的 `_from_config()` 在 CPU 上实例化了完整的 2GB 骨架然后再 `to('npu')`，使得 libc 碎片化泄漏问题（问题 1）再次复发。

## 3. 解决方案 (Solution)

### 终极方案 (Fix)
我们必须达到双重目的：**绝对不触发 CPU 内存分配（治 OOM）** 且 **绝对不遗漏任何持久化状态（保精度）**。

1. **强行全量抓取备份（跳过 state_dict）**：
   在初始化时，使用底层遍历强行提取所有参数和 Buffer。
   ```python
   self._cpu_state_dict = {}
   for k, v in self.vit_model.named_parameters():
       self._cpu_state_dict[k] = v.cpu().clone()
   for k, v in self.vit_model.named_buffers():
       self._cpu_state_dict[k] = v.cpu().clone()
   ```

2. **使用 `to('meta')` 卸载（零开销）**：
   ```python
   self.vit_model.to('meta')
   gc.collect()
   empty_cache()
   ```

3. **使用 `to_empty` 并手动强制修补 Buffers（完美复原）**：
   ```python
   self.vit_model.to_empty(device='npu')
   self.vit_model.load_state_dict(self._cpu_state_dict, strict=False)
   # 手动强制覆写被 load_state_dict 遗漏的 persistent=False 的 Buffer
   for k, v in self.vit_model.named_buffers():
       if k in self._cpu_state_dict:
           v.copy_(self._cpu_state_dict[k])
   ```

## 4. 验证结果 (Verification)
- **内存表现**：`EncoderDriver` 的 `rss` 在多次 `offload` / `update` 循环中增量为绝对的 **0.00G**，彻底解决了 2GB/step 的泄漏。
- **精度表现**：`logprobs_diff` 在长跑中回落至极健康的 **0.02** 水平，`reward.mean` 稳定上涨。

## 5. 沉淀与关联
- 关联知识点: [[wiki/03_tuning/memory_leak_libc_pytorch|PyTorch libc 碎片化引起的虚假泄漏排查]]
- 关联知识点: [[wiki/02_precision/load_state_dict_persistent_false|load_state_dict 忽略 persistent=False 的精度踩坑]]
