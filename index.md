# Map of Content (知识入口)

欢迎来到 LLM-WIKI。这里是异构计算 Infra 知识的索引核心。

---

## 🏛️ 知识目录

### 0. [[wiki/00_bugfix/index|常规排错 (Bugfix)]]
- 日常环境异常与框架启动报错
- 业务逻辑层的 Bug 修复复盘与 Workaround

### 1. [[wiki/01_operators/index|算子迁移 (Operators)]]
- GPU (CUDA) -> NPU (CANN) 算子映射表
- 算子规避与自定义算子实现
- `torch_npu` 特有算子库

### 2. [[wiki/02_precision/index|精度对齐 (Precision)]]
- FP16/BF16 溢出排查
- NaN/Inf 问题诊断
- 逐层结果对齐工具与方法

### 3. [[wiki/03_tuning/index|性能调优 (Tuning)]]
- HCCL 并发与通信优化
- 显存复用与 OOM 解决
- 算子融合 (Operator Fusion) 策略
- Profiling 结果分析

### 4. [[wiki/04_frameworks/index|框架适配 (Frameworks)]]
- **vLLM**: NPU Backend 改造点
- **Megatron-LM**: 昇腾适配版分析
- **DeepSpeed**: 加速库适配

---

## 🕒 最近更新

- [[changelog|查看完整更新日志]]
