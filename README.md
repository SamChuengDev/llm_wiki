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
与其在主项目中建立软链接（经核实，Antigravity IDE 的文件扫描系统为防死循环，会**彻底忽略全部软链接**），**最无缝且在任意项目中都能调用的方式**是将源文件实体同步（Hard Copy）到全局配置目录下。

为此，我们在仓库根目录提供了一键同步脚本：

```bash
chmod +x sync_workflows.sh
./sync_workflows.sh
```
*执行上述脚本后，底层引擎会把最新的提取流推送到 `~/.gemini/antigravity/global_workflows/` 下。无需重启，轻敲 `/` 即可立刻唤醒 `Ingest Bugfix` 等命令。由于是硬拷贝，未来如果您微调了规则，需要重新执行一次该脚本。*

## 🛠️ AI Agent 交互

本项目深度集成了 AI Agent 指令。当使用 Antigravity IDE 时，Agent 会自动遵循目录规范，通过 `Ingest` 流程吸收新知识，并通过 `Vibe Coding` 流程产出高质量的 Infra 代码。

**预置的 Agent Workflows:**
您可以在 `/workflows>` 界面直接触发（或输入对应斜杠命令）：
- **Ingest Bugfix** 开发 / 排错经验吸收 (`.agents/workflows/ingest-bugfix.md`)
- **Ingest Tuning** 性能调优分析与指导生成 (`.agents/workflows/ingest-tuning.md`)
- **Ingest Precision** 精度对齐步骤总结 (`.agents/workflows/ingest-precision.md`)
