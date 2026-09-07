# Stage 4A.6.3.1-R 文献方法—当前代码映射

| 理论环节 | 当前代码/配置 | 输入与输出 | 文献对应 | 实现程度与限制 |
|---|---|---|---|---|
| 候选图语法 | `src/generate_radial_topology_candidates.m`、`config/default_config.m` 的 `generator` | 允许主路径支路位置、最大支路数、径向/单层约束 → 稳定排序的候选图 | 空间先验/树估计类文献支持“先验限定候选空间” | 已实现小规模人工语法；不接 GIS/台账/现场开关 |
| 图合法性 | `src/validate_radial_topology_candidate.m` | 候选图 → 连通、径向、节点/边合法性 | 径向配电网和树重构文献 | 约束范围有限，不能代表完整配电网 |
| 先验过滤 | `src/generate_prior_constrained_candidates.m`、`src/validate_topology_prior_consistency.m` | 图与合成先验 → P0/P1/P2 候选集 | de Jongh spatial priors 的接口思想 | 当前先验明确标记为 `synthetic_demo_prior_not_field_data` |
| 参数域 | `src/topology_parameter_grid.m`、`src/build_extended_parameter_domain.m` | 五维参数域/243个离散模板 → 图—参数库 | 传输线参数识别/空间先验文献 | 离散模板和模型内扩展域；不是现场参数分布 |
| 复合模板 | `src/build_stage4a5_1_template_cache.m`、`src/build_stage4a3_1_template_cache.m` | 图、参数、频率、正向模型 → CFR 模板缓存 | CTF/模型匹配类工作 | 复用缓存；不提高物理可辨识性 |
| 观测评分 | `src/score_stage4a5_observation.m` | CFR 观测、缓存、子带集合 → `d1,d2,margin,rho`及子带/邻域/稳定性证据 | CTF、距离匹配、选择性拒判的可解释部分 | 不是 ML/MAP；未建噪声协方差似然 |
| 冻结确认 | `src/apply_stage4a5_confirmation.m`、新 `src/stage4a6_3_1_r_confirm_with_frozen_stage4a5_1.m` | 观测证据、校准模型、冻结 spec → 唯一/等价类/拒判 | 候选验证、拒判和 risk–coverage | R 版禁止 `match_nominal`；哈希不兼容硬失败 |
| 等价类成员 | 新 `src/stage4a6_3_1_r_profile_all_accepted_members.m`、`src/stage4a6_3_1_r_aggregate_class_evidence.m` | 接受成员集合 → 每成员 profile → 保守聚合 | 有限测量可辨识性文献 | 不能强拆 `{G002,G005}` 等 SISO 等价类 |
| 参数 profile | `src/compute_stage4a6_2_parameter_profile.m`、`src/compute_stage4a6_2_member_evidence.m` | 固定参数扫描、其余 active 参数优化 → constrained residual profile | profile likelihood 仅作为概念对照 | 当前没有统计似然；平坦/失败保留为不可判定 |
| 逐参数判据 | `src/apply_stage4a6_2_parameter_decision.m` | profile、校准阈值、边界/灵敏度 → in/out/indeterminate | 物理残差和 selective abstention | 阈值来自独立 calibration；当前 R 版不使用最终保留集 |
| 独立场景 | 新 `src/stage4a6_3_1_r_generate_independent_scenarios.m`、`src/stage4a6_3_1_r_materialize_scenario.m` | seed、拓扑、参数越界层级 → 真值参数、CFR/观测 hash | 文献中的独立实验/统计评价要求 | 无噪声、A网格；不等于现场样本；hash 生成不进入确认器 |
| 统计评价 | `src/stage4a6_3_1_r_evaluate_metrics.m`、`src/evaluate_stage4a6_3_1_metrics.m` | 决策表+离线标签 → 无条件指标、coverage、selective risk、Wilson区间 | SelectiveNet 的 risk–coverage 语义 | 以 physical scenario 去重；Pilot 样本仍小 |

## 关键解释

`d1` 是排序量，不是确认充分条件；`margin`、`rho`、子带一致性、邻域模板证据与 block stability 是当前冻结确认器的补充证据。[代码静态核对]

参数 profile 位于拓扑确认之后。拓扑拒判时输出 `parameter_not_evaluated`，不把未执行参数证据计为库内或库外。接受等价类时逐成员计算，成员缺失或冲突则输出 `parameter_domain_indeterminate`。[代码静态核对]

当前工程先验只表示“在指定合成语法下可行”，不表示真实资产覆盖；候选库之外的样本仍可能被最近模板吸收。因此 Pilot 需要同时保留拒判、不可判定与错误接受。[模型推断]
