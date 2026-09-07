# Stage 4A.6.3.1-R.1 结果目录

本目录保存 R.1 的指标语义、校准身份和独立统计修正结果。它不覆盖历史 `results/data/stage4a6_3_1_r/`，也不包含完整 Final。

## 运行范围

- 网格：`A_stage4a1_quick61`
- 候选拓扑：7 个
- Calibration：14 个独立场景
- Pilot：35 个独立场景
- Profile：26 个接受场景进入成员 profile
- `final_reserved`：只生成身份清单，未生成 CFR、未评分
- MATLAB：R2024a
- Worker：1，串行

## 主要文件

```text
scenario_manifest.csv
final_reserved_manifest.csv
configuration_manifest.csv
topology_calibration_thresholds.csv
parameter_calibration_thresholds.csv
runtime_summary.csv
calibration/
pilot/pilot_match_decisions.csv
pilot/pilot_member_evidence.csv
pilot/pilot_scoring_labels.csv
pilot/pilot_metrics.csv
pilot/independence_audit.csv
pilot/observation_cluster_audit.csv
stage4a6_3_1_r1_pilot_results.mat
```

大型 MAT 和缓存用于本地复核；CSV、配置、日志、哈希和 MATLAB 入口构成可追溯重建链。参数 OOD 不再替代 false-unique；不可靠 profile 不允许生成确定的参数域状态。完整 Final 未运行，Stage 4B 未启动。[本次运行]
