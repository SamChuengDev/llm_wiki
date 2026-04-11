---
title: "Precision: [精度问题简述]"
tags: [status/resolved, category/nan|overflow|diff]
last_updated: YYYY-MM-DD
source: [raw/docs/xxx.md]
---

# Precision Alignment Report: [对齐项标题]

## 1. 差异现象 (Deviation Symptoms)
- **现象**: [如：训练 1000 step 后 Loss 突变发散，或输出 logits 与 GPU 基线对不齐]
- **数据类型**: [FP16 / BF16 / FP32]

## 2. 定位过程 (Debugging Process)
- **使用工具**: [例如：PTA 精度比对工具，或手动 dump tensor]
- **可疑算子/模块**: [例如：`RMSNorm` 或 `RoPE`]

## 3. 修复方案 (Alignment Fix)
- **方案描述**: [例如：该层计算敏感，强制将累加器 Cast 为 FP32]
- **代码实现**:
  ```python
  # 修复前
  # out = x + y
  # 修复后
  out = x.float() + y.float()
  out = out.half()
  ```

## 4. 对齐验证 (Validation)
- 验证手段：[如：Cosine Similarity > 0.999，或 Loss 曲线完全拟合]

## 5. 关联知识
- [[wiki/02_precision/overflow_handling|相关基础概念]]
