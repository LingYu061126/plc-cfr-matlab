# Stage 4A.7.2 文献方法与候选确认证据矩阵

## 1. 阅读范围与证据边界

本矩阵依据工作区中可读取的 PDF 原文文本层建立。页码按 PDF 页面计数；文本抽取存在排版换行风险，关键公式在后续正式引用前仍应以 PDF 页面复核。工作区未找到 Erseghe 等关于 smart micro grids 的原始 PDF，因此该文不列为本阶段已阅读证据。[代码静态核对][待验证]

本阶段只把文献中的候选生成、集合值输出、可辨识性和信道对称性思想映射为工程接口或实验假设，不声称复现论文的完整算法、现场保证或原始观测条件。[模型内推断]

## 2. 文献—方法矩阵

| 文献 | 原始输入 | 候选如何产生 | 判定统计量/输出 | 理论条件 | 可移植部分 | 不可直接移植部分 | 位置 |
|---|---|---|---|---|---|---|---|
| D. Eppstein, *Finding the k Smallest Spanning Trees* | 带边权的无向图 | 生成按权重排序的 k 棵最小生成树；论文使用收缩、删除和替换边降低问题规模 | 生成树总权重与 k-best 顺序 | 图权重、生成树约束；论文复杂度结论对应其特定算法 | “按先验代价顺序、按需产生 Top-K”的算法目标 | 当前项目还有 required/forbidden、度数、路径和正向模型兼容约束；当前实现不是 Eppstein 算法，不能继承其复杂度 | PDF pp.1–3 摘要、引言；pp.4–6 Theorem 1 附近；算法直觉见 p.2 |
| H. N. Gabow, E. W. Myers, *Finding All Spanning Trees of Directed and Undirected Graphs* | 有向/无向图 | DFS/backtracking 与 bridge 检测，逐棵输出且不重复 | 全部生成树集合 | 连通图、树/根树定义；时间和空间界限依赖输出规模 | 作为完整受约束枚举的算法参照、检查不重复和输出敏感性 | 当前工程枚举器不是该论文实现，也没有实现 bridge-based 输出敏感算法 | PDF p.1 摘要与算法定义；pp.1–2 Section 1–2 |
| M. Sadinle, J. Lei, L. Wasserman, *Least Ambiguous Set-Valued Classifiers with Bounded Error Levels* | 特征与类别标签 | 输出包含多个 plausible labels 的集合，以覆盖约束控制平均集合大小/歧义 | 覆盖率、集合大小、拒识/空集 | 概率分类模型与训练/校准数据；可出现空集 | “不强迫唯一类别、同时报告 coverage 与集合大小”的评价思想 | 当前输入是物理 CFR 距离而非条件类别概率；本项目经验 p-value 不能直接称为该论文的最优分类器 | PDF p.1 摘要；pp.5–7 oracle/set-valued 定义；p.15 附近有限样本方法；空集讨论 p.1、p.14 |
| Y. Romano, M. Sesia, E. J. Candès, *Classification with Valid and Adaptive Coverage* | 可交换 calibration/test 样本与类别评分 | split-conformal/CV+ 等校准预测集合 | marginal coverage、集合大小、p-value/阈值 | 可交换性、独立 hold-out 校准；coverage 是分布意义而非物理定律 | calibration 与 Pilot 分离、集合值输出、coverage—集合大小权衡 | 当前实验没有概率分类器，也没有现场 exchangeability 证据；本项目只能称 empirical calibrated candidate set | PDF pp.1–4；Algorithm 1 p.4；Theorem 1 p.4；p.7 附近 label-conditional 扩展 |
| T. C. Banwell, S. Galli, *On the Symmetry of the Power Line Channel* | 两端口 PLC 网络的传递函数 | 不是拓扑搜索，而是证明特定源/负载端接下信道对称性，并给出实验拓扑变化 | 正反方向传递函数关系 | 特定端接与二端口互易条件；对称性与拓扑无关但依赖端接 | 支持在受限 SISO 条件下保留观测等价类、不要强制唯一化 | 不能单独证明任意两个不同拓扑等价；不提供当前候选库的确认阈值 | PDF p.1 摘要；pp.2–4 symmetry proof；p.4 experimental confirmation |
| M. O. Ahmed, L. Lampe, *Power Line Communications for Low-Voltage Power Grid Tomography* | 多 PLC 节点的端到端距离/ToA 信息 | 由叶节点/分支节点测距构造树结构或 tomography | 距离矩阵、路径/树结构 | 多节点部署、同步/测距质量和可观测节点条件 | 作为路线 C 多节点测距直接重构的能力边界依据 | 当前只有单 TX–RX 复 CFR，没有成对距离矩阵，不能把当前 IFFT 峰当作其输入 | PDF pp.1–3 问题与系统假设；pp.5–7 tomography/叶节点讨论 |
| G. Cavraro et al., *Real-Time Identifiability of Power Distribution Network Topologies With Limited Monitoring* | 配电网有限监测量测 | 依测量位置和 observable islands 讨论可恢复结构 | identifiability/detectability 与可观测区域 | 监测位置、网络结构和电气模型共同决定唯一性 | 支持“观测不足时输出等价类/不可判定”而非强制唯一 | 不是 PLC CFR 算法，也不提供当前单端口候选距离的阈值 | PDF p.1 摘要；pp.3–5 identifiability/observable islands |
| D. Deka, V. Kekatos, G. Cavraro, *Learning Distribution Grid Topologies: A Tutorial* | 电压、电流、功率或主动响应等配电网量测 | 既有基础设施下检测开关状态，未知基础设施下识别连接与阻抗；图搜索、LS、凸优化、混合整数等 | 物理约束下的拟合/拓扑判定 | 径向馈线、测量布置、线路基础设施和阻抗先验 | 明确区分 topology detection 与 identification；支持工程先验层与可辨识性审计 | 不应把该文的电压/功率量测方法写成当前 CFR 算法已复现 | PDF pp.1–2 摘要与引言；可辨识性和方法综述见 pp.4–13 |
| *Topology and Parameter Identification in Electrical Distribution Systems using Spatial Priors* | µPMU/NPMU 电压、电流量测与 GIS 空间信息 | GIS 导出允许边、线路参数边界和拓扑变量；MIQP/约束优化 | 拓扑/参数联合识别与误差 | 空间先验、径向连通约束、测量误差模型 | 支持工程候选层：允许边、required/forbidden、长度区间、软先验成本 | 当前 synthetic prior 不是 GIS；没有把 MIQP 或电压量测直接移植到 CFR | PDF pp.1–5；MIQP、空间先验和径向约束见 pp.3–5 |

## 3. 对 Stage 4A.7.2 的直接影响

1. **候选生成与确认必须分层。** Eppstein/Gabow–Myers 只支持图候选生成的算法方向；当前候选仍须经过严格的 stable forward-model adapter，工程可行不等于 CFR 可评分。[论文明确给出][代码静态核对]
2. **集合值输出优先于强制唯一。** Sadinle/Romano 的共同启示是：困难观测可以输出集合并同时报告 coverage 和集合大小；本项目将其适配为 empirical nonconformity candidate set，不称为完整 conformal guarantee。[论文明确给出][模型内推断]
3. **等价性需要物理条件限定。** Banwell–Galli 支持端接条件下的对称性分析，但当前 same-theta cluster 和 profile/near-symmetry 实验仍是模型内证据，不是任意拓扑的全局等价定理。[论文明确给出][模型内推断]
4. **缺少多节点距离观测。** Ahmed–Lampe 和 Cavraro 的条件说明当前单端口 CFR 无法直接使用 RNJA、distance-matrix tomography 或 observable-island 结论作为已经实现的算法。[论文明确给出][代码静态核对]
5. **先验应被记录为约束来源。** Deka 及空间先验论文支持把节点、边、径向性和长度范围作为工程先验，但当前 `synthetic_demo_prior_not_field_data` 不能写成现场 GIS 覆盖。[论文明确给出][代码静态核对]

## 4. 当前代码对应关系

| 当前对象 | 文件/函数 | 对应文献思想 | 当前限制 |
|---|---|---|---|
| 工程候选规范化 | `src/normalize_engineering_candidate_spec.m` | 允许边、required/forbidden、节点和结构约束 | 先验是合成配置；不是 GIS/资产台账 |
| 完整受约束枚举 | `src/generate_engineering_topology_candidates.m` | spanning-tree enumeration 方向 | 不是 Gabow–Myers 的复杂度实现；当前规模小 |
| Lazy Top-K | `src/generate_topk_topology_candidates.m` | k-best tree 目标，受 Eppstein 启发 | 是本项目 best-first branch-and-bound 原型，不声称 Eppstein |
| 图到 CFR 模型适配 | `src/adapt_engineering_candidate_to_forward_model.m` | 工程图与物理模型分层 | 只支持主路径加一级叶支路 |
| 经验候选集合 | `src/calibrate_candidate_nonconformity_family.m`、`src/apply_candidate_nonconformity_set.m` | set-valued/calibration 思想 | 没有噪声似然和现场 exchangeability 保证 |
| 观测条件下不可区分图 | `src/build_candidate_indistinguishability_graph.m` | ambiguity/indistinguishability 诊断 | 不是严格物理等价类 |
| 非唯一场景 | `src/build_stage4a7_2_nonunique_clusters.m`、`src/build_stage4a7_2_near_symmetry.m` | 对称性与不可辨识审计 | 最新 profile/near-symmetry 修改尚未由 MATLAB 重跑确认 |

## 5. 尚未完成的文献核验

工作区未找到 Erseghe 等 *Topology Estimation for Smart Micro Grids via Powerline Communications* 的原始 PDF；因此本阶段不把 GLRT 的原始公式、页码或实验条件写成已核验事实。若后续需要 CFR-domain GLRT-compatible baseline，应先补齐原文并明确当前 CFR 版本的噪声协方差、未知参数处理和独立校准来源。[本次未运行][待验证]
