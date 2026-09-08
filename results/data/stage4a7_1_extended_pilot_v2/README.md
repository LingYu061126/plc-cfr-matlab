# Stage 4A.7.1 扩展 Pilot 数据

该目录保存最终的 700 条 calibration＋500 条 Pilot 扩展实验。运行模式为 `extended_pilot`，A 网格 61 点，串行 1 worker；完整 Final 和 Stage 4B 未运行。

复现命令：

```matlab
run_stage4a7_1_candidate_generation_and_confirmation('extended_pilot')
```

核心文件包括 `configuration_manifest.csv`、`calibration_scenario_manifest.csv`、`pilot_scenario_manifest.csv`、`pilot_match_decisions.csv`、`pilot_scoring_labels.csv`、`pilot_metrics.csv`、`independence_audit.csv`、`scenario_equivalence_audit.csv`、`runtime_summary.csv` 和 `stage4a7_1_pilot_results.mat`。

Scientific hash：`0a7ad136906bcc694e9cdc57485e98b3b14f59e1c377a526b9098a8d631e77f1`。

Source-tree hash：`1141cb13c2e374847868383474ff86613e2d208f6174d54251de1e327054a705`。

运行日志：`results/logs/stage4a7_1_extended_pilot_v2_run.log`。

完整回归日志：`results/logs/stage4a7_1_extended_pilot_v2/full_regression.log`。
