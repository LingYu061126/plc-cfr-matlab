# Stage 7A.1 参数校准与候选剖面判定诊断报告

本报告按预先写定的 [诊断协议](stage7a1_diagnostic_protocol.md) 分析 Stage 7A 候选规模实验。标记“[代码确认]”表示源码分支或公式直接支持；“[实验验证]”仅表示本次受控合成模型、固定种子和样本下的观测；“[待验证]”不构成算法修改依据。`UNIQUE_CONFIDENT` 是当前候选库和校准域内的判决，不是物理全局唯一。

## 1. 身份、范围与数据

- [代码确认] 审计开始时 `main`、`origin/main`、HEAD 均为 `38fcced7eac5aa310b7604afebd1807619a05169`（Stage 7A 后的完整回归验证提交）；Stage 7A 算法提交是 `64c2ec2258b14d4eb02d15b88cdbb6672e992548`。开始时工作树干净。结果元数据中的 `source_commit` 固定表示审计基线身份，不是新增诊断文件最终所在的提交号。
- [代码确认] 原 Stage 7A 配置、缓存、距离、校准、四状态判决与正式 CSV 已逐项核对。只读取 Stage 4A、5B.1、6A、6B 冻结代码和正式结果；未更改其算法、阈值、频率网格、随机种子或结果。新增结果全部位于 [Stage 7A.1 数据目录](../results/data/stage7a_1/)，日志位于 [Stage 7A.1 日志目录](../results/logs/stage7a_1/)。
- [实验验证] 重放原 Stage 7A 正式 candidate-scale 的每库 10 条，得到 30/30 行状态、集合大小和距离匹配归档 CSV；最大距离差 `4.58×10⁻¹⁶`。另以独立固定 C 种子生成每库 100 条 20 dB 测试观测，三库共 300 条物理观测；同一观测供 Stage 6B 与各 Stage 7A 条件逐样本配对。A（candidate set/domain）、B（evidence）、C（最终测试）种子空间相异；库身份、候选顺序、搜索域、三组身份哈希、种子及配置见 [配置身份表](../results/data/stage7a_1/formal/stage7a1_calibration_identity.csv)、[元数据](../results/data/stage7a_1/formal/stage7a1_metadata.csv) 与 `stage7a1_config_snapshot.mat`。

归档主表为 [逐样本诊断](../results/data/stage7a_1/formal/stage7a1_sample_diagnostics.csv)、[逐候选诊断](../results/data/stage7a_1/formal/stage7a1_candidate_diagnostics.csv)、[分组汇总](../results/data/stage7a_1/formal/stage7a1_group_summary.csv)、[搜索审计](../results/data/stage7a_1/formal/stage7a1_search_audit.csv) 和 [资源成本](../results/data/stage7a_1/formal/stage7a1_resource_cost.csv)。逐候选表包含物理签名、profile distance、名次、经验 p 值与最佳模板；逐样本表包含真值库覆盖、集合、domain 相对距离与阈值、margin、normalized confidence score、entropy、逐门槛布尔值、四状态、判决分支和失败码。normalized confidence score 不是 Bayesian posterior，也不能跨候选库当作统一概率。

## 2. 原 10 条/库结果：选错与保守输出分开

| 候选数 | Top-1 为真值 | 真值入集合 | 正确 `UNIQUE_CONFIDENT` | `LOW_CONFIDENCE` | `REJECTED` | false unique |
|---:|---:|---:|---:|---:|---:|---:|
| 3 | 10/10 | 8/10 | 7/10 | 1/10 | 2/10 | 0/10 |
| 7 | 10/10 | 10/10 | 8/10 | 2/10 | 0/10 | 0/10 |
| 23 | 10/10 | 10/10 | 4/10 | 6/10 | 0/10 | 0/10 |

[实验验证] 3 候选的正确唯一率 7/10 的 95% Wilson 区间为 `[0.397,0.892]`；7 候选 8/10 为 `[0.490,0.943]`；23 候选 4/10 为 `[0.168,0.687]`。即使 30/30 Top-1 正确和 0/30 false unique，这些小分母也不能给出总体识别率或零风险结论。Stage 6B 对这三组同一归档观测各为 10/10 正确唯一，但 Stage 7A 的拒绝/低置信度不得计作“选错候选”。

[实验验证] 非唯一判决的逐样本归因如下；所有这些行的 Top-1 仍为真值：

- 3 候选：`scale_small_r01`、`r07` 的真值均被 candidate-set p 值门槛排除，集合为空、最终 `REJECTED`；`r04` 为真值单元素集合，但 margin 和 confidence 未过，故 `LOW_CONFIDENCE`。
- 7 候选：`scale_medium_r01`、`r07` 都是真值单元素集合；margin/confidence 通过、entropy 不通过，故 `LOW_CONFIDENCE`。
- 23 候选：`scale_large_r02/r03/r05/r06/r08/r10` 的集合均为 `{G004,G007}`，真值 `G004` 在内；margin、confidence、entropy 均通过，但集合大小为 2，现有四状态函数输出 `LOW_CONFIDENCE`。这是候选竞争和状态语义的交互，不是 Top-1 排错；两者是否在物理上真正不可辨识仍需独立研究。

两条重点小库样本的真值 p 值均为 `1/21=0.047619<0.05`。`r01` 的 domain 相对距离 `0.412005<0.421770`，是集合空导致拒绝；`r07` 为 `0.423181>0.421770`，集合与 domain 两关同时失败。两条真值 profile distance 分别为 `0.118838`、`0.122530`。[实验验证] 同观测 Stage 6B 真值模板距离分别为 `0.085016`、`0.081100`，最佳主线尺度均为 `0.98`；Stage 7A 缓存 fine-grid 中对应最优为主线 `1.00`、负载 `1.20`。两条真实主线尺度分别为 `0.988280`、`0.987459`。Stage 7A 主线网格步长 `0.025`，未包含 Stage 6B 的 `0.98` 点；“扩大搜索区间”并不意味着离散模板集合嵌套。这是两例残差偏高的具体网格/参数补偿机制证据，但不能据此宣称改变网格就能安全提升确认率。

[实验验证，探索性] 对这两条已知失败观测，仅在预先固定的各校准模型上重新评分，不计入新 C 测试统计。20 dB 窄参数、200 条/候选校准使 `r01` 入集合，但仍为 `LOW_CONFIDENCE`；`r07` 仍拒绝。20 dB 宽参数、100 条/候选使两条都入集合，但都为 `LOW_CONFIDENCE`。增加校准量或改变 nuisance 分布能移动这些样本的集合门槛，却没有把两条变为可信唯一；不能将此探索性结果用于调阈值。

## 3. 独立 100 条/库：逐观测配对

| 候选数 | Stage 6B 正确唯一 | 原 Stage 7A 正确唯一 | Stage 7A 真值入集合 | Stage 7A 其余状态 | 两者均唯一 / 仅 Stage 6B / 仅 Stage 7A / 均非唯一 |
|---:|---:|---:|---:|---|---|
| 3 | 86/100 | 85/100 | 94/100 | 9 low、6 rejected | 74 / 12 / 11 / 3 |
| 7 | 85/100 | 94/100 | 100/100 | 6 low | 79 / 6 / 15 / 0 |
| 23 | 86/100 | 52/100 | 100/100 | 48 low | 40 / 46 / 12 / 2 |

[实验验证] 300/300 条新观测在原 Stage 7A 及 Stage 6B 上的 Top-1 均为真值；本次所有条件观测到的 false unique 均为 0，但单组 0/100 的 95% Wilson 上界仍约 `3.70%`。原 Stage 7A 正确唯一率的 95% Wilson 区间分别为 3 候选 `[0.767,0.907]`、7 候选 `[0.875,0.972]`、23 候选 `[0.423,0.615]`。每库 100 条比归档 10 条更可解释，但三库共享相同物理观测种子，不能把它们合并成 300 个独立的“候选规模效果”。

[实验验证] 3 候选原 Stage 7A 的 6 个拒绝全是空集合，其中 1 个也未通过 domain；另外 9 个 low 均为真值单元素集合的 evidence 门槛不足。7 候选的 6 个 low 均为真值单元素集合，只有 entropy 未过。23 候选的 48 个 low 全是真值加第二候选的双元素集合，三项 evidence 都通过、domain 也通过。这直接定位了本次 23 候选确认率下降的输出机制：candidate-set 竞争与现行多元素集合语义，而非 Top-1 错误或 domain gate 拒绝。[待验证] 此竞争是否代表 CFR 真正不可辨识、模板分辨率或校准分布偏差，不能仅靠一次合成测试定论。

## 4. SNR、nuisance 与校准量的预注册对照

下表每格为“正确唯一 / 真值入集合”，分母均为同一独立测试 C 批的 100 条/库；原 Stage 7A 是同批 A 距离复用的归档方法，其余新条件按 A/B 分离。配置、种子和完整四状态计数见 [分组汇总](../results/data/stage7a_1/formal/stage7a1_group_summary.csv)。

| 校准条件 | 3 候选 | 7 候选 | 23 候选 |
|---|---:|---:|---:|
| 原 Stage 7A：35 dB、宽参数、n=20、A 复用 | 85 / 94 | 94 / 100 | 52 / 100 |
| 20 dB、窄参数、n=20、A/B 分离 | 86 / 89 | 64 / 97 | 49 / 99 |
| 20 dB、窄参数、n=100、A/B 分离 | 72 / 94 | 86 / 94 | 54 / 94 |
| 20 dB、窄参数、n=200、A/B 分离 | 86 / 97 | 88 / 94 | 53 / 97 |
| 35 dB、窄参数、n=100、A/B 分离 | 77 / 94 | 75 / 96 | 52 / 89 |
| 20 dB、宽参数、n=100、A/B 分离 | 78 / 99 | 86 / 98 | 47 / 91 |
| 35 dB、宽参数、n=20、A/B 分离 | 73 / 94 | 80 / 95 | 40 / 89 |
| 35 dB、宽参数、n=100、A/B 分离 | 77 / 94 | 74 / 88 | 55 / 96 |
| 原 A 固定、仅 B 独立 n=20 | 72 / 94 | 89 / 100 | 52 / 100 |

[实验验证] 固定 n=100 与窄参数比较 20/35 dB，可隔离这一次配置中的 SNR 差；固定 20 dB、n=100 比较窄/宽参数，可隔离这一次 nuisance 分布差。然而三个候选规模的结果并不同向：35 dB 在 3/7 候选降低唯一率，在 23 候选几乎不变；宽 nuisance 在 3 候选提高集合覆盖，在 23 候选降低集合覆盖。n=20/100/200 也没有单调提升。因此不能把 Stage 7A 原结果归因于单一 SNR mismatch、单一 nuisance mismatch 或样本数不足，更不能仅凭增加样本数“修复”分布错配。有限校准种子和离散 p 值/阈值波动仍是解释限制。

## 5. 同批距离复用、粗到细精确性与状态语义

- [代码确认] `stage7a_calibrate_candidate_library` 用同一批 profile 距离先拟合 conformal-style candidate set，再在这些行上形成 `set_size`，筛选 Stage 5B.1 evidence 参考行。n=20、`alpha=0.05` 时校准行自身进入 p 值计数，使原 A 批真值集合覆盖为 3/7/23 库各 100%；这不是对独立测试覆盖率的估计。新 A/B/C 方案只以 A 拟合集合/domain，以独立 B 形成 evidence 参考，以独立 C 测试。
- [实验验证] 保持原 A 不变、仅改用独立 B 后，B 批真值集合覆盖为 3 候选 `57/60`、7 候选 `139/140`、23 候选 `438/460`，对照 A 批自身的 `60/60`、`140/140`、`460/460`；evidence 参考数由原 `60/44/38` 变为 `57/43/35`。同一 C 批唯一数由原 `85/94/52` 变为 `72/89/52`。这证明复用改变参考样本的独立性、阈值和本次判决，但不能从一次独立 B 抽样判定偏差方向或幅度的总体规律；23 候选的多元素集合问题也未因此消失。
- [实验验证] 对 30 条归档和 300 条独立观测的 Stage 7A 原模型，穷举相同缓存内全部 admissible fine 模板。330 次评分中 48 个候选-观测行存在粗到细距离高于穷举的误差，最大 `0.000505377`；这些是 16 条物理观测在三库中的重复。相应全局最优模板在粗最优点的局部窗口外，说明单 pivot 可能漏掉缓存内最优。然而 Top-1、candidate set 和四状态变化均为 `0/330`；两条重点小库案例的粗到细与穷举距离完全相同。故这一已测搜索误差不能解释当前确认率下降。穷举仅限现有离散缓存，不证明连续参数全局最优。
- [代码确认] `classify_stage5b1_decision_state` 先处理空集合/domain 拒绝；单元素且全部 evidence 通过才 `UNIQUE_CONFIDENT`；多元素且 evidence 不足才 `MULTIPLE_AMBIGUOUS`；多元素但三项 evidence 通过则为 `LOW_CONFIDENCE`。新增测试锁定了这两个多元素分支。此输出符合当前代码定义，但“集合多候选且分数看似分离”命名为 low 而非 ambiguous，语义可能令人误读；本阶段不修改 Stage 5B.1 定义。新增 `stage7a_score_observation` 校验搜索域哈希、候选库身份/顺序、缓存参数网格坐标和频率网格，不匹配即拒绝，防止静默使用错误校准模型；定向测试已覆盖。此检查针对配置/缓存身份，不宣称对缓存 CFR 数组做逐字节完整性校验。
- [代码确认] Stage 7A 原 `safety.pass` 只覆盖 false unique、库外误接受和 T3/T5、three-topology-close 非唯一正控制；不覆盖集合覆盖率、正确唯一率、domain 分布或算法总体优势。Stage 7A.1 新拆分模型未重跑库外/非唯一安全控制，因此本报告不为这些模型宣布安全通过。

## 6. 测试、运行成本与边界

[实验验证] MATLAB `24.1.0.2537033 (R2024a)`、Linux `glnxa64`，串行、无并行池/worker。实际入口为 `test_stage7a_profile_search`、`test_stage7a1_diagnostics`，`run_stage7a1_diagnostic(pwd,'smoke')`、`run_stage7a1_diagnostic(pwd,'formal')`；相关回归另运行 `test_stage5b1_decision_metrics`、`test_stage6a_candidate_generation`、`test_stage6b_robustness`、`test_stage6_archive_integrity`。这些命令在仓库根目录、独立 `MATLAB_PREFDIR` 下，用现有兼容库执行 `matlab -nodisplay -nosplash -softwareopengl -batch`，不改变实验科学配置。最终定向测试、smoke、正式诊断、相关回归退出码均为 0，独立 CSV 一致性检查通过。正式 MATLAB 计算 `59.446 s`，输出 3076 条样本方法行、33708 条候选行、330 条搜索样本审计行及 3630 条搜索候选审计行；多条件重复评分同一 C 批，3076 不是独立物理样本数。最终有效 diary 见 [定向测试](../results/logs/stage7a_1/stage7a1_targeted_tests_verified.log)、[smoke](../results/logs/stage7a_1/stage7a1_smoke_verified.log)、[formal](../results/logs/stage7a_1/stage7a1_formal_verified.log)、[相关回归](../results/logs/stage7a_1/stage7a1_related_regression_verified.log)。同目录无 `verified` 后缀日志与 `stage7a1_smoke_final.log` 是身份检查补齐前或沙箱内 `client-v1` 退出挂起期间的运行记录，不作为最终退出码证据。最初的 [结果一致性日志](../results/logs/stage7a_1/stage7a1_result_integrity.log) 后，又对最终重跑的 3076/33708/330 行及 44 个分组再次做独立读取检查，全部一致。本次未把 `tests/run_tests.m` 当作完整回归重跑：其 Stage 4A clean-Git 检查与本阶段必要的未提交诊断文件冲突；该文件未修改且 Stage 6 archive 哈希测试通过。不得将相关回归冒称完整 `run_tests` 通过。

[实验验证] 23 候选原 Stage 7A 模型 `whos` 字节数约 `1.52 MB`，缓存建立 `0.443 s`、原校准 `0.539 s`；同次 Stage 6B baseline 模型约 `0.93 MB`。23 候选 matched20_n100 独立 A/B 校准分别约 `2.77/3.06 s`，n200 为 `5.68/5.32 s`。这些是 MATLAB 变量逻辑大小与本次 wall-clock，非峰值进程内存、跨机器性能或大规模复杂度结论。23 候选不代表大规模候选库。

所有结论仅适用于当前受控 MATLAB 模型内合成观测、给定候选 grammar、频率网格、模板缓存与噪声/参数分布；没有真实 PLC 收发机或现场低压台区验证。拒绝不能自动定位错误台账，真值入库不保证可辨识，候选集合覆盖也不等于唯一识别。

## 7. 诊断结论与下一轮修改门槛

[代码确认 + 实验验证] 本次没有证据把候选规模现象概括为“选错拓扑”：归档和新 C 批均无 Top-1 错误。小库有集合漏纳入（部分同时 domain 拒绝），且两条重点样本存在非嵌套离散网格引发的更高真值残差；中库主要是 entropy evidence 未过；大库主要是真值与另一候选共同入集合，现有状态语义给出 low。粗到细确有缓存内局部最优遗漏，但未影响已测判决。校准复用与分布差异需要保留为独立风险，现有对照未支持简单的单因解释。

[待验证] 下一轮若考虑调整 profile 网格、candidate-set 校准或多候选状态语义，须先单独预注册改变的科学定义、使用独立 A/B/C 种子并重新校准，不得复用本次 C 批调参。只有在新独立测试中同时满足真值集合覆盖、正确唯一及其区间、false unique、库外误接受、域外拒绝、T3/T5 与 three-topology-close 不强制唯一、wall-clock/内存代价均可接受，且不恶化 Stage 6B 安全边界时，才建议进入算法修改与保留评估。当前 Stage 7A.1 完成的是判因诊断和观测接口，不宣称新算法已优于 Stage 6B，也不把保守拒绝本身视为缺陷。
