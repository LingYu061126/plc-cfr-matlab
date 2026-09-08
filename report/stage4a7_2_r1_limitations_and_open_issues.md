# Stage 4A.7.2-R.1：缺陷、不足与结果适用性审计

## 1. 审计结论

Stage 4A.7.2-R.1 已完成受控 MATLAB Pilot、定向测试和完整历史回归；但本阶段结果不应被解释为候选拓扑确认性能已经得到充分验证。当前证据更适合支持以下结论：共享不确定工程先验、候选生成—正向适配—离散 profile distance—候选集合输出的执行链已经能够运行，并且非唯一场景不会被强制压缩为单一候选。对一般网络的识别率、拒识率和候选集合紧致性，证据仍不足。[本次运行]

关键结果为：工程候选 131 个，正向模型兼容候选 53 个，Top-K 评分候选 6 个；development/calibration/Pilot 为 12/12/6；100 个受控非唯一场景的 false-unique unconditional/conditional 均为 0/100。[本次运行]

上述数字不能单独构成“效果良好”的证据。非唯一审计中实际输出集合为全部 7 个 legacy 候选，集合大小为 7；小型 Pilot 的 singleton rate 为 0/6。因而较低的 false-unique 主要反映保守的多候选输出，而不是已经实现了高分辨率拓扑确认。[本次运行]

## 2. 缺陷与不足清单

| 编号 | 严重性 | 发现 | 代码或结果证据 | 对结论的影响 | 后续门槛 |
|---|---|---|---|---|---|
| R1-01 | 阻塞正式性能结论 | 公开子网 reference truth 未进入实际评分库 | `candidate_coverage_audit.csv` 中 `truth_in_engineering_space=1`、`truth_forward_model_compatible=1`、`truth_in_scored_library=0`，原因是 `truth_in_engineering_and_forward_but_topk_truncated` | Pilot 没有评价 ENWL 派生 reference topology；6/6 只是在 Top-K 自生成候选中的条件 coverage | 必须提高 Top-K 或采用全兼容候选评分，并单独报告 reference truth coverage |
| R1-02 | 阻塞阈值有效性 | 每个 calibration 类只有 2 个样本，而 `alpha=0.05` | `runtime_summary.csv` 为 calibration=12；6 个候选对应每类约 2 个样本；经验 p-value 的最小值为 (1/(2+1)=0.333) | 在该配置下无法以 0.05 拒绝候选，候选集合天然偏大；coverage 和 empty-set 指标会被动改善 | 每类 calibration 样本数必须足以达到冻结的 p-value 分辨率，并在 Pilot 前验证可拒识性 |
| R1-03 | 阻塞方法选择 | development 中 5 个方法完全并列 | `development_method_selection.csv` 中 absolute/scaled/ratio/margin/absolute_I 均为 coverage=12/12、mean set size=6、singleton=0、empty=0；最终 `absolute` 由词典序并列规则选出 | `absolute` 没有得到数据支持的优越性；当前“选择并冻结”实际上是 tie-break | 扩大 development/calibration，保证候选方法产生可区分的分数和集合行为；并列时报告 no_method_meets_gate 或明确 tie 状态 |
| R1-04 | 阻塞非唯一泛化 | 100 个非唯一场景属于 legacy G004/G007 控制审计，不是共享 ENWL 派生候选库的非唯一场景 | `legacy_nonunique_audit` 使用 `generate_radial_topology_candidates`，并硬编码 truth set `G004,G007` | false-unique=0/100 不能代表公开子网候选确认器的非唯一性能 | 将 same-theta 等价审计接入共享工程候选库，并按场景重新计算 truth equivalence set |
| R1-05 | 阻塞物理等价证明 | 非唯一循环由 G004 生成观测，未在每个随机参数点重新验证 G007 的同参数 CFR 等价 | `experiments/exp_stage4a7_2_r1_data_driven_closure.m` 的 `legacy_nonunique_audit` 只从 `legacy(pair)` 生成 (H)，G007 仅作为预设成员 | truth set 是冻结假设而非本轮逐场景重建的等价性证据 | 对每个场景计算 same-theta candidate CFR，并记录容差、比较状态和不可比较原因 |
| R1-06 | 重要限制 | Top-K 只保留 7 个候选，其中只有 6 个进入评分 | `summary.csv`：engineering=131、forward=53、scored=6；profile cache 只覆盖 scored candidates | 评分库覆盖率低，候选被先验成本和 Top-K 截断支配；无法把拒绝解释为观测模型失配 | 同时报告工程空间、兼容空间和评分空间 coverage；正式结论必须建立在 reference truth 进入评分库的条件下 |
| R1-07 | 重要限制 | 正向模型兼容性损失较大 | 131 个工程候选中只有 53 个兼容；不兼容原因包括 nested branch 和 unsupported component | 候选空间缩小部分来自模型表达能力，而不是观测判别能力 | 保留不兼容候选并统计 coverage loss；不得把它们当作分类器错误或观测拒识 |
| R1-08 | 重要限制 | Pilot 样本量过小 | development/calibration/Pilot=12/12/6；Pilot coverage 95% Wilson 区间约为 [0.61,1.00] | 不能支持稳定的总体性能、OOD 拒识或现场外推 | 正式验证前增加独立场景，并按拓扑、参数状态和方向分层 |
| R1-09 | 重要限制 | 不确定工程先验是从处理后的公开 OpenDSS 模型派生的受控合成不确定性 | `uncertainty_generation_audit.csv` 标记 `synthetic_ambiguity_count=6`；代码使用 `controlled_unknown_edge_presence` 和 `synthetic_edge_exchange` | 先验可审计，但不等同于真实错误 GIS、真实开关不确定性或现场账本缺陷 | 若研究现场适用性，需要真实工程账本、开关状态和几何误差的独立数据 |
| R1-10 | 重要限制 | 距离不是统计似然 | `stage4a7_2_r1_profile_distance` 使用 `complex_raw`；没有噪声协方差、噪声分布或现场误差标定 | 只能称为 profile distance，不应称为严格 likelihood、GLRT 或现场置信度 | 后续增加独立噪声/模型误差 calibration，并明确加权残差的统计解释 |
| R1-11 | 重要限制 | Pilot 的观测分布由评分候选自身生成 | `materialize_and_score` 对每个 scored candidate 生成 `truth_topology_id` 和无噪声 CFR，Pilot 每个候选仅 1 个场景 | 这是候选自洽性测试，不是来自独立网络或独立拓扑的外部泛化测试 | 使用不参与候选构造的独立 reference/scenario bank；truth 只能在离线评分阶段出现 |
| R1-12 | 可复现性风险 | 配置名称写为 `frozen_243_parameter_grid`，但实际 Pilot 每候选保存 1458 个模板 | `config/stage4a7_2_r1_data_driven_config.m` 与 `runtime_summary.csv` 不一致 | 运行语义容易被误读，复现者可能生成不同规模模板库 | 统一配置名称、模板生成规则和结果中的 template_count 后重新生成结果 |
| R1-13 | 可复现性风险 | scientific hash/source-tree hash 没有把派生 ENWL CSV 内容作为科学输入哈希的一部分 | `stage4a7_2_r1_source_tree_hash.m` 只哈希代码和配置；`external_data_manifest.csv` 未写入原始文件 SHA256 | 代码身份相同但派生输入被替换时，结果 hash 可能不变 | 将派生输入文件 hash、外部源文件 hash 和字段映射版本纳入数据身份 |
| R1-14 | 重要限制 | round-trip 主要审计图结构和属性，未形成完整多参数 CFR 数值审计表 | `adapter_roundtrip_audit.csv` 记录结构恢复；没有每个候选、多参数点的 (D(H_{legacy},H_{adapted})) 汇总 | 结构可恢复不等同于所有参数点的频响等价 | 对代表性兼容候选和多个参数点保存 CFR discrepancy summary |
| R1-15 | 重要限制 | 当前没有噪声、同步误差、端接漂移或真实 CFR 误差 | `measurement_kind=siso_forward`，frequency grid 为 A_stage4a1_quick61 | 结果只覆盖无噪声模型内情形 | 将噪声和测量误差作为独立压力测试，不与当前 Pilot 混合调阈值 |
| R1-16 | 指标不足 | 当前 Pilot 主表没有报告候选集合平均大小、接受 coverage、选择性 risk 和结构 OOD false acceptance 的完整分层 | `pilot_confirmation_metrics.csv` 仅含 truth_set_coverage、singleton_rate、empty_set_rate | 无法同时评价“覆盖”和“集合是否过宽” | 下一阶段必须报告集合大小分布、topology selective risk、结构 OOD 和模型覆盖损失 |

## 3. 结果的正确解释

### 3.1 可以支持的结论

1. 一份共享 ledger 可以驱动多个工程候选的生成；
2. 候选工程空间、正向模型兼容空间和评分空间可以分层审计；
3. 离散 profile distance 接口不读取观测生成时的真实参数；
4. 当前非唯一控制审计能够避免把已知非唯一场景强制输出为单一拓扑；
5. constrained best-first Top-K 原型在 8 节点、18 边控制实例上与穷举键集合一致。[本次运行]

### 3.2 不能支持的结论

1. 不能声称 ENWL 派生 reference topology 已被 Pilot 正确识别，因为它未进入评分 Top-K；
2. 不能把 `truth_set_coverage=6/6` 解释为总体拓扑准确率；
3. 不能把 `false_unique=0/100` 解释为实际系统的假唯一率很低；
4. 不能声称 `absolute` 比其他四种方法更优；
5. 不能把 Top-K 控制实例 speedup 外推到大规模网络；
6. 不能把模型内无噪声 CFR 结果写成真实 PLC 或现场配电网验证。

## 4. 进入下一阶段的必要条件

下一阶段至少应完成以下闭环后，才适合重新讨论方法效果：

1. 让公开 reference truth 或独立隐藏 truth 进入实际评分库，且记录 Top-K 截断前后的覆盖；
2. 增加每候选 calibration 样本，使经验 p-value 分辨率与目标 alpha 相容；
3. 重新冻结并验证 method selection，避免所有方法并列时任意选择；
4. 将 same-theta scenario equivalence 接入共享候选库，取消硬编码 legacy truth set 作为主非唯一证据；
5. 增加独立的结构 OOD、参数 OOD、模型不兼容和噪声压力测试；
6. 修正 243/1458 模板命名和科学输入 hash；
7. 输出候选集合大小、选择性风险、拒识率和 coverage loss 的分层结果；
8. 保留 Final 为预留集，在上述规则冻结前不得运行或据其调参。

## 5. 可复核证据

- Pilot 汇总：`results/data/stage4a7_2_r1/pilot/summary.csv`；
- 候选覆盖：`results/data/stage4a7_2_r1/pilot/candidate_coverage_audit.csv`；
- 方法选择：`results/data/stage4a7_2_r1/pilot/development_method_selection.csv`；
- 冻结方法：`results/data/stage4a7_2_r1/pilot/frozen_method_manifest.csv`；
- 非唯一指标：`results/data/stage4a7_2_r1/pilot/nonunique_confirmation_metrics.csv`；
- 非唯一逐场景结果：`results/data/stage4a7_2_r1/pilot/nonunique_decisions.csv`；
- Top-K 审计：`results/data/stage4a7_2_r1/pilot/topk_scaling_audit.csv`；
- 定向测试：`results/logs/stage4a7_2_r1_targeted_final.log`；
- 完整历史回归：`results/logs/stage4a7_2_r1_full_regression_final.log`；
- Pilot 日志：`results/logs/stage4a7_2_r1_pilot.log`。

## 6. 阶段边界

当前结果属于受限径向候选库、公开处理模型派生的 controlled uncertainty、A 网格和模型生成无噪声复 CFR。候选集合覆盖不等于拓扑唯一识别，profile distance 最优不等于参数全局可辨识，非唯一集合输出不等于真实物理等价性已经在所有参数点得到证明。本阶段未运行完整 Final，未启动 Stage 4B，也未进行现场配电网或真实 PLC 收发机验证。
