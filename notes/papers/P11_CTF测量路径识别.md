# P11 Path Identification in a Power-Line Network Based on Channel Transfer Function Measurements

## 1. 基本信息

- 作者：Pagani、Ismail、Zeddam
- 年份：2012
- 来源：IEEE Transactions on Power Delivery, 27(3)
- 文件路径：`Path_Identification_in_a_Power-Line_Network_Based_on_Channel_Transfer_Function_Measurements.pdf`
- 标签：`#传输线与信道建模` `#主动信号拓扑识别`
- 阅读状态：重点读

## 2. 一句话定位

论文从宽频 CTF 测量反演传播路径的幅度、衰减和时延，用 FDML 与 Matrix Pencil 做路径识别；路径识别不等于完整树拓扑唯一重建。

## 3. 输入、输出与观测

- 输入：端到端 CTF/VNA 频率响应，约 0–100 MHz 的室内网络测量和仿真。
- 观测：耦合器连接的两端；实验含开放插座和分支反射。
- 输出：路径数、路径幅度和时延、CIR 及由路径差推断的支路长度。
- 先验：传输线传播和衰减模型；路径模型阶数/噪声条件影响反演。

## 4. 核心公式与算法

- 位置：传输线模型 Eq. (1)–(4)，经验 CTF 多径模型 Eq. (5) 附近；FDML 目标/残差 Eq. (10)–(11)。
- 经验形式：`H(f)=A Σ_i g_i exp(-j2πfτ_i) exp(-(a0+a1 f^k)d_i)`（排版以原 PDF 为准）。
- FDML：迭代拟合一条路径并从残差中继续提取。
- Matrix Pencil：SVD 选阶、广义特征值求指数参数，再最小二乘求幅度。

## 5. 主要结果与限制

- 论文比较显示 FDML 分辨率较高但复杂度较大；Matrix Pencil 在研究场景下更快、残差较低，但衰减大/远路径和低 SNR 会损害阶数与特征值分辨率。
- 仿真涉及约 2–100 MHz、较高 SNR；实测约 30 kHz–100 MHz VNA 频响，提取多条路径并用路径差推支路长度。
- 这证明“宽带 CTF 可携带路径信息”，不能直接证明四候选树在单端 SISO 下唯一可辨识。

## 6. 对当前项目的价值

- 可复用：`CFR→CIR→路径参数` 的接口、路径残差和 Matrix Pencil 作为后续可选特征。
- 不可直接复用：VNA 带宽、耦合器校准、路径模型阶数和实验结论不能直接替换项目 OFDM 配置。
- 当前项目应先完成真实频率网格/物理时间原点和端口校准，再增加路径模块。

## 7. 证据等级

- 论文明确陈述：路径模型、FDML/Matrix Pencil 流程、实验网络和局限。
- 根据论文推断：宽带可能改善近似路径分离，但严格 SISO 等价仍需额外视图。
- 待验证理解：当前 sampled CFR 是否满足 Matrix Pencil 的采样和时间原点要求。
