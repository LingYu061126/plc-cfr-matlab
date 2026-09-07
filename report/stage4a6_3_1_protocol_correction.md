# Stage 4A.6.3.1 文献方法核验、候选确认协议修正与独立样本 Pilot

## 摘要

[本次运行] 本阶段完成了 A 网格、串行、受控规模的候选确认协议 pilot。旧 Stage 4A.6.3 的结果、报告、CSV、MAT 和历史日志未被覆盖。新 pilot 使用 Stage 4A.5.1 的缓存评分与确认路径，生成 7 个候选拓扑、14 个 calibration 样本和 139 个 evaluation 样本；合并 bank 共 153 个独立物理场景 ID。结果写入 `results/data/stage4a6_3_1/`。

[本次运行] 原始多案例 profile-enabled pilot 在 MATLAB 进程层面未完成：该入口没有产生正常完成标记或完整结果文件，事实记录在 `results/logs/stage4a6_3_1/profile_attempt_process_termination.log`。因此没有把该次尝试的任何参数 profile 结果计入 calibration，也没有将参数域状态写成已验证结论。随后增加的隔离单 case 批次不修改正式 calibration/final 结果，仅用于验证执行稳定性。

结论为：协议修正和独立样本拓扑确认 pilot 完成；隔离单 case 的等价类成员 profile 已能稳定执行，但原始多案例连续入口仍未证明可稳定完成；完整 Stage 4A.6.3 Final 未重跑；Stage 4B 未启动。

## 1. 阶段范围与证据边界

本阶段核验候选生成、候选确认、开放集拒判和选择性评价的文献方法，修正正式入口，建立等价类逐成员接口，生成独立 pilot 样本并保存兼容性身份。当前观测仍是完整树正向模型产生的单发送端—单接收端复数 CFR；A 网格是当前项目的 61 点快速研究网格。[代码静态核对]

先验来源统一为 `synthetic_demo_prior_not_field_data`，不等同于 GIS、线路台账或现场开关记录。[代码静态核对]

## 2. 文献资料与方法映射

### 2.1 实际读取的原始资料

采用 `pdftotext -layout` 提取正文，并按章节、公式、算法、图表和结论定位，实际读取：

- Deka, Kekatos, Cavraro, *Learning Distribution Grid Topologies: A Tutorial*；
- de Jongh et al., *Topology and Parameter Identification in Electrical Distribution Systems using Spatial Priors*；
- Cavraro et al., *Real-Time Identifiability of Power Distribution Network Topologies With Limited Monitoring*；
- Ahmed, Lampe, *Power Line Communications for Low-Voltage Power Grid Tomography*；
- Passerini, Tonello, *On the Exploitation of Admittance Measurements for Wired Network Topology Derivation*；
- Cavraro, Kekatos, Veeramachaneni, *Voltage Analytics for Power Distribution Network Topology Verification*；
- Cavraro, Arghandeh et al., *Distribution Network Topology Detection with Time Series Measurement Data Analysis*；
- Geifman, El-Yaniv, *SelectiveNet: A Deep Neural Network with an Integrated Reject Option*；
- Ahmed/Lampe 的 FDR 与 PLC topology inference 论文；
- Pagani/Zeddam/Ismail 的 CTF path identification 论文；
- Passerini/Tonello 的 admittance/TLS 论文。

[本次未运行] 未执行外部网页检索；本阶段使用工作区原始 PDF 和仓库资料。W. J. Scheirer 等 *Toward Open Set Recognition* 原文未在工作区找到，因此不声称已阅读该论文。[待验证]

逐文献矩阵见 `report/stage4a6_3_1_literature_method_matrix.md`。该矩阵记录观测量、先验、候选生成、评分和接受标准的原始位置，以及对当前项目的可迁移性。

### 2.2 两类候选生成路线

**路线 A：先验约束候选库**

```text
GIS/单线图/线路台账
→ 允许边集合
→ 已知开关状态和节点类型
→ 连通、无环、径向、度数和长度约束
→ 候选图集合
```

当前 `generate_radial_topology_candidates.m` 与 `generate_prior_constrained_candidates.m` 只是小规模合成接口，没有真实 GIS 或资产系统接入。[代码静态核对]

**路线 B：直接拓扑重构**

Ahmed/Lampe 的 PLC tomography 使用多节点测距和树重构；Passerini/Tonello 的方法使用多节点导纳或 TLS；Cavraro 系列方法依赖多节点电压/统计量和测量布置。这些方法需要当前单端口 CFR 不具备的观测，不能写成当前代码已经实现。[论文明确陈述][模型推断]

### 2.3 客观确认与统计术语

当前候选确认可表示为：

$$
d_G=\min_{\theta\in\Theta_G}D\left[z(\hat H),z(H_O(G,\theta))\right],
$$

$$
d_1=\min_G d_G,\qquad \Delta=d_2-d_1,\qquad
\rho=\frac{d_2}{d_1+\varepsilon}.
$$

Stage 4A.5.1 实际使用最佳残差、异类间隔、子频带统计、拓扑模板邻域和频率块稳定性。最小残差只提供排序，不能单独证明候选覆盖、唯一性或开放集接受。[代码静态核对]

当前方法是 distance matching，不是最大似然或 MAP。正式最大似然还需要观测似然、噪声分布和协方差；MAP 还需要经过标定的 `p(G)`。当前没有这些定义，故不把残差阈值称为正式似然比或现场置信度。[模型推断]

当前 `compute_stage4a6_2_parameter_profile.m` 产生的是固定参数并优化其余参数后的约束距离曲线，应称为 profile residual 或 constrained residual profile，而不是严格的 profile likelihood。[代码静态核对]

## 3. 协议修正

### 3.1 冻结确认路径

`confirm_stage4a6_3_1_topology.m` 不调用旧 Stage 4A.6.3 的局部 `match_nominal()`。正式路径调用：

1. `score_stage4a5_observation.m`；
2. `apply_stage4a5_confirmation.m`；
3. 输出 `decision`、`best_topology_id`、`accepted_topology_set`、`best_distance`、`second_distance`、`margin`、`rho`、稳定性和兼容性 hash。

旧 `match_nominal()` 未删除，历史入口未修改；它不再作为本阶段正式确认器。[代码静态核对]

### 3.2 等价类成员

`run_stage4a6_3_1_member_profiles.m` 和 `aggregate_stage4a6_3_1_member_evidence.m` 要求 accepted member IDs 与 evaluated member IDs 一一对应。成员缺失、成员失败或结论冲突时输出 `parameter_domain_indeterminate`，不挑选有利成员。

本次拓扑 pilot 仍能输出 `{G002,G005}` 和 `{G004,G007}` 等多成员集合；因 profile 子集为 0，`evaluated_member_count` 保持 0，未宣称参数诊断完成。[本次运行]

### 3.3 独立物理样本

`generate_stage4a6_3_1_independent_trials.m` 使用 sample-ID 派生的稳定 seed，对目标越界参数和 nuisance 参数分别抽样。near、medium、far 区间不重叠；不同 replicate 会改变 `truth_theta`，从而改变无噪声正向 CFR；这些真值字段只用于离线评分，不传给确认器。[代码静态核对]

## 4. Calibration/Final 身份

兼容性 hash 包括 A 网格实际频率数组、候选 ID 与 canonical key、参数网格和域、观测端接、距离和权重、profile 规则、Stage 4A.5.1 确认方法、缓存 schema/hash 及正向模型依赖源码 hash。calibration/final seed 不进入该 hash；科学判据变化会改变 hash。[代码静态核对]

隔离 pilot 的身份为：

```text
compatibility_hash = a6c12facc0071f4fc59858c331eb2300d3cdbab4674021ee777808a9a37d2194
source_tree_hash   = 59e8fe95438713dcd4b8735e350162b395f75e017b5b17d0fa3491cd85a87e1d
```

结果中的 calibration model 保存兼容性 hash、源码树 hash、calibration scientific hash、split ID、MATLAB 版本和创建时间。旧的 `c4c3...`/`6190...` 身份属于早期未隔离运行，不作为本次最终 pilot 身份。[代码静态核对][本次运行]

## 5. Pilot 配置与结果

### 5.1 配置

| 项目 | 设置 |
|---|---|
| 网格 | `A_stage4a1_quick61` |
| 频点数 | 61 |
| 候选图 | 7 |
| 参数模板 | 243/图，1701 个复合模板 |
| 确认器 | `Stage4A5_1_M3_frozen` |
| 子带 | 8 个连续子带 |
| 稳定性 | 6 次连续块重采样，2 块 |
| worker | 1，串行 |
| calibration/evaluation | 14 / 139 |
| profile 子集 | 0；profile-enabled 尝试单独记录为阻塞 |
| 先验来源 | `synthetic_demo_prior_not_field_data` |

### 5.2 Trial bank 审计

[本次运行] `stage4a6_3_1_trial_bank_audit.csv` 报告：calibration 14、evaluation 139、合并 153、ID 交集 0、独立 physical scenario 153、重复物理场景 0、候选图 7。evaluation 分层为：in-domain 7、OOD near 66、OOD medium 33、OOD far 33。

### 5.3 拓扑确认结果

[本次运行] evaluation pilot 的 139 个决策为：

| 决策 | 数量 |
|---|---:|
| `unique_topology` | 27 |
| `equivalence_class` | 61 |
| `reject_model_mismatch` | 23 |
| `reject_subband_mismatch` | 12 |
| `reject_low_stability` | 11 |
| `reject_neighborhood_mismatch` | 5 |

该 pilot 只验证确认协议和身份链，不替代完整 Final 性能结论。对称候选没有被随机模板差异强行拆分。[本次运行]

### 5.4 指标语义

[本次运行] 最新 `stage4a6_3_1_pilot_metrics.csv` 保存 nominal row count、unique physical scenario count、duplicate observation count、effective denominator、Wilson 区间、coverage 和 selective risk。拓扑集合准确率为：in-domain 7 个样本中 0.8571，OOD near 66 个样本中 0.8182，OOD medium 33 个样本中 0.4242，OOD far 33 个样本中 0.4242。

参数层的 `coverage` 为 0，`indeterminate_rate` 为 1，因为本次 profile 未执行；参数 OOD recall、OOD false acceptance、in-domain false alarm 和 selective risk 因而不是有效的参数性能结果。拓扑确认的 accepted/reject 不能重新解释成参数域判断。[本次运行]

## 6. Profile 阻塞项与受控修复验证

启用小 profile 子集后，MATLAB 没有产生正常 completion marker，也没有保存完整 profile pilot result。该执行按进程级失败/阻塞处理，未纳入任何 calibration evidence；日志为 `results/logs/stage4a6_3_1/profile_attempt_process_termination.log`。[本次运行]

因此目前只能确认：拓扑确认器和独立样本协议可运行；等价类成员 profile 的端到端执行稳定性、参数域 calibration model 和参数 OOD 性能仍未验证。[本次运行]

随后新增了独立的 `run_stage4a6_3_1_profile_smoke.m`，将 profile 计算隔离为单个 MATLAB 进程中的单个 evaluation case；它不改写正式 pilot CSV。受控验证结果如下：

| case | 频点数 | accepted/evaluated members | 预算 | 运行时间 | 退出状态 |
|---|---:|---:|---|---:|---:|
| 单成员 profile smoke | 61 | 1 / 1 | 10 iterations / 30 evaluations | 3.55 s | 0 |
| 等价类 profile smoke | 61 | 2 / 2 | 10 iterations / 30 evaluations | 7.44 s | 0 |
| 等价类 profile smoke（原 pilot 预算） | 61 | 2 / 2 | 20 iterations / 60 evaluations | 6.93 s | 0 |

三次受控 smoke 均完成并生成独立 MAT 结果；profile 已计算，返回状态为 `parameter_domain_indeterminate`，因为 smoke 使用了无效的参数 calibration model，不代表参数域性能。该结果支持“单 case/单等价类成员路径可稳定运行”，但尚未证明旧的多 case 连续入口已经修复。[本次运行]

当前未观察到与本次 profile smoke 对应的新 MATLAB crash dump。因此此前的进程级中止暂时只能归因于旧入口的多 case 运行规模、资源累计或外部终止，不能进一步声称已定位到 MATLAB 内核缺陷。[本次运行][待验证]

在此基础上，采用“每个 profile case 单独启动 MATLAB、单独写入 MAT/日志”的隔离批次执行了 4 个代表性 case：G001 单成员 1.37 s，G002/G005 等价类 2.66 s，G004/G007 等价类 3.35 s，G003 单成员 2.82 s；4 个 case 均退出状态 0，等价类成员均为 2/2 完整评估。[本次运行]

该隔离批次支持将 profile 运行改造为逐 case shard/resume 方式，但不等同于 139 个 evaluation case 的完整参数 Final；后者尚未运行。

随后又执行了 12 个不覆盖既有 MAT/日志的隔离 profile case，覆盖 G001、G002、G003、G004、G005、G006、G007，以及 G002/G005 和 G004/G007 等价类，并包含域内、近边界和参数越界示例。与前一批合计形成 16 个独立 MATLAB 进程执行产物、14 个不重复 `sample_id`；其中两个样本 ID 被有意重复执行以核对重复 case 的稳定行为。16 个执行均返回退出状态 0，未发现 `PROFILE_SMOKE_ERROR`、异常终止或新的 MATLAB crash dump；累计 profile 计算时间为 51.365 s，平均每次 3.210 s。每个等价类 case 的 accepted/evaluated member 均保持 2/2，单成员 case 保持 1/1。所有这些 smoke 的参数域状态均为 `parameter_domain_indeterminate`，原因是使用了无效 calibration model，因此这些数字只能证明执行路径和成员覆盖，不构成参数域性能结果。[本次运行]

新增产物按 `results/logs/stage4a6_3_1/profile_batch_case*.log` 和 `results/data/stage4a6_3_1/stage4a6_3_1_case*.mat` 保存；每个进程使用 A 网格 61 点和 20 iterations / 60 evaluations 预算。该批次仍不是完整多案例连续 runner，也未运行 139 个 evaluation case 的 profile 版本。[本次运行]

## 7. 正式 A 网格拓扑运行

[本次运行] 在受控 profile smoke 验证后，重新运行了当前冻结的 A 网格拓扑确认入口 `run_stage4a6_3_1_protocol_pilot`。该入口的配置仍为 `profile_case_limit=0`，所以本次正式运行只验证 Stage 4A.5.1 拓扑确认路径，不是参数域 Final。

| 项目 | 结果 |
|---|---|
| MATLAB | R2024a `24.1.0.2537033` |
| 运行入口 | `run_stage4a6_3_1_protocol_pilot` |
| 频率网格 | A，61 点 |
| evaluation | 139 个独立物理场景 |
| calibration | 14 个样本 |
| worker | 1，串行 |
| profile case count | 0 |
| runtime | 6.008231 s |
| exit status | 0 |
| compatibility hash | `a6c12facc0071f4fc59858c331eb2300d3cdbab4674021ee777808a9a37d2194` |

正式运行复核后的拓扑指标与隔离 pilot 一致：in-domain 集合准确率 0.8571，near OOD 0.8182，medium OOD 0.4242，far OOD 0.4242。参数域指标仍不可用，因为 profile case count 为 0。[本次运行]

日志：`results/logs/stage4a6_3_1/formal_topology_run.log`。

## 8. 测试、运行和时间记录

### 7.1 针对性测试

MATLAB R2024a，退出状态 0；日志：`results/logs/stage4a6_3_1/targeted_tests_final.log`。新协议测试和后续完整回归均通过。[本次运行]

### 7.2 完整历史回归

运行 `run_tests`，MATLAB R2024a，退出状态 0；Stage 1.5 至 Stage 4A.6.3.1 测试通过。日志：`results/logs/stage4a6_3_1/full_regression_final.log`。[本次运行]

### 7.3 时间记录

| 阶段 | 预计时间 | 实际时间 | 偏差/说明 |
|---|---:|---:|---|
| 文献与仓库核对、方法矩阵 | 10–20 分钟 | 约 15 分钟 | 工作区 PDF 文本层和仓库静态检查 |
| 代码与协议实现 | 20–40 分钟 | 约 35 分钟 | 接口、独立样本和兼容性身份 |
| 针对性测试 | 1–3 分钟 | 约 20 秒 | MATLAB R2024a，退出状态 0 |
| profile-enabled 尝试 | 2–8 分钟 | 未正常完成 | 无正常退出标记，不能作为成功耗时 |
| 拓扑确认 pilot | 2–8 分钟 | 约 1 分钟 | 串行、A 网格 |
| 完整历史回归 | 2–5 分钟 | 约 28 秒 | MATLAB R2024a，退出状态 0 |

实际值为工具执行和日志可观察到的近似值；profile-enabled 尝试没有可报告的正常完成时间。[本次运行]

### 7.4 未运行项目

- 完整 1272 条 Stage 4A.6.3 Final：未运行；
- 多 case profile-enabled 正式 pilot：未运行；
- B OFDM active-subcarriers 网格：未运行；
- 1/4 worker benchmark：未运行，本阶段保持 1 worker；
- 真实 GIS/台账/开关状态：未接入；
- 真实 PLC 收发机、FDR/TFDR 和现场量测：未验证。

## 9. 阶段判断与后续门槛

当前判断为：**Stage 4A.6.3.1 协议修正完成，独立样本拓扑 pilot 完成，隔离 profile smoke 扩展通过，但多案例连续 profile pilot 仍未完成，整体部分完成。**

完整 Final 重跑门槛尚未满足。下一步必须将上述已验证的单 case 隔离路径接入可追踪的 batch/shard runner，记录 completed/failed/resumed 状态，并在不改变 calibration 规则的前提下完成小批量 profile 汇总；不能根据当前 smoke 结果调节 Final 阈值。

## 10. 研究边界

当前结果仍是受限径向候选库、合成先验、模型生成 CFR 和 A 网格下的模型内审计。残差确认不是现场置信度；拓扑集合正确不等于物理拓扑全局唯一；profile 收敛不等于参数真实可辨识；参数域怀疑不等于准确恢复真实参数；Open-set rejection 不等于恢复真实未知结构。Stage 4B 未启动。
