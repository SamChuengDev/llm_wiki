---
title: "Precision: Tensordict 原生不适配导致异步内存踩踏"
tags: [status/resolved, category/diff]
last_updated: 2026-04-16
source: [raw/docs/rl_precision_case.pdf]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Precision Alignment Report: Tensordict 在 NPU 的异步错误

## 1. 差异现象 (Deviation Symptoms)
- **现象**: Qwen 长跑流程极度不稳，且 `grad_norm` 频发极高的尖刺并长期高于 GPU 基线。
- **数据类型**: 通用 (Memory Address Issue)

## 2. 定位过程 (Debugging Process)
- **使用工具**: 开启确定性，打桩排查前向与反向输入数据内存地址 (`tensor.data_ptr`)。
- **可疑算子/模块**: `tensordict.to`
- **排查逻辑**: 强行把打桩内容喂给第二步反演后恢复正常表明错误来自第二步开始的 Reference Engine 异步产出失效；地址校验发现 `ref_logp` 与老旧的 `old_logp` 分配了完全一致的内存基地址。根因指向到利用 `tensordict` 时底层的 `tensordict.to()` 属于异步提交，然而 NPU 端缺少特定的框架钩子（`torch.cuda.is_initialized` 固定为 False）未能正确阻塞或附带 sync。这就使得 `actor_worker` 在 CPU 推演还没准备好的时候污染了 `ref_worker` 的同一处共享显存栈，形成错乱。

## 3. 修复方案 (Alignment Fix)
- **方案描述**: 推进升级已补全 NPU 同步行为和钩子的包版本。
- **代码实现**:
  ```bash
  # 升级至包含 NPU Native Support 的版本
  pip install tensordict==0.10.0
  ```

## 4. 对齐验证 (Validation)
- **验证手段**: 运行过程被同步隔离干净，不再出现同地址重复映射，梯度无尖刺。

## 5. 关联知识
- [[wiki/00_bugfix/index|环境修复与排错]]
