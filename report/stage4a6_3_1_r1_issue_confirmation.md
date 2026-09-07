# Stage 4A.6.3.1-R.1 静态问题确认表

本表针对当前 Git 提交 `b0ed9cae5b8635b43da671a10e10ef0dfe1a15f4` 的工作树核对形成。历史 R 目录保持只读；R.1 结果写入独立目录。证据标签表示静态代码核对，不等同于 Pilot 数值证据。

| 问题 | 是否确认存在 | 证据文件 | 函数或行附近逻辑 | 影响的指标或结论 | 修正方案 | 对应测试 |
|---|---|---|---|---|---|---|
| `false_unique` 使用参数 OOD 代替观测等价非唯一 | 是 | `src/evaluate_stage4a6_3_1_metrics.m` | 原实现以 `outood & unique_topology` 计数 | 拓扑唯一性结论被参数域标签污染 | R.1 评分标签保存冻结 P0 等价类；仅以真实非唯一等价类和单拓扑输出计数 | `test_stage4a6_3_1_r1_metrics_and_identity` |
| `selective_risk` 混合拓扑错误与参数状态 | 是 | `src/evaluate_stage4a6_3_1_metrics.m` | 原实现以 `wrong=decided&~eq` 覆盖全部状态 | topology/parameter 风险无法解释 | R.1 分别输出 topology、parameter 和 end-to-end coverage/risk | 同上 |
| profile 不可靠时仍可能产生类级确定结论 | 是 | `src/aggregate_stage4a6_3_1_member_evidence.m`、`src/apply_stage4a6_2_parameter_decision.m` | 旧聚合器主要检查成员计数，未将所有成员可靠性作为硬门控 | 参数 OOD 怀疑可能没有可靠 profile 支持 | R.1 聚合器要求所有接受成员 profile reliable；否则 indeterminate | 同上 |
| 拓扑与参数 calibration 身份未分离 | 是 | `experiments/exp_stage4a6_3_1_r_independent_pilot.m` | 决策表只有 `calibration_hash` | 参数阈值来源不能独立追溯 | R.1 保存并硬校验 `topology_calibration_hash` 与 `parameter_calibration_hash` | 同上 |
| 参数 profile 只检查 compatibility hash | 是 | `src/stage4a6_3_1_r_profile_all_accepted_members.m` | 原入口没有独立参数 calibration 身份 | 可能加载错误参数阈值模型 | R.1 参数入口新增参数 calibration hash 硬校验 | 同上 |
| 统计去重主要使用 physical scenario ID | 是 | `src/evaluate_stage4a6_3_1_metrics.m` | 原实现只按 `physical_scenario_id` 保留首行 | 修改 sample ID 可能虚增独立分母 | R.1 优先按 noiseless CFR hash，其次参数 hash、物理 ID 聚类并报告各层计数 | 同上及 R.1 Pilot 审计 |
| 跨 split 审计未拆分参数哈希和 CFR 哈希 | 是 | `experiments/exp_stage4a6_3_1_r_independent_pilot.m` | 原审计只有合并的 `cross_split_duplicate_count` | 无法区分参数重复和观测重复 | R.1 输出参数、CFR、observation hash 三类交叉计数；final_reserved 标为 not evaluated | Pilot `independence_audit.csv` |
| source-tree hash 未覆盖完整默认配置和正向依赖 | 是 | `src/stage4a6_3_1_r_source_tree_hash.m` | 原清单未包含 `config/default_config.m` 等关键入口 | 科学代码身份可能漏变更 | 扩展 R.1 scientific dependency manifest，排除路径、结果和时间戳 | source hash 变更测试 |
| 拓扑阈值 CSV 的 status 为空 | 是 | `results/data/stage4a6_3_1_r/calibration/topology_confirmation_thresholds.csv` | 导出函数使用了不存在的 `calibration_status` 字段 | 校准状态被误读为未知 | R.1 生成显式 `topology_calibration_status` 和身份字段 | R.1 阈值表审计 |
| 当前报告仍描述部分已提交文件为未提交 | 是 | `report/stage4a6_3_1_r_reproducibility_audit.md` | 运行后报告固定写入“尚未提交 Git” | 复现状态与实际 Git 不一致 | R.1 报告区分历史未跟踪大文件、R 版历史与 R.1 新结果 | R.1 报告路径审计 |

## 处理范围

R.1 只修正指标语义、校准身份、可靠性门控和独立统计闭环。它不改变传输线正向模型，不把参数域判断改写为拓扑唯一性，也不运行完整 Final。所有最终结论仍限定于受限径向候选库、合成先验、A 网格和模型生成复数 CFR。[代码静态核对]
