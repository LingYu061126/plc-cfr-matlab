# Stage 4A.6.3.1-R 文献方法矩阵

## 阅读范围与方法

工作目录中实际找到并使用 `pdftotext -layout` 阅读了以下原始 PDF 的正文、摘要、方法段、算法/公式及实验段：Ahmed & Lampe 的低压 PLC tomography；Lampe & Ahmed 的 PLC topology inference；Passerini & Tonello 的导纳拓扑推导与 TLS 版本；de Jongh 等的 spatial priors；Cavraro 等的 topology verification；Cavraro 等的 time-series topology detection；Pagani/Zeddam/Ismail 的 CTF path identification；Geifman & El-Yaniv 的 SelectiveNet；以及工作区中关于阻抗、PLC channel estimation、OFDM channel estimation 和 topology change detection 的若干原始论文。PDF 页码以下按 PDF 页面计，版式或扫描/OCR造成的不确定位置标为“待核对”。[论文明确陈述]

本阶段直接用于矩阵的代表性 PDF 文件包括：

* `060904工作集/Power_Line_Communications_for_Low-Voltage_Power_Grid_Tomography.pdf`
* `060904工作集/Power_grid_topology_inference_using_power_line_communications.pdf`
* `060904工作集/On_the_Exploitation_of_Admittance_Measurements_for_Wired_Network_Topology_Derivation.pdf`
* `060904工作集/Power_line_network_topology_identification_using_admittance_measurements_and_total_least_squares_estimation (1).pdf`
* `Topology_and_Parameter_Identification_in_Electrical_Distribution_Systems_using_Spatial_Priors.pdf`
* `1707.06671v1.pdf`
* `1504.05926v1.pdf`
* `060904工作集/Path_Identification_in_a_Power-Line_Network_Based_on_Channel_Transfer_Function_Measurements.pdf`
* `geifman19a.pdf`
* `060904工作集/Power_line_network_topology_inference_using_Frequency_Domain_Reflectometry.pdf`

以下英文原文在当前工作区未找到，因此没有把它们写成“已完整阅读”：Deka/Kekatos/Cavraro *Learning Distribution Grid Topologies: A Tutorial*；Cavraro *Real-Time Identifiability...*；Scheirer *Toward Open Set Recognition*。仓库已有的索引和摘要只作为待核对线索。[待核对]

## 文献—方法—代码矩阵

| 文献身份 | 研究任务与输入 | 候选集合/生成约束 | 匹配或判定统计量 | 阈值/拒识/等价处理 | 对当前代码的采用 | 位置与证据 |
|---|---|---|---|---|---|---|
| M. O. Ahmed, L. Lampe, *Power Line Communications for Low-Voltage Power Grid Tomography*, IEEE TCOM, 2013, DOI 10.1109/TCOMM.2013.111613.130238 | PLC 多节点端点通信，利用 ranging 与端到端测量推断电网连接和长度；摘要、Introduction 和系统模型在 PDF pp.5163–5165。 | 假定部署于网络边缘的 PLC 节点及树形电网；由节点对距离构造树估计问题，而不是固定 CFR 模板枚举。 | ToA/超分辨测距和 tomography；后续 rooted neighbor-joining 类树估计。 | 依赖测距误差和部署条件；输出树结构，不是单端 SISO CFR 的等价类判定。 | 采用“直接重构路线需要多节点测距”的边界；不把它移植成当前匹配器。 | PDF pp.5163–5165，方法和实验章节；[论文明确陈述] |
| L. Lampe, M. O. Ahmed, *Power Grid Topology Inference Using Power Line Communications*, SmartGridComm 2013, DOI 10.1109/SmartGridComm.2013.6687980 | 端点 PLC signaling、time-of-flight 和多节点距离矩阵。 | 已部署 PLC modem 的节点集合、树假设和端到端距离。 | 距离矩阵到 rooted tree estimation。 | 多节点和时钟/ToF 条件是必要前提。 | 作为候选生成路线 B 对照；当前只有一对端口，不能声称实现。 | PDF p.1 的模型/问题定义及算法段；[论文明确陈述] |
| F. Passerini, A. M. Tonello, *On the Exploitation of Admittance Measurements for Wired Network Topology Derivation*, IEEE TIM, 2017, DOI 10.1109/TIM.2016.2636478 | 多节点导纳测量；PDF p.1 摘要明确给出 plug-and-play 和 all PLC modems。 | 由节点集合、传输线 carry-back 关系和多节点导纳推导连接；不是小型固定图库。 | 导纳解析关系、传输线方程和噪声下估计；PDF pp.2–5。 | 依赖节点导纳，噪声与可观测距离限制结果；未用当前 SISO CFR。 | 借鉴物理模型和观测条件必须同时写明；不移植导纳/TLS判据。 | PDF pp.1–5，传输线导纳与算法章节；[论文明确陈述] |
| F. Passerini, A. M. Tonello, *Power Line Network Topology Identification Using Admittance Measurements and Total Least Squares Estimation*, ICC 2017, IEEE 文献号 7996943 | 单频或多频/多时刻节点导纳，TLS 融合误差。 | 节点—链路图与所有节点测量。 | TLS regression、carry-back 方程和 topology algorithm；PDF pp.1–4。 | 噪声降低依赖重复测量融合，不是当前无噪声模板距离。 | 只作为“误差模型会改变确认标准”的证据。 | PDF pp.1–4；文献号核对为 7996943，旧索引冲突单独保留；[论文明确陈述] |
| S. de Jongh et al., *Topology and Parameter Identification in Electrical Distribution Systems using Spatial Priors*, ISGT Europe 2024, DOI 10.1109/ISGTEUROPE62998.2024.10863283 | 配电网拓扑和参数联合识别；空间先验和电气量测。 | GIS/空间候选边、开关和参数边界缩小可行组合；PDF pp.1–4。 | 约束优化/MIQP 形式，先验定义候选边而非替代观测。 | 硬先验错误会排除真值；需要空间和电气量测。 | 采用 `synthetic_demo_prior_not_field_data` 的接口语义；不声称真实 GIS 接入。 | PDF pp.1–4；[论文明确陈述] |
| G. Cavraro, V. Kekatos, *Voltage Analytics for Power Distribution Network Topology Verification*, IEEE TSG, 2018, DOI 10.1109/TSG.2017.2743153 | 电压时间序列/统计量，验证已知或候选拓扑。 | 径向树、线路参数边界、测量节点和物理约束；PDF Definition 1 与模型章节。 | least-squares/MAP/拓扑验证目标；PDF pp.2–6、式(12)–(20)附近。 | MAP 需先验概率和统计模型；验证不等于单次完整恢复。 | 用于区分 distance matching、ML 与 MAP；当前只报告校准残差判据。 | PDF pp.2–6、公式(12)–(20)；[论文明确陈述] |
| G. Cavraro et al., *Distribution Network Topology Detection with Time-Series Measurement Data Analysis*, arXiv:1504.05926 | 拓扑变化检测；时间序列电压/状态量和基线。 | 拓扑状态由开关向量描述；从模拟 topology signatures 建库。 | trend vector 投影、signature library 与 Algorithm 1/3；PDF pp.1–3、6–8。 | 明确指出有限测量下需要历史拓扑或额外信息；检测变化不等于恢复任意树。 | 采用“拓扑检测和候选确认分离”、独立 calibration/评价。 | PDF pp.1–3、6–8；[论文明确陈述] |
| F. Pagani, A. Zeddam, A. Ismail, *Path Identification in a Power-Line Network Based on Channel Transfer Function Measurements*, 2012, DOI 10.1109/ICC.2012.6363874 | CTF/CFR 路径识别，目标偏向路径/多径而非任意完整树。 | 由线路路径、反射和传播模型构造可行解释。 | CTF/CIR 路径特征和匹配追踪；PDF 方法和实验章节，页码以版式复核为准。 | 路径识别需要端口、带宽、反射和同步条件；不能外推完整树唯一性。 | 作为当前 CFR 距离匹配的近邻背景；保留 SISO 等价类。 | 工作区 PDF，方法/实验段；[论文明确陈述] |
| Y. Geifman, R. El-Yaniv, *SelectiveNet: A Deep Neural Network with an Integrated Reject Option*, PMLR 2019 | 选择性预测，不是电力网物理模型。 | 由训练分布、选择函数和 coverage 约束形成接受域。 | selective risk 与 coverage，PDF pp.1–3，式(1)–(4)。 | 明确把拒判样本从接受覆盖中分开；输出 risk–coverage 曲线。 | 只采用 coverage/selective risk 的评价语义，不引入神经网络。 | PDF pp.1–3；[论文明确陈述] |
| *Power line network topology inference using Frequency Domain Reflectometry* | FDR 反射测量、传播路径和拓扑推断。 | 参考面、反射路径、候选网络和传播速度假设。 | 频域反射到时域/路径峰和结构解释。 | 需要真实反射前端、端接和绝对 ToF 标定。 | 作为未来额外观测路线；当前没有 FDR/绝对 ToF。 | 工作区 PDF；章节/公式位置待版式复核；[待核对] |

## 影响本阶段的设计决定

1. 候选库采用“工程先验约束的受限径向枚举”路线；真实 GIS、台账、开关状态在代码中仍未接入。[代码静态核对]
2. 接受判定不能只用最小距离；Stage 4A.5.1 的残差、间隔、子带/邻域/块稳定性必须通过冻结 adapter 复用。[代码静态核对]
3. 选择性评价同时保存无条件指标、coverage 和 selective risk；拒判/不可判定样本留在分母。[论文明确陈述][代码静态核对]
4. 当前 profile 是 constrained residual profile，不是带噪声协方差的 profile likelihood；缺少 `p(\hat H|G,\theta,\Sigma_N)` 时不得使用 likelihood ratio 的表述。[代码静态核对][模型推断]
5. 多节点测距、导纳/TLS、全节点电压和 FDR 是补充观测方法，不是当前单端口复 CFR 已实现内容。[论文明确陈述][模型推断]
