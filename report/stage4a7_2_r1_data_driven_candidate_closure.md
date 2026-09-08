# Stage 4A.7.2-R.1：公开低压网络派生的不确定工程先验、候选参数剖面匹配与非唯一判定闭环

## 1. 阶段结论

本阶段已完成受控的 MATLAB Pilot、定向测试和完整历史回归，阶段状态为：

**Stage 4A.7.2-R.1 completed controlled pilot**。

该结论仅适用于受限子网、共享不确定先验、A 网格和模型生成 CFR 的受控实验。Pilot 不是完整 Final，也不是现场验证。Stage 4B 未启动，Stage 4A.7.2 历史结果未覆盖。[本次运行]

结果适用性、关键缺陷和下一阶段门槛见独立审计：[Stage 4A.7.2-R.1 缺陷、不足与结果适用性审计](stage4a7_2_r1_limitations_and_open_issues.md)。

## 2. 数据来源与公开模型边界

[本次运行] 未下载外部文件；输入文件由工作区预先提供并在读取前完成只读哈希核对。来源清单、URL、文件大小和 SHA256 见 [ENWL LVNS 数据清单](../materials/external_data/enwl_lvns_manifest.md)。实际阅读了 `summary-report.pdf` 和 `lvns_closedown_report.pdf` 的正文相关章节。[论文明确陈述] summary report 描述了 25 个公开 LV network、131 条 feeder、5952 个用户和约 172 km LV cable，并说明 GIS 端点存在毫米至厘米级间隙，需要连通分量和几何邻近修复后生成 OpenDSS 模型。[论文明确陈述] closedown report 说明了模型验证、数据缺失时的假设和公开模型的知识产权边界。

选定的派生对象是 `network_13 / Feeder_3` 的局部子网：source 为节点 `32`，receiver 为节点 `39`，节点集合为 `32–39`。保留主路径 `32–33–34–35–36–37–39` 和一级叶支路 `36–38`，共 8 个节点、7 条边。选择局部诱导子网是为了满足当前稳定正向模型的“source→receiver 主路径＋一级叶支路”接口；馈线边界外的深层结构不被压缩后冒充为本子网。

公开 OpenDSS 模型是经过处理和校验的确定网络，不能被描述为原始不完整 GIS。R.1 的不确定性是从该确定模型派生的 controlled uncertainty，不是 ENWL 现场错误台账。[模型内推断]

## 3. 三层身份

实现中严格区分：

1. `reference truth`：公开子网确定图，仅用于离线生成观测和评分；
2. `observed engineering ledger`：候选器可见的一份共享工程账本；
3. `candidate set`：从共享账本按 required、forbidden、optional、径向、连通和最大度约束生成的候选。

候选生成接口不接收 `truth_topology_id` 或 reference graph。公开子网行中的 source record 和 reference status 仅保存在派生输入和离线实验上下文中。

## 4. 共享不确定工程先验

`src/build_stage4a7_2_r1_uncertain_engineering_prior.m` 将 7 条公开参考边放入一份共同 ledger，并将两条 source/receiver 锚边设为 required；其余公开边为 optional。另加入 6 条受控 `synthetic_edge_exchange` ambiguity edges，所有这些边均带有 prior cost、长度区间、线缆类别、来源网络、馈线和 source record。

这些 ambiguity edges 不是声称来自 ENWL 的开关记录或 GIS 误差；它们是可复现的工程不确定性控制输入。若后续采用真实 switch 或坐标邻近信息，应在 manifest 中另行记录状态来源和单位。

## 5. 候选生成与 Top-K

路线 A 使用现有剪枝型工程树枚举器，避免先生成允许边全集的幂集。R.1 同时保留 `generate_topk_topology_candidates` 的 constrained best-first branch-and-bound prior-cost prototype，作为规模扩展接口。候选层、forward-model compatibility 层和 scored library 层分开保存；不兼容候选不被静默删除，而是由 adapter 标记并从评分库排除。

R.1 的中型 Top-K 控制实例配置为 8 节点、18 条允许边、K 为 1/5/10/20，并实际记录状态扩展、剪枝、队列峰值及 runtime。该实例共有 2376 棵可行树；K=1/5/10/20 的 runtime 分别为 0.026709/0.033062/0.031759/0.089020 s，均与穷举结果的规范键集合一致。对应穷举耗时为 3.627709 s，原型 speedup 分别为 135.82/109.72/114.23/40.75。[本次运行] 该结果是小型中型控制实例证据，不等同于大规模网络性能保证。

## 6. 正向模型 round-trip

`src/adapt_engineering_candidate_to_forward_model.m` 将主路径节点和边 ID、长度、线缆类别以及一级支路挂接节点、叶节点、长度、线缆类别和负载写入 `adapter_metadata`。round-trip 从 `network.main_lengths`、`network.main_cable_type`、`network.branches` 和该元数据恢复工程图，再比较：canonical edge set、source/receiver、节点集合、边长度、cable type、端接负载和树结构。它不再直接读取 candidate 的原始 `edges` 作为“恢复结果”。

适配器审计在 Pilot 中实际执行：兼容候选使用 `forward_network_and_adapter_metadata` 完成图结构恢复，`adapter_roundtrip_audit.csv` 中记录 `round_trip_ok`、属性差异和不兼容原因。当前审计的兼容候选均通过结构往返；嵌套支路和不支持组件被显式标记为不兼容并排除评分。[本次运行] 多参数点的完整 CFR 数值对照由 profile cache 和测试接口覆盖，但不将这一小规模审计外推为一般网络的适配保证。[模型内推断]

## 7. 候选独立 profile distance

R.1 使用固定的离散参数模板网格作为第一版 profile；本次 Pilot 的每个候选缓存包含 1458 个模板：

$$
d_G(x)=\min_{\theta\in\Theta_G}D\bigl(x,H(G,\theta)\bigr).
$$

每个兼容候选都有自己的模板 CFR 缓存，`stage4a7_2_r1_profile_distance` 只接收观测 views、模板 cache 和距离配置，不接收真实 theta。Pilot 实际使用了每候选 1458 个离散参数模板，输出 profile distance、最优模板索引、最优模板参数和有限模板数。该实现与 same-theta distance 分开保存；profile distance 只用于候选独立拟合，不读取观测生成时的真实参数。[本次运行]

## 8. Development、calibration 与 Pilot

入口的顺序为 development → method selection → calibration → frozen profile method → Pilot。当前配置为 A 网格 2–30 MHz、61 点；串行为默认执行模式。development 只按 coverage gate、平均集合大小、singleton accuracy 和 empty-set rate 选择方法；选择结果写入 frozen method manifest。calibration 仅估计候选经验分布，Pilot 不参与方法选择或阈值调整。`final_reserved` 只保留身份，不物化。

本次 MATLAB Pilot 实际完成 development/calibration/Pilot = 12/12/6，冻结选择的方法为 `absolute`。Pilot 的 `truth_set_coverage=6/6`，`singleton_rate=0/6`，`empty_set_rate=0/6`；Wilson 区间和 scientific hash 保存在 `pilot_confirmation_metrics.csv`。这些数字只代表受控 Pilot，不代表总体性能或现场 coverage。[本次运行]

## 9. 非唯一与近对称

入口为历史 G004/G007 same-theta 非唯一对构造观测，每个观测只保留一行，`truth_member_count=2`。`stage4a7_2_r1_nonunique_metrics` 将：

* `false_unique_unconditional_rate` 的分母定义为全部具有可靠 truth-set 标签的场景；
* `false_unique_conditional_rate` 的分母定义为真实 truth-set 成员数大于 1 的场景；
* singleton 输出即使属于 truth set，也不能在真实非唯一场景中被称为正确唯一。

入口另生成 50 个受控近对称场景，保存扰动比例、两候选 same-theta 距离和候选集合大小。`absolute_I` 的 resolution floor 由 development 距离的数值尺度冻结，而不是继续使用未经校准的固定常数；无噪声时只能称为 numerical/model resolution，不能称为现场分辨率。

本次实际生成 100 个 same-theta 非唯一场景和 50 个近对称场景。非唯一场景的 truth-set coverage 为 100/100，multi-candidate rate 为 100/100，false-unique unconditional/conditional 均为 0/100；近对称表保留 0.001、0.005、0.01、0.02、0.05 五档扰动及两候选距离，当前 Pilot 的冻结判据对这些控制场景均输出 7 候选集合。结果见 `nonunique_confirmation_metrics.csv` 和 `near_symmetry_decisions.csv`。[本次运行]

## 10. 测试与运行记录

已加入 `tests/test_stage4a7_2_r1_data_driven_closure.m`，并接入 `tests/run_tests.m`。测试覆盖共享 ledger 不泄漏 reference truth、多个候选、profile API 不接收真实 theta、adapter round-trip 返回字段和 false-unique conditional denominator。

已完成：[本次运行]

* `git diff --check`：通过；
* MATLAB R2024a 定向测试：通过，日志为 `results/logs/stage4a7_2_r1_targeted_final.log`；
* 完整历史回归：通过，日志为 `results/logs/stage4a7_2_r1_full_regression_final.log`；
* R.1 Pilot：通过，日志为 `results/logs/stage4a7_2_r1_pilot.log`；
* MATLAB 执行模式：JVM、串行 1 worker；
* Pilot 总耗时：10.732911 s（包含结果保存）；
* MATLAB 进程实际入口报告 elapsed：11.479 s；
* 选定方法：`absolute`；
* source-tree hash：`969d8b016ac82f8ff581601b984073620297d51b20e602c805b5b0fbda7876e9`；
* scientific hash：`291bc432a3363a3c39d7b58362e891ed0fe4b68e98257d70f61a781ac722c002`；
* `final_reserved`：仅保存身份，未物化；
* 并行：未启用；本阶段样本规模小，沿用串行 fallback，未把并行速度外推为科学结论。

## 11. 下一步门槛

后续若继续扩展，应重新设计独立的更大 calibration/Pilot，并在扩大样本前冻结数据划分、候选覆盖审计和 profile 判据。当前不建议把 6 个 Pilot 场景或 100 个受控非唯一场景解释为稳定总体性能。

当前仍不进入 Stage 4B，不运行完整 Final，也不把公开网络派生先验或模型 CFR 写成真实 PLC 现场验证。
