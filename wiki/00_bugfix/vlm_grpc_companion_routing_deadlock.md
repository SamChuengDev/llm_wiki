---
title: "Bugfix: VLM Companion Encoder gRPC 路由死锁与地址错配"
tags: [status/resolved, priority/critical, category/network, category/vlm]
last_updated: 2026-04-12
source: session log
confidence: high
status: completed
open_questions: []
contradictions: []
---

# Bugfix Report: VLM Companion Encoder gRPC 路由死锁与地址错配

## 1. 现象描述 (Symptoms)
- **环境**: VLM 2B5 RL 推理服务，16 Rank，NPU 集群，xLLM 架构。
- **报错信息**:
  服务在拉起 `CompanionDPRoutingTableUpdater` 之后卡住，客户端发起图文请求时全数抛出 `EncodeRejected` 错误：
  ```text
  EncodeRejected('encoder|unknown|EncodeRejected|Request encode pod failed, Request encoder pod failed, retried up to 5 times')
  ```
  同时观察到 Companion 服务 `QueryStatesWatchDog` 未启动，服务端主日志由于等待失败甚至出现挂起及 `EADDRINUSE` 端口遗留问题。
- **复现机制**:
  在使用默认 `veturborpc` 配置（针对单卡或特定环境优化，不支持 Python Fork 子进程环境）且路由表 Scheme 和 listen地址硬编码状态下，必定触发该死锁。

## 2. 根本原因分析 (Root Cause)
故障源于三层连锁的通信协议层断裂：
1. **进程模型不兼容**: Companion ViT Engine 的工作流是通过主进程 fork 拉起，而 `veturborpc` 底层的 C++ Session 在 Fork 环境下无法重新绑定端口，`init_rpc` 极大概率报 `RpcErrorCode: 20004` 并触发 `block_until_ready` 死锁。
2. **强制替换 gRPC 带来的路径降级**: 为了规避 1，强制改用 `grpc`。但在 `driver_proxy.py` 中，当 `method=="grpc"` 且 `scheme=="unix"` 时，其自动放弃 `dp_{rank}.sock` 格式，退化为 `/tmp/[UUID]` 生成临时套接字。
3. **路由表强制格式与双重前缀冲突**: 
   - 客户端路由组件 `CompanionDPRoutingTableUpdater` 为了找 Server，其生成表默认硬编码为 `unix://dp_{rank}.sock`。
   - 这就导致服务端绑定 `/tmp/UUID` 协议，而客户端跑向 `unix://dp_{rank}.sock` 的盲目寻址行为。
   - 此外，如果将其 Scheme 设为 `unix` 以求握手，`RemoteExecutorWrapperConfig` 内部的 `addr` 装饰器会自动加 `unix:` 前缀，导致生成的格式变为非法 gRPC 路径: `unix:unix://dp_{rank}.sock`。

## 3. 解决方案 (Solution)

彻底的解决方式是消除地址漂移并将客户端与服务端的寻址协议严丝合缝地对齐 `unix:dp_X.sock` 格式。

### 终极方案 (Fix)
**1. 客户端路由表格式打平对齐 (xllm/backend/driver/routing/routing_table_fetcher.py)**:
允许客户端对 `scheme=="unix"` 取特殊判断，生成 `dp_{rank}.sock`（没有前缀），依靠 `addr` 特性安全包裹为 `unix:dp_X.sock`。
```python
if cfg.remote_scheme == "unix":
    addr_fmt = "dp_{rank}.sock"
else:
    addr_fmt = "unix://dp_{rank}.sock"
```

**2. 服务端驱动路径豁免 (xllm/backend/driver/driver_proxy.py)**:
针对 `encoder` 类型，无论是不是 `grpc` 都不允许走 `/tmp/UUID` 临时分配机制，必须严格固定为 `dp_{rank}.sock`。
```python
if driver_type in ["encoder", "audio_encoder"]:
    # 强制固定地址格式
    unix_socket_address = f"dp_{dp_rank}.sock"
```

**3. 环境总调度入口强制约定 (srv_dp16ep16.sh)**:
要求环境必须向双端告知使用 `grpc` 和 `unix`：
```bash
export COMPANION_XLLM_ENCODER_METHOD="grpc"
export XLLM_DRIVER_ENCODER_ROUTING_CONFIG__ROUTING_TABLE_UPDATER_CONFIG__REMOTE_SCHEME="unix"
export XLLM_DRIVER_ENCODER_ROUTING_CONFIG__ROUTING_TABLE_UPDATER_CONFIG__REMOTE_METHOD="grpc"
```

## 4. 验证结果 (Verification)
改好后在远端通过 `srv_dp16ep16.sh` 测试：
- Server 端日志 `QueryStatesWatchDog` 进程激活到达 `96` 标志。
- 所有 16 个 Driver 的监听日志打印均为标准格式：`start listen unix:dp_[0-15].sock`。
- 客户端执行 16 并发 VLM 图文评测打通，`EncodeRejected` 归零，缓存复投耗时 2.9s，多路请求未互相污染。

## 5. 沉淀与关联
- 关联问题: 分布式 RPC 联调、`veturborpc` Fork 限制规避。
