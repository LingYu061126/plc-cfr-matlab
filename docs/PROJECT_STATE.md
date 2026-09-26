# Project State

更新时间：2026-09-26

## Current stage

Stage 6 Archive Closure completed。Stage 7A 至 Stage 7A.4 的受控算法及观测对照已归档；最新的 R.1/R.2 仅检验指定已知二拓扑的输入阻抗差分辨率和有界连续参数剖面，见 [阶段汇总](stage7a4_resolution_closure.md)。它们尚未替代 Stage 6B baseline，也未完成正式论文报告。Stage 4B 与 Multi-view CFR 均未启动。

## Completed

- Stage 4A freeze：engineering candidate library、CFR forward/profile scoring、candidate set、domain rejection 与 non-unique benchmark。
- Stage 5B.1：candidate margin、normalized confidence score、entropy 与 `UNIQUE_CONFIDENT / MULTIPLE_AMBIGUOUS / LOW_CONFIDENCE / REJECTED` 四状态判决。
- Stage 6A：required/optional nodes、partial edges/switches、图约束、长度范围、最大分支数、复杂度排序、既有 forward interface 导出、old/new library comparison。
- Stage 6A 正式受控实验、测试、CSV/MAT 归档和技术报告。
- Stage 6B：wrong-open/wrong-closed prior sensitivity、3/7/23 candidate scale、长度/负载 parameter uncertainty、T3/T5 与三拓扑 CFR-close identifiability positive controls。
- Stage 6B 正式 CSV/MAT、4 张 PNG 图表、定向测试和技术报告。
- Stage 7A：独立的有界粗到细参数剖面搜索、局部校准、六类成对对照及安全审计；安全检查通过，但候选规模下的确认率退化尚未解决。
- Stage 7A.4-R.1/R.2：在每次复输入阻抗观测误差仍为 1 Ω RMS 的二拓扑合成控制中，分别审计固定参数下的阻抗差分辨率与有界连续参数拟合；独立测试、紧凑汇总、配置和日志见 [汇总报告](stage7a4_resolution_closure.md)。

## Key commits

- `54868370cc6c426f417681146caace79de78291` — Stage 4A canonical calibration identity source。
- `9611b284da57bd10cd64ee7e48c7ba9f3ec46a92` — Stage 4A clean-source freeze closure。
- `50267e30da9f3d42789d12c6b3fdfead85ac0c86` — Stage 5B.1 objective confirmation。
- `bea0aee10b216ba42813329772f05a24dbdca07c` — Stage 6A / Stage 6B 统一归档及本次复现验证基线。

## Stage 6 reproducibility identity

- 独立临时工作树中的 MATLAB R2024a 定向测试、完整回归和 Stage 6A/6B formal 复现均通过；11 份正式科学 CSV 的 4,426 个非运行时间字段按记录容差一致。新增归档完整性测试已纳入完整回归。
- 环境、命令、前置派生文件、容差与非致命 warning 见 [`stage6_reproducibility_closure.md`](stage6_reproducibility_closure.md)。
- 原始字节 SHA-256 清单及逐字段对照见 [`results/data/stage6_closure/`](../results/data/stage6_closure/)；post-commit archive-closure 验证日志见 [`results/logs/stage6_closure/`](../results/logs/stage6_closure/)。这些日志不是最初生成正式结果时的原始日志。
- 本次没有改变 Stage 4A/5B.1 冻结源码或结果，也没有覆盖 Stage 6A/6B canonical CSV、MAT、PNG。

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

若考虑把连续参数拟合用于主线，先在实际候选规模、候选库外拓扑、参数域外和非唯一正控制上独立校准并检查错误唯一、库外误接受及运行成本；当前二拓扑灵敏度结果不足以批准替换完整判定。Stage 6B 仍是独立 baseline；正式报告／论文综合撰写尚未在本轮启动。Multi-view CFR 是可选后续增强，不是当前主线的阻塞条件。
