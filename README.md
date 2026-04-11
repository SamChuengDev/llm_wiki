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

**✅ 最稳健的做法：注册为全局工作流 (Global Workflows)**
与其在主项目中建立软链接（某些基于监听的 IDE 文件系统可能会安全忽略软链），**最无缝且在任意项目中都能调用的方式**是直接将其软链接到 Antigravity IDE 的全局配置目录下：

```bash
mkdir -p ~/.gemini/antigravity/global_workflows
ln -s ~/codes/llm_wiki/.agents/workflows/ingest-bugfix.md ~/.gemini/antigravity/global_workflows/ingest-bugfix.md
ln -s ~/codes/llm_wiki/.agents/workflows/ingest-tuning.md ~/.gemini/antigravity/global_workflows/ingest-tuning.md
ln -s ~/codes/llm_wiki/.agents/workflows/ingest-precision.md ~/.gemini/antigravity/global_workflows/ingest-precision.md
```
*执行上述命令后，无需区分所在项目，您均可随时通过 `/ingest` 斜杠命令直接唤醒图谱分析。*

## 🛠️ AI Agent 交互

本项目深度集成了 AI Agent 指令。当使用 Antigravity IDE 时，Agent 会自动遵循目录规范，通过 `Ingest` 流程吸收新知识，并通过 `Vibe Coding` 流程产出高质量的 Infra 代码。

**预置的 Agent Workflows:**
您可以在 `/workflows>` 界面直接触发（或输入对应斜杠命令）：
- **Ingest Bugfix** 开发 / 排错经验吸收 (`.agents/workflows/ingest-bugfix.md`)
- **Ingest Tuning** 性能调优分析与指导生成 (`.agents/workflows/ingest-tuning.md`)
- **Ingest Precision** 精度对齐步骤总结 (`.agents/workflows/ingest-precision.md`)
