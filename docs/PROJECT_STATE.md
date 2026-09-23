# Project State

更新时间：2026-09-23

## Current stage

Stage 6B — robustness and identifiability evaluation 已完成。Stage 6A 与 Stage 6B 的代码、正式结果、测试和报告统一归档于本阶段提交。

## Completed

- Stage 4A freeze：engineering candidate library、CFR forward/profile scoring、candidate set、domain rejection 与 non-unique benchmark。
- Stage 5B.1：candidate margin、normalized confidence score、entropy 与 `UNIQUE_CONFIDENT / MULTIPLE_AMBIGUOUS / LOW_CONFIDENCE / REJECTED` 四状态判决。
- Stage 6A：required/optional nodes、partial edges/switches、图约束、长度范围、最大分支数、复杂度排序、既有 forward interface 导出、old/new library comparison。
- Stage 6A 正式受控实验、测试、CSV/MAT 归档和技术报告。
- Stage 6B：wrong-open/wrong-closed prior sensitivity、3/7/23 candidate scale、长度/负载 parameter uncertainty、T3/T5 与三拓扑 CFR-close identifiability positive controls。
- Stage 6B 正式 CSV/MAT、4 张 PNG 图表、定向测试和技术报告。

## Key commits

- `54868370cc6c426f417681146caace79de78291` — Stage 4A canonical calibration identity source。
- `9611b284da57bd10cd64ee7e48c7ba9f3ec46a92` — Stage 4A clean-source freeze closure。
- `50267e30da9f3d42789d12c6b3fdfead85ac0c86` — Stage 5B.1 objective confirmation。
- Stage 6A / Stage 6B：本阶段统一归档提交，包含候选拓扑生成框架、鲁棒性与可辨识性评估、正式结果、测试及技术报告。

## Main results

- broad unknown-switch partial prior 生成 7 个候选，与旧 7 候选物理网络集合一致，真拓扑包含率为 1。
- informative switch prior 将候选数由 7 降至 2，仍包含真拓扑；9 个正式测试样本得到 7 `UNIQUE_CONFIDENT`、1 `LOW_CONFIDENCE`、1 `REJECTED`。
- stale switch prior 生成 4 个候选但排除真拓扑；该受控实验中 9/9 被拒绝，未出现错误 confident unique。
- 正式生成时间：旧库 0.055695 s；broad 0.251640 s；informative 0.031343 s；stale 0.015762 s。
- Stage 4A forward/scoring 与 Stage 5B.1 decision source 未修改。
- Stage 6B prior sensitivity：14 个实际施加 wrong-open/wrong-closed 的样本全部拒绝，false unique 为 0；20% population error 使 coverage 降至 0.8。
- Candidate scale：3/7/23 candidates 下生成中位时间为 0.0005525/0.001224/0.004593 s，平均评分时间为 0.0002933/0.0003784/0.0009484 s；30/30 仍为正确 confident unique。
- Parameter uncertainty：0% length error + 随机 ±20% load perturbation 时 10/10 confident unique；±5%、±10%、±20% 下 60/60 rejected，false unique 为 0。
- Identifiability：T3/T5 和三拓扑 CFR-close 案例均输出 `MULTIPLE_AMBIGUOUS`；三候选 normalized entropy 为 0.9999999993。
- Stage 6B formal 串行总时间 11.068872 s，未使用 parallel worker。

结果文件：

- `results/data/stage6a/stage6a_candidate_generation_summary.csv`
- `results/data/stage6a/stage6a_runtime.csv`
- `results/data/stage6a/stage6a_identification_summary.csv`
- `results/data/stage6a/stage6a_identification_metrics.csv`
- `results/data/stage6a/stage6a_results.mat`
- `results/data/stage6b/stage6b_prior_sensitivity.csv`
- `results/data/stage6b/stage6b_candidate_scale.csv`
- `results/data/stage6b/stage6b_parameter_uncertainty.csv`
- `results/data/stage6b/stage6b_identifiability.csv`
- `results/data/stage6b/stage6b_runtime.csv`
- `results/data/stage6b/stage6b_results.mat`

## Known limitations

- 当前只验证小型、一层分支、受控合成 partial prior，不是现场验证。
- 潜在节点和 allowed edge universe 仍需工程输入，尚未直接接入独立 GIS/台账。
- optional-node 和 edge enumeration 随规模组合增长，目前依赖显式上限。
- 冻结 forward adapter 只支持 TX--RX 单主路径加内部节点一层叶支路。
- Stage 6A domain/evidence calibration 是每个候选库的局部实验校准，不是 Stage 4A freeze 的 87-candidate threshold。
- 一个 stale-switch 案例的完全拒绝结果不能外推到所有漏真拓扑场景。
- Stage 6B prior error 仅测试一条 wrong-open 和一条 wrong-closed edge；14/14 rejection 不能外推到所有错误先验。
- Candidate scale 上限仅 23，且仍属于固定主路径一层分支 grammar。
- Parameter experiment 采用全主线统一 length scale；未覆盖逐线段误差、RLGC 误差、频变复负载或同步误差。
- ±5% 及更大误差的全拒绝只说明当前 ±2% calibration protocol 较窄，不是现场通用容差。
- 三拓扑 close case 使用近电气不可见的退化支路，不是典型台区参数。

## Next recommended step

优先将 Stage 4A/5B.1/6A/6B 整理为论文实验章节，明确受控仿真与尚未现场验证的边界。若继续技术研究，建议 multi-view CFR：通过双向/多节点观测检验 T3/T5 和 near-invisible branch ambiguity 能否被额外视角打破。
