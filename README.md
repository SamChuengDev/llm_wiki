# LLM-WIKI: AI Infra 异构计算知识库

本项目是一个专门针对大模型在异构硬件（如华为 Ascend NPU）上的迁移、适配、调优与 Debug 的知识库。

## 🚀 核心架构

- **`.antigravityrules`**: 赋予 AI Agent (Antigravity) 首席架构师角色，定义知识处理流。
- **`index.md`**: 知识图谱入口 (Map of Content)。
- **`wiki/`**: 核心知识区，包含算子映射、精度对齐、性能调优等。
- **`raw/`**: 原始资料收集区。
- **`templates/`**: 规范化沉淀模板。

## 📦 Submodule 挂载指南与 Workflow 激活

配置当前 `llm_wiki` 仓库为主项目的子模块：

```bash
git submodule add https://github.com/SamChuengDev/llm_wiki.git projects/llm_wiki
```

**⚠️ 唤醒快捷工作流（关键步骤）**：
由于 Antigravity IDE 默认只扫描主项目根目录下的 `.agents/workflows/` 寻找快捷指令。为了能在主项目中直接敲出 `/Ingest Bugfix` 斜杠命令，您**不需要拷贝文件（以免破坏版本控制的双向同步）**，而是建议**建立软链接 (Symlink)**：

```bash
mkdir -p .agents/workflows
ln -s projects/llm_wiki/.agents/workflows/ingest-bugfix.md .agents/workflows/ingest-bugfix.md
ln -s projects/llm_wiki/.agents/workflows/ingest-tuning.md .agents/workflows/ingest-tuning.md
ln -s projects/llm_wiki/.agents/workflows/ingest-precision.md .agents/workflows/ingest-precision.md
```

## 🛠️ AI Agent 交互

本项目深度集成了 AI Agent 指令。当使用 Antigravity IDE 时，Agent 会自动遵循目录规范，通过 `Ingest` 流程吸收新知识，并通过 `Vibe Coding` 流程产出高质量的 Infra 代码。

**预置的 Agent Workflows:**
您可以在 `/workflows>` 界面直接触发（或输入对应斜杠命令）：
- **Ingest Bugfix** 开发 / 排错经验吸收 (`.agents/workflows/ingest-bugfix.md`)
- **Ingest Tuning** 性能调优分析与指导生成 (`.agents/workflows/ingest-tuning.md`)
- **Ingest Precision** 精度对齐步骤总结 (`.agents/workflows/ingest-precision.md`)
