# Stage 4A.6.3.1-R.2：场景级等价性审计、指标最终闭环与 MATLAB 并行执行基准

## 阶段判定

**Stage 4A.6.3.1-R.2 completed with a performance limitation。**

### 当前宿主环境复核

原始 `parallel_benchmark.csv` 和相关日志保留了 MATLAB 环境未修复时的失败证据。本阶段随后在恢复 Xwayland 和 `Processes` 并行池的宿主环境中，以当前源码重新完成了同规模 1、4、6、8 workers 运行。当前有效 benchmark 和串并行一致性证据分别见：

- `results/data/stage4a6_3_1_r2/parallel_benchmark_host_recheck.csv`；
- `results/data/stage4a6_3_1_r2/parallel_correctness_audit_host_recheck.csv`；
- `report/stage4a6_3_1_r2_host_parallel_recheck.md`；
- `results/logs/stage4a6_3_1_r2/full_regression_host_recheck_20260908.log`。

四组运行均完成 14 个 calibration 和 35 个 Pilot 场景。4、6、8 workers 的输出与 1-worker 基准逐文件一致，但均慢于串行基准；8 workers 运行期间观察到较高内存和 swap 压力，因此不推荐作为默认配置。

指标和场景级等价性协议已完成，14 个 calibration 场景和 35 个 Pilot 场景已在 A/61 点网格上完成串行和并行复核；当前源码下完整历史回归和 R.2 定向测试通过。完整 Final、B 网格和 Stage 4B 均未运行。[本次运行]

当前阶段不宣称获得并行加速；R.2 的并行结论是“接口和数值一致性通过，但本任务规模下并行不具备性能收益”。

## 1. 范围与边界

本阶段继续使用 7 个受限径向候选拓扑、243 个离散参数模板、A 网格 `A_stage4a1_quick61` 和模型生成的无噪声复数 CFR。先验标签为 `synthetic_demo_prior_not_field_data`。结果不代表真实低压配电网、现场 PLC 测量或完整 PLC PHY 验证；候选确认接受也不等于物理拓扑唯一性已经证明。[代码静态核对]

## 2. R.1 剩余问题与修正

R.2 开工前审计记录于 `report/stage4a6_3_1_r2_prechange_audit.md`。主要修正如下：

| 问题 | R.2 处理 |
|---|---|
| 配置清单在 calibration 完成前写出，双 calibration hash 为空 | 延迟到 topology/parameter calibration model 完成后写出；非空字段缺失时硬失败 |
| false-unique 与参数 OOD 混淆 | 改为基于 same-theta 场景等价类，并同时输出无条件和条件分母 |
| 只有 nominal equivalence | 新增 nominal、same-theta 和 composite 三类等价性字段 |
| calibration/Pilot stability seed 复用 Pilot seed | `score_opts` 显式接收 split，calibration 使用 `sc.seeds.calibration`，Pilot 使用 `sc.seeds.pilot` |
| source-tree hash 依赖清单不足 | 加入 R.2 配置、实验入口、runner、等价性和指标函数等科学依赖 |
| 没有可关闭任务级并行 | 加入外层 materialization/equivalence 任务并行接口和串行 fallback |
| 参数 calibration hash 受诊断运行字段影响 | 身份只由阈值、计数、split、seed、规则和 compatibility hash 组成，不含 elapsed/runtime trace |

历史 R/R.1 结果没有被覆盖。[代码静态核对]

## 3. 等价性定义

R.2 同时保存三种概念：

1. `nominal_equivalence`：使用缓存中冻结名义模板得到的等价类；
2. `same_theta_scenario_equivalence`：对当前场景的同一参数向量映射到各候选拓扑，在同一频带、端口、端接和相对容差 `1e-9` 下比较 CFR；不可物理映射的候选标记为 `not_comparable_under_same_theta`；
3. `composite_library_equivalence`：使用冻结候选库的最佳模板距离做诊断，不与确认器接受阈值混用。

false-unique 的主定义为：真实 same-theta 场景等价类可评价且成员数大于 1，但输出 `unique_topology`。参数 OOD 不参与该指标。

R.2 同时输出：

- `false_unique_unconditional_rate`：分母为全部可评价等价性场景；
- `false_unique_conditional_rate`：分母为真实非唯一场景数；
- `false_unique_evaluable_count`、`true_nonunique_count`、两个分母和 Wilson 区间。

本次 35 个 Pilot 场景的 same-theta 等价审计中，没有出现成员数大于 1 的可评价 Pilot 场景。因此 Pilot 的 false-unique 无条件分母为 35（按类别每类 7），条件分母为 0，条件 rate 为 `NaN`，不能解释为 0% 的真实非唯一拓扑检验。[本次运行]

名义上，G002/G005 和 G004/G007 在部分名义场景中属于等价组；场景级 same-theta 计算显示，参数变化可以打破名义等价，说明 nominal class 不能直接替代场景级真实等价标签。[本次运行]

## 4. 身份与随机性

最终 R.2 配置清单 `results/data/stage4a6_3_1_r2/configuration_manifest.csv` 保存了非空的：

- `compatibility_hash`：`ad648a46371d1f9da2f9f015c22f260838596fa6808f01e216e31941a0634a9f`；
- `source_tree_hash`：`26f32697acb1700bb9b9d975f1bcdc198ab7a87439fbc245eac5ec96536b651d`；
- `cache_hash`：`43f529ef2d17c7602362a86fe3ba695aec63e8e9f153aa2d2b22f3c7777d9927`；
- `equivalence_configuration_hash`：`63bd640a77017cc0f550e7b88dde5de11a17141eaee5637d018168c55e20ef59`；
- `topology_calibration_hash`：`61ad8acc808a0ee375b47eacc2b701b9589e76c6a1f54a5c6c37937b519a3ea0`；
- `parameter_calibration_hash`：`186abce651c3a6583f19e7a90513e4805c001873b84c18403e264aa5397ad48a`。

Calibration、Pilot、final_reserved 的主 seed 分别为 `20266031`、`20266032`、`20266033`。本轮没有物化或运行 final_reserved。稳定 seed 由 split master seed 与 sample ID 派生，不依赖 worker 调度顺序；定向测试验证了 split 隔离和 worker 数不改变 seed 映射。[代码静态核对][本次运行]

## 5. Pilot 设置与结果

| 项目 | 数值 |
|---|---:|
| calibration 场景 | 14 |
| Pilot 场景 | 35 |
| 候选拓扑 | 7 |
| 参数模板/拓扑 | 243 |
| 有接受拓扑的 Pilot | 26/35 |
| profile cases | 26 |
| 串行总计算时间 | 61.895 s |
| MATLAB | R2024a 24.1.0.2537033 |
| final_reserved | 未执行 |

Pilot 分层指标如下。每类 7 个独立物理场景；区间为 Wilson 95% 区间，完整字段见 `pilot/pilot_metrics.csv`。

| 类别 | topology-set accuracy | parameter decision coverage | OOD recall | parameter indeterminate rate | false-unique unconditional |
|---|---:|---:|---:|---:|---:|
| in-domain interior | 6/7 = 0.857 | 3/7 = 0.429 | N/A | 4/7 = 0.571 | 0/7 = 0 |
| in-domain boundary | 7/7 = 1.000 | 3/7 = 0.429 | N/A | 4/7 = 0.571 | 0/7 = 0 |
| OOD near | 5/7 = 0.714 | 1/7 = 0.143 | 1/7 = 0.143 | 6/7 = 0.857 | 0/7 = 0 |
| OOD medium | 4/7 = 0.571 | 0/7 = 0 | 0/7 = 0 | 7/7 = 1.000 | 0/7 = 0 |
| OOD far | 4/7 = 0.571 | 0/7 = 0 | 0/7 = 0 | 7/7 = 1.000 | 0/7 = 0 |

这些结果说明当前协议能够把拓扑接受、参数确定性判断和不可判定分开记录，但参数域 profile 在 medium/far OOD 上主要输出 `indeterminate`，不能宣称已经具备稳定的参数域外检测能力。小样本 Pilot 也不足以给出稳定总体性能结论。[本次运行]

## 6. 成员级执行

确认器拒绝的场景不进入 profile。确认器输出等价类时，R.2 对所有接受成员调用 profile，并在 `pilot_member_evidence.csv` 中保存成员证据。类级聚合要求 `accepted_member_count == evaluated_member_count`；不可靠成员或成员结论冲突时输出 `parameter_domain_indeterminate`。定向测试覆盖成员缺失、冲突和不可靠成员路径；完整 Pilot 生成 26 个 profile cases。[代码静态核对][本次运行]

## 7. 并行 benchmark

R.2 只并行独立外层 materialization/equivalence 任务，不在 worker 中写共享文件，也不嵌套 `parfor`。串行 fallback 保留。

| workers | 结果 | runtime | speedup | peak RSS | swap | 说明 |
|---:|---|---:|---:|---|---|---|
| 1 | completed | 61.895 s | 1.00 | 未测得 | 未测得 | 当前最终身份对齐的串行 Pilot |
| 4 | not evaluable as parallel | 未形成可信并行 runtime | N/A | 未测得 | 未测得 | `parpool('Processes',4)` worker validation/ApplicationService 失败；入口 fallback 为串行 |
| 6 | skipped | N/A | N/A | 未测得 | 未测得 | 当前 Processes profile 最大 worker 数为 4；6 请求直接失败 |
| 8 | skipped | N/A | N/A | 未测得 | 未测得 | 4/6 前置失败后停止，避免继续触发进程级异常 |

4-worker fallback 曾完成一轮 14+35 任务，但因发生在参数 calibration hash 稳定化之前，结果目录仅作为诊断保留，不纳入最终 speedup 结论。没有可报告的并行加速比，也没有声称并行正确性已通过。[本次运行]

## 8. 测试与日志

定向测试日志：

- `results/logs/stage4a6_3_1_r2_targeted_tests_v2.log`；
- `results/logs/stage4a6_3_1_r2/full_regression_final.log`。

完整回归逐项通过，最终耗时 `6.434650 s`；R.2 定向测试包含 false-unique 两种分母、无真实非唯一场景的 NaN 语义、split seed、并行配置和指标闭环测试。MATLAB 在并行池启动期间产生 `ApplicationService client-v1` 错误，因此并行池测试状态是失败/不可评价，不是“通过”。[本次运行]

## 9. 产物

主要产物包括：

- `config/stage4a6_3_1_r2_protocol_config.m`；
- `experiments/exp_stage4a6_3_1_r2_equivalence_parallel.m`；
- `run_stage4a6_3_1_r2_equivalence_parallel.m`；
- `src/stage4a6_3_1_r2_evaluate_metrics.m`；
- `src/stage4a6_3_1_r2_scenario_equivalence.m`；
- `tests/test_stage4a6_3_1_r2_equivalence_parallel.m`；
- `results/data/stage4a6_3_1_r2/configuration_manifest.csv`；
- `results/data/stage4a6_3_1_r2/scenario_manifest.csv`；
- `results/data/stage4a6_3_1_r2/pilot/scenario_equivalence_audit.csv`；
- `results/data/stage4a6_3_1_r2/pilot/pilot_match_decisions.csv`；
- `results/data/stage4a6_3_1_r2/pilot/pilot_member_evidence.csv`；
- `results/data/stage4a6_3_1_r2/pilot/pilot_scoring_labels.csv`；
- `results/data/stage4a6_3_1_r2/pilot/pilot_metrics.csv`；
- `results/data/stage4a6_3_1_r2/parallel_benchmark.csv`；
- `results/data/stage4a6_3_1_r2/parallel_correctness_audit.csv`；
- `results/logs/stage4a6_3_1_r2/stage4a6_3_1_r2_pilot.log`；
- `results/logs/stage4a6_3_1_r2/full_regression_final.log`。

大 MAT cache/model 文件留在本地生成目录并由确定性配置、seed、hash 和入口重建；本阶段没有把它们当作可直接提交的轻量 Git 证据。

## 10. 后续门槛

已满足：双 calibration hash、场景级等价性字段、独立 split seed、false-unique 双分母、串行 fallback、相同规模串行 Pilot、定向测试和历史回归。未满足：MATLAB 并行池实际启动、4 worker 并行结果与串行结果的逐样本一致性、6/8 worker 实测和可信内存记录。因此本阶段不满足 R.2 全部通过条件。

下一步应先修复当前 MATLAB Parallel Computing Toolbox/Processes profile 的启动环境并重新做小规模 4-worker correctness audit，再决定是否扩大样本。科学上仍应优先关注 near/medium/far 参数域外的高 indeterminate 比例，而不是继续增加同一 CFR 距离规则的复杂度。

**Stage 4B：未启动。完整 Final：未运行。**
