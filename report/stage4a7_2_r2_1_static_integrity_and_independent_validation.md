# Stage 4A.7.2-R.2.1：静态完整性与独立验证记录

## 1. 阶段范围与结论

本阶段修正 Stage 4A.7.2-R.2.1 中与摘要、科学身份、候选生成接口、确定性排序、参数采样和方法选择有关的实现，并运行受控串行 smoke。研究仍限于 A 网格、共享工程先验和模型生成的复数 CFR；没有运行完整 Final，也没有启动 Stage 4B。

综合结论为 **partial / blocked**：静态修正、定向测试、历史回归、smoke、formal 和补充的 35 场景独立 Pilot 均已执行；但当前结果仍不是任务书意义上的完整独立参数域验证，场景等价性和拓扑/参数分层指标存在明确缺口。

## 2. 证据等级与运行环境

- `[代码静态核对]` 当前分支为 `main`，工作前后远端基线均为 `f6d21d17bc80fa13a738f986b8e9b60b88a50555`；本阶段修改尚未提交。
- `[本次运行]` MATLAB 为 `24.1.0.2537033 (R2024a)`。运行使用 MATLAB R2024a 的串行 `-batch` 入口，配置 `use_parallel=false`、`num_workers=1`。
- `[本次运行]` 为避免此前 ApplicationService/`agent::interprocess::mutex` 启动故障，使用了隔离的 `HOME`、`MATLAB_PREFDIR`、兼容库路径、`QT_QPA_PLATFORM=offscreen`、`-nojvm` 和 `-singleCompThread`。MATLAB 命令可执行并返回 0，但启动输出仍出现 MathWorks interprocess mutex 警告；该环境 workaround 已验证可完成本次 formal，不等于 MATLAB 桌面启动问题已根治。
- `[本次未运行]` 未启用 Parallel Computing Toolbox，不进行 worker benchmark。

## 3. 主要修正

### 3.1 摘要和确定性排序

`src/stage4a7_2_r2_sha256_file.m` 改为按二进制字节读取并计算 SHA-256，避免 Java `int8` 缓冲区导致摘要对应全零字节。已在 MATLAB 中验证：

| 输入 | 期望摘要 | MATLAB 结果 |
|---|---|---|
| 空文件 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 一致 |
| `abc` | `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad` | 一致 |
| 派生 ENWL CSV | `b1796a9a0cf7ae94f66b58a9e12de2ff21debd371f68e2fe2085e7b42a057f20` | 与系统摘要一致 |

`stage4a7_2_r2_compare_text`、`stage4a7_2_r2_compare_candidate` 和 `stage4a7_2_r2_sort_candidates` 提供唯一的数值—规范键稳定排序，修正 MATLAB `strcmp` 不能进行三向比较的问题。工程候选生成、Lazy Top-K、Stage 2.3 汇总和测试均改用该比较语义。

### 3.2 身份层

`stage4a7_2_r2_1_build_hashes` 将身份拆为 source-tree、data provenance、candidate library、configuration、template cache、experiment 和 runtime environment 层。实验 hash 包含模式、候选库、模板缓存和配置；smoke 与 formal 配置因此不会共用同一 experiment hash。结果目录被排除，派生数据使用仓库相对逻辑标识，不把本机绝对路径写入科学配置身份。

当前 smoke 身份摘要见 `results/data/stage4a7_2_r2_1/smoke/configuration_manifest.csv`。其中 `source_tree_hash`、`data_provenance_hash`、`candidate_library_hash`、`configuration_hash`、`template_cache_hash` 和 `experiment_hash` 均非空。

### 3.3 部署接口和离线 benchmark 构造

`stage4a7_2_r2_1_build_deployment_spec` 只接收 observed engineering ledger 和部署配置，不接收 reference graph、truth topology ID 或测试标签。`stage4a7_2_r2_1_build_benchmark_ledger` 位于离线 benchmark 侧，用于生成 nominal、missing-edge、false-edge、confidence-inversion、incorrect-required-edge、missing-switch-state 和 mixed-corruption 台账情形。

该分离只表明接口不泄漏真值；它不保证错误台账仍能覆盖参考拓扑。smoke 的候选覆盖审计中，nominal、false-edge、confidence-inversion、incorrect-required-edge 和 missing-switch-state 的参考拓扑进入兼容评分空间；missing-edge 和 mixed-corruption 出现 prior exclusion/candidate gap，应按候选空间覆盖损失处理，而不是按分类器错误处理。

## 4. Smoke 结果

### 4.1 配置和规模

入口：

```text
run_stage4a7_2_r2_1_independent_validation('smoke')
```

结果目录：`results/data/stage4a7_2_r2_1/smoke/`；日志：`results/logs/stage4a7_2_r2_1/smoke_rebuilt.log`。

| 项目 | 数值 |
|---|---:|
| engineering candidates | 204 |
| forward-compatible candidates | 87 |
| profile-scored candidates | 87 |
| development scenarios | 174 |
| calibration scenarios | 870 |
| Pilot scenarios | 87 |
| templates per candidate | 243 |
| total profile templates | 21141 |
| worker | 1 |
| status | `smoke_completed` |
| runtime | 1560.129 s |

上述场景规模是当前 R2.1 smoke 配置按候选生成的结果。它不是完整 Final，也不能替代任务书要求的正式独立 OOD 评价。

### 4.2 覆盖与独立性

`candidate_coverage_audit.csv` 的 nominal 行为：204 个工程候选、87 个兼容候选和 87 个评分候选，参考拓扑先验排序第 35，首次纳入评分库的最小 K 为 35。该结果不再是由参考边固定低成本构造出来的第 1 名；候选先验仍是受控 benchmark 先验，不是现场概率。

`independence_audit.csv` 中 development、calibration 和 pilot 各自的 physical ID、parameter hash、CFR hash 和 observation hash 均无重复，跨 split 的四类重复计数均为 0。该审计只覆盖已物化的三个 split；final-reserved 保持 `manifest_only_not_materialized`。

### 4.3 校准分辨率与方法选择

smoke 的每候选 calibration 数为 10，经验分辨率为：

\[
p_{\min}=1/(10+1)=0.0909091>\alpha=0.05.
\]

因此 smoke 的 calibrated 状态只表示数据结构和执行流程已生成，不能在 `alpha=0.05` 下提供足够的经验 p-value 拒绝分辨率。五种方法在当前 development 评价上没有科学唯一优胜者，`scientifically_unique_winner=false`；`absolute` 只是确定性执行 fallback，不是经过验证的科学最优方法。

## 5. Formal 执行状态

formal 预期使用 3 个 development、40 个 calibration 和 2 个 Pilot 场景/候选，规模约为 261、3480 和 174。早期启动日志 `results/logs/stage4a7_2_r2_1/formal_rebuilt.log` 只写入 MATLAB 版本和启动 mutex 错误，未生成 formal `summary.csv` 或有效 formal 汇总；该尝试不计入完成样本，也不计入性能结果。

formal 的最终运行使用 `-nojvm -singleCompThread`，状态为 `[本次运行]`、退出状态 0，耗时 462.457 秒。formal 生成了独立的 `summary.csv`、`configuration_manifest.csv`、`pilot_decisions.csv`、`pilot_metrics.csv`、`scenario_manifest.csv`、`independence_audit.csv` 和 `summary.mat`。早先两次只输出 MATLAB 版本后消失的尝试保留在独立日志中，不计入正式结果。

formal 的机器可读指标位于 `results/data/stage4a7_2_r2_1/formal/pilot_metrics.csv`；本报告引用的是最终 source-tree hash `9316fbcd8ce45df4bd9acb84830cf2fb5027b3b8b6e91a06b9ac755435527ddd` 对应的 formal 重跑，而不是较早的未含指标表版本：

| 指标 | 分子 | 分母 | 结果 | Wilson 95% CI |
|---|---:|---:|---:|---:|
| truth-set coverage | 159 | 174 | 0.913793 | [0.862647, 0.947062] |
| topology acceptance coverage | 174 | 174 | 1.000000 | [0.978400, 1.000000] |
| singleton rate | 42 | 174 | 0.241379 | [0.183826, 0.310105] |
| empty-set rate | 0 | 174 | 0.000000 | [0.000000, 0.021600] |
| singleton correct rate | 37 | 174 | 0.212644 | [0.158394, 0.279307] |
| topology selective risk | 15 | 174 | 0.086207 | [0.052938, 0.137353] |
| mean set size | 769 | 174 | 4.419540 | 不适用 |

这些指标只评价当前 87 个兼容候选自行生成的 off-grid、频域等效噪声场景。它们不包含结构库外、参数库外或真实现场样本，因此不能解释为开放集识别性能。

### 5.1 补充的 35 场景独立 Pilot

入口：

```text
run_stage4a7_2_r2_1_independent_35_pilot()
```

该入口从 formal 的 `checkpoint_identity.mat` 读取已经完成的候选 cache 和 scored 候选，从 formal `summary.mat` 读取冻结配置与方法模型；不重新校准，不读取最终保留 split，也不把 truth 字段传入 profile distance 或候选集合函数。结果目录为 `results/data/stage4a7_2_r2_1/independent35/`，最终日志为 `results/logs/stage4a7_2_r2_1/independent35_manifest_run.log`；同目录另保存 `configuration_manifest.csv`。

| 分层 | 场景数 | truth-set coverage | topology acceptance | singleton rate | empty-set rate | mean set size |
|---|---:|---:|---:|---:|---:|---:|
| in-domain | 10 | 8/10 | 10/10 | 4/10 | 0/10 | 2.9 |
| boundary lower | 5 | 5/5 | 5/5 | 1/5 | 0/5 | 5.4 |
| boundary upper | 5 | 5/5 | 5/5 | 0/5 | 0/5 | 7.0 |
| parameter OOD near | 5 | 4/5 | 5/5 | 1/5 | 0/5 | 3.0 |
| parameter OOD medium | 5 | 1/5 | 5/5 | 2/5 | 0/5 | 3.4 |
| parameter OOD far | 5 | 0/5 | 3/5 | 2/5 | 2/5 | 0.8 |

按 35 个独立场景汇总，truth-set coverage 为 23/35，topology acceptance 为 33/35，singleton 为 10/35，empty-set 为 2/35，平均集合大小为 127/35=3.628571；在已接受的 33 个场景中，拓扑集合错误为 10/33。该 Pilot 使用 20 dB 频域等效复高斯噪声，目标参数为 `main_length_scale`，不是完整结构 OOD 或真实现场验证。独立性审计显示 physical ID、parameter hash、无噪声 CFR hash 和观测 hash 均为 35 个唯一值；详见 `independence_audit.csv`。

### 5.2 全候选同参数与有限 cross-theta 等价性审计

为补足有限模板最近竞争摘要，新增 `src/stage4a7_2_r2_1_full_equivalence_audit.m`。该审计对 87 个 scored 候选的 3,741 个候选对计算全部 243 个同参数模板的最小复 CFR 距离；随后对每个候选的同参数最近竞争者执行分块的完整 243×243 cross-theta/profile 距离。结果：

| 项目 | 数值 |
|---|---:|
| 候选数 | 87 |
| 同参数候选对 | 3,741 |
| 数值等价对（阈值 1e-10） | 0 |
| cross-theta 最近竞争 pair 数 | 62 |
| cross-theta 数值等价 pair | 0 |
| 运行时间 | 0.980804 s |

结果文件为 `same_theta_equivalence_pairs.csv`、`nearest_competitor_full_equivalence.csv` 和 `equivalence_audit_summary.csv`。这里的 `1e-10` 仅是数值完全等价阈值；本次没有独立噪声/测量误差模型可以冻结现场不可辨识阈值，因此 `noise_resolution_threshold=NaN`。cross-theta 审计范围是每个候选的同参数最近竞争 pair，不应被表述为所有候选对的完整 cross-theta 穷举。

## 6. 测试记录

已运行：

```text
addpath(genpath(pwd)); run_tests
```

日志：`results/logs/stage4a7_2_r2_1/full_regression_final.log` 和 `results/logs/stage4a7_2_r2_1/full_regression_final_stdout.log`。

退出状态为 0。日志逐项显示 Stage 4A.6.2、4A.6.2.1、4A.6.3.1、R.1、R.2 及 R2.1 静态完整性检查通过；同时保留了既有 `lsqnonlin` 欠定问题的 MATLAB warning。该 warning 没有导致测试失败，但说明相关测试使用了较少方程数的轻量输入。

已运行的 R2.1 核心检查包括 SHA-256 向量、派生 CSV 摘要、稳定种子、smoke/formal 配置差异、NaN resolution fallback、重复边属性冲突和部署接口真值隔离。

## 7. 时间记录

| Phase | 事前预计 | 实际 | 偏差 | 原因 |
|---|---:|---:|---:|---|
| 静态核对与修正 | 约 20–40 min | 已完成，未单独计时 | — | 代码和结果核对与已有修正连续完成 |
| R2.1 定向测试 | 约 1–3 min | 已完成，退出 0 | 在区间内 | MATLAB 启动后测试规模较小 |
| smoke 重建 | 约 5 min | 1560.129 s（约 26.0 min） | 显著高于预计 | 87 个兼容候选逐场景计算 profile 距离，且包含候选覆盖和模板计算 |
| 完整历史回归 | 约 5–15 min | 已完成，退出 0 | 在区间内 | 既有测试总量可控 |
| formal 首次尝试 | 约 75–110 min | 未形成有效运行 | 不适用 | MATLAB 进程级启动/互进程服务故障 |
| formal 最终重跑 | 约 8–15 min | 462.457 s（约 7.7 min） | 显著低于预计 | `-nojvm -singleCompThread` 降低启动和运行时负担；进度 checkpoint 证明阶段正常完成 |
| 独立 35 场景 Pilot | 约 2–6 min | 3.485 s | 显著低于预计 | 复用已完成 formal cache，单场景 profile 只需读取 87 个候选模板距离 |
| 全候选等价性审计 | 约 3–15 min | 0.980804 s | 显著低于预计 | 同参数计算向量化；cross-theta 仅对最近竞争 pair 做分块计算 |

## 8. 当前限制和阶段判断

当前实现仍有以下未完成项：

1. 当前新增的 `same_theta_equivalence_pairs.csv` 已覆盖 scored 候选的全部候选对；`nearest_competitor_full_equivalence.csv` 只覆盖每个候选的同参数最近竞争 pair，仍不是所有候选对的完整 cross-theta 穷举，也不是逐物理场景的 same-theta 等价标签。
2. smoke 的候选集合因 `p_min>alpha` 而可能保留大集合；这揭示了校准分辨率限制，不构成识别成功。formal 虽满足 `p_min=1/41<=0.05`，但候选集合仍有明显非 singleton 输出。
3. 当前 R2.1 实验输出主要记录拓扑候选集合，尚未形成完整的成员级参数域状态、拓扑/参数双选择性风险表和正式 false-unique 评价。
4. formal 场景由兼容候选自身生成，缺少结构 OOD、参数 OOD 和独立真实非唯一簇，因此 0/174 的空集率不能被解释为拒识能力。
5. ENWL 派生参数中的终端负载使用显式的 `50 ohm` 控制模型默认值，不能写成 ENWL 实测负载或高频 PLC 参数；工频线路参数也没有被当作 MHz 级 RLGC。

因此本阶段判定为：

```text
Stage 4A.7.2-R.2.1 partial / blocked
```

已经完成的是摘要修正、身份分层、部署/离线接口隔离、确定性排序、候选覆盖审计、35 场景独立性 Pilot、全候选同参数等价性审计、formal 自洽运行和历史回归。尚未完成的是逐场景真实等价标签、完整 cross-theta 候选对审计、结构 OOD/真实非唯一开放集评价和参数域有效性闭环。

Stage 4B 未启动。
