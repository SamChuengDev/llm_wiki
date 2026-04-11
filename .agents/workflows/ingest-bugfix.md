# 知识吸收: Bugfix 经验 (Ingest Bugfix)

此工作流指导 Agent 从相关的报错日志或用户交流中提取排错经验，并在 Wiki 中创建结构化的知识条目。

1. **上下文提取 (支持 Submodule 感知)**: 
   - 优先通过**当前对话的上下文记录**（即 Agent 在主干项目中协助 Debug 和尝试修复的代码提交流程）来梳理思路。如果用户指定了 `raw/` 目录下的某个文件，则读取该文件。
   - 确保所有的读写操作都明确指向 `llm_wiki` 所在的子模块路径。
2. **分析故障点**: 
   - 提取环境信息（例如 CANN 版本，特定算子，框架版本）。
   - 提取核心报错堆栈或异常崩溃特征。
   - 总结导致该问题的根本原因（Root Cause），以及最终验证通过的解决方案（Workaround 或彻底的 Fix）。
3. **套用模板**: 
   - 使用 `templates/bugfix_template.md` 将提取的经验进行规范化排版。
   - 务必完整填写 Markdown 顶部的 YAML 元数据。
4. **归档至 Wiki**: 
   - 将格式化后的文档保存至相关的维基目录下（如 `wiki/01_operators/` 算子报错，或 `wiki/02_precision/` 精度报错），并确保文件名表意清晰（例如 `wiki/02_precision/attn_fp16_overflow.md`）。
5. **更新索引与日志**: 
   - 在 `index.md` 中对应的分类下添加指向新生成的知识条目的双向链接 `[[WikiLink]]`。
   - 在 `changelog.md` 顶部追加一条相关的操作日志，宣告该经验吸收完毕。
