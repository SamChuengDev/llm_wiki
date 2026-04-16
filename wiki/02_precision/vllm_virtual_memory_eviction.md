---
title: "Precision: 虚拟内存开关导致 KV Cache 驱逐差异"
tags: [status/resolved, category/diff]
last_updated: 2026-04-16
source: [raw/docs/rl_precision_case.pdf]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Precision Alignment Report: VLLM 显存不一致导致驱逐机制分叉

## 1. 差异现象 (Deviation Symptoms)
- **现象**: Qwen2.5 32B 长跑过程中，改变系统的虚拟内存开关会导致模型 response length 等指标产生分叉，生成不一致的 response。
- **数据类型**: 通用 (VLLM Sampling)

## 2. 定位过程 (Debugging Process)
- **使用工具**: msprobe 采集 L0 层级结构、排查调度逻辑。
- **可疑算子/模块**: VLLM Scheduler、KV Cache
- **排查逻辑**: 采集缩并注入确定性，排查 L0 层信息发现第 484 token 时 Shape 不一致现象，触发异常的源头是 `input_batch.num_reqs`。这是因为剩余可用显存在调整虚拟内存开关后存在区别，致使 VLLM 内部调度器 (Scheduler) 因预测容量差异执行了不同的请求驱逐(eviction)。

## 3. 修复方案 (Alignment Fix)
- **方案描述**: RL rollout 由于涉及大批量的推算输出，极其依赖一致的调度队列不被截断。若要比对一致性，必须强制对齐环境上硬件暴露的剩余可用显存，消除不同驱逐分支的影响。
- **代码实现**: 无 (确保运行配置与 GPU 或者集群间显存冗余状态完全同步即可)。

## 4. 对齐验证 (Validation)
- **验证手段**: 通过打桩人为控制显存占用，确保显存池水位同步后 response 生成完全一致。

## 5. 关联知识
- [[wiki/04_frameworks/vllm_npu|vLLM VRAM Scheduler]]
