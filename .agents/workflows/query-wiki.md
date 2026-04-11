---
description: 基于 Wiki 知识库进行结构化查询并择优回写
---

# 知识查询: Wiki 检索与综合 (Query Wiki)

此工作流指导 Agent 利用已积累的 Wiki 知识回答技术问题，并将有价值的分析结果回写到 Wiki 实现知识复利。

1. **接收问题**:
   - 理解用户提出的技术问题或探索方向。
   - 明确期望的输出格式（Markdown 页面、对比表格、代码片段等）。

2. **检索索引 (Index Scan)**:
   - 读取 `index.md`，快速定位与问题相关的 wiki 页面列表。
   - 如果 `index.md` 中未找到直接相关条目，尝试按领域分类（bugfix/operators/precision/tuning/frameworks）缩小范围。

3. **深度阅读 (Deep Read)**:
   - 逐一读取定位到的 wiki 页面，提取与问题直接相关的知识。
   - 特别注意页面中的 `contradictions` 和 `open_questions` 字段——这些可能影响回答的准确性。
   - 检查页面的 `confidence` 和 `status` 字段，优先引用 `confidence: high` 且 `status: active` 的知识。

4. **综合回答 (Synthesize)**:
   - 整合多个页面的知识，给出结构化的回答。
   - 每个关键论点必须附带引用来源（如 `参考 [[wiki/02_precision/rmsnorm_bf16_nan]]`）。
   - 如果 wiki 中知识不足以回答问题，明确告知用户，并建议需要补充的原始资料类型。

5. **择优回写 (Selective Writeback)**:
   - 判断本次回答是否产生了 **新的综合知识**（如跨多个页面的对比分析、新发现的因果关联、之前未记录的最佳实践）。
   - 如果是，将其作为新页面写入 `wiki/` 对应分类下，并在 `index.md` 中收录。
   - 如果回答只是已有知识的直接重复，则不回写。

6. **日志记录**:
   - 在 `log.md` 顶部追加 `## [YYYY-MM-DD] query | <问题摘要>` 格式的条目。
   - 如果进行了回写，在日志中标注 `(writeback: wiki/xx/new_page.md)`。
