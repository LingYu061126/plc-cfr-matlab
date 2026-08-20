# 发布版说明

本仓库用于代码审阅与轻量复现，包含 MATLAB 源码、阶段 1.5–2.3 报告、图、CSV 汇总数据和运行日志。

未包含大型 MAT 原始数据，特别是 `stage2_3_partial_*_results.mat` 与 `stage2_3_results.mat`。阶段 2.3 的完整原始 trial 仍可由 `results/data/stage2_3_trials.csv` 审阅；如需逐批复算或检查所有中间变量，请向仓库维护者索取原始数据包。

## 克隆与运行

```bash
git clone <你的远程仓库地址>
cd matlab_plc_cfr_publish
```

在 MATLAB R2024a 中运行 `run_stage2_3` 可执行测试和阶段 2.3 实验。正式阶段 2.3 会产生大型 MAT 文件；公开仓库建议保留其 CSV/图/报告，而将新的 MAT 输出放入忽略目录或外部数据存储。

本项目使用频域等效 OFDM 导频模型，不是完整 PLC 收发机；结论仅适用于报告中说明的完整树网络、端接、噪声和参数假设。
