# Changelog (更新日志)

所有由 AI Agent (Antigravity) 执行的知识吸收 (Ingest) 和维护操作都将记录在此。

---

## [2026-04-11] Ingest: Precision - VLM RL `logprobs_diff` 根因分析
- **来源**: 本地工作汇报 (`vlm_rl_root_cause_analysis.md`)
- **提取点 1**: 定位因推理引擎底层的防错篡改，导致 RL 流程中特殊 token `-100` 全部变成 `1` 的幽灵 Bug。
- **提取点 2**: 记录下利用 `image_token_indices` 指纹定点打补丁，恢复 `Actor` 图像感知特征的手段。
- **提取点 3**: 记录了 `logprobs_diff` 从 `0.58` 断崖下降恢复到 `0.02` 以满足多模态强化学习的验收标准。

## [2026-04-11] Init: 初始架构构建
- **提取点 1**: 构建项目核心目录结构 (`wiki/`, `raw/`, `templates/`)。
- **提取点 2**: 初始化 `.antigravityrules` 角色与工作流指令。
- **提取点 3**: 建立 `index.md` 全局知识图谱入口。
