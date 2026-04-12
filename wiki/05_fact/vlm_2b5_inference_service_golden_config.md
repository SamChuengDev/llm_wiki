---
title: "Fact: VLM 2B5 单测推理服务化部署黄金配置 (DP16/EP16)"
tags: [status/stable, category/fact, category/vlm, category/deployment]
last_updated: 2026-04-12
source: [srv_dp16ep16.sh, xllm_client_vlm.sh 3轮16并发压测通过]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Fact: VLM 2B5 单测推理服务化部署黄金配置 (DP16/EP16)

> **本文档记录了经过 4+ 小时排查、调试并通过端到端 3 轮 16 并发压测验证的精确部署配置。**
> 任何对以下配置的修改都可能破坏服务的稳定性，修改前必须参考本文档进行影响评估。

## 1. 版本锁定 (Golden Commit IDs)

**以下 Commit 组合是验证通过的黄金版本，回退必须三个同时回退。**

| 仓库 | 分支 | Commit ID | 说明 |
|------|------|-----------|------|
| `maas_engine_xgn` (主仓库) | `m8_vlm_xg` | `7e680632` | 包含 `engine.py`, `launch_envs.py`, `ray.sh` 等 RL 框架层修改 |
| `3rdparty/xllm` | `m8_vlm_xg` | `2ed41d27` | 含 `driver_proxy.py` unix socket 路径修复、`routing_table_fetcher.py` scheme 对齐、`srv_dp16ep16.sh` 完整环境配置 |
| `3rdparty/xpu_gpt` | `m8_vlm_xg` | `82991346` | 含 `xpu_async_inferencer.py` 空 batch 处理、`xpu_inferencer.py` weight sync prefix 剥离 |

## 2. 核心架构事实 (Core Architecture)

### 2.1 模型特性
- **VLM 2B5 = 激活参数 2.5B、总参数 ~25B 的 MoE (Mixture of Experts) 模型**，绝非 dense 小模型
- 必须使用 **EP=16** 将全部 25B 参数分布到 16 个 NPU 上
- ViT Encoder 参数量 ~680M，在 RL 中完全 frozen（无梯度更新）

### 2.2 双引擎架构
服务由两个引擎协同工作：
```
┌─────────────────────────────────────────────┐
│          xllm.service.rpc.ark.serve          │
│                                             │
│  ┌──────────────┐    ┌──────────────────┐   │
│  │  LLM Engine  │    │ Companion Engine │   │
│  │  (local)     │    │ (encoder/ViT)    │   │
│  │  16 workers  │    │ 16 DP workers    │   │
│  │  EP16/TP1    │    │ EP16/TP1         │   │
│  │  W8A8 量化   │    │ BF16 推理        │   │
│  │  gRPC:62000  │    │ unix:dp_X.sock   │   │
│  └──────────────┘    └──────────────────┘   │
└─────────────────────────────────────────────┘
```

## 3. LLM 主引擎并行配置

```bash
# ===== 并行度 =====
XLLM_PARALLEL_LOCAL_WORLD_SIZE="16"   # 本地 16 rank（必须 = NPU 数量）
XLLM_PARALLEL_DP_SIZE="16"           # 数据并行度 16
XLLM_PARALLEL_TP_SIZE="1"            # 张量并行度 1（精度约束，禁止改大）
XLLM_PARALLEL_PP_SIZE="1"            # 流水线并行度 1
XLLM_PARALLEL_SP_SIZE="1"            # 序列并行度 1

# ===== XPU 底层 =====
XPU_DP_SIZE="16"                     # MoE EP 必须 = 16
XPU_EP_SIZE="16"                     # Expert Parallelism = 16
XPU_TP_SIZE="1"
XPU_PP_SIZE="1"
XPU_SP_SIZE="1"
XPU_MP_SIZE="1"
XPU_FORCE_USE_BIGEP="1"             # BigEP 算子路径（MoE 必须）
XPU_QUANT_MODE="D_W8A8C8"           # W8A8 量化模式
XPU_DIE_PER_NODE="16"
XPU_VOCAB_TP_SIZE="8"

# ===== 引擎类型 =====
XLLM_ENGINE_CLS_TYPE="async_tp_engine"  # W8A8 使用 async_tp_engine
XLLM_INFERENCER_CLS_TYPE="xpu"
XLLM_INFERENCER_ASYNC_MODE="1"          # LLM 引擎异步模式
XLLM_INFERENCER_RL_MODE="1"             # RL 模式开启
```

## 4. Companion ViT 引擎配置

```bash
# ===== Companion 并行度（与主引擎共享 16 NPU）=====
COMPANION_XLLM_PARALLEL_LOCAL_WORLD_SIZE="16"
COMPANION_XLLM_PARALLEL_DP_SIZE="16"
COMPANION_XLLM_PARALLEL_ENABLE_ATTENTION_DP="1"
COMPANION_XPU_DP_SIZE="16"
COMPANION_XPU_EP_SIZE="16"

# ===== Companion 引擎类型 =====
COMPANION_XLLM_ENGINE_CLS_TYPE="tp_engine"           # ViT 使用 tp_engine（非 async_tp）
COMPANION_XLLM_INFERENCER_ASYNC_MODE="0"              # ViT 同步模式
COMPANION_XLLM_INFERENCER_RL_MODE="0"                 # ViT 不参与 RL weight sync
COMPANION_XLLM_ENGINE_MAIN_PROCESS_HANDLES_DEVICE="1" # 主进程处理设备
COMPANION_XLLM_INFERENCER_MULTI_MODAL_TYPE="ViT"

# ===== Companion ViT 特性 =====
COMPANION_VLM_ENABLE_NAVIT="1"
COMPANION_XLLM_ENCODER_CACHE_SIZE="2000"  # 图片 embedding 缓存 2000 条
COMPANION_XLLM_ENCODER_SYNC="1"           # 同步编码

# ===== Companion 模型配置 =====
COMPANION_XLLM_MODEL_MP_SIZE="1"
COMPANION_XLLM_MODEL_NUM_BLOCKS="1"
COMPANION_XLLM_MODEL_SLOT_BLOCK_SIZE="1"
COMPANION_XLLM_MODEL_USE_VLLM="1"
COMPANION_XLLM_MAX_NEW_TOKENS="32768"

# ===== Companion 通信端口 =====
COMPANION_XLLM_INFERENCER_torch_distributed_port="61110"  # 与主引擎 63110 分开
COMPANION_HCCL_IF_BASE_PORT="64501"                        # 与主引擎 64500 分开
```

## 5. gRPC 通信协议配置（最关键，4h 修复核心）

### 5.1 Companion Encoder → LLM Driver 路由链路

```
                        路由表查询                    gRPC unix socket
LLM GetEmbeddingLoop ──────────────► RoutingPolicy ──────────────────► Companion Driver
        │                                  │                                │
        │                                  ▼                                ▼
        │                       CompanionDPRouting            unix:dp_X.sock
        │                       TableUpdater                  (X = 0..15)
        │                       addr="dp_X.sock"
        │                       scheme="unix"
        │                       method="grpc"
        │
        ▼
  EncodeRejected (如果路由失败)
```

### 5.2 关键环境变量

```bash
# ----- 路由表配置 (LLM 侧) -----
# 告诉 LLM 的 GetEmbeddingLoop 如何找到 Companion
XLLM_DRIVER_ENCODER_ROUTING_CONFIG__ROUTING_TABLE_UPDATER_CONFIG__TYPE="companion_dp"
XLLM_DRIVER_ENCODER_ROUTING_CONFIG__ROUTING_TABLE_UPDATER_CONFIG__DP_SIZE="16"
XLLM_DRIVER_ENCODER_ROUTING_CONFIG__ROUTING_TABLE_UPDATER_CONFIG__REMOTE_SCHEME="unix"
XLLM_DRIVER_ENCODER_ROUTING_CONFIG__ROUTING_TABLE_UPDATER_CONFIG__REMOTE_METHOD="grpc"

# ----- Companion Encoder 配置 (ViT 侧) -----
# 告诉 Companion Driver 如何监听
COMPANION_XLLM_ENCODER_METHOD="grpc"            # 强制 grpc（禁止 veturborpc）
COMPANION_XLLM_ENCODER_REMOTE_SCHEME="unix"     # 使用 unix domain socket
COMPANION_XLLM_ENCODER_DRIVER_PORT="0"          # TCP 端口无意义，unix socket 替代

# ----- RPC 超时 -----
XLLM_ENCODER_RPC_TIMEOUT_S="120"   # ViT 首次 graph 编译冷启动约 46 秒，设 120 秒超时
```

### 5.3 地址格式对齐规则（血泪教训）

| 组件 | 生成的地址 | 最终 addr 属性 |
|------|-----------|---------------|
| `CompanionDPRoutingTableUpdater`（客户端） | `listen_addr="dp_X.sock"`, `scheme="unix"` | `unix:dp_X.sock` ✅ |
| `AsyncDriverProxy.driver_loop`（服务端） | `listen_addr="dp_X.sock"`, `scheme="unix"` | `unix:dp_X.sock` ✅ |

**以下组合会导致 `EncodeRejected`，绝对禁止：**

| 错误配置 | 结果 | 后果 |
|---------|------|------|
| Encoder method=`veturborpc` | `init_rpc` in fork → RpcErrorCode 20004 | `block_until_ready` 死锁 |
| Encoder method=`grpc` 但不做 encoder 类型豁免 | `listen_addr=/tmp/UUID` | 路由表找不到 → EncodeRejected |
| `REMOTE_SCHEME` 不设或为 None | 路由表 `listen_addr="unix://dp_X.sock"` + `addr` 属性拼出 `unix:unix://dp_X.sock` | 双重前缀，gRPC 连接失败 |
| `REMOTE_SCHEME="unix"` 但 `routing_table_fetcher.py` 未修改 | 同上 | 同上 |

### 5.4 底层代码关键修改点

1. **`driver_proxy.py` L1257-1270**: encoder 类型的 driver 始终使用 `dp_{dp_rank}.sock` 格式（不走 UUID），无论 method 是 grpc 还是 veturborpc。
2. **`routing_table_fetcher.py` L328-337**: `CompanionDPRoutingTableUpdater` 根据 `remote_scheme` 决定地址前缀：`scheme="unix"` 时用 `dp_{rank}.sock`（无 `unix://`），`scheme=None` 时保持 `unix://dp_{rank}.sock` 的向后兼容。

## 6. 服务启动参数

```bash
python3 -m xllm.service.rpc.ark.serve \
    --model-dir "$MAAS_MODEL_DIR" \
    --driver-type local \
    --companion-driver-type encoder \
    --port 62000 \
    --num-server-procs 32 \
    --disable-warmup
```

## 7. 环境清理（启动前必须执行）

```bash
rm -rf /data00/cjsRL/engine_*      # 清理旧 engine 文件
rm -rf /tmp/engine_*                # 清理临时 engine socket
rm -rf /dev/shm/DynamicProfileNpuShm*  # 清理 NPU 共享内存
rm -rf /tmp/*.sock                  # 清理所有残留 unix socket
```

## 8. 验证标准

服务启动后，判定就绪的标准：
1. **`Server starts at 0.0.0.0: 62000`** — gRPC 主端口绑定成功
2. **`Companion ViT engine launched successfully`** — Companion 引擎启动完毕
3. **`start listen` 出现 32 次** — 16 LLM Driver + 16 Companion Driver 全部监听
4. **`QueryStatesWatchDog` 出现** — 所有 worker 进入 polling 状态
5. **`RpcErrorCode` 出现 0 次** — 无 RPC 通信异常

客户端验证（`xllm_client_vlm.sh`）：
- **3 轮 16 并发 = 96 请求**
- **0 错误**，MATCH 率 ≥ 93%（DIFF 仅限格式歧义如"粉色"vs"粉红色"）
- **Round 3 耗时 ≤ 5s**（ViT 缓存命中后）

## 9. 沉淀与关联
- 关联 Bugfix: [[wiki/00_bugfix/vlm_grpc_companion_routing_deadlock|VLM Companion Encoder gRPC 路由死锁与地址错配]]
- 关联 Bugfix: [[wiki/00_bugfix/veturborpc_env_override|强行禁用 veturborpc_ext 及 xLLM 环境映射机制]]
- 启动脚本: `3rdparty/xllm/srv_dp16ep16.sh`
- 测试脚本: `3rdparty/xllm/xllm_client_vlm.sh`
