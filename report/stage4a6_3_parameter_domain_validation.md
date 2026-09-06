# Stage 4A.6.3：A 网格多拓扑、多 Seed 参数域验证

## 1. 阶段范围

本阶段只验证 `A_stage4a1_quick61` 研究网格，即当前配置导出的 61 个频点、7 个受限径向候选拓扑、连续参数扩展域和单端口复数 CFR 正向模型。研究对象是参数域诊断协议，而非真实 PLC 设备、现场线路或完整 OFDM PHY。

本阶段未运行 B 网格，未接入真实 GIS、线路台账、现场端接、耦合器、同步误差或现场量测，也未启动 Stage 4B。

## 2. 研究问题与判定接口

本阶段回答的问题是：在候选拓扑已完成模型内确认后，连续参数 profile 是否能够在独立 calibration 下识别参数域外样本，同时报告库内误报警和不可判定比例。

完整流程为：

```text
观测 CFR
→ 拓扑候选确认
→ 接受的拓扑或观测等价类
→ 域内/扩展域参数拟合
→ 逐参数 profile
→ 可靠性与校准阈值判断
→ M1/M2/M3 参数域状态
→ 离线统计评分
```

匹配决策函数不接收 `truth_topology_id`、真实参数、`outlier_dimension`、`outlier_severity` 或覆盖标签。真实标签只在匹配完成后用于生成评分文件。

方法定义如下：

| 方法 | 判定含义 |
|---|---|
| `A6_3_M0_topology_only` | 只输出拓扑/等价类；参数域指标为 `NaN/not_applicable`。 |
| `A6_3_M1_boundary` | 使用域内拟合的边界行为，作为简单参数诊断基线。 |
| `A6_3_M2_profile` | profile 可靠、阈值已校准、扩展域最优点越界，且绝对或相对改善达到阈值。 |
| `A6_3_M3_joint_diagnostic` | 在 M2 基础上同时要求绝对改善、相对改善、灵敏度、边界/向外趋势和等价类成员一致。证据不完整时输出不可判定。 |

参数域状态包括 `parameter_in_domain`、`parameter_out_suspected`、`parameter_domain_indeterminate` 和 `parameter_not_evaluated`。`parameter_out_suspected` 只表示当前模型和观测支持参数域外怀疑，不表示真实参数已被准确恢复。

## 3. Trial Bank 与数据隔离

[代码静态核对] 配置固定为 A 网格、串行 1 worker、`fixed_grid_with_midpoints` profile。profile 包含库内边界、扩展域边界和中点；本阶段不启用复杂自适应细化。无支路拓扑的 `branch_length_scale` 和 `branch_load_scale` 被标记为 inactive，不生成相应的越界样本，也不进入这些参数的分母。

[本次运行] 全量 trial bank 审计结果如下：

| 项目 | 数量/状态 |
|---|---:|
| 候选拓扑 | 7 |
| development pilot | 28 |
| calibration | 70 |
| final | 1272 |
| sample ID 交集 | 0 |
| split 交集 | 0 |
| seed 交集 | 0 |
| inactive 参数越界样本 | 0 |
| 审计状态 | `passed` |

Final 样本包括 84 个域内样本，以及 near、medium、far 各 396 个参数域外样本。每个参数的越界样本按 lower/upper 方向生成；无支路拓扑只对其 active 参数生成样本。每个最终分层单元实际为 2 个样本/seed、3 个 final seed，少于理想的 10 个独立样本，因此分层比例的置信区间仍较宽。

## 4. Calibration

[本次运行] calibration 使用 70 个样本。离线筛选后共有 66 条 calibration evidence，55 条 profile 可靠证据，5 个参数均达到每参数至少 10 条可靠证据的最低要求，阈值状态均为 `calibrated`。

| 参数 | Calibration evidence | 可靠数 | 状态 | 绝对改善阈值 | 相对改善阈值 | 灵敏度下限 |
|---|---:|---:|---|---:|---:|---:|
| `main_length_scale` | 66 | 55 | calibrated | 4.4493e-08 | 0.98013 | 5.4691 |
| `branch_length_scale` | 66 | 46 | calibrated | 4.5763e-08 | 0.98002 | 5.4197 |
| `branch_load_scale` | 66 | 46 | calibrated | 4.5763e-08 | 0.98002 | 5.4197 |
| `source_impedance_ohm` | 66 | 55 | calibrated | 4.4493e-08 | 0.98013 | 5.4691 |
| `receiver_impedance_ohm` | 66 | 55 | calibrated | 4.4493e-08 | 0.98013 | 5.4691 |

阈值来自独立 calibration，不使用 final 标签反向调整。Calibration 哈希为 `a2a3b909089ebf82a0d440350ce1d9e61e50f0175147b9bd11e45df7ba0cffe2`，源码树哈希为 `ef5e6aa1245fff5f77ba99e89b225c1d1064e1a8ad8d4f653763e161a5ac3af3`。

## 5. Final 执行完整性

[本次运行] Final 使用 3 个独立 seed：`20263901`、`20263902`、`20263903`。最终 1272/1272 个 shard 完成，失败数和 pending 数均为 0；分批运行使用同一 run ID 和同一 scientific hash，并通过 resume 完成。Final scientific hash 为 `9584b02a950b32f14cde9bc240e6db4714ea9c703fa8b5a8013ee45135d4e98a`，源码树哈希为 `93df76f79aff0be8961a032c99cd4d4ea9bde217de56c9341bedcf49e045d564`。

逐 shard 运行时间之和为 2058.398585 s；shard 文件时间跨度为 2758.304089 s。后者包含 MATLAB 进程重启和 resume 开销，不能等同于单次 MATLAB 进程 wall-clock。详细审计见 `stage4a6_3_final_runtime_audit.csv`。

## 6. Final 参数域结果

下表为全部 final 样本的类别汇总；比例均保留其分子、分母和 Wilson 95% 区间于 CSV。M0 不执行参数域判定，因此其参数域指标均为 `NaN/not_applicable`，不可与 M1～M3 的 OOD recall 直接比较。

| 方法 | 类别 | OOD recall | OOD false acceptance | 不可判定率 | decision coverage |
|---|---|---:|---:|---:|---:|
| M1 boundary | near | 0.712 (282/396) | 0.136 (54/396) | 0.152 | 0.848 |
| M1 boundary | medium | 0.879 (348/396) | 0.076 (30/396) | 0.045 | 0.955 |
| M1 boundary | far | 0.727 (288/396) | 0.015 (6/396) | 0.258 | 0.742 |
| M2 profile | near | 0.879 (348/396) | 0.045 (18/396) | 0.076 | 0.924 |
| M2 profile | medium | 0.864 (342/396) | 0.045 (18/396) | 0.091 | 0.909 |
| M2 profile | far | 0.848 (336/396) | 0.015 (6/396) | 0.136 | 0.864 |
| M3 joint diagnostic | near | 0.061 (24/396) | 0.045 (18/396) | 0.894 | 0.106 |
| M3 joint diagnostic | medium | 0.030 (12/396) | 0.045 (18/396) | 0.924 | 0.076 |
| M3 joint diagnostic | far | 0 (0/396) | 0.015 (6/396) | 0.985 | 0.015 |

域内 84 个样本的结果为：M1 和 M2 的 in-domain false alarm 为 10/84=0.119，indeterminate rate 为 14/84=0.167，decision coverage 为 70/84=0.833；M3 的 false alarm 为 0/84，indeterminate rate 为 24/84=0.286，coverage 为 60/84=0.714。M3 的低误报警来自极高的不可判定比例，不能作为无条件性能提升。

从本次冻结数据看，M2 是三种参数判据中最平衡的结果：它相较 M1 降低了 near OOD false acceptance，并保持较高的 decision coverage；但其 OOD recall 仍不是现场意义上的检测率。M3 的联合条件过于保守，在当前 61 点、无噪声模型和 calibration 阈值下没有形成可用的检测覆盖。

## 7. 参数维度和越界方向

[本次运行] 详细的参数×severity×direction 结果保存在 `stage4a6_3_final_stratified_metrics.csv`。主要现象如下：

- `branch_length_scale` 和 `branch_load_scale` 在有支路拓扑中多数分层的 M2 recall 较高，许多分层达到 1.0；但 far branch-length upper 分层为 0.667，显示仍存在不可判定样本。
- `main_length_scale` 的 M2 结果对越界方向和程度不对称，near lower/upper 为 1.0，而 medium lower 和 far lower 分别为 0.714 和 0.286，且不可判定比例上升。
- `source_impedance_ohm` 与 `receiver_impedance_ohm` 的 M2 recall 多数约为 0.571～1.0，同时存在 0～0.286 的分层 false acceptance 或不可判定，说明端口阻抗与其他连续参数存在补偿关系。
- M3 在大多数参数维度上因灵敏度和联合证据门槛未同时满足而输出 `indeterminate_conflicting_evidence`，不能据此声称这些参数已被可靠排除。

这些结果只支持“当前模型下不同参数方向的可诊断程度不同”的模型内推断，不支持从 CFR 唯一恢复真实线路参数。

## 8. 拓扑层结果

[本次运行] 四种方法共享同一冻结拓扑确认结果：1272 个样本中输出 846 个 `equivalence_class`、426 个 `unique_topology`。以离线真值评分：拓扑集合命中为 1076/1272=0.846，严格唯一图命中为 384/1272=0.302。当前观测等价性仍由既有 SISO 审计约束；历史等价组 `{G002,G005}` 与 `{G004,G007}` 不能被本阶段参数 profile 强行拆分。

参数域诊断不改变拓扑等价类的物理语义。参数判定应理解为“在已接受的拓扑或等价类条件下，当前参数域是否足以解释观测”，而不是对拓扑唯一性的替代。

## 9. 证据、测试与运行入口

[本次运行] MATLAB 版本为 `24.1.0.2537033 (R2024a)`。主要入口和状态如下：

```text
run_stage4a6_3_parameter_domain_validation('pilot')       completed 28/28
run_stage4a6_3_parameter_domain_validation('calibration') completed 70/70
run_stage4a6_3_parameter_domain_validation('final')       completed 1272/1272
```

针对性测试日志：`results/logs/stage4a6_3/targeted_tests_matlab.log`，退出码 0。

完整回归日志：`results/logs/stage4a6_3/full_regression.log`，退出码 0。完整回归包含 Stage 1.5、Stage 2、Stage 3A、Stage 3B-pre/waveform baseline、Stage 4A.1～Stage 4A.6.2.1 以及本阶段新增测试。

主要结果文件：

```text
results/data/stage4a6_3/stage4a6_3_audit_trial_bank.csv
results/data/stage4a6_3/stage4a6_3_calibration_thresholds.csv
results/data/stage4a6_3/stage4a6_3_final_trial_bank.csv
results/data/stage4a6_3/stage4a6_3_final_shard_manifest.csv
results/data/stage4a6_3/stage4a6_3_final_decisions.csv
results/data/stage4a6_3/stage4a6_3_final_scoring_labels.csv
results/data/stage4a6_3/stage4a6_3_final_metrics.csv
results/data/stage4a6_3/stage4a6_3_final_stratified_metrics.csv
results/data/stage4a6_3/stage4a6_3_final_runtime_audit.csv
results/data/stage4a6_3/stage4a6_3_final_results.mat
```

`stage4a6_3_final_decisions.csv` 中的 `scientific_hash` 字段记录了所用 calibration model 的哈希；Final 运行身份以 configuration manifest、runtime audit 和 shard manifest 中的 Final scientific hash 为准。两类哈希分别用于标识校准模型和 Final 实验配置，不能混用。

## 10. 结论与限制

[本次运行] 协议层面完成：split/seed 隔离、A-only frozen configuration、calibration 阈值冻结、shard resume、无失败 Final shard、参数分层统计和完整回归均有文件或日志证据。

[模型内推断] 在当前设置下，M2 profile 判据相较 M1 boundary 判据具有更好的整体平衡，尤其降低了 near/medium OOD 的 false acceptance；但 M3 联合诊断的 decision coverage 过低，当前不适合作为主要参数域输出。

[模型内推断] 参数域外样本被接受时，拓扑层仍可能正确或处于等价类内；因此“参数域外漏报警”不能直接写成“拓扑识别错误”。当前结果应同时报告拓扑状态与参数域状态。

[待验证] 本阶段没有 B 网格、噪声/同步压力测试、连续参数全局优化、真实资产资料、真实端接或现场量测。profile 收敛不等于全局物理可辨识，OOD 检测也不等于真实参数值恢复。

阶段判断：A 网格的协议与冻结验证已经完成，但参数域方法证据属于“部分有效”而非全面解决。M2 可作为后续报告中的模型内候选方案；M3 需要重新校准或增加观测维度后才可继续采用。Stage 4B 未启动。
