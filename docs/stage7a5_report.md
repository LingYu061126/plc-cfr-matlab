# Stage 7A.5 技术报告：按需候选扩展与客观确认

## 结论摘要

在本阶段预先固定的 10 图径向 grammar、20 dB 合成观测和所声明的参数范围内，通用的一支路增加/删除/移动搜索在四个留出库外图家族中均生成了真图（每图 30/30）。当观测为源端输入阻抗 `Zin50` 时，120 个库外测试样本中有 113 个正确唯一确认、7 个拒绝；联合使用 `H50+Zin50` 时为 120/120 正确唯一，0/120 错误唯一。单端 `H50` 没有正确唯一确认：114/120 的真图进入最终候选集合，但输出 81/120 多候选歧义、39/120 低置信。

这说明按需扩展在一个小型、预枚举的合成 grammar 中确实找回了原库不含的图；它没有证明可以对任意未知网络拒识或唯一反演。按预注册判据，本阶段不通过“可广泛推广的安全改进”门槛：固定库基线的错误唯一下降只发生在 MIRROR_M3/H50 这一家族，且 H50 的库内正确唯一从 62/90 降到 27/90；此外搜索空间只有 10 个预枚举图。因此保留该原型作为受限 grammar 下的条件性结果，优先验证更多未见拓扑家族和模型失配，而不扩大其适用性表述。

## 1. 仓库身份与冻结基线

- 阶段名称：仓库内未发现先前占用的 Stage 7A.5 名称；本轮协议将其固定为“按需候选扩展与客观确认”。
- 分支：`main`。
- 本轮代码/结果验证基线：`7412aade6c129f982f1ebb766299166ccbae2515`。正式运行期间工作树含有仅属于 Stage 7A.5 的新文件；该提交号是运行基线，不是新增代码的归档提交号。
- Stage 4A、5B.1、6A、6B、7A、7A.1–7A.4 的代码、配置和正式结果均保持只读；Stage 7A.4 两项 formal 结果完整性测试通过。

Stage 7A.4 原始 15 m 镜像对 CSV 的独立复核值为：原始三候选库、H50 连续参数剖面下库内正确唯一 `299/360`；`MIRROR_M3` 未在该三图库时错误唯一 `106/120`。来源是 [`stage7a4_15m_continuous/formal/summary.csv`](../results/data/stage7a_4_15m_continuous/formal/summary.csv)。这些是旧阶段结果；本阶段 A 使用新 seed 和新独立校准集，不能把其比例直接当成本轮 A/B/C 的同一测试样本对照。

### 观测、候选集合和状态定义

- `H50`：模型计算的 50 Ω 源/接收端之间端到端复数 CFR；不是反射测量。
- `Zin50`：模型计算的源端一端口输入阻抗；不是逐节点网络导纳。
- `H50_Zin50`：同一物理参数下两种模拟观测的联合评分。
- 库内真值候选覆盖：判决候选集合包含真拓扑的样本数 / 库内样本数。
- 库外扩展覆盖：真拓扑先被通用编辑生成，再分别记录它是否进入最终候选集合；生成、入集和正确唯一是三个不同事件。
- `false_unique` 的审计定义为：输出 `UNIQUE_CONFIDENT` 且最佳拓扑不等于评估真图。正确生成并选中一个原始库外真图是扩展成功，不会因为其“不在初始库”而同时算成 false unique。
- 非空候选集合与最终接受状态分开统计：集合可以非空但因拟合质量门而输出 `REJECTED`。

## 2. 本地论文原文核对与算法迁移边界

下表路径相对于仓库根目录；PDF 未复制到仓库。题名、作者和年份依据 PDF 首页核对，哈希按本地原始 PDF 字节计算。PDF 页码指文件页码；各论文的图号、式号作为定位补充。

|论文身份|本地 PDF 路径、页数与 SHA-256|原文观测与拓扑判据（PDF 定位）|本项目可借鉴及不可等同之处|
|---|---|---|---|
|Mohamed Osama Ahmed、Lutz Lampe，2012，*Power Line Network Topology Inference Using Frequency Domain Reflectometry*|`../060904工作集/Power_line_network_topology_inference_using_Frequency_Domain_Reflectometry.pdf`；5 页；`3bd48ba7b0a93e0bf6726cd16880b50fba7d82d0d22f8ad61e0b7fa02c9d6417`|用单点 FDR 得到随距离变化的反射相关峰，再以峰距离约束逐步扩展图；对扩展图合成 FDR 相关并检验与观测的一致性。PDF p.5 Fig. 7 显示候选集合逐层扩展，正文还限制峰/回波及最大扩展规模。|可借鉴“当前图不能解释观测时提出少量结构扩展、用前向模型复核”。本项目没有 FDR 反射峰或反射相关函数；`H50` 残差不能称作反射峰。论文的反射距离判据不是本项目的连续 CFR profile 距离。|
|同一 Ahmed–Lampe 2012 ICC 论文的另一份本地副本|`../2012-Topo-ICC.pdf`；5 页；`dc9203f52e955f1775bceff59192c410df99cfc2ccafdea7fc03ecb2e521a452`|首页题名、作者与年份相同；与上一文件内容版本/封面不同，按重复副本处理。|两份 PDF 均保留原位；本报告引用第一份的正文定位。|
|Michael Ulrich、Bin Yang，2015，*Inference of Wired Network Topology Using Multipoint Reflectometry*|`../1570099185.pdf`；5 页；`d80026cc65656a4af370e063510324cb31d44715028732302160d120ef34f569`|CoMaTeCh 使用多个电缆端点的反射范围/幅值：Connect 建立测量点间 core graph；Map 找当前图无法解释的反射；Test 枚举扩展；Choose 按模拟反射的代价选择扩展。PDF p.2 Table 1、pp.2–4 §3.3–3.6。局部支路近似假设相同特性阻抗，负载端常按开路/短路处理。|与本项目“解释不了观测时扩展结构”的动机相近；但其证据是多点反射测量及模拟反射响应，不能移植为端到端 CFR 的反射峰规则。其成本不是本项目的独立留频拟合门。|
|Mohamed O. Ahmed、Lutz Lampe，2013，*Power Line Communications for Low-Voltage Power Grid Tomography*|`../060904工作集/Power_Line_Communications_for_Low-Voltage_Power_Grid_Tomography.pdf`；13 页；`b3ca34c91fa18092a8f5f32c84534b269b22611198adcb93187aaa47f05b05`|在多个 PLC modem 节点间用 OFDM CFR 导出 ToA/路径距离，再以距离矩阵和 rooted-neighbor-joining 重建树。传输路径模型及 ToA 部分见 PDF pp.4–6，式 (8)–(15)；树反演后文给出。|说明 CFR 可用于构造距离量测，但需要多节点/多链路观测及 ToA 推导。本项目只用一个端到端传递 CFR，不执行多点 ToA 或 RNJA。|
|Federico Passerini、Andrea M. Tonello，2017，*On the Exploitation of Admittance Measurements for Wired Network Topology Derivation*|`../060904工作集/On_the_Exploitation_of_Admittance_Measurements_for_Wired_Network_Topology_Derivation.pdf`；9 页；`64d72522bcd7dc272980c3705b7c049c912a5d78a3e8dbc007b3d8a200886232`|在每个网络节点测复导纳，利用传输线关系从端点/相邻节点导纳推线长；Theorem 1 规定何时计算得到的线长对应直接相邻节点，PDF p.4；推导算法及 leaf-node 处理见 PDF pp.6–7 Algorithm 1 及相邻推导。要求线/负载参数已知，波长和线长受限。|可借鉴“物理一致的局部连接检验”，但本项目的 `Zin50` 是一个端口的输入阻抗，不是多节点导纳矩阵，也不具备论文的逐节点邻接判据。|
|Tomaso Erseghe、Stefano Tomasin，2012，*Plug and Play Topology Estimation via Powerline Communications for Smart Micro Grids*|`../Erseghe.pdf`；2 页；`191eade2b9f14275f27aef4f4065de8950582ffd2d41b789f8f34bed849d40d0`|节点间由 PLC 双向握手估计 TOF；对三节点检验 `τ_AB` 与 `τ_AC+τ_CB` 的关系，以 GLRT/近似 GLRT 判断节点是否在最短路径上。PDF pp.1–2，式 (1)–(7)。|判据展示了多假设比较与测量误差建模；本项目没有节点间握手或 TOF，也不把 CFR 频点直接当作该论文的距离量测。|
|Chao Zhang、Xu Zhu、Yi Huang、Gan Liu，2015，*High-Resolution and Low-Complexity Topology Estimation for Power Line Communication Networks*|`../High-resolution_and_low-complexity_topology_estimation_for_power_line_communication_networks.pdf`；6 页；`b2266290604b5122df1a9f2952d27ca2c45707bbc5c84ff588ff3f0912a4c08d`|TFDR 估计反射路径长度，再用 node-by-node greedy 搜索连接结构；PDF pp.3–4，式 (6)–(13)、Fig. 3。|可借鉴有预算的逐步结构扩展；本项目没有实现 TFDR、路径长度峰或论文的贪心距离约束。|
|Chao Zhang、Xu Zhu、Yi Huang、Gan Liu，2016，*High-resolution and low-complexity dynamic topology estimation for PLC networks assisted by impulsive noise source detection*|`../060904工作集/IET Communications - 2016 - Zhang - High‐resolution and low-complexity dynamic topology estimation for PLC networks.pdf`；9 页；`a66f9705de205380731265b4d60babbae63bc0e4cf4072f2bcd0684631b24288`。副本 `...(1).pdf` 哈希相同。|使用单端 TFDR 路径长度与脉冲噪声源检测辅助动态拓扑更新；路径长度估计式及 node-by-node 图更新见 PDF pp.3–5。|仅借鉴“未解释路径触发图更新”的结构；本项目未生成脉冲噪声定位或反射响应。|
|Federico Passerini、Andrea M. Tonello，2017，*Power Line Network Topology Identification Using Admittance Measurements and Total Least Squares Estimation*（ICC 会议版本）|`../Power_line_network_topology_identification_using_admittance_measurements_and_total_least_squares_estimation.pdf`；6 页；`e41bd1e5e66206695cbf0488e1a8c30bde2768a231b753c4d51c488dc492026e`。相同哈希副本还在 `../060904工作集/Power_line_network_topology_identification_using_admittance_measurements_and_total_least_squares_estimation (1).pdf` 与 `../english_P09-P16/Power_line_network_topology_identification_using_admittance_measurements_and_total_least_squares_estimation.pdf`。|每个节点测网络导纳，再由传输线方程和 total least squares 融合重复时间/频率观测估计相邻关系/距离矩阵；PDF pp.1–6。|属于节点导纳测量的会议版本，与本阶段 `Zin50` 单端口输入阻抗仍不同；不是本阶段实现的估计器。|

本阶段真正迁移的只有有限图编辑与前向模型复核这一一般思想。拟合观测始终是模型内 CFR/Zin 向量，拟合/检验统计量是按噪声尺度归一化的复向量残差；没有任何反射峰、FDR 距离、TOF 估计或逐节点导纳结果被伪称为本项目观测。

## 3. 固定问题与方法

初始库固定为 `{G001,G002,G003}`，拓扑签名和额外图族见 [`topology_inventory.csv`](../results/data/stage7a_5/formal_v2/topology_inventory.csv)。主线 TX–RX 为 4 段、每段 20 m；支路只能接在 M1/M2/M3，长度 15 m、负载名义值 50 Ω，最多两条一层支路。有限 grammar 共 10 个连通无环图；它不包含嵌套支路、环路、任意线长/电缆型式/负载变化。

### A/B/C 三条流程

- **A：固定库 + Stage 7A.4 连续 profile 规则。** 61 个频点全部评分；只校准固定三图库。
- **B：固定库 + 独立留频拟合质量门。** 预先固定 41 个训练频点（索引模 3 非 0）与 20 个留出频点（索引模 3 为 0）；仅用训练频点拟合和排序，留频残差只检验训练最佳图，不重拟合、不改排名。留频按一条 20 维样本向量汇总；相邻频点不被视为独立统计样本。
- **C：按需启用图编辑 + 与 B 相同确认逻辑。** 从初始三图按 Top-K=2、最多两轮编辑和总候选上限 7 或 10 扩展；图编辑限一条支路增加、删除或连接点移动。候选先做物理约束验证、以网络结构 signature 去重，再用 profile 与留出门确认。

需要准确限定“按需”：本实现事先枚举了 grammar 中的 10 张图，并为所有图缓存 45 个粗网格 nuisance 参数点的 H50/Zin50 正向模板；运行时按观测启用和 profile 候选，而不是在全新无限图空间里无中生有地搜索。真值图 ID 和生成参数只存在于实验生成/结果审计层，评分/判决函数不接收这些字段。

profile 距离按所选观测视图和训练频点计算：

\[
d_i=\min_{\theta\in\Theta}\sqrt{\frac{1}{|V|}\sum_{v\in V}
\left(\frac{\operatorname{RMS}_{k\in K_{train}}
\{y_v[k]-\widehat H_v(G_i,\theta)[k]\}}{\sigma_v}\right)^2}.
\]

搜索只剖面拟合主线长度尺度 `[0.9,1.1]` 和支路负载尺度 `[0.8,1.2]`；支路长度尺度固定为 1。由 45 点网格取粗最优点，再在其相邻主线尺度区间与完整负载尺度区间执行三次一维 `fminbnd`。这是局部粗到细搜索，不是全局最小值证明。

### 独立校准与四状态

`E` 估计模拟噪声尺度；`A` 校准候选集合；独立 `F` 校准 B/C 留频质量门；`D` 只从预算 `{7,10}` 中选择；最终 `T` 从未反馈进校准、拟合边界、方法选择或阈值。

- A 使用每类经验 profile 距离阈值和 F 拟合门。
- B/C 使用 A 上 `d_i-min_j(d_j)` 的独立集合校准，并使用 F 上训练选中图的留频质量校准。
- 唯一 margin 阈值固定为 3；任何校准阈值未依据 formal T 回调。
- `REJECTED`：拟合质量门失败或候选集合为空；`MULTIPLE_AMBIGUOUS`：通过拟合门但集合含多图；`LOW_CONFIDENCE`：集合为单例但 margin 不足，或搜索范围被截断；`UNIQUE_CONFIDENT`：拟合门、单例和 margin 均通过且搜索完整。

### 代码结构

|模块|实现文件|职责|
|---|---|---|
|配置、入口、实验|[`stage7a5_config.m`](../config/stage7a5_config.m)、[`run_stage7a5.m`](../run_stage7a5.m)、[`exp_stage7a5_candidate_extension.m`](../experiments/exp_stage7a5_candidate_extension.m)|冻结 smoke/formal 参数，生成独立 E/A/F/D/T，比较 A/B/C 并导出逐样本与汇总数据|
|grammar 与共享模板|[`stage7a5_candidate_pool.m`](../src/stage7a5_candidate_pool.m)、[`stage7a5_template_bank.m`](../src/stage7a5_template_bank.m)|生成/验证 10 张有限候选图、结构签名去重，并缓存 45 点 × 10 图的 H50/Zin50 正向模板|
|profile 与扩图|[`stage7a5_profile.m`](../src/stage7a5_profile.m)、[`stage7a5_graph_edit_neighbors.m`](../src/stage7a5_graph_edit_neighbors.m)、[`stage7a5_expand_candidates.m`](../src/stage7a5_expand_candidates.m)|按观测 profile 选择编辑父图、扩展图邻居，并记录活动图、生成项和预算截断|
|留频、校准、判决|[`stage7a5_holdout_stat.m`](../src/stage7a5_holdout_stat.m)、[`stage7a5_calibrate_legacy.m`](../src/stage7a5_calibrate_legacy.m)、[`stage7a5_calibrate_split.m`](../src/stage7a5_calibrate_split.m)、[`stage7a5_decide.m`](../src/stage7a5_decide.m)、[`stage7a5_score_observation.m`](../src/stage7a5_score_observation.m)|独立校准候选集合和质量门，并保留四状态；校准身份需与候选库及搜索域一致|
|测试、归档|[`test_stage7a5_candidate_extension.m`](../tests/test_stage7a5_candidate_extension.m)、[`test_stage7a5_result_integrity.m`](../tests/test_stage7a5_result_integrity.m)、[`stage7a5_write_manifests.m`](../src/stage7a5_write_manifests.m)|覆盖搜索身份/状态/正控制，并验证结果存在性及 SHA-256 manifest|

## 4. 正式数据划分与运行身份

|分区|结构/数量|种子基数|每图样本数|用途|
|---|---|---:|---:|---|
|E|初始库 3 图|101000000|20|噪声尺度，60 条|
|A/F|初始库 3 图|102000000 / 103000000|50|集合校准 150 条；拟合质量校准 150 条|
|D|初始库 + ADD_M1_M2、DOUBLE_M2，共 5 图|104000000|20|只选择候选预算，不进入 T|
|T 库内|G001/G002/G003，共 3 图|105000000|30|90 条/每流程、每观测|
|T 库外|MIRROR_M3、ADD_M1_M3、ADD_M2_M3、DOUBLE_M3，共 4 图|105000000|30|120 条/每流程、每观测；四个目标结构未进入 D|
|T 域外|G002/G003，主线尺度固定 1.15|155000000|30|60 条/流程/观测，仅测拒绝|
|非唯一控制|T3/T4_NEAR_T3/T5，共 3 图|109000000（独立 E/A/F 为 106/107/108M）|30|专用独立校准；T3/T5 镜像与 near-invisible close control|

观测为 2–30 MHz、61 个复数频点，20 dB 模型内 CFR SNR；每频点复 `Zin` 噪声 RMS 为 1 Ω。真主线尺度来自 `[0.98,1.02]`，支路负载尺度来自 `[0.8,1.2]`；域外集真主线尺度为 1.15。所有数值仅是模型研究设定，不代表 PLC 设备规格或现场容差。

正式 MATLAB 为 R2024a `24.1.0.2537033`，Linux `glnxa64`；不使用并行池。最终结果目录 [`results/data/stage7a_5/formal_v2/`](../results/data/stage7a_5/formal_v2/) 记录 config snapshot、基线 commit、模板/搜索身份、候选 signature、seed manifest、来源与 artifact SHA-256 manifest。正式日志见 [`results/logs/stage7a_5/`](../results/logs/stage7a_5/)。

正式运行的关键命令：

```matlab
test_stage7a5_candidate_extension(pwd)
out = run_stage7a5(pwd,'smoke')
test_stage7a5_result_integrity(pwd,'smoke')
out = run_stage7a5(pwd,'formal')
test_stage7a5_result_integrity(pwd,'formal')
test_stage7a4_result_integrity(pwd,'formal')
test_stage7a4_15m_result_integrity(pwd,'formal')
```

在本机沙箱内启动 MATLAB 曾触发 `client-v1` 初始化问题；最终 smoke/formal 使用专用 `MATLAB_PREFDIR` 和 `-nodisplay -nosplash -softwareopengl -batch` 在沙箱外隔离环境完成。第一份正式运行耗时 1,195.84 s；修正结果统计标签后，`formal_v2` 使用同一 seed/阈值再次完整运行，耗时 **1,194.66 s**。两次样本级决策、距离、候选排名、状态和控制结果逐项相同；仅 233 个“正确扩展后唯一”的样本标签由 false unique 更正为 correct unique。首份预备运行 `formal/` 保留在本地作为审计快照，不纳入公开归档；最终结论与公开数据只引用 `formal_v2/`。

## 5. 正式结果

所有置信区间均为逐样本 Wilson 95% 区间；每个正式拓扑有 30 次噪声/参数重复，同一拓扑重复不能视为独立拓扑结构。四个库外家族的结构等权结果另按逐家族计数报告。

### 库内正确唯一、集合覆盖和状态

|观测|流程|正确 `UNIQUE_CONFIDENT`|真值集合覆盖|平均集合大小|REJECTED / AMBIGUOUS / LOW_CONFIDENCE|
|---|---|---:|---:|---:|---:|
|H50|A|46/90（51.1%，CI 41.0–61.2%）|87/90（96.7%，CI 90.7–98.9%）|0.967|9 / 0 / 35|
|H50|B|62/90（68.9%，CI 58.7–77.5%）|90/90（100%，CI 95.9–100%）|1.000|3 / 0 / 25|
|H50|C|27/90（30.0%，CI 21.5–40.1%）|89/90（98.9%，CI 94.0–99.8%）|1.289|3 / 26 / 34|
|Zin50|A|80/90（88.9%，CI 80.7–93.9%）|81/90（90.0%，CI 82.1–94.6%）|0.900|10 / 0 / 0|
|Zin50|B|87/90（96.7%，CI 90.7–98.9%）|90/90（100%，CI 95.9–100%）|1.000|3 / 0 / 0|
|Zin50|C|87/90（96.7%，CI 90.7–98.9%）|90/90（100%，CI 95.9–100%）|1.000|3 / 0 / 0|
|H50+Zin50|A|82/90（91.1%，CI 83.4–95.4%）|85/90（94.4%，CI 87.6–97.6%）|0.944|8 / 0 / 0|
|H50+Zin50|B|85/90（94.4%，CI 87.6–97.6%）|90/90（100%，CI 95.9–100%）|1.000|5 / 0 / 0|
|H50+Zin50|C|85/90（94.4%，CI 87.6–97.6%）|90/90（100%，CI 95.9–100%）|1.000|5 / 0 / 0|

C 相对 B 在 Zin50 与 H50+Zin50 的库内正确唯一、覆盖率和拒绝数完全相同；单端 H50 则从 62/90 降至 27/90，并增多集合歧义。这是必须保留的代价，不能只报告扩库后库外找回率。

### 初始库外拓扑：A/B/C 并列

下表 `非空集合` 与最终状态分开。`U` 是任意唯一结果；对 C 再拆分正确唯一与错误唯一。所有库外样本合计 120 条/视图/流程。

|观测|流程|非空集合|正确唯一|错误唯一（95% CI）|最终状态计数（U / AMBIGUOUS / LOW / REJECTED）|
|---|---|---:|---:|---:|---:|
|H50|A|30/120（25.0%，CI 18.1–33.4%）|0|16/120（13.3%，CI 8.4–20.6%）|16 / 0 / 14 / 90|
|H50|B|120/120（100%，CI 96.9–100%）|0|16/120（13.3%，CI 8.4–20.6%）|16 / 0 / 14 / 90|
|H50|C|120/120（100%，CI 96.9–100%）|0|0/120（0%，CI 0–3.1%）|0 / 81 / 39 / 0|
|Zin50|A|0/120（0%，CI 0–3.1%）|0|0/120（0%，CI 0–3.1%）|0 / 0 / 0 / 120|
|Zin50|B|120/120（100%，CI 96.9–100%）|0|0/120（0%，CI 0–3.1%）|0 / 0 / 0 / 120|
|Zin50|C|120/120（100%，CI 96.9–100%）|113/120（94.2%，CI 88.4–97.1%）|0/120（0%，CI 0–3.1%）|113 / 0 / 0 / 7|
|H50+Zin50|A|0/120（0%，CI 0–3.1%）|0|0/120（0%，CI 0–3.1%）|0 / 0 / 0 / 120|
|H50+Zin50|B|120/120（100%，CI 96.9–100%）|0|0/120（0%，CI 0–3.1%）|0 / 0 / 0 / 120|
|H50+Zin50|C|120/120（100%，CI 96.9–100%）|120/120（100%，CI 96.9–100%）|0/120（0%，CI 0–3.1%）|120 / 0 / 0 / 0|

B 的 `Zin50` 和联合观测虽然有 120/120 非空 singleton 集合，但 120/120 都因独立留频拟合门输出 `REJECTED`；“非空集合”不等于被确认接受。H50 固定库 A/B 的 16 个错误唯一全来自 MIRROR_M3，其余三个结构没有被错误唯一，而是被拒绝或降级；这正是为什么不能只用总体“零错误”称为普遍拒识。

### C 的候选生成、集合命中与按拓扑家族结果

C 在四个留出库外家族、三个观测视图中均由通用编辑生成真图：120/120（逐样本 Wilson CI 96.9–100%；结构家族层面为 4/4）。120/120 均未被搜索剪枝；所有视图 `search_truncated=0/120`。下表列出真图进入最终集合与正确唯一数；每格均为 `/30`。n=30 的区间：0/30 为 0–11.4%，27/30 为 74.4–96.5%，28/30 为 78.7–98.2%，29/30 为 83.3–99.4%，30/30 为 88.6–100%。

|库外图族|H50：入集 / 正确唯一；真图平均排名|Zin50：入集 / 正确唯一；真图平均排名|H50+Zin50：入集 / 正确唯一；真图平均排名|
|---|---|---|---|
|MIRROR_M3|27/30；0/30；1.40|30/30；29/30；1.00|30/30；30/30；1.00|
|ADD_M1_M3|30/30；0/30；1.00|30/30；28/30；1.00|30/30；30/30；1.00|
|ADD_M2_M3|30/30；0/30；1.37|30/30；29/30；1.00|30/30；30/30；1.00|
|DOUBLE_M3|27/30；0/30；1.50|30/30；27/30；1.00|30/30；30/30；1.00|

H50 对镜像单支路、M3 双支路仍无法形成正确唯一：拓扑已生成，但有些样本未进入最终集合，其他样本为多图或低置信。Zin50 下四族真图全部入集，113/120 正确唯一、7 拒绝。联合观测下四族均为 30/30 入集且正确唯一。各家族各 30 次重复的比例区间较宽；4 个固定结构不足以推出对其他图族的泛化率。

### 域外参数与非唯一正控制

- 主线尺度 1.15 的域外压力集：三种观测 × A/B/C 均为 `REJECTED 60/60`，唯一接受 0/60（Wilson CI 0–6.0%）。这只验证本次固定域外设置，不是任意参数偏移的拒绝保证。
- H50 T3/T5 镜像与 T3/T4_NEAR_T3 控制：每个确认流程在 90 条控制样本中 `UNIQUE_CONFIDENT=0/90`（CI 0–4.1%）；其余是歧义、低置信或拒绝。A 为 83 ambiguous/7 rejected；B 与 `C_control` 各为 76 ambiguous/4 low/10 rejected。
- Zin50 或 H50+Zin50 可将 T5 与 T3/T4_NEAR_T3 分开；T5 的唯一结果均为正确匹配，T3 与 T4_NEAR_T3 没有被错误唯一。这反映新增阻抗观测改变了等价类，不是规则强制单例。
- `C_control` 使用专用固定 `{T3,T4_NEAR_T3,T5}` 控制库来隔离确认器，不代表 Stage 7A.5 的单层径向 grammar 能生成该 near-invisible 连续参数图。

### 搜索预算、成本与选择结果

独立 D 集从预算 `{7,10}` 选择：

|观测|预算 7 库外生成 /40|预算 7 库内正确唯一 C vs B|预算 10 库外生成 /40|预算 10 库内正确唯一 C vs B|最终预算|
|---|---:|---:|---:|---:|---:|
|H50|40/40|0/60 vs 36/60|40/40|17/60 vs 36/60|10（无预算同时满足门槛，按协议取最大值作诊断）|
|Zin50|40/40|0/60 vs 58/60|40/40|58/60 vs 58/60|10|
|H50+Zin50|40/40|0/60 vs 57/60|40/40|57/60 vs 57/60|10|

以一个配对联合 profile 样本测得候选数 3/7/10 时的时间分别为 0.0455/0.1202/0.1998 s，优化目标评估 138/316/480 次，模板缓存分别 264,144/616,336/880,480 bytes。正式共享模板调用 450 次；完整 `formal_v2` 串行 wall-clock 为 1,194.66 s（约 19.9 min）。C 在 OOD T 上平均活动候选数 H50=10.00、Zin50=9.25、联合=9.25；profile/holdout 评估成本见 [`candidate_scale_benchmark.csv`](../results/data/stage7a_5/formal_v2/candidate_scale_benchmark.csv) 与 [`samples.csv`](../results/data/stage7a_5/formal_v2/samples.csv)。峰值进程内存未单独测量；报告缓存逻辑字节数，不将其冒充峰值 RSS。

## 6. 结果校正、测试与追溯

第一次完整导出把“初始库外的任何唯一结果”一律记为错误唯一，即使 C 已正确生成且选中该真实图。该口径与拓扑恢复任务不符。修正定义后以相同 seeds 完整重跑 formal_v2：2,430 条样本的状态、候选距离、候选排名、生成与控制输出逐行一致；233 条动态扩库后正确唯一被从错误唯一更正为正确唯一。阈值、观测、校准、候选图和方法选择均未改变。标签定义、代码和最终输出分别见 `experiments/exp_stage7a5_candidate_extension.m`、`tests/test_stage7a5_result_integrity.m`、`formal_v2/samples.csv`；逐行核对结论见 [`stage7a5_replay_comparison.log`](../results/logs/stage7a_5/stage7a5_replay_comparison.log)。预备运行 `formal/` 只保留在本地，不是报告或公开归档的主结果。

已完成并通过：

|命令/检查|结果|
|---|---|
|`test_stage7a5_candidate_extension(pwd)`|PASS，覆盖 grammar signature、图编辑、搜索身份、四状态和非唯一正控制|
|`run_stage7a5(pwd,'smoke')`（smoke_v5）|PASS，243 条样本，90.71 s|
|`test_stage7a5_result_integrity(pwd,'smoke')`|PASS，243 sample rows、1,053 candidate rows，SHA-256 manifest 一致|
|`run_stage7a5(pwd,'formal')`（最终 formal_v2）|PASS，2,430 条样本，1,194.66 s，budget `[10,10,10]`|
|`test_stage7a5_result_integrity(pwd,'formal')`|PASS，2,430 sample rows、12,546 candidate rows|
|`test_stage7a4_result_integrity(pwd,'formal')`|PASS，48,000 decisions、20 schemes|
|`test_stage7a4_15m_result_integrity(pwd,'formal')`|PASS，31,680 rows 与 SHA-256 identities|

完整 `tests/run_tests.m` 本轮未运行；Stage 7A.5 定向测试、smoke、formal 完整性及 Stage 7A.4 冻结结果完整性均已运行。主要运行日志：

- [`stage7a5_targeted_metric_fix.log`](../results/logs/stage7a_5/stage7a5_targeted_metric_fix.log)
- [`stage7a5_smoke_v5.log`](../results/logs/stage7a_5/stage7a5_smoke_v5.log)
- [`stage7a5_formal_v2.log`](../results/logs/stage7a_5/stage7a5_formal_v2.log)
- [`stage7a5_postformal_v2_integrity.log`](../results/logs/stage7a_5/stage7a5_postformal_v2_integrity.log)
- [`stage7a5_replay_comparison.log`](../results/logs/stage7a_5/stage7a5_replay_comparison.log)
- [`stage7a5_detailed_summary.log`](../results/logs/stage7a_5/stage7a5_detailed_summary.log)
- [`stage7a5_interval_summary.log`](../results/logs/stage7a_5/stage7a5_interval_summary.log)

## 7. 限制与阶段判断

1. **模型边界：**全部数据由受控 MATLAB forward model 合成；没有真实端口、PLC 收发机或现场台区验证。`Zin50` 也是模型观测，不代表已有设备可以直接获取此频带的输入阻抗。
2. **候选空间边界：**10 张图在实验前已枚举，C 只按需激活/评分；正式预算 10 等于 grammar 上限。它是小型有限空间验证，不是大规模拓扑生成器。
3. **观测可辨识性：**H50 的 MIRROR_M3 单端观测继续出现错误唯一或多候选；把有界扩库与宽松集合门叠加并不能让单视角物理歧义消失。H50 的 C 牺牲库内正确唯一率换来歧义表达。
4. **参数优化：**连续 profile 从粗网格最优点做局部坐标搜索，仍可能漏掉全局最优；只拟合主线尺度及负载尺度，没有拟合支路长度、线型、端接、源阻抗或频变复杂负载。
5. **校准外推：**A/F/D/T 拓扑和 seed 分离；覆盖/校准仅支持声明的合成分布。四个 OOD 家族都属于同一有限 grammar。置信区间是噪声重复区间，不是随机拓扑家族区间。
6. **误接受解释：**C 的 0/120 false unique 只覆盖本次 4 个已知测试图族和当前 grammar；对 grammar 未包含的图，没有拒识保证。Zin50 的 7/120 拒绝也不意味着拒绝率对任意未知网络有效。

### 对预注册阶段门的判断

- 非唯一控制未被 H50 强制唯一：通过。
- 真图生成：4/4 留出库外家族均 30/30；有限 grammar 内确实找回预置在搜索空间但不在初始库中的结构。
- Zin50/联合视图的库内性能：相对 B 未下降；库外视图中得到 113/120、120/120 正确唯一。
- 严格整体“安全算法改进”门：未通过。固定库 A/B 的错误唯一改善只出现在 MIRROR_M3/H50 单一族，未满足至少两个家族的改善要求；H50 库内正确唯一从 62/90 降为 27/90，明显超过允许退化；预算 10 也是当前全部 grammar 的有限枚举上限。

### 对三个核心问题的回答

1. **库外误接受卡在哪里？**原始故障首先是候选库缺少镜像连接位置，同时 H50 单视角对相应拓扑接近不可辨识；独立留频质量门 B 在本次 H50 镜像样本上仍有 16/30 错误唯一，说明确认门本身也不足以消除该族的相对误判。对其他拓扑，固定库 B 多数拒绝而不是选错。
2. **按需扩库是否找回拓扑、代价如何？**在本阶段 10 图 grammar 中，C 对四个留出目标族均生成真图 30/30、剪枝 0/120；H50 114/120 入最终集合但 0 正确唯一；Zin50 113/120 正确唯一并拒绝 7；联合观测 120/120 正确唯一。正式串行运行约 19.9 分钟、缓存约 0.84 MiB；这不代表扩展到更大 topology library 的成本。
3. **下一轮优先优化什么？**优先扩大结构上真正独立的留出图族，并测试未被 grammar 枚举的拓扑/参数变化；同时把 H50-only 与 H50+Zin50 的信息差异作为主实验问题。只有在更大、结构等权的测试与更多 nuisance 失配下保持库内覆盖和低 false-unique，才值得优化搜索效率或扩大 grammar。当前结果不足以支持普遍安全拒识，也不足以称作现场拓扑识别已验证。
