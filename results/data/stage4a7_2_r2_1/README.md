# Stage 4A.7.2-R.2.1 结果归档

本目录保存 Stage 4A.7.2-R.2.1 的可复核代码配套结果。当前阶段状态为 `partial / blocked`。

## 已归档结果

- `smoke/`：串行 smoke 的 CSV 结果和配置摘要。
- `formal/`：87 个兼容候选、development/calibration/Pilot 的 CSV 结果和配置摘要。正式运行使用的 checkpoint MAT 未纳入本次轻量提交；其身份和重建入口记录在阶段报告与日志中。
- `independent35/`：35 个独立 off-grid、20 dB 频域等效噪声 Pilot，包括场景清单、决策、指标、hash 独立性审计、配置清单和等价性审计。

## 重建入口

```matlab
addpath(genpath(pwd));
summary = run_stage4a7_2_r2_1_independent_validation('formal');
summary35 = run_stage4a7_2_r2_1_independent_35_pilot();
```

MATLAB 使用 R2024a；当前机器需要采用阶段报告中记录的隔离 `HOME`/`MATLAB_PREFDIR`、兼容库、offscreen、`-nojvm` 和 `-singleCompThread` workaround。

## 未纳入轻量归档的文件

formal checkpoint 和完整 `summary.mat` 属于运行中间状态或大型 MATLAB 原始结果，本次保留在本地工作目录，不作为轻量代码提交内容。若后续需要跨机器复现，应使用外部 artifact manifest 或 Git LFS 方案，并同时保存 SHA-256；不能用缺失 MAT 冒充已归档原始结果。

## 研究边界

结果来自受限候选空间、合成/派生工程先验和模型生成 CFR；不是真实 PLC 现场测量，不证明物理拓扑唯一性，也不是完整 Final。Stage 4B 未启动。
