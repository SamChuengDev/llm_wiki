---
title: "Precision: VLM RL 长序列 RoPE 偏移导致 logprobs_diff 发散 (400x vs 20x)"
tags: [status/resolved, category/diff, component/rope, mode/rl]
last_updated: 2026-04-21
source: [maas_engine_vlm2b5/outputs/logs/vlm_0421_174423.log, 2b5_llm_0.1_logpdiff.md]
confidence: high
status: active
open_questions: []
contradictions: []
---

# Precision Alignment Report: VLM RL 长序列 RoPE 参数错配导致 logprobs_diff 发散

## 1. 差异现象 (Deviation Symptoms)
- **现象**: 在 VLM 2.5B 的 PPO RL 训练中，发现 Actor 和 Rollout 之间的 `logprobs_diff` 在极短序列下尚能维持在 0.07 左右，但一旦生成的响应序列超过 1000 Tokens，误差即飙升至 `0.15~0.16`。
- **数据类型**: BF16 (Actor 计算图) vs W8A8 (Rollout 推理)。

## 2. 定位过程 (Debugging Process)
- **排查逻辑**: 
  - 最初怀疑是 Actor 训练权重时间戳和 W8A8 量化权重不一致，但经过架构机制确认 `update_weights` 会在每一轮结束后执行在线量化同步，排除了物理分叉。
  - 通过提取多轮（1~20 step）日志指标，敏锐发现 `logprobs_diff` 与 `response_length` 的**强正相关性**。这种随长度倍增的误差，其数理本质唯一指向**旋转位置编码 (RoPE)** 的计算位移。
  > [!TIP]
  > **核心排查线索 (Golden Clue)**: 当观察到 `logprobs_diff` 呈现 **“句子越长，差异越大”** 的强正相关规律时，即可强烈暗示（甚至直接定界为）底层系统存在 **RoPE 位置编码缩放因子 (factor)** 或者位置索引 (position_ids) 计算规则不一致的问题。
- **可疑算子/模块**: 位置编码层 (RoPE) 以及背后的配置加载基类 `ModelSpec._init_config()`。
- **配置深挖**: 
  - Actor 目录 `2b5_saved_model` 下不仅有 `config.json`，还包含了一个幽灵文件 `cruise_cli.yaml`。
  - `ModelSpec` 隐式优先加载了 `cruise_cli.yaml`，使得 Actor 的 `rope_scale` 固定在了 **400**，而目标 Rollout 加载的 `2b5_saften/config.json` 中 `factor` 其实是 **20**。

## 3. 修复方案 (Alignment Fix)
- **方案描述**: 
  因为 Actor **必须**加载 BF16 目录 (`2b5_saved_model`) 进行回传训练，不可直接将模型路径迁移到 W8A8 目录。所以必须做底层配置剥离的“外科手术”，覆盖 BF16 目录内的 `cruise_cli.yaml` 数据，令两边对齐。
- **代码实现**:
  向 NPU 发送 Python 脚本强制干预 YAML 以及嵌套子字典参数：
  ```python
  import yaml, json
  # 修复 cruise_cli.yaml
  with open('cruise_cli.yaml', 'r') as f:
      cfg_yaml = yaml.safe_load(f)
  cfg_yaml['model']['network']['rope_scale'] = 20
  cfg_yaml['model']['network']['max_position_embeddings'] = 32768
  # ... dump yaml ...

  # 修复 config.json 中的 text_config 子字典
  with open('config.json', 'r') as f:
      cfg_json = json.load(f)
  cfg_json['text_config']['rope_scaling']['factor'] = 20
  cfg_json['text_config']['max_position_embeddings'] = 32768
  # ... dump json ...
  ```

## 4. 对齐验证 (Validation)
- 验证手段：热修复配置后，重新发起 `bash ray.sh`。第一轮计算 `train/rollout/logprobs_diff` 指标直接掉落地板，达到 **`0.0104514`**，刚好切中量化底噪 1% 的微小误差容限。
- PPL (困惑度)：Actor PPL 为 `1.029`，Rollout PPL 为 `1.025`，两端数据表现极度咬合，对齐完成。

## 5. 关联知识
- [[wiki/02_precision/rl_alignment_checklist|RL 精度对齐排查前置清单 (Golden Checklist)]]
- [[wiki/02_precision/vlm_2b5_w8a8_gibberish|VLM 2.5B W8A8 推理高熵乱码问题 (RoPE 冲突)]]
