# LLM-WIKI: AI Infra 异构计算知识库

本项目是一个专门针对大模型在异构硬件（如华为 Ascend NPU）上的迁移、适配、调优与 Debug 的知识库。

> 📖 基于 [Karpathy llm-wiki 模式](https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f)构建：知识不是每次从原始文档重新推导，而是被 LLM **编译一次、持续维护**的复利型知识资产。

## 🏗️ 三层架构

| 层级 | 目录 | 角色 | 所有权 |
|------|------|------|--------|
| **Raw Sources** | `raw/` | 不可变的原始资料（日志、Profiling、文档） | 人类写入，LLM 只读 |
| **Wiki** | `wiki/` | 提炼后的结构化知识库 | LLM 全权管理 |
| **Schema** | `.antigravityrules` | 定义结构、约定、操作流 | 人类 + LLM 共同演进 |

**导航文件**:
- `index.md` — 知识图谱入口 (Map of Content)，LLM 查询知识的起点
- `log.md` — 时间线操作日志，支持 `grep "^## \[" log.md | tail -5` 快速检索

## ⚙️ 三大核心操作

| 操作 | Workflow | 说明 |
|------|----------|------|
| **Ingest** | `/ingest-bugfix`, `/ingest-precision`, `/ingest-tuning` | 吸收新资料，提炼为 wiki 页面 |
| **Query** | `/query-wiki` | 基于 wiki 知识回答问题，有价值的回答回写 wiki |
| **Lint** | `/lint-wiki` | 健康检查：死链、孤立页、矛盾、陈旧、缺页 |

## 📂 Wiki 分类

```
wiki/
├── 00_bugfix/       # 环境异常与排错记录
├── 01_operators/    # GPU→NPU 算子映射与规避
├── 02_precision/    # 精度对齐（FP16/BF16 溢出、NaN 排查）
├── 03_tuning/       # 性能调优（HCCL、显存、算子融合）
└── 04_frameworks/   # 框架适配（vLLM、Megatron-LM、DeepSpeed）
```

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
