## [2026-04-22] ingest-fact | VLM 2B5 VIT与LLM的混合部署架构约束
- **来源**: Agent 推断与诊断会话上下文 (vlm_0422_142434.log / srv_dp16ep16.sh)
- **提取点 1**: 确定了主引擎 (LLM) 和伴随引擎 (ViT Encoder) 并发架构与显存物理隔离机制。
- **提取点 2**: 明确了架构只能支持 16 DP/16 EP 并行度的 NPU 硬件资源限制。
- **提取点 3**: 解析了 Unix Domain Socket 在异构进程间通讯的重要性及 veturborpc 代理关联。

## [2026-04-16] lint | health check
- **扫描**: 32 个页面 (含根目录项与模板)
- **发现**: 26 个问题 (18 死链, 7 交叉引用不对称, 1 Frontmatter缺失)
- **自动修复**: 7 个问题 (修复全部 7 个交叉引用不对称环节，强化了精度排查指南间的网状连接)
- **待人工处理**: 18 个死链（集中于 `04_frameworks` 和 `01_operators` 目录尚未建立实际内容文件的规划分类索引节点），`README.md` 缺少元数据块。


- **来源**: `raw/docs/rl_precision_case.pdf`
- **提取点 1**: 提取并归档了全视角的精度指标含义（从 `entropy` 坍缩到 `clip_ratio` 拉扯）。
- **提取点 2**: 提炼出严格控制确定性的黄金跑图 Checklist (屏蔽 Shuffle，指定 seed_all)。
- **提取点 3**: 建立了标准化五阶段问题截断防泄漏流水线追踪体系（Scale Down -> Skip Rollout 定界）。
- **提取点 4**: 单独梳理极其隐秘危险的“训推并发 Off-Policy”根因与纠偏方法，以及专用于多流算子级探查的 `npu_sanitizer` 激活技巧。

## [2026-04-16] lint | health check
- **扫描**: 22 个文件 (21 wiki 页面 + index.md)
- **发现**: 10 个问题 (6 死链, 2 交叉引用不对称, 1 Frontmatter缺失, 1 潜在缺页)
- **自动修复**: 3 个问题 (修复 2 个交叉引用不对称，补全 1 个 Frontmatter)
- **待人工处理**: 6 个死链与 1 个缺失页面，建议日后创建归档页面或作为 Todo。

## [2026-04-16] ingest-precision | 批量排查并吸收各类强化学习模型对齐偏差与精度溢出经验 (共 9 篇)
- **来源**: `raw/docs/rl_precision_case.pdf`
- **提取点 1**: `tokenizer_config` 与 `RMSNorm_eps` 缺漏引起的 Reward 分叉。
- **提取点 2**: VeRL 分布式调度以及 `moe_shared_expert_overlap` 并发时序导致的多发性梯度爆炸与踩踏错乱。
- **提取点 3**: vLLM 驱逐分叉、NPU 硬件级异构随机数生成等底层长尾缺陷引发的推理发散。
- **提取点 4**: `dummy` 加载模式下、NZ 维度重排引起的严重 Off-Policy 行为偏移以及 Tensordict 的异步脏指针。
## [2026-04-14] ingest | CANN aclnnGather 算子零长维报错与规避
## [2026-04-12] ingest | Companion ViT 启动死锁与 EncodeRejected 双根因修复

# Log (操作日志)

所有由 AI Agent 执行的操作（Ingest / Query / Lint）均按时间倒序记录在此。
格式规范：`## [YYYY-MM-DD] <operation> | <title>`，支持 `grep "^## \[" log.md | tail -5` 快速检索。

---

## [2026-04-22] ingest-bugfix | VIT 接入经验总结 (Companion RPC 连接失败)
- **来源**: 诊断会话上下文及报错日志
- **提取点 1**: 追踪到因环境变量丢失导致 RPC 将 unix 错误解析为 TCP 且带有端口号 `:0` 的报错逻辑。
- **提取点 2**: 提炼了针对 `veturborpc` Proxy 的正确映射方案。
- **提取点 3**: 提炼了在 ark server 中回填继承 `MAAS_MODEL_DIR` 的解决路径。

## [2026-04-21] lint | health check
- **扫描**: 31 个页面 (包含所有分类目录与模板)
- **发现**: 14 个死链 (大抵为早期规划好的未来分类索引节点或暂未成文的主题), 3 对交叉引用不对称
- **自动修复**: 3 个问题 (补全了 `vlm_rl_actor_rope_logprobs_diff.md` 及 `vlm_2b5_rl_rollout_quantization.md` 相关的双向反演引用链接)
- **待人工处理**: 14 个待建设页面 (如 `vllm_npu.md`, `xllm_pydantic_mapping.md` 等占位符)

## [2026-04-21] ingest-fact | VLM 2.5B RL 低精度 Rollout 量化实现 (D_W8A8C8)
- **来源**: Agent 推断与底座代码解析 (`linear_dy_w8a8.py` 和 `quant_conf.py`)
- **提取点 1**: 确定了系统采用 SmoothQuant 加上 Dynamic W8A8 (D_W8A8C8) 的架构设计。
- **提取点 2**: 解析了权重 (Weight) 是离线静态且 Per-Channel 量化的。
- **提取点 3**: 解析了激活 (Activation) 是包含静态平滑因子预处理的在线动态量化，且提取极值粒度为 Per-Token。
- **提取点 4**: 补全了底层利用 `xpu_ops.smooth_quant` 现场换算与截断的核心代码实现。

## [2026-04-21] ingest-precision | VLM RL 长序列 RoPE 偏移导致 logprobs_diff 发散 (400x vs 20x)
- **来源**: Agent 推理会话及 `2b5_llm_0.1_logpdiff.md`
- **提取点 1**: 确定了 `logprobs_diff` 在长序列上误差飙升的规律，直接定位到底层物理位移的 RoPE 放缩误差。
- **提取点 2**: 揭示了 `ModelSpec` 隐式优先加载 `cruise_cli.yaml` 导致 `rope_scale=400` 残留的幽灵架构坑。
- **提取点 3**: 提炼出在不破坏 Actor (BF16) 训练回传机制的前提下，使用 Python 热补丁外科手术式改写 NPU 远程参数的设计方案。

## [2026-04-12] ingest-fact | VLM 2B5 推理服务化部署黄金配置归档
- **来源**: `srv_dp16ep16.sh` 完整环境变量 + `xllm_client_vlm.sh` 3 轮 16 并发压测通过记录
- **提取点 1**: 锁定黄金版本 Commit ID 三元组（主仓库 `7e680632` / xllm `2ed41d27` / xpu_gpt `82991346`），供后续回退对照。
- **提取点 2**: 梳理 LLM 主引擎（EP16/TP1/W8A8）和 Companion ViT 引擎（16 DP/同步/frozen）的完整并行度配置。
- **提取点 3**: 详细记录 gRPC + unix socket 通信协议的正确配置组合，标注 3 类致命错误配置及其后果。
- **提取点 4**: 归纳服务就绪判定标准和客户端验证流程。

## [2026-04-12] init | 增加 ingest-fact 工作流
- **来源**: 用户需求
- **提取点 1**: 增加了 `ingest-fact.md` 以用于归档系统架构、设计约束等纯事实类知识。
- **提取点 2**: 创建了配套的 `fact_template.md` 模板。
- **提取点 3**: 更新了 `index.md` 提供入口及事实类知识分类。

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
