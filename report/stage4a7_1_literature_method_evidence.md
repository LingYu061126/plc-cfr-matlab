# Stage 4A.7.1 文献方法证据矩阵

## 1. 阅读范围与证据边界

本矩阵只把工作区中实际存在并通过 `pdftotext -layout` 阅读的 PDF 作为“已阅读原文”。未找到原始 PDF 的文献只记录题名、DOI/链接和“原文未在工作区找到”，不将搜索摘要或二手笔记作为公式证据。[代码静态核对]

当前工作区内实际阅读的补充论文包括：

- *Power Line Communications for Low-Voltage Power Grid Tomography*，Ahmed and Lampe，IEEE Transactions on Communications, 2013，PDF 13 页，工作区文件 `060904工作集/Power_Line_Communications_for_Low-Voltage_Power_Grid_Tomography.pdf`。
- *Power Grid Topology Inference Using Power Line Communications*，Lampe and Ahmed，IEEE SmartGridComm, 2013，PDF 6 页，工作区文件 `060904工作集/Power_grid_topology_inference_using_power_line_communications.pdf`。
- *Topology and Parameter Identification in Electrical Distribution Systems using Spatial Priors*，de Jongh et al., IEEE ISGT Europe, 2024，PDF 6 页，工作区文件 `Topology_and_Parameter_Identification_in_Electrical_Distribution_Systems_using_Spatial_Priors.pdf`。
- *Parametric and nonparametric methods for power line network topology inference*，PDF 6 页，工作区文件 `Parametric_and_nonparametric_methods_for_power_line_network_topology_inference.pdf`。
- *On the Exploitation of Admittance Measurements for Wired Network Topology Derivation*，PDF 9 页，工作区文件 `060904工作集/On_the_Exploitation_of_Admittance_Measurements_for_Wired_Network_Topology_Derivation.pdf`。
- *High-resolution and low-complexity dynamic topology estimation for PLC networks assisted by impulsive noise source detection*，Zhang et al., IET Communications, 2016，PDF 9 页，工作区文件 `060904工作集/IET Communications - 2016 - Zhang - High‐resolution and low‐complexity dynamic topology estimation for PLC networks.pdf`。

以下用户指定原文在本次递归扫描中未找到 PDF，故未宣称已阅读：Erseghe–Tomasin–Vigato (2013)；Deka–Kekatos–Cavraro tutorial；Cavraro et al. limited-monitoring；Gabow–Myers；Angelopoulos et al.；Fisch et al.。[待核对]

## 2. 方法矩阵

| 文献 | 原始输入 | 候选如何产生 | 判定统计量 | 理论条件 | 可移植部分 | 不可直接移植部分 | 页码/公式/算法 |
|---|---|---|---|---|---|---|---|
| Ahmed & Lampe, 2013 | 多个 PLC 节点之间的端到端 PLC 测距/ToA | 假定 PLC 节点形成树；由叶节点和分支节点的成对距离做 tomography | 距离矩阵满足树加性；RNJA 重构树 | 节点部署在边缘/负载位置；有成对测距；树结构；时钟/ToA 误差受控 | 说明观测配置决定可恢复拓扑；把“候选库外/不可观测”与分类器错误分开 | 当前只有单 TX–RX CFR，没有所有节点的成对距离，也没有该文的两向测距协议 | PDF pp.2–3 系统模型；p.3 式(1)–(5)；p.4–5 传播模型与 ToA；p.7–8 RNJA/测距条件；结论 p.13。[论文明确陈述] |
| Lampe & Ahmed, 2013 | 所有叶节点 PLC modem 的成对距离，另有根节点 | rooted neighbor-joining algorithm；逐步合并具有共同父节点的叶节点 | `q_ij = 1/2(d_si+d_sj-d_ij)`，选择最大者并迭代 | 成对叶节点距离可用；二叉树模型；测距误差小于最短边长的一半时有正确恢复条件 | 建立路线 C capability gate；支持“缺少 pairwise matrix 则 not_applicable” | 不能把单端口 CFR 的 IFFT 峰直接当作该距离矩阵，也不能声称 RNJA 已在本项目复现 | PDF p.4 图/式(2)和 RNJA Algorithm 1；p.4–5 关于二叉树和误差条件。[论文明确陈述] |
| de Jongh et al., 2024 | µPMU/NPMU 电压、电流/功率测量与 GIS 位置 | 允许边集合 `E_prior`；可能来自已知开关状态或 Delaunay triangulation，再在先验边集合上做 MIQP | 电力流近似模型残差 + 二进制拓扑变量 + 参数边界 | `E_true ⊆ E_prior`；先验边数显著少于完全图；径向/连通约束和参数物理范围 | 直接支持工程候选层、prior hash、候选覆盖审计和“错误先验排除真值”的独立标签 | 当前没有 GIS/现场 µPMU/NPMU；其 MIQP 不是当前 SISO CFR 的直接算法 | PDF p.1 摘要；p.2–3 “Spatial Prior Information”；式(1)、(5)、(7)–(19)；表 I/II/III。[论文明确陈述] |
| Parametric and nonparametric methods, 2012 | 单点 FDR 反射测量或离散 `H(f)` | 反射点路径参数化；FDR/IFT 或 Prony/SVD-子空间参数估计 | 式(3) 多径传播和反射系数；式(10)–(15) 频域指数模型 | 单点测量、反射路径模型、频率响应模型；非参数分辨率受带宽限制 | 支持当前 CFR 是模型匹配观测，不等于完整拓扑恢复；支持带宽/频率采样影响 | 其 FDR 单点反射路径不能替代多节点 pairwise distance；也不是本项目的拓扑确认器 | PDF pp.1–2 式(1)–(9)；pp.2–3 式(10)–(15)；pp.3–4 Prony/SVD 方法。[论文明确陈述] |
| On admittance measurements, 2016 | 线网输入导纳/阻抗测量 | 从节点导纳/测量方程和候选连接推导网络拓扑 | TLS/残差类拓扑评分 | 需要导纳测量、网络节点定义及参数模型 | 作为“需要改变观测维度”的证据；说明输入阻抗/导纳可能补充 SISO CFR | 当前主实验没有独立输入导纳通道，不能将其结果并入 CFR 拓扑识别准确率 | PDF 的网络模型、拓扑推导和实验章节；具体页码随版本需复核。[论文明确陈述/待核对] |
| Zhang et al., 2016 | 单 modem 的 TFDR/反射信号、动态脉冲噪声辅助信息 | 先估计路径长度，再按节点逐步 greedy 构造拓扑 | 反射峰/路径长度一致性；动态变化由脉冲噪声触发 | 有反射可见性、节点/路径结构假设和时频处理条件 | 支持候选生成与确认应区分；可作为未来单点反射测量路线 | 当前复数 CFR 正向模型没有 TFDR 专用反射测量，也不应把其 greedy 输出写成当前结果 | PDF p.1 摘要；p.2 TFDR 模型；p.4–5 node-by-node greedy algorithm；实验章节。[论文明确陈述] |
| Erseghe et al., 2013 | 指定 PLC 节点之间的传播时间观测 | 用户指定原文未找到 | 用户指定为 GLRT/假设检验 | 原文未核对 | 只保留为待核对的理论对照 | 不得把未读论文的 GLRT 细节写成已复现算法 | 原文未在工作区找到；DOI/公式位置待核对。[待核对] |
| Deka et al., 2024 tutorial | 配电网拓扑量测/图结构方法综述 | 用户指定原文未找到 | 综述性比较 | 原文未核对 | 仅作为后续综述核对入口 | 不作为本阶段的直接公式证据 | 原文未在工作区找到；DOI/页码待核对。[待核对] |
| Cavraro et al., 2020 | 有限监测节点的电压/功率等配电网量测 | 用户指定原文未找到 | observable islands/有限监测可辨识性 | 原文未核对 | 研究上保留“唯一判定依赖观测配置”的原则 | 不把其 observable-island 结论直接套到单端口 CFR | 原文未在工作区找到；页码待核对。[待核对] |
| Gabow & Myers, 1978 | 有向/无向图边集合 | 用户指定原文未找到 | all spanning trees 输出敏感枚举 | 原文未核对 | 本阶段路线 A 采用“边增量 + 剪枝 + 确定性输出”的同类思想 | 不声称已复现其具体复杂度定理或代码 | 原文未在工作区找到；DOI/算法位置待核对。[待核对] |
| Angelopoulos et al., 2021 | 校准集非相容度分数 | 用户指定原文未找到 | conformal prediction set/p-value/coverage | 原文未核对 | 本阶段只实现经验候选集接口，并保留交换性和候选库覆盖条件 | 不宣称 distribution-free 现场保证 | 原文未在工作区找到；页码/定理待核对。[待核对] |
| Fisch et al., 2022 | 多标签候选集合 | 用户指定原文未找到 | coverage 与 false positives 权衡 | 原文未核对 | 作为 set-size/coverage 权衡的后续参考 | 不直接移植其多标签学习假设到物理 CFR 候选库 | 原文未在工作区找到；页码/定理待核对。[待核对] |

## 3. 对当前 Stage 4A.7.1 的直接约束

1. 工程候选生成只能表示“先验允许的候选空间”；它不能证明真实网络属于该空间。[论文明确陈述/模型推断]
2. Ahmed/Lampe 路线要求多 PLC 节点和成对距离。当前单端口 CFR 只能进入模型匹配路线，路线 C 返回 `not_applicable`。[论文明确陈述]
3. `d_1`、margin 和 ratio 只能排序或形成确认证据；没有独立噪声模型时称为 residual/weighted residual，不称为严格 likelihood。[模型推断]
4. candidate set 的 empirical p-value 需要独立 calibration；每类样本少时最小可达到 p-value 为 `1/(n_G+1)`，不能宣称稳定 coverage。[模型推断]
5. nominal equivalence、same-theta physical equivalence 和 calibrated indistinguishability 必须分别存储。[代码静态核对]

