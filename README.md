# LLM-WIKI: AI Infra 异构计算知识库

本项目是一个专门针对大模型在异构硬件（如华为 Ascend NPU）上的迁移、适配、调优与 Debug 的知识库。

## 🚀 核心架构

- **`.antigravityrules`**: 赋予 AI Agent (Antigravity) 首席架构师角色，定义知识处理流。
- **`index.md`**: 知识图谱入口 (Map of Content)。
- **`wiki/`**: 核心知识区，包含算子映射、精度对齐、性能调优等。
- **`raw/`**: 原始资料收集区。
- **`templates/`**: 规范化沉淀模板。

## 📦 Submodule 挂载指南

如果需要挂载外部项目作为子模块进行分析：

```bash
git submodule add <repository_url> projects/<project_name>
```

## 🛠️ AI Agent 交互

本项目深度集成了 AI Agent 指令。当使用 Antigravity IDE 时，Agent 会自动遵循目录规范，通过 `Ingest` 流程吸收新知识，并通过 `Vibe Coding` 流程产出高质量的 Infra 代码。
