# Stage 4A.7.1 结果目录

本目录保存 A 网格受控候选生成与候选确认 Pilot。实验使用 140 个独立 calibration 场景和 33 个独立 Pilot CFR；`final_reserved` 只保存 seed 身份，未运行。结果不是完整 Final，也不是现场或真实 PLC PHY 验证。

主要文件：

- `configuration_manifest.csv`：科学哈希、源码树哈希、校准身份、split seeds 和仓库相对缓存路径；
- `legacy_candidate_audit.csv`、`engineering_candidate_audit.csv`、`topk_candidate_audit.csv`：三类候选生成证据；
- `candidate_coverage_audit.csv`：工程覆盖、正向模型覆盖和评分库覆盖分层；
- `candidate_complexity_audit.csv`：参数维数、模板数和候选残差审计；
- `calibration_scenario_manifest.csv`、`calibration_nonconformity.csv`、`candidate_set_calibration.csv`：每类 20 条独立 calibration；
- `pilot_scenario_manifest.csv`、`pilot_match_decisions.csv`、`pilot_scoring_labels.csv`、`pilot_metrics.csv`：truth-free 决策与离线评分；
- `scenario_equivalence_audit.csv`、`independence_audit.csv`：same-theta 等价和 split 独立性；
- `runtime_summary.csv`、`stage4a7_1_pilot_results.mat`：运行分解与可复核汇总。

复现入口：

```matlab
run_stage4a7_1_candidate_generation_and_confirmation()
```

最终运行环境为 MATLAB `24.1.0.2537033 (R2024a)`，串行 1 worker。Pilot 和完整回归日志分别位于：

- `results/logs/stage4a7_1/stage4a7_1_calibrated_pilot_final.log`
- `results/logs/stage4a7_1/stage4a7_1_full_regression_final.log`

最终 scientific hash 为 `11e7be32aeffcf55df2bd00cad81a4f7b0c0890194fd4fe2a2071893993a8acb`；source-tree hash 为 `76cd43be057d65b27321d1ec6621c23960af2ec9f96a56dfb5191b50f6ff012a`。
