# Stage 4A.2：先验约束候选库、参数覆盖与稳健匹配验证

## 1. 目标与边界

本阶段在 Stage 4A.1 的受限径向树、名义复合模板和观测等价类审计之上，增加资产/工程先验接口、五维参数网格的流式匹配、候选库覆盖审计以及最小的唯一/等价类/拒判输出逻辑。研究链条为：

```text
资产/工程先验
→ 可行图集合
→ 图—参数复合库
→ 完整树 CFR 匹配
→ 唯一拓扑 / 观测等价类 / 拒判
```

全部先验均为 `synthetic_demo_prior_not_field_data`。本阶段不使用真实 GIS、台账、线路档案或现场量测；不实现 FDR/TFDR、绝对 ToF、全节点导纳/TLS、真实收发机、机器学习或 OFDM 资源优化。结果仅是给定候选语法、端接、频率网格和完整树分布参数正向模型下的模型内审计，不构成现场拓扑恢复结论。

## 2. 先验结构与候选生成

`config/stage4a2_prior_config.m` 定义 `asset_prior`，包含节点清单、边先验、径向规则和观测先验。边先验记录 `allowed`、`required`、`forbidden`、长度区间、线型集合、硬/软类别和来源标签；规则记录根、接收节点、最大度、最大支路深度、允许支路位置和开关状态。

`src/validate_topology_prior_consistency.m` 在生成前拒绝缺失节点、必需边与禁止边冲突、非法长度区间、与当前一层径向前向模型不兼容的规则。`src/generate_prior_constrained_candidates.m` 只在 Stage 4A.1 已支持的主路径加一级侧支路语法内过滤：硬先验排除候选，软先验只产生 `soft_prior_score`，不在无 CFR 证据时删除候选。

每个保留候选保存 `prior_trace`、满足的硬约束、软得分、逐边长度区间、允许线型和完整先验哈希。规范键仍固定 TX→RX 主路径方向，因此输入边先验的顺序不改变候选集合或排序。

三个固定合成情景如下：

| 情景 | 候选数 | 覆盖语义 |
|---|---:|---|
| P0_no_prior | 7 | 复现 Stage 4A.1 图语法与规范键。 |
| P1_partial_consistent_prior | 4 | 禁止靠近接收端的一级侧支路；不直接指定真实图，仍保留多个候选。 |
| P2_stale_or_inconsistent_prior | 4 | 错误地禁止中部一级侧支路；指定的 G003 测试真值不在可行集，必须报告覆盖不足。 |

因此候选数减少本身不解释为识别能力提升；任何先验排除真值都必须与覆盖率一并报告。

## 3. 参数复合库与流式匹配

参数网格直接引用 `default_config.stage2_3.search`：主线长度比例、支路长度比例、支路负载比例、$Z_s$ 和 $Z_r$ 均为三个取值，故每个图有 $3^5=243$ 个参数模板。P0/P1/P2 的复合模板规模分别为 1701、972 和 972。

`src/stream_composite_library_templates.m` 以确定性批次发出图—参数元数据；`src/match_composite_topology_library.m` 逐批计算完整树无噪声复 CFR 并释放批次。距离复用既有 `topology_feature_distance.m` 的 `complex_raw` 定义。输出保存最佳模板、最佳图、最佳观测类、参数、距离、异类次优距离、间隔、候选数、参数模板数、覆盖状态和是否采用流式计算。

次优项按不同观测等价类计算，不将同一物理等价类的另一个参数模板误报为竞争拓扑。名义参数下的等价类由完整复 CFR 和冻结的 `tie_tolerance=10^{-10}` 连通分量形成；它不表示图同构。

校准和测试使用不同随机种子。校准集仅产生名为 `model-internal calibration threshold` 的模型内残差/间隔门限；测试集不用于调节门限。输出逻辑为：多成员最优类或间隔不足时输出 `equivalence_class`；单成员且通过两类门限时才输出 `unique_topology`；残差过大时输出 `reject_model_mismatch`；可行集为空、库外或被硬先验排除时输出 `reject_no_feasible_candidate`。

## 4. 频率网格与可追溯性

配置保留两组频率：A 为 Stage 4A.1 的 2--30 MHz、61 点快速网格；B 直接由 `default_config.ofdm.active_frequency_hz` 导出，记录 `NFFT=4096`、$F_s=64$ MHz、有效 bin、频点数组和子载波间隔。代码不手写 B 的频率列表。

`stage4a2_config_hash.m` 对候选语法、完整先验、参数网格数值、完整频率数组、观测/端接、距离定义、容差、校准门限、随机种子和版本生成稳定 SHA-256 摘要，同时保存可复核的规范化配置文本。频率清单 CSV 也保留完整数组而非只保留频点数量。

## 5. 测试与已运行结果

`tests/test_stage4a2_prior_constrained_library.m` 覆盖 P0 复现、P1 覆盖和缩减、P2 排除、硬先验冲突、允许边/长度/度数约束、输入顺序不变性、243 模板计数、流式与小规模全量结果一致、库内模板不误拒、T3/T5 对称 SISO 等价以及合法库外树不被无条件唯一接受。

MATLAB R2024a 已完成正式 A/B 网格运行，入口为 `run_stage4a2_prior_constrained_matching.m`，运行时间为 68.073 s。A 使用 61 个频点；B 使用由当前 OFDM 配置导出的 1793 个有效子载波，频率数组、有效 bin、`NFFT=4096`、$F_s=64$ MHz 和 15.625 kHz 间隔均写入 `stage4a2_frequency_grid_manifest.csv`。完整结果保存为 `stage4a2_results.mat` 及同前缀 CSV。

在 A 网格上，P0 的库内网格点 G003 以零距离匹配并输出 `unique_topology`；网格外 G007 的最优类为 `{G004,G007}`，但最优残差超过模型内校准门限，输出 `reject_model_mismatch`；合法库外 G008 输出 `reject_no_feasible_candidate`，未被唯一接受。P1 将候选从 7 缩减到 4，覆盖样本 G005 以零距离输出 `unique_topology`。P2 同样保留 4 个候选，但 G003 被错误硬先验排除，覆盖率为零并输出 `reject_no_feasible_candidate`。P0 在 B 网格的库内 G003 样本仍严格匹配；因其模型内间隔低于 B 网格校准门限，输出 `equivalence_class`，而非将零残差写成唯一恢复。

正式等价类在 A、B 两个网格下均包含 `{G002,G005}` 与 `{G004,G007}`；它们仅表示当前对称 SISO、端接和容差条件下的不可区分性。`stage4a2_smoke_*` 为此前的三频点接口冒烟输出，与正式结果分开保留。

## 6. T1--T6、等价类与后续接口

历史 `topology_candidates.m` 和 T1--T6 的物理定义未修改。Stage 4A.2 的自动图语法仍以 Stage 4A.1 的 7 图小库为基线；独立测试继续核对 T3/T5 在对称 50/50 Ω SISO 下的等价性。改变端接、观测端口或频点后，必须重新审计，不能复用旧等价类。

进入后续阶段前需要冻结真实端口参考面、端接、测量节点和资产资料来源。真实资产先验、真实 PLC 收发机、现场拓扑恢复以及正式 Stage 3B 的导频/功率/PSD/子载波资源优化均不属于本阶段。
