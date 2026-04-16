---
title: "Precision: tokenizer_config 未对齐导致 response 异常"
tags: [status/resolved, category/diff]
last_updated: 2026-04-16
source: [raw/docs/rl_precision_case.pdf]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Precision Alignment Report: Qwen3-8B tokenizer_config 差异导致推理输出对不齐

## 1. 差异现象 (Deviation Symptoms)
- **现象**: 模型 reward 与 response length 与 GPU 差异大，精度无法对齐。
- **数据类型**: 未指明，通用。

## 2. 定位过程 (Debugging Process)
- **使用工具**: md5 校验文件。
- **可疑算子/模块**: tokenizer config
- **排查逻辑**: 排查环境与参数后，利用 md5 校验权重及配置文件，发现 `tokenizer_config.json` 被更改，移除了 `chat_template` 中使能 think (思考) 的字段。这导致推理长度缺少思考过程。

## 3. 修复方案 (Alignment Fix)
- **方案描述**: 将 `tokenizer_config.json` 还原为与 GPU 完全一致的初始状态。
- **代码实现**: 无需代码修改，仅替换 json 配置。

## 4. 对齐验证 (Validation)
- **验证手段**: 推理恢复 think 过程，模型 reward 与 response length 基本对齐。

## 5. 关联知识
- 无
