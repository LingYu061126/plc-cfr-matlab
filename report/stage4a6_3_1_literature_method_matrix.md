# Stage 4A.6.3.1 文献方法—候选确认协议映射矩阵

## 1. 资料范围与读取方法

本矩阵用于 Stage 4A.6.3.1 的方法核验。资料范围包括当前仓库既有文献目录，以及工作区中可定位到的 PLC 拓扑推断、配电网拓扑识别、开放集拒绝和选择性预测原始论文。已读取的 PDF 均先使用 `pdftotext -layout` 提取正文，再按章节、公式、算法、表格和图注定位；本轮未对公式图像逐页 OCR，PDF 文本层异常或版式造成的细节仍标记为待核对。

工作区没有找到 W. J. Scheirer 等人的 *Toward Open Set Recognition* 原文，因此只将其列为待获取资料，不把搜索摘要或二手转述作为已阅读证据。

证据等级采用：`[论文明确陈述]`、`[代码静态核对]`、`[本次运行]`、`[模型推断]`、`[待验证]`、`[本次未运行]`。

## 2. 文献—方法—代码矩阵

| 文献 | 研究任务与观测 | 先验与候选生成 | 原始评分/确认标准及位置 | 等价性或不可辨识处理 | 对本项目拟采用方式 | 不采用部分与原因 | 精确位置与证据 |
|---|---|---|---|---|---|---|---|
| Deka, Kekatos, Cavraro, *Learning Distribution Grid Topologies: A Tutorial* | 配电网拓扑识别与检测综述；讨论电压、功率、导纳、网络模型等多类观测。 | 径向树、节点/边集合、线路基础设施是否已知、完整或部分量测等假设决定候选空间。 | 综述最大似然、MAP、优化和可观测性等路线；不能由最小残差自动推出真实图。PDF pp.1–4、拓扑识别/检测章节。 | 强调可观测区域、部分监测和拓扑检测与完整识别的区别。 | 用于统一“候选库覆盖—观测可辨识—拒判”的概念边界。 | 不把综述中的电压/导纳/全网方法当作当前单端口 CFR 已实现功能。 | `[论文明确陈述]`；PDF pp.1–4及后续方法分类，页码以 PDF 版式为准。 |
| de Jongh et al., *Topology and Parameter Identification in Electrical Distribution Systems using Spatial Priors* | 配电网拓扑和参数联合识别；使用空间先验与 NPMU/μPMU 电气量。 | GIS/空间候选边、Delaunay 等生成 `E_prior`，并以 `E_true ⊆ E_prior`、开关/连通等约束缩小组合空间。 | MIQP/约束优化，目标和边变量、参数边界在 PDF pp.2–4 给出；空间先验不是观测本身。 | 通过先验减少不可行边，仍依赖量测和参数约束，先验错误会排除真值。 | 采用“工程先验→可行图集合”的接口语义，保留 `synthetic_demo_prior_not_field_data`。 | 当前没有 GIS、NPMU、全节点电压或真实开关状态，不能直接迁移 MIQP 观测模型。 | `[论文明确陈述]`；PDF p.1 摘要/引言，pp.2–4 空间先验与优化。 |
| Cavraro et al., *Real-Time Identifiability of Power Distribution Network Topologies With Limited Monitoring* | 有限监测下的拓扑可辨识性；电压二阶统计量及可观测 island graph。 | 测量节点布置和网络图决定可观测区域，不是任意优化器都能弥补的条件。 | 以可辨识性/可观测岛为核心，而非单一最近邻残差；Definition 1 及相关条件在 PDF p.4 附近。 | 明确有限监测可能只识别可观测子图，测量布置决定等价与不可辨识。 | 用于要求当前 SISO 输出等价类，并把观测配置作为候选确认前提。 | 当前没有多节点电压二阶统计量，不能声称复现其可辨识性定理。 | `[论文明确陈述]`；PDF pp.3–6，Definition 1 和结论。 |
| Ahmed, Lampe, *Power Line Communications for Low-Voltage Power Grid Tomography* | PLC 两向测距和低压配电网树重构；观测为端到端传播距离/ToA 类量测。 | 假设树结构，利用 PLC 节点间测距构造距离矩阵，再进行 rooted neighbor-joining。 | 传播/距离误差下的树重构算法及实验，PDF pp.2–10；确认标准是距离一致性与重构树。 | 需要多节点距离；测距误差会改变树重构，不能由单端口 CFR 唯一替代。 | 作为“直接拓扑重构”路线的对照，说明多 PLC 节点/测距与当前候选库路线不同。 | 当前只有单发送端—单接收端 CFR，没有全节点两向距离矩阵。 | `[论文明确陈述]`；PDF pp.2–5 模型与测距，pp.6–10 算法/实验。 |
| Passerini, Tonello, *On the Exploitation of Admittance Measurements for Wired Network Topology Derivation* | 有线网络拓扑导出；观测为多节点导纳/阻抗量测。 | 需要所有或多节点端口导纳、节点和支路模型；通过 carry-back 逐层消元。 | 线路传输线变换、导纳误差与阈值函数；算法在 PDF pp.3–5。正式 DOI 为 `10.1109/TIM.2016.2636478`。 | 依赖多节点导纳和阈值，拓扑可由量测矩阵结构推断；与单端口 CFR 不同。 | 借鉴“物理模型残差 + 观测条件”而非肉眼曲线相似；提醒将观测缺失写入限制。 | 不把节点导纳、KCL/TLS 判据移植到当前 SISO CFR。 | `[论文明确陈述]`；PDF pp.1–5，DOI 已按原始出版信息核对。 |
| Passerini, Tonello, *Power Line Network Topology Identification Using Admittance Measurements and Total Least Squares Estimation* | 多节点导纳测量下的拓扑识别与支路参数估计。 | 以网络节点/支路和导纳观测建立候选/估计问题。 | TLS/导纳残差、误差阈值和算法流程在 ICC 2017 PDF pp.1–4；IEEE 文献号核对为 `7996943`，旧记录中的 `7997262` 不作为当前结论。 | 通过全局导纳一致性与噪声鲁棒估计处理误差，不等同于 SISO CFR。 | 作为“全节点导纳/TLS 不可直接移植”的证据。 | 当前缺少全节点导纳矩阵、TLS 原始输入与节点同步。 | `[论文明确陈述]`；PDF pp.1–4；元数据冲突按“旧记录—原始来源核对—当前结论”保留。 |
| Cavraro, Kekatos, Veeramachaneni, *Voltage Analytics for Power Distribution Network Topology Verification* | 已有/待验证拓扑的电压分析与拓扑验证。 | 线路指示变量、网络物理约束、线路参数边界和先验可进入优化。 | PDF pp.3–5 给出约束优化，p.6 附近给出 MAP 形式；MAP 需要先验概率与观测噪声模型。 | 重点是验证候选/变化，而非无条件从单一端口重构完整树。 | 用于区分 distance matching、最大似然和 MAP；当前只实现冻结残差判据。 | 没有把 MAP 先验概率或电压观测虚构为当前 CFR 接口。 | `[论文明确陈述]`；PDF pp.3–6、pp.8–10 结果。 |
| Cavraro, Arghandeh et al., *Distribution Network Topology Detection with Time-Series Measurement Data Analysis* | 基于时间序列的拓扑变化检测；电压/功率趋势特征和基线变化。 | 需要历史基线、测量节点和已知/先前拓扑；不是任意未知树的单次识别。 | 趋势向量/签名库与 Algorithm 1，PDF pp.4–6。 | 输出变化检测/候选签名，依赖基线，不等于完整拓扑唯一确认。 | 借鉴“检测与确认分离”和独立基线的实验协议。 | 当前没有真实时序测量和基线，不把变化检测指标写成完整拓扑恢复。 | `[论文明确陈述]`；PDF pp.4–6，Algorithm 1。 |
| Ahmed, Lampe, *Power Line Network Topology Inference Using Frequency Domain Reflectometry* | PLC/FDR 反射测量和低压网络拓扑推断；观测为频域反射响应和时延/路径信息。 | 依赖反射前端、参考面和传播路径假设；候选路径由反射特征和网络结构形成。 | 频域反射到时域/路径解释及候选推断；PDF 章节与图表需结合版式复核。 | 反射峰和路径顺序提供额外信息，但对耦合、端接和分辨率敏感。 | 作为“未来绝对 ToF/FDR 观测”的边界参照。 | 当前模型不含真实反射前端、绝对 ToF 和参考面校准。 | `[论文明确陈述]`；工作区副本 `Power_line_network_topology_inference_using_Frequency_Domain_Reflectometry.pdf`；页码以 PDF 为准。 |
| Lampe, Ahmed, *Power Grid Topology Inference Using Power Line Communications* | 利用 PLC 测距进行树拓扑推断；输出树和边距离。 | 需要多个 PLC 节点、端到端距离和树假设，使用 rooted neighbor-joining。 | 算法流程和距离矩阵在 PDF p.4 附近，实验在后续章节。 | 树结构和测距误差决定重构；不是单端口 CFR 的模板分类。 | 作为路线 B 的另一原始证据，明确“多节点测距 vs 受限候选库”。 | 当前不具备多节点测距输入。 | `[论文明确陈述]`；工作区副本 `Power_grid_topology_inference_using_power_line_communications.pdf`。 |
| Pagani, Zeddam, Ismail, *Path Identification in a Power-Line Network Based on Channel Transfer Function Measurements* | 通过 PLC 信道传递函数识别路径/链路。 | 依赖测量路径和网络布置假设；候选目标主要是路径而非完整任意树。 | CTF 特征与路径匹配，论文方法章节/实验图；全文已读取，具体页码需排版复核。 | 路径可辨识不等于完整树拓扑可辨识，测量端口和负载改变结果。 | 作为当前 CFR 距离匹配的近邻文献背景。 | 不把路径识别结论扩写为当前完整 7 图库的唯一恢复。 | `[论文明确陈述]`；工作区副本 `Path_Identification_in_a_Power-Line_Network_Based_on_Channel_Transfer_Function_Measurements (1).pdf`，页码待版式核对。 |
| Geifman, El-Yaniv, *SelectiveNet: A Deep Neural Network with an Integrated Reject Option* | 开放集/选择性预测；不是电力网拓扑物理模型。 | 训练集覆盖、选择函数和拒判区域由数据分布定义。 | selective risk 与 coverage 的定义及 Eq. (1)–(2)，PMLR PDF pp.1–3。 | 允许在覆盖率与选择性风险之间权衡，不把拒判样本当作错误接受。 | 只采用 coverage、selective risk 的指标语义，要求无条件和选择性指标并列。 | 不引入深度网络或把有限合成样本写成分布无关保证。 | `[论文明确陈述]`；PMLR PDF pp.1–3。 |
| Scheirer et al., *Toward Open Set Recognition* | 开放集识别与未知类拒绝。 | 原文需要独立获取。 | 未在当前工作区找到原文，本矩阵不转述公式或实验。 | 待原文获取。 | 仅列为待获取的开放集理论来源。 | 不使用搜索摘要作为证据。 | `[待验证]`；原文未在当前工作区找到。 |

## 3. 与当前 MATLAB 实现的对应关系

| 理论环节 | 当前对象 | Stage 4A.6.3.1 处理决定 |
|---|---|---|
| 先验约束候选图 | `generate_radial_topology_candidates.m`、`generate_prior_constrained_candidates.m` | 保留 7 图受限径向生成器；先验标记为 `synthetic_demo_prior_not_field_data`。 |
| 图—参数复合库 | Stage 4A.5.1 cache、`score_stage4a5_observation.m` | 只使用经过身份校验的候选模板缓存；科学 hash 与运行路径分离。 |
| 候选排序 | `score_stage4a5_observation.m` | 使用最佳距离、异类间隔、类等价成员、子带和稳定性；不把最小距离单独称为确认。 |
| 候选确认 | `apply_stage4a5_confirmation.m` | 新阶段入口必须复用该冻结路径；Stage 4A.6.3 的局部 `match_nominal()` 不能作为正式确认器。 |
| 参数 profile | `compute_stage4a6_2_member_evidence.m`、`compute_stage4a6_2_parameter_profile.m` | 称为 constrained residual profile；只有确认器接受后，对 accepted set 的每个成员分别执行。 |
| 参数聚合 | 新阶段 member adapter/aggregator | 所有成员一致才输出确定参数域状态；缺失或冲突则 `parameter_domain_indeterminate`。 |
| 选择性评价 | 新阶段 metrics | 同时报告 unconditional metrics、coverage、selective risk 和独立 physical scenario 分母。 |

## 4. 客观确认标准的统一解释

当前模型中可写为：

$$
d_G=\min_{\theta\in\Theta_G}D\left[z(\hat H),z\left(H_O(G,\theta)\right)\right],
$$

$$
d_1=\min_Gd_G,\qquad
\Delta=d_2-d_1,
$$

并可定义距离比为：

$$
\rho=\frac{d_2}{d_1+\varepsilon}.
$$

这里的 `d1` 只能提供候选排序；`Delta`、`rho`、子带一致性、稳定性、候选等价类和校准残差门限共同构成确认输入。当前代码实际以复 CFR 距离、类间隔和 Stage 4A.5.1 的多尺度/稳定性规则为主，并未定义带噪声协方差的

$$
p(\hat H\mid G,\theta,\Sigma_N).
$$

因此 Stage 4A.6.3.1 使用“残差 profile”或“constrained residual profile”，不把它命名为严格的 profile likelihood，也不把残差阈值写成现场置信度。

最大似然需要明确噪声分布和协方差；MAP 还需要先验概率 `p(G)` 及其标定；distance matching 只是在给定候选库、特征和权重下的模型匹配。三者不能互换。

## 5. 对本阶段设计的直接约束

1. **候选生成路线 A**：工程资产/空间先验给出允许边和约束，再生成可行径向图；当前只实现小规模合成接口，不声称接入 GIS 或台账。
2. **候选生成路线 B**：PLC 多节点测距、导纳矩阵、recursive grouping 或最小生成树属于直接重构路线，需要当前 SISO CFR 不具备的观测，因此只作为文献对照。
3. **确认器身份**：新阶段必须保存 `confirmation_method_id`、`calibration_hash`、候选缓存身份和兼容性 hash；缺失或不匹配时停止，而不是退回名义最近邻。
4. **等价类成员**：如果输出 `{G002,G005}` 或 `{G004,G007}`，每个成员都要执行参数 profile；成员结论冲突时只能输出不确定。
5. **独立样本**：不同 replicate 必须改变物理参数和 CFR；仅改变 solver seed 不构成独立物理样本。
6. **选择性统计**：低 selective risk 必须与 coverage 同时报告；重复的相同 CFR 不能扩大 Wilson 区间的有效分母。

## 6. 元数据核对记录

- `On the Exploitation of Admittance Measurements for Wired Network Topology Derivation`：当前结论采用正式 DOI `10.1109/TIM.2016.2636478`。[论文明确陈述]
- `Power Line Network Topology Identification Using Admittance Measurements and Total Least Squares Estimation`：当前结论采用 IEEE 文献号 `7996943`；仓库旧记录中的 `7997262` 保留为历史冲突说明，不作为新阶段元数据。[待验证/代码静态核对]
- `Toward Open Set Recognition`：原文未在当前工作区找到，未读取其公式和实验。[待验证]

本矩阵是方法核验产物，不改变既有阶段结果、旧报告或历史运行文件。
