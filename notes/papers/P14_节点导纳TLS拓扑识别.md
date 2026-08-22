# P14 Power Line Network Topology Identification Using Admittance Measurements and Total Least Squares Estimation

## 1. 基本信息

- 作者：Passerini、Tonello
- 年份：2017
- 来源：IEEE ICC，论文约 6 页
- 文件路径：`Power_line_network_topology_identification_using_admittance_measurements_and_total_least_squares_estimation.pdf`
- 标签：`#被动电气量拓扑识别` `#树图反演与组合优化`
- 阅读状态：重点读

## 2. 一句话定位

论文在多个节点获取导纳观测，用传输线 carry-back 方程和 ANIT 逐步识别叶节点相邻关系，并用 TLS 处理复杂噪声和误差变量。

## 3. 输入、输出与先验

| 项目 | 内容 |
|---|---|
| 输入 | 每个节点的输入导纳/电压电流测量，单频或多频、多时刻重复 |
| 输出 | 树边、节点邻接和线路长度候选 |
| 先验 | `Zc/gamma`、负载导纳、线路参数、节点测量可用 |
| 关键假设 | 叶节点与相邻节点的 carry-back 关系，参数和噪声模型可控 |

## 4. 关键公式与算法

- carry-back Eq. (1)：`Y(d)=Y_C(1-rho_L exp(-2 gamma d))/(1+rho_L exp(-2 gamma d))`，`rho_L` 用导纳形式定义。
- 叶节点相邻关系 Eq. (3)–(4) 和 Adjacent Node Identification Theorem (ANIT)：理想无噪声且参数准确时，真实长度满足候选关系。
- 复杂有色高斯噪声和 error-in-variables 下使用 TLS，目标式见 Eq. (8)。
- 频率选择约束见 Eq. (9)：相位传播量过小/过大都会造成估计不适定或相位绕回。

## 5. 实验与结果边界

- 仿真示例使用 10–100 kHz、约 500 m 最大支路、10 节点和随机树；重复多频测量改善完整拓扑错误率，具体数值只保留为原文仿真证据。
- 结果依赖节点导纳测量和先验参数，不能被写成单端 `H_rt` 最近邻的复现。

## 6. 对当前项目的价值

- 可复用：多频点不只是增加 CFR 样本，还可作为频率选择和参数可辨识性约束；TLS 提醒需要同时建模测量量两侧误差。
- 不可直接复用：当前项目没有节点 V/I/导纳观测接口，不能声称已经实现 ANIT/TLS 拓扑识别。
- 研究设计：将“节点导纳”列为 O 的独立测量方式，不与普通 OFDM CFR 混合统计。

## 7. 证据等级

- 论文明确陈述：carry-back、ANIT、TLS、频率选择和多节点测量要求。
- 根据论文推断：节点观测可能比单端 CFR 更直接地破除对称性，但代价是传感器和校准。
- 待验证理解：项目实际节点是否可接入、负载/耦合器参数是否可获得。
