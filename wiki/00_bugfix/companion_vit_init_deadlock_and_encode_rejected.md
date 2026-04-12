---
title: "Bugfix: VLM Companion ViT Engine 启动死锁与 EncodeRejected (Unix Socket URI 格式)"
tags: [status/resolved, priority/high, category/companion, category/vlm, category/rl]
last_updated: 2026-04-12
source: [outputs/logs/vlm_0412_174846.log, outputs/logs/vlm_0412_180741.log, outputs/logs/vlm_0412_181947.log]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Bugfix Report: VLM Companion ViT Engine 死锁 + EncodeRejected 双根因

## 1. 现象描述 (Symptoms)

- **环境**: Ascend NPU 910B x16, CANN, Python 3.11, xLLM 服务化推理
- **触发场景**: VLM 2.5B RL 训练启动时，`_serve` 子进程初始化 Companion ViT engine
- **报错信息**:
  ```text
  # 第一阶段：Step 2/3 后永远卡住，未到 Step 3/3
  [Companion] Step 2/3: ArkLauncher(build_config)...
  # 超过 10 分钟无任何后续日志
  
  # 第二阶段（若 Step 3/3 勉强完成）：所有 image embedding 请求失败
  E0412 18:13:46 sockaddr_resolver.cc: authority-based URIs not supported by the unix scheme
  channel stack builder failed: UNKNOWN: the target uri is not valid: unix://dp_0.sock:0
  EncodeRejected: encoder|unknown|EncodeRejected|Request encoder pod failed, retried up to 5 times
  ```
- **单测 (`srv_dp16ep16.sh`) 完全正常**：Step 2→3 耗时 255ms，48 请求全 OK

## 2. 根本原因分析 (Root Cause)

### 根因 1：Companion ArkLauncher 使用了 LLM 的 model_dir（导致 IO 死锁）

`run.sh` 中 `+rollout.model.path=/data01/model_weights/2b5_saved_model` 被传递到 `engine.py` 中的 `self._model_dir`。

`serve.py` 的 `launch_driver()` 在初始化 Companion launcher 时，直接使用了 `self._model_dir`（LLM 路径），而非 Companion 专用路径：

```python
# 错误（修复前）
self._companion_launcher = ArkLauncher(self._model_dir, ...)
```

`2b5_saved_model/` 中存在 `tokenizer_config.json` 和一个 12MB 的 `tokenizer.json`，触发了 `HuggingfaceStyleModelConfigWrapper` 中的 `AutoTokenizer.from_pretrained()`。在 16 卡 NPU 高 I/O 负载场景，该调用可能阻塞 60+ 分钟。

`2b5_saften/`（正确的 Companion model_dir）没有 tokenizer_config.json，走 `CruiseStyleModelConfigWrapper` 路径，毫秒级完成。

`substitute_companion_env()` 已将 `COMPANION_MAAS_MODEL_DIR` 覆盖到 `MAAS_MODEL_DIR` 环境变量（即 `2b5_saften`），但代码跳过了环境变量直接使用 Python 变量。

### 根因 2：缺少 REMOTE_SCHEME=unix 导致 Unix Socket URI 格式错误

`CompanionDPRoutingTableUpdater` 根据 `cfg.remote_scheme` 决定路由 URI 格式：

```python
if cfg.remote_scheme == "unix":
    addr_fmt = "dp_{rank}.sock"   # 正确：gRPC 补全为 unix:dp_0.sock
else:
    addr_fmt = "unix://dp_{rank}.sock"  # 错误：含双斜杠
```

`runtime_env.yaml` 缺少以下配置，导致 `cfg.remote_scheme=None`：
```yaml
XLLM_DRIVER_ENCODER_ROUTING_CONFIG__ROUTING_TABLE_UPDATER_CONFIG__REMOTE_SCHEME: "unix"
```

`listen_port=0` 与解析后地址拼接，生成 `unix://dp_0.sock:0`，gRPC 因 "authority-based URI" 格式拒绝连接。

单测 `srv_dp16ep16.sh` 第 207 行有此 `export` 语句，但 RL `runtime_env.yaml` 遗漏，造成单测/RL 环境不一致。

## 3. 解决方案 (Solution)

### 终极方案 (Fix)

**修改 1**：`3rdparty/xllm/xllm/service/rpc/ark/serve.py`

```python
# 修复后：从 env 读取 Companion 专用 model_dir
companion_model_dir = os.environ.get("MAAS_MODEL_DIR", self._model_dir)
logger.info(f"[Companion] companion_model_dir={companion_model_dir} (from env MAAS_MODEL_DIR)")
self._companion_launcher = ArkLauncher(companion_model_dir, self._companion_driver_type, yaml_file)
```

**修改 2**：`runtime_env.yaml`

```yaml
"XLLM_DRIVER_ENCODER_ROUTING_CONFIG__ROUTING_TABLE_UPDATER_CONFIG__REMOTE_SCHEME": "unix"
```

## 4. 验证结果 (Verification)

修复后：
- Companion Step 2→3：575ms（与单测 255ms 量级一致）✅
- `EncodeRejected` 出现次数：0 ✅
- `RL global_step=1` 在 ~90 秒内完成 ✅
- 日志确认 `companion_model_dir=/data01/model_weights/2b5_saften` ✅

## 5. 经验与关联

### 关键规则
1. **Companion 配置必须双向对照 `srv_dp16ep16.sh`**：每次新增 `runtime_env.yaml` 配置，要对照单测脚本逐行检查，禁止遗漏任何 `export` 语句。
2. **`MAAS_MODEL_DIR` 是 Companion 的黄金路径**：`substitute_companion_env()` 已将该变量设置为 Companion 专属值，所有后续初始化应从 env 读取，不要绕过。
3. **Unix socket URI 格式**：
   - ✅ 正确：`unix:dp_0.sock` 或 `unix:///abs/path/to/sock`
   - ❌ 错误：`unix://dp_0.sock`（双斜杠，gRPC 解析为 authority-based URI）
4. **RL 环境 I/O 放大效应**：16 NPU 高负载时，网络存储上的大文件读取（tokenizer.json 等）可能被放大数十倍，任何体积超过 1MB 的文件加载都需要评估。

### 相关诊断工具
- 快速检测 Step 2→3 耗时：`grep -a "Companion.*Step" logs/vlm_*.log`
- 检测 URI 问题：`grep -a "authority-based URI\|unix://dp_" logs/vlm_*.log | head -5`
- 检测实际 companion_model_dir：`grep -a "companion_model_dir=" logs/vlm_*.log`
