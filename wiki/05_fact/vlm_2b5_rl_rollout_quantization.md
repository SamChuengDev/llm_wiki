---
title: "Fact: VLM 2.5B RL 训推转换低精度 Rollout 量化实现"
tags: [status/stable, category/fact, quantization]
last_updated: 2026-04-21
source: Agent 代码分析与日志推理 (`linear_dy_w8a8.py`, `quant_conf.py`, `outputs/logs/vlm_0421_174423.log`)
confidence: high
status: active
open_questions: []
contradictions: []
---

# Fact: VLM 2.5B RL 训推转换低精度 Rollout (D_W8A8C8) 量化实现

## 1. 核心事实 (Core Fact)
在 VLM 2.5B RL 的部署场景中，为了兼顾强化学习中的 Actor/Rollout 端到端稳定性与训推转换的一致性，系统采用了 **SmoothQuant 结合 Dynamic W8A8 (D_W8A8C8)** 的复合量化模式：
- **权重 (Weight)**：采用**静态量化 (Static)**，粒度为 **Per-Channel (W8)**。
- **激活 (Activation)**：采用**动态量化 (Dynamic)**，粒度为 **Per-Token (A8)**，同时在动态截断前，引入了一个预计算的静态 Per-Channel 平滑因子（Smooth Factor）进行条件预处理。
- **KV Cache**：采用 8-bit 量化 (C8)。

## 2. 设计背景 (Background & Rationale)
由于 VLM 在 PPO 或其他 RL 算则下的 Actor Rollout 对推理解码造成的数值误差非常敏感：
1. 若全局采用严格的静态 W8A8，可能因少量离群点（Outliers）导致严重的 `logprobs_diff` 漂移，破坏 RL 梯度下降的平滑性。
2. 通过引入 `D_W8A8C8`（SmoothQuant 方案），离线预先分发每个通道的静态降幅因子（`mojo_smooth_scale`），然后在推理现场计算每一个 Token 的最大极值（`input_scale`），在性能损失微小的情况下实现了激活值的伪静态与高精度。

## 3. 应用场景与约束 (Constraints)
- 在 Actor 与 Rollout 通信转换格式必须强绑定为 `D_W8A8C8`。
- 不能更改 `mojo_weight_scale` 和 `mojo_smooth_scale` 的预解析逻辑，这是为了保证训练期浮点模型与推理期 INT8 运算的数学完全等价。

## 4. 相关配置或引用 (References)
底层量化算子实现（见 `xpu_gpt/.../operators/linear/linear_dy_w8a8.py`）：

```python
# 核心代码片段：权重静态装载与激活值动态量化
class LinearDyW8A8(MojoOperator):
    def load_weights(self, infuser: WeightInfuser, prefix: str):
        # Weight 静态加载: int8
        weight = infuser.get_tensor(f"{prefix}.weight")
        self.weight = infuser.to_parameter(weight)
        
        # 激活预处理静态平滑因子（SmoothQuant 特性）
        in_scale = infuser.get_tensor(f"{prefix}.mojo_smooth_scale")
        self.in_scale = infuser.to_parameter(1.0 / in_scale, dtype=torch.bfloat16)
        
        # Weight Per-Channel Scale
        out_scale = infuser.get_tensor(f"{prefix}.mojo_weight_scale").squeeze(0)
        self.out_scale = infuser.to_parameter(127.0 * out_scale.to(torch.float), dtype=torch.float)

    def forward(self, x, fwd_params: ForwardArgs):
        # 运行时 Activation 本地分配
        x_quant = torch.empty(x.shape, dtype=torch.int8, device='cuda')
        input_scale = torch.empty([bs * tgt_len], dtype=torch.float32, device='cuda')
        
        # 动态 Activation 换算：同时应用静态通道平滑 self.in_scale 与产出 Per-Token 的极值缩放 input_scale
        xpu_ops.smooth_quant(x, self.in_scale, x_quant, input_scale)
        
        # W8A8 Gemm (Weight=Static_Per-Channel, Activation=Dynamic_Per-Token)
        xpu_ops.matmul(x_quant, self.weight, out, bias=self.bias, x_pc_max=input_scale, w_pc_max=self.out_scale)
        return out
```

## 5. 沉淀与关联
- 关联知识点: [[wiki/02_precision/vlm_2b5_w8a8_gibberish]]
- 关联系统日志: `outputs/logs/vlm_0421_174423.log`
