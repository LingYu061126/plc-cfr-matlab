# Stage 2.3 final audit progress

本文件记录本次 `/goal` 审计的实际检查点、命令、结果和剩余问题。未运行内容不标记为通过。

## 初始审计

命令：`git status --short`、`git log -3 --oneline` 及 fixed 文件清单。

结果：工作树在审计开始时干净；最新提交为 `672b01a results(stage2.3): publish formal fixed aggregation`。公开仓库根目录没有单独的 `AGENTS.md`；已按项目实际结构完整读取上级 `Codes/AGENTS.md`，并读取任务书、README、PUBLISHING 和阶段 2.3 报告。没有删除历史结果，也没有进入 Stage 3。

剩余问题：公开仓库不包含大型 formal MAT；formal fixed 轻量结果的来源需在后续检查点单独核对。

## 检查点 1：partial 批次和模式隔离

公开 smoke 文件检查命令：

```text
find results/data -maxdepth 1 -type f -name 'stage2_3_*partial*_results.mat' -printf '%f\\n' | sort
```

结果：公开仓库有 7 个、且仅有 `stage2_3_smoke_partial_<measurement_kind>_b1_results.mat`；7 个 measurement kind 分别为 `bidirectional_endpoint_fixed`、`dual_receiver_complete`、`siso_forward`、`siso_forward_asymmetric`、`siso_reverse_endpoint_fixed`、`siso_reverse_role_fixed`、`three_view_complete`。当前 helper `stage2_3_partial_files` 会校验文件名、batch、MAT `mode`、`sc.measurement_kinds` 和 `config.measurement_kind`，smoke 期望值为 7。

formal 来源文件检查命令：

```text
find ../matlab_plc_cfr/results/data -maxdepth 1 -type f -name 'stage2_3_partial_*_results.mat' | sort
sed -n '1,80p' results/logs/stage2_3_formal_upgrade.log
```

结果：本机研究目录找到 14 个 legacy formal MAT，即 7 种 measurement kind、每种 `b1`/`b2` 各一个。升级日志逐一记录 14 个输入且每个补算 6 条 raw pairwise；输入 MAT 的 mode/config 校验由 `stage2_3_upgrade_legacy_pairwise` 执行。公开仓库没有这些 14 个大型 MAT，因此 clone 后不能独立执行 formal 汇总；不会把未标记 legacy 文件混入 `stage2_3_partial_files(...,'formal')`。

剩余问题：正式原始 MAT 不在公开仓库；公开仓库只能审计已发布的 formal fixed 轻量 CSV 和生成日志。

## 检查点 3：fixed CSV 结构

MATLAB 命令使用 `readtable` 读取 smoke/formal fixed 的 pairwise、summary、confusion、config，并检查唯一键、列名和有限性。

实际结果：

```text
smoke pairwise_rows=42 summary_rows=371 confusion_rows=1456 config_rows=7 unique_keys=42 kinds=7 raw_finite=1 has_norm=1 has_raw=1
formal pairwise_rows=42 summary_rows=371 confusion_rows=1456 config_rows=7 unique_keys=42 kinds=7 raw_finite=1 has_norm=1 has_raw=1
```

结果：smoke/formal fixed 均满足 7 × C(4,2)=42；pairwise 同时包含 `complex_distance` 和 `complex_distance_raw`，raw 距离全为有限值。历史旧 formal CSV 未被覆盖。

剩余问题：上述正式 CSV 是适配 legacy formal MAT 后的 fixed 轻量汇总，不是从头重跑 formal 实验；来源审计见检查点 4。

## 检查点 2：完整 MATLAB 测试

命令：

```matlab
addpath('src'); addpath('config'); addpath('experiments'); addpath('tests');
diary('results/logs/goal_stage2_3_tests.log'); disp(version); run_tests; diary off
```

实际环境：MATLAB `24.1.0.2537033 (R2024a)`，MATLAB license test=1；未使用额外工具箱。

结果：退出码 0。阶段 1.5、阶段 2、阶段 2.1、阶段 2.2、阶段 2.3 全部报告 `ALL ... TESTS PASSED`。阶段 2.3 中结构体安全转表、raw/normalized complex CFR 距离、42-pair 审计以及 smoke/formal partial 文件隔离测试均实际运行并通过。

剩余问题：无测试失败。长时间 MATLAB 启动/退出不影响退出码和日志完整性。

## 检查点 4/5：formal 来源和 20 dB 关键指标

来源核对命令：`git ls-files`、`git check-ignore`、`sha256sum`，以及查看 `stage2_3_formal_upgrade.log` 和 `stage2_3_formal_fixed_compile.log`。

结果：`stage2_3_formal_fixed_summary.csv` 与历史 `stage2_3_summary.csv` SHA-256 相同；这确认 trial/summary/confusion 统计沿用了旧 formal MAT 的原始汇总。新 `complex_distance_raw` 列不是旧 MAT 中直接保存的字段，而是 `stage2_3_upgrade_legacy_pairwise` 基于当前完整网络模型重新补算的 nominal pairwise 数据。日志记录 14 个旧 MAT、每批 6 个 raw pairwise，随后 fixed 汇总得到 371/42/1456 行。没有从头重新运行 14 批 formal 实验；formal fixed trial CSV 本机生成约 44 MB，但按发布策略未加入 Git。

20 dB、`noise_only`、`amp_phase_joint_weighted` 的 formal fixed 汇总（每行 100 次 trial；列为 `strict/equiv/unique/ambiguous/false_unique`）：

```text
measurement_kind                 method                  strict  equiv  unique  ambiguous  false_unique
bidirectional_endpoint_fixed     nominal_nearest           0.920   0.920   0.920     0          0
bidirectional_endpoint_fixed     nuisance_aware_joint     0.920   0.920   0.920     0          0
dual_receiver_complete           nominal_nearest           1.000   1.000   1.000     0          0
dual_receiver_complete           nuisance_aware_joint     1.000   1.000   1.000     0          0
siso_forward_asymmetric           nominal_nearest           0.880   0.880   0.880     0          0
siso_forward_asymmetric           nuisance_aware_joint     0.880   0.880   0.880     0          0
siso_forward                      nominal_nearest           0.750   1.000   0.500     0.500      0
siso_forward                      nuisance_aware_joint     0.7375  1.000   0.500     0.375      0.125
siso_reverse_endpoint_fixed       nominal_nearest           0.880   0.880   0.880     0          0
siso_reverse_endpoint_fixed       nuisance_aware_joint     0.880   0.880   0.880     0          0
siso_reverse_role_fixed           nominal_nearest           0.900   0.900   0.900     0          0
siso_reverse_role_fixed           nuisance_aware_joint     0.900   0.900   0.900     0          0
three_view_complete                nominal_nearest           1.000   1.000   1.000     0          0
three_view_complete                nuisance_aware_joint     1.000   1.000   1.000     0          0
```

关键核对：对称 `siso_forward` 的 T3/T5 归一化复数 CFR 距离为 `1.0331e-17`，raw 距离为 `1.1843e-16`，因此只能报告 `{T3,T5}` 等价类；nominal 的严格识别约 0.75、等价类识别 1、唯一识别 0.5，joint 的严格识别约 0.7375、等价类识别 1、唯一识别 0.5，且 joint `false_unique=0.125`。这不是算法成功打破对称，而是等价类内伪唯一输出风险。相应地，非对称端接和完整多视图的 T3/T5 距离在当前模型中非零，但仍只代表该模型和参数条件下的可分性。

距离定义核对：`complex_distance` 是单位范数归一化后的复数 CFR 形状距离；`complex_distance_raw` 是不归一化的绝对复数 CFR 差异。前者用于保持既有等价类定义，后者只作绝对标定审计，二者未被混称。

剩余问题：以上 formal 指标来自旧 formal trial 的 fixed 汇总，不应表述为本次从头 formal 重跑或现场性能。

## 检查点 6：smoke 入口和最终结构复核

第一次直接调用 `run_stage2_3('smoke')` 的进程在前四个 batch 后提前退出，未产生完整入口返回码；该次未计为通过。随后使用可轮询 MATLAB 终端会话重试同一命令：

```matlab
diary('results/logs/goal_stage2_3_smoke_retry.log');
run_stage2_3('smoke');
diary off
```

结果：MATLAB 退出码 0；7 个 measurement kind 全部生成，每批 `evaluation rows=1060`，最后记录 `Stream-compiled 7 sealed batches`。当前 smoke fixed 文件行数为：pairwise 43（表头+42）、summary 372（表头+371）、confusion 1457（表头+1456）、config 8（表头+7）、trials 7421（表头+7420）。7 个 smoke partial MAT 均存在，且入口先运行的完整阶段 1.5–2.3 测试全部通过。

剩余问题：本次 smoke 运行按设计更新了可复现的 `stage2_3_smoke_fixed_*` 轻量结果；旧版本仍由 Git 历史提交保留。formal fixed 文件没有被 smoke 覆盖。

## 检查点 7：文档和最终结构复核

命令：对 smoke/formal fixed 重新执行 `wc -l`、按 `measurement_kind|topology_i|topology_j` 排序去重、kind 去重和 raw 空值检查，并检查 pairwise 表头。

结果：两组 fixed pairwise 均为 43 行（表头+42），summary 372 行（表头+371），confusion 1457 行（表头+1456），config 8 行（表头+7）；两组均 `unique_keys=42`、`kinds=7`、`raw_empty=0`。表头包含 `complex_distance` 和 `complex_distance_raw`。README、PUBLISHING 和阶段 2.3 报告已补充当前测试状态、formal fixed 来源、归一化/raw 距离含义及模型边界。

最终剩余问题：公开 clone 缺少 14 个大型 formal MAT 和约 44 MB formal trial CSV，因此不能独立重建 formal fixed；本次没有伪造完整 formal 重跑。模型仍是 2–30 MHz 全导频频域等效 `Y=XH+N`，不是完整 OFDM 收发机或现场 PLC 实验。
