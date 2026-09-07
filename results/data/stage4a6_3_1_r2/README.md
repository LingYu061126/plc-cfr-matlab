# Stage 4A.6.3.1-R.2 结果索引

本目录保存 R.2 的 A/61 点、14 calibration + 35 Pilot 结果。它不是完整 Final，也不进入 Stage 4B。

## 当前有效并行复核

原始 `parallel_benchmark.csv` 和 `parallel_correctness_audit.csv` 保留了宿主 MATLAB 环境修复前的失败/不可评价记录，不能单独代表最终并行结论。当前源码和宿主环境下的有效复核保存在：

- `parallel_benchmark_host_recheck.csv`；
- `parallel_correctness_audit_host_recheck.csv`；
- `../host_serial_w01_20260908/`；
- `../host_parallel_w04_20260907/`；
- `../host_parallel_w06_20260907/`；
- `../host_parallel_w08_20260907/`。

四组运行均为 14 calibration + 35 Pilot，决策、成员证据和 scoring labels 的 SHA256 完全一致。运行时间分别为 59.730270 s、72.374594 s、73.935406 s 和 78.254347 s；当前任务没有并行加速。8 workers 的运行期间观察到明显内存/swap 压力，峰值 RSS 未可靠测得，因此不推荐默认使用 8 workers。

## 可复核入口

```matlab
addpath('src'); addpath('config'); addpath('experiments');
run_stage4a6_3_1_r2_equivalence_parallel(pwd, 1, 'pilot');
```

运行入口会重新生成同一科学配置下的候选 cache、场景、topology calibration、parameter calibration、场景级等价审计、成员证据和 Pilot 指标。结果目录可能因重新运行时间而变化，但 `compatibility_hash`、`source_tree_hash`、split seed 和规则版本由配置冻结。

## 主要文件

- `configuration_manifest.csv`：最终非空双 calibration hash 和科学身份；
- `scenario_manifest.csv`：14 calibration + 35 Pilot 的场景身份；
- `pilot/scenario_equivalence_audit.csv`：nominal、same-theta、composite 等价性；
- `pilot/pilot_match_decisions.csv`：truth-free 拓扑确认输出；
- `pilot/pilot_member_evidence.csv`：每个已接受成员的参数证据；
- `pilot/pilot_scoring_labels.csv`：离线评分标签；
- `pilot/pilot_metrics.csv`：无条件和选择性指标；
- `parallel_benchmark.csv`、`parallel_correctness_audit.csv`：环境修复前的并行尝试和不可评价原因。
- `parallel_benchmark_host_recheck.csv`、`parallel_correctness_audit_host_recheck.csv`：宿主环境修复后的有效 1/4/6/8 workers benchmark 与逐文件一致性结果。

大体积 `.mat` cache/model 是本地运行产物，未作为轻量 Git 依赖；代码、配置、seed、hash、CSV 汇总和日志提供确定性重建依据。R.2 的并行池在宿主环境复核中成功启动并完成 4/6/8 workers，但当前任务规模下没有获得加速。
