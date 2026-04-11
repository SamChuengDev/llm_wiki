---
description: 全面检查 Wiki 健康状态并修复结构性问题
---

# 知识库维护: 健康检查 (Lint Wiki)

此工作流指导 Agent 对 Wiki 知识库进行全面的健康检查，发现并修复结构性问题，保持知识库的高质量。

1. **死链检测 (Broken Links)**:
   - 遍历 `wiki/` 下所有 `.md` 文件中的 `[[WikiLink]]` 引用。
   - 验证每个链接目标是否存在。
   - 输出死链列表并建议修复方案（删除链接 or 创建缺失页面）。

2. **孤立页面 (Orphan Pages)**:
   - 查找 `wiki/` 中没有被任何其他页面 `[[引用]]` 的页面。
   - 排除各分类的 `index.md` 文件（这些无需被引用）。
   - 建议将孤立页面连接到相关页面或收录到 `index.md`。

3. **交叉引用对称性 (Cross-Ref Symmetry)**:
   - 如果页面 A 链接到页面 B，验证 B 是否也链接回 A。
   - 列出不对称的链接对，并自动补全反向引用。

4. **矛盾检测 (Contradiction Scan)**:
   - 检查不同页面中针对同一问题（如同一报错信息、同一算子）的解法是否存在矛盾。
   - 特别关注不同 CANN/PyTorch 版本间的差异行为。
   - 标记矛盾并在相关页面的 `contradictions` frontmatter 中记录。
   - 对无法自行裁决的矛盾，向用户提问确认。

5. **陈旧检测 (Staleness Check)**:
   - 查找 `status: active` 但 `last_updated` 距今超过 90 天的页面。
   - 跳过 `status: archived` 的页面（已归档的不需要检查时效性）。
   - 输出陈旧页面列表，建议复审或标记为 `superseded`。

6. **缺页发现 (Missing Pages)**:
   - 查找被多次以 `[[WikiLink]]` 引用但尚未创建独立页面的概念。
   - 建议为高频引用的缺失概念创建页面。

7. **Frontmatter 完整性 (Schema Compliance)**:
   - 验证所有 wiki 页面的 YAML frontmatter 是否包含必要字段：
     - 必填: `title`, `tags`, `last_updated`, `source`
     - 推荐: `confidence`, `status`, `open_questions`
   - 输出不合规的文件列表及缺失字段。

8. **生成报告与日志**:
   - 将本次 Lint 的结果汇总为结构化报告，向用户汇报。
   - 在 `log.md` 顶部追加 `## [YYYY-MM-DD] lint | health check` 格式的条目。
   - 报告内容应包括: 检查项数、发现问题数、自动修复数、待人工处理数。
