# 发布版说明

本仓库用于代码审阅与轻量复现，包含 MATLAB 源码、阶段 1.5–2.3 报告、图、CSV 汇总数据和运行日志。

未包含大型 MAT 原始数据，特别是 `stage2_3_partial_*_results.mat` 与 `stage2_3_results.mat`。formal fixed 的 148400 条 trial CSV 已在本机生成但按发布策略不推送；仓库中的 `results/data/stage2_3_formal_fixed_summary.csv`、`_confusion.csv`、`_config.csv` 和 `_pairwise_distance.csv` 是使用本机 formal MAT 和当前 raw-pairwise 适配器生成的轻量汇总结果。原始 trial 仍可由维护者提供外部数据包；当前仓库的历史 `results/data/stage2_3_trials.csv` 可用于审阅旧 trial 记录。

## 克隆与运行

```bash
git clone <你的远程仓库地址>
cd matlab_plc_cfr_publish
```

在 MATLAB R2024a 中运行 `run_stage2_3('smoke')` 可独立执行轻量 smoke；它只读取/写入 `stage2_3_smoke_partial_*`。汇总后的 `stage2_3_smoke_fixed_pairwise_distance.csv` 和 `stage2_3_formal_fixed_pairwise_distance.csv` 均应有 42 条拓扑对数据，并包含 `complex_distance` 与 `complex_distance_raw`。`run_stage2_3('formal')` 只接受 `stage2_3_formal_partial_*` 原始 MAT；发布版未附带这些大文件，因此重新汇总会明确报出缺失批次，而不会混入旧 smoke 或历史 formal 数据。

本项目使用频域等效 OFDM 导频模型，不是完整 PLC 收发机；结论仅适用于报告中说明的完整树网络、端接、噪声和参数假设。

最终审计状态：MATLAB R2024a 的阶段 1.5、2、2.1、2.2、2.3 测试全部通过；smoke 入口完整生成 7 个 batch 并成功汇总。formal fixed 的轻量 CSV 已通过 42/371/1456 行结构检查，但其 trial、summary、confusion 来自本机旧 formal MAT，raw pairwise 列由当前代码适配补算；本次没有从头重跑 formal，公开 clone 不能在缺少 MAT 时独立重建该统计结果。详细命令和证据见 `results/logs/goal_stage2_3_progress.md`。
