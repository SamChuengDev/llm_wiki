# Log (操作日志)

所有由 AI Agent 执行的操作（Ingest / Query / Lint）均按时间倒序记录在此。
格式规范：`## [YYYY-MM-DD] <operation> | <title>`，支持 `grep "^## \[" log.md | tail -5` 快速检索。

---

## [2026-04-12] ingest | VLM Companion Encoder gRPC 路由死锁与地址错配
- **来源**: 测试会话日志 (`srv_dp16ep16.sh` 及 `xllm_client_vlm.sh`)
- **提取点 1**: 剖析了因 NPU 下 Fork 环境限制导致 `veturborpc` 获取不到套接字并引发 20004 错误的死锁本质。
- **提取点 2**: 完整梳理了将 Companion Encoder 切换至 `grpc` 之后发生的地址漂移与路由表格式错配冲突。
- **提取点 3**: 记录了通过对齐服务端(`driver_proxy`)与客户端(`routing_table`)关于 `unix` Scheme 地址拼接格式来彻底根除 `EncodeRejected` 的架构层修复手法。

## [2026-04-11] ingest | xLLM 环境映射机制与 veturborpc 拦截
- **来源**: 本地推演 (`srv_dp16ep16.sh` 及日志)
- **提取点 1**: 追踪并记录了 `veturborpc` 报错的根本原因是单 rank 的 Companion 服务隐式继承了 Launcher 的全局 RPC 配置。
- **提取点 2**: 明确了利用 `XLLM_ENCODER_METHOD` 而非 `REMOTE_EXECUTOR_METHOD` 来绕过 `InferencerConfig` 强校验的方法。

## [2026-04-11] lint | health check
- **扫描**: 6 wiki 页面 + index.md, 共 7 项检查
- **发现**: 15 个问题 (8 死链/缺页, 2 交叉引用不对称, 5 缺 frontmatter)
- **自动修复**: 7 个 (5 index 页补 frontmatter, 1 占位死链删除, 1 交叉引用修复)
- **待人工**: 8 个缺页 (规划型链接，待日后 Ingest 填充)

## [2026-04-11] ingest | VLM RL logprobs_diff 发散根因分析
- **来源**: 本地工作汇报 (`vlm_rl_root_cause_analysis.md`)
- **提取点 1**: 定位因推理引擎底层的防错篡改，导致 RL 流程中特殊 token `-100` 全部变成 `1` 的幽灵 Bug。
- **提取点 2**: 记录下利用 `image_token_indices` 指纹定点打补丁，恢复 `Actor` 图像感知特征的手段。
- **提取点 3**: 记录了 `logprobs_diff` 从 `0.58` 断崖下降恢复到 `0.02` 以满足多模态强化学习的验收标准。

## [2026-04-11] init | 初始架构构建
- **提取点 1**: 构建项目核心目录结构 (`wiki/`, `raw/`, `templates/`)。
- **提取点 2**: 初始化 `.antigravityrules` 角色与工作流指令。
- **提取点 3**: 建立 `index.md` 全局知识图谱入口。
