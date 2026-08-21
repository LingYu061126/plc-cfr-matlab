# 发布版说明

本仓库用于代码审阅与轻量复现，包含 MATLAB 源码、阶段 1.5–3A 报告、图、CSV 汇总数据和运行日志。

未包含大型 MAT 原始数据，特别是 `stage2_3_partial_*_results.mat` 与 `stage2_3_results.mat`。formal fixed 的 148400 条 trial CSV 已在本机生成但按发布策略不推送；仓库中的 `results/data/stage2_3_formal_fixed_summary.csv`、`_confusion.csv`、`_config.csv` 和 `_pairwise_distance.csv` 是使用本机 formal MAT 和当前 raw-pairwise 适配器生成的轻量汇总结果。原始 trial 仍可由维护者提供外部数据包；当前仓库的历史 `results/data/stage2_3_trials.csv` 可用于审阅旧 trial 记录。

## 克隆与运行

```bash
git clone <你的远程仓库地址>
cd matlab_plc_cfr_publish
```

在 MATLAB R2024a 中运行 `run_stage2_3('smoke')` 可独立执行轻量 smoke；它只读取/写入 `stage2_3_smoke_partial_*`。汇总后的 `stage2_3_smoke_fixed_pairwise_distance.csv` 和 `stage2_3_formal_fixed_pairwise_distance.csv` 均应有 42 条拓扑对数据，并包含 `complex_distance` 与 `complex_distance_raw`。`run_stage2_3('formal')` 只接受 `stage2_3_formal_partial_*` 原始 MAT；发布版未附带这些大文件，因此重新汇总会明确报出缺失批次，而不会混入旧 smoke 或历史 formal 数据。

本项目使用频域等效 OFDM 导频模型，不是完整 PLC 收发机；结论仅适用于报告中说明的完整树网络、端接、噪声和参数假设。

## 阶段 3A 数据

阶段 3A 的入口为 `run_stage3a('smoke')` 和 `run_stage3a('formal')`。formal 轻量 CSV 和图已保存在 `results/data/stage3a_formal_*`、`results/figures/stage3a_formal_*`；本机的 `stage3a_formal_raw.mat` 约 185 MB，按大型原始数据策略不发布。它包含每次试验的 H_true、H_hat、CIR、循环延迟、噪声细节和参数配置，克隆者不能在缺少该 MAT 时独立重建完整原始 trial。

阶段 3A 当前是 `Y=XH+N` 的通信型等效模型，加入了仿真 IFFT/CP/FFT/LS 和稀疏导频插值，但没有完整同步、CFO、编码、PAPR、现场有色/脉冲噪声、真实耦合器/MIMO 或市电测量。FDR/TFDR 和输入导纳输出仅为明确标记的 proxy，不应和普通端到端 OFDM-CFR 混称。

最终审计状态：MATLAB R2024a 的阶段 1.5、2、2.1、2.2、2.3 测试全部通过；阶段 3A 单元测试和 formal 入口也已实际通过。阶段 3A formal 使用固定种子和当前代码运行生成 1088 条 trial 指标、136 条汇总组；轻量 CSV 可审阅，但约 185 MB 的 raw MAT 不发布。阶段 2.3 的旧 formal fixed 仍按历史来源说明，不与阶段 3A formal 混用。详细命令、数据来源和限制见 `report/stage3a_communication_baseline.md`。
