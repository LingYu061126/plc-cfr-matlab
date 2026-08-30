# 基于电力线载波 OFDM 信道响应的配电网拓扑识别理论建模与仿真分析

> **报告性质。** 本文是面向导师汇报的理论推导与仿真基线报告，而不是现场工程验收报告。它只讨论“拓扑变化下的 PLC/OFDM 理论与仿真模型”；接地故障定位、真实商用 PLC PHY、现场耦合器和市电硬件试验均未完成。
>
> **版本与证据。** 本文静态核对的代码版本为 Git `f663bda04f9ef541db28be2cff9aeb5399577150`。仓库根目录没有 `AGENTS.md`；上一级工作集的 `../AGENTS.md` 可读取，本文遵循其研究与证据约束。用户指定的 `core_derivation_reviewed_corrected.md` 不在当前可见目录或上级目录，故本文没有引用或臆测其内容，而以可读取的 `report/core_derivation_reviewed.md`、阶段报告、文献笔记、MATLAB 源码和日志为依据。
>
> 文中使用六类证据标记：**[论文明确陈述]**、**[代码静态核对]**、**[本次实际运行]**、**[历史日志或历史结果]**、**[模型推断]**、**[待人工核对]**。本报告撰写阶段没有新启动 MATLAB；数值结论均标明其历史 CSV/日志来源。

## 摘要

配电网拓扑会通过主线长度、分支位置、端接及支路负载改变电力线通信（power line communication, PLC）信道。针对“能否复用通信型正交频分复用（orthogonal frequency-division multiplexing, OFDM）导频进行拓扑感知”这一问题，本文建立从探测信号、分布参数传输线网络、接收信号、信道频率响应（channel frequency response, CFR）估计，到候选拓扑匹配和可辨识性判定的统一理论框架。物理层以频率相关的 RLGC 电报方程、均匀传输线 ABCD 二端口、支路输入阻抗回推和完整节点导纳网络为基础；观测层以 OFDM 子载波上的 $Y_{rt}[k]=X_t[k]H_{rt}(f_k;G,\theta)+N_{rt}[k]$ 和最小二乘（least squares, LS）估计为基础；反演层以特征距离、拓扑等价类及有界参数联合搜索为基础。

已有代码和历史结果显示：在当前采样 CFR 的循环模型内，频域相乘与显式循环卷积的最大差约为 $3.72\times10^{-16}$，但该等价不等于已经构建连续时间、因果且经校准的 PLC 时域信道。当前 2--30 MHz 的单边带限 IFFT 产生的是**循环带限 CIR**，其峰位置只能称为 **circular-delay proxy**，不可作为真实传播 ToA 或测距结果。在对称端接的端到端单输入单输出（SISO）条件下，候选镜像拓扑 T3/T5 是映射 $(G,\theta)\mapsto H_O$ 非单射的明确反例：模型可正确识别其等价类，却不能据带噪声下的随机编号选择声称唯一识别。历史 20 dB 结果中，SISO 名义匹配的等价类正确率为 1.000、唯一严格率为 0.500；有界参数联合匹配的严格率为 0.785，却伴随 0.470 的 false-unique 率，说明增加参数自由度并不自动改善物理可辨识性。

本文的贡献是给出可追溯的模型、代码—公式映射、结果解释边界和后续阶段门控：普通通信 OFDM 在端口、端接、参数范围和观测协议固定且候选拓扑类间距离大于类内扰动时，可作为拓扑感知的频域测量手段；它并不天然保证未知树拓扑唯一可识别。当前最优先的工作不是直接进入导频/波形优化，而是冻结真实测量端口、耦合器、端接和因果时域校准条件，并在相同拓扑、扰动、能量和观测时间下完成窄带/宽带公平 Level-A CFR 比较。

**关键词：** 电力线通信；OFDM；传输线；ABCD 矩阵；信道频率响应；拓扑识别；可辨识性；多视图观测

---

## 1 引言

### 1.1 研究背景

低压和配电侧电力线同时承担供电与信号传播功能。导线、分支、负载和端接共同决定高频波的衰减、反射和多径叠加，因此网络结构 $G$、线路及负载参数 $\theta$ 会影响端口间的传递函数。若能从 PLC 收发过程中获得稳定、可解释的信道量测，就有机会把通信链路扩展为网络状态感知的信号来源。

本课题关注的不是“CFR 曲线是否会随拓扑变化”，而是更严格的问题：在给定观测协议 $O$、候选拓扑集合和允许的参数扰动下，是否能由所测响应唯一或至少以正确的**观测等价类**识别拓扑。这个问题将物理反问题、通信信道估计和统计判决联系起来。

### 1.2 导师问题与本文范围

本文围绕下列研究链条组织：

```text
探测信号 / OFDM 导频 X
        ↓
电力线传播 H(f; G, θ)
        ↓
接收信号 Y 与 CFR 估计 H_hat
        ↓
CFR / 循环带限 CIR / circular-delay proxy / 阻抗类观测
        ↓
候选拓扑匹配与参数联合估计
        ↓
拓扑、等价类、歧义和 false-unique 的评价
```

本文回应四个导师问题，但严格限定证据范围。

1. 文献层面归纳主动 PLC、反射/阻抗、节点导纳和被动电气量方法所使用的信号、观测量与反演算法；
2. 建立通信型 OFDM 导频复用于 CFR 测量和候选拓扑匹配的必要条件；
3. 给出何时应优先改善观测节点或端接，何时才有理由研究导频、子载波、带宽和功率；
4. 说明拓扑、负载和未来可加入的接地阻抗参数如何进入 $H(f;G,\theta)$，但不把尚未实现的接地故障定位写成成果。

本文不实现真实 G.hn、HomePlug AV2、IEEE P1901、PRIME 或 G3 PHY；不实现完整编码、同步、CFO、PAPR、MIMO 耦合器和现场市电试验；也没有开始阶段 3B 的 OFDM 资源优化。

### 1.3 本文工作与潜在贡献

本文当前可确认的工作是：

- 将传输线 RLGC、ABCD、支路阻抗回推、稳定递推和完整节点导纳模型统一到 $H_{rt}(f;G,\theta)$；
- 将 OFDM 视为离散频点的等效信道测量流程，而非已完成的商用收发机；
- 建立 CFR、循环带限 CIR、循环时延代理、幅相联合特征、结构等价类、ambiguity 与 false-unique 的统一解释；
- 用 T3/T5 说明对称 SISO 下的结构可辨识性限制；
- 用多接收节点、高阻接收和 counterfactual 视图区分“增加信息”与“改变网络工作点”；
- 为后续宽窄带公平对照和 OFDM 感知资源设计建立阶段门控。

这些是**基于模型的潜在研究贡献**，而非“首次提出”或现场已验证的技术创新结论。

---

## 2 前人研究现状

### 2.1 PLC 收发机、OFDM 导频与通信型信道估计

P09 研究室内宽带 PLC 的 OFDM 信道估计，比较 LS、LMMSE/aLMMSE、频域插值和 DFT 域方法，并以室内实测信道讨论不同 PLC 协议的频带与有效载波条件。[论文明确陈述；P09 笔记] 该工作说明 PLC 的信道估计可以从前导、头部或导频符号获得离散 CFR；但其目标是通信估计误差，不是未知树拓扑唯一重建。对于本项目，它提供“$X[k]\to\hat H[k]$”链路和频率缺口/非均匀有效子载波会影响插值的直接启发，不能把其通信评估指标改写为拓扑识别率。

P10 分析宽带 PLC 在脉冲噪声与多径下的 OFDM 传输性能，重点涉及保护间隔、ISI/ICI 与 BER 的关系。[论文明确陈述；P10 笔记] 其价值在于提示循环前缀长度、子载波数和最大时延的相互约束；但“对 BER 合适的 CP”不必然保留对拓扑感知最有效的路径信息，因而不能直接代替拓扑可辨识性设计。

P15 讨论利用现有 PLC 设备的 OFDM 信道估计进行线路诊断，强调与健康状态 CFR 的差分/去卷积、水位正则化和重复测量平均。[论文明确陈述；P15 笔记] 它是“通信 OFDM 是否可复用于诊断”的重要依据，但其笔记所述验证聚焦点到点诊断，不等价于复杂树网络的唯一拓扑重构。

### 2.2 PLC 信道与传输线网络建模

多径参数模型将端到端信道表示为有限条传播路径的延迟、衰减和相位叠加，适合解释 CIR 峰和路径提取；P11 对 CTF 测量、频域最大似然和 Matrix Pencil 路径参数估计进行了比较。[论文明确陈述；P11 笔记] 但“提取出若干路径”与“唯一恢复整棵树”是不同反问题：多个网络可能产生相同或近似相同的端口路径集合。

传输线模型从导线的单位长度 $R'$, $L'$, $G'$, $C'$ 出发，计算传播常数、特性阻抗、支路反射和级联传递函数。中文资料《低压电力线通信信道建模及传输特性研究》（P02，当前索引中无完整元数据）以及《网络参数对低压宽带电力线信道的影响》等被项目作为该类正向模型依据。[论文文件与笔记存在；页码、版本待人工核对] 这一路线的优势是能显式分析长度、支路、负载、端接与 CFR 的因果关系；风险是频率相关参数、耦合器和实际负载外推必须标记，不能把经验损耗模型推广到未校准频段。

P14 则使用节点导纳测量、传输线导纳回推和 total least squares（TLS）进行拓扑反演。[论文明确陈述；P14 笔记] 该方法量测的是节点电压/电流导纳信息，不是普通端到端 CFR；若没有对应电压电流或输入导纳装置，本项目不能宣称复现了该算法。

### 2.3 主动式拓扑变化、路径与反射感知

P12 面向 PLC 网络拓扑变化检测，以 CIR/路径时延形成线路标识并结合分布式信息交换判断变化。[论文明确陈述；P12 笔记] 该类方法强调“拓扑改变检测和变化位置判断”，与任意未知树的完整唯一重建不同；负载改变也可能产生与拓扑异常相似的响应，因而需要阈值、重复测量和假阳性分析。

P11 从 CTF/CIR 中提取传播路径，适合把反射路径与支路或阻抗不连续点关联。[论文明确陈述；P11 笔记] 它可作为本项目未来的可选路径特征模块，当前不能把 Matrix Pencil 的路径提取成功写成完整拓扑已识别。

P13 讨论全双工 PLC modem 的网络感知，区分输入阻抗 $Z_{\mathrm{PL}}$、反射系数 $\rho$、FDR trace 与端到端传递函数。[论文明确陈述；P13 笔记] 其关键边界是：普通端到端 OFDM 信道估计得到 $H_{rt}$，并不自动等价于 $Z_{\mathrm{PL}}$、$\rho$ 或 FDR；后者需要同端发射接收、电压电流测量、耦合器或等效的自干扰消除假设。

### 2.4 被动式电气量拓扑识别

项目中的树状图编码、时频多源、低压智能开关和状态量测文献（历史编号 P03--P06）使用 KCL/KVL、功率平衡、电压相关性、谐波或组合优化从被动量测重建馈线关系。[历史项目分类；当前笔记目录未包含 P03--P06 的可核对完整条目] 这些方法通常不注入 PLC 探测信号，优点是能利用已有计量基础设施；限制包括数据同步、负载相关性、缺失量测与组合规模。它们可借鉴“物理约束+全局搜索”的反问题形式，但不能与主动 PLC CFR 方法混为同一种观测。

### 2.5 多端口、多节点与 MIMO-PLC

P16 的综述从物理层、网络层、应用层梳理 PLC 对电网信息的推断，并将端到端 CFR、反射、阻抗/导纳和多节点量测区分为不同的信息源。[论文明确陈述；P16 笔记] 多接收节点、双向或多端口观测可增加观测维度，但候选端口数量不等于独立自由度；例如三导体 PLC 的若干线间端口通常存在相关性。

项目中的《多输入多输出电力线载波通信的噪声建模和消除研究》（P07）同样提醒：L--N、N--PE、L--PE 的端口数不能直接当作三个独立差模激励。[历史项目资料；元数据待人工核对] 本文当前仍是简化单导体/等效端口模型，不是多导体 MIMO 传输线仿真。

### 2.6 PLC 噪声、同步误差和鲁棒性

P10 讨论脉冲噪声与多径，P09 讨论频率选择性和导频估计，项目中文噪声资料 P08 讨论有色、脉冲、周期和非平稳 PLC 噪声。[论文明确陈述/历史资料，具体页码待核对] 这些工作共同表明，白高斯噪声只是可控基线；实际噪声、载波频偏、定时误差、采样时钟偏差和时变负载都会使 $\hat H$ 偏离名义 $H$。因此较低的 CFR NMSE 或 BER 并不能直接推出更高的拓扑唯一识别率。

### 2.7 重点文献的证据卡片

下表将每篇可读取笔记中的“问题—输入—输出—验证—局限”压缩到可追溯的粒度。笔记没有给出的页码、作者细节或实验数字均不补写。

| 文献 | 研究问题与拓扑层级 | 信号/观测与核心特征 | 反演算法 | 仿真/实测与主要结果 | 局限及对本项目的借鉴 |
|---|---|---|---|---|---|
| P09 | 室内 BB-PLC 的 OFDM 信道估计；不输出拓扑 | OFDM 前导/头部/导频，CFR、频率缺口 | LS、LMMSE/aLMMSE、频域插值、DFT 域估计 | 笔记记录 171 个室内实测信道、22 个住宅和 1--87.15 MHz VNA 频率测量；通信估计指标的具体数值不在本文引用 | 可复用离散 CFR 估计与插值问题；不能把通信 NMSE 变成拓扑率 |
| P10 | 脉冲噪声和多径下的 BB-PLC OFDM 通信；不输出拓扑 | OFDM、脉冲噪声、多径、保护间隔，BER/ISI/ICI | 通信检测与性能分析 | 当前笔记确认其为模型/性能分析；具体参数与 BER 数字待回原文核对 | 可借鉴噪声与 CP 约束；BER 最优并非拓扑感知最优 |
| P11 | 从 CTF 找传播路径；路径/支路线索而非完整树唯一重建 | CTF/CFR、IFFT CIR、路径幅度和时延 | 频域最大似然（FDML）、Matrix Pencil | 笔记记录实测网络 CTF 和两类方法对比；具体残差/分辨率数字待原文核对 | 可作为路径特征模块；路径提取成功不推出完整拓扑唯一 |
| P12 | PLC 网络的拓扑变化检测及变化位置判断 | 多次 CFR/CIR、路径时延、量化的 PL ID | 局部判断、token/信息交换 | 笔记记录二/多节点仿真和 NB 42--472 kHz、BB 2--30 MHz 场景；其高检测率必须连同原始条件使用 | 可借鉴变化检测、重复测量和假阳性分析；不等于未知树重建或现场验证 |
| P13 | 通过全双工 PLC 进行单端网络感知 | 输入阻抗 $Z_{PL}$、反射系数 $\rho$、FDR trace、反射 CIR | 自干扰抵消后反射/阻抗分析 | 笔记确认 IBFD 观测关系；硬件数值/页面待人工核对 | 清楚界定端到端 CFR 与反射测量不同；FDR 需要额外仪器假设 |
| P14 | 基于节点导纳的配电网拓扑反演 | 多节点电压/电流和复导纳 | carry-back equation、ANIT、TLS | 笔记确认复杂有色高斯噪声/TLS 场景；网络规模和结果待原文核对 | 为节点导纳测量提供反演对照；本项目没有该量测，不能声称复现 |
| P15 | 复用 PLC device 的信道估计进行线路诊断 | OFDM CFR、健康/当前响应差、重复平均 | 去卷积、水位正则化 | 笔记记录点到点仿真、5 kHz--5 MHz、450 载波、1000 m 为论文场景；非现场树拓扑识别 | 是“通信 OFDM 可用于诊断”的证据，但不能外推到复杂树唯一重建 |
| P16 | PLC 推断电网信息的方法地图 | CFR、CIR/ToA、FDR/TFDR、阻抗/导纳、智能表数据 | 综述分类，非单一反演器 | 综述性论文；原始技术参数需回到其引用论文 | 用于区分拓扑估计、映射、异常检测和故障定位；不能单独作技术参数原始证据 |

### 2.8 文献横向比较

| 文献 | 拓扑层级 | 主动/被动 | 输入信号或量测 | 核心特征 | 反演方法 | 需要的观测节点 | 主要局限 | 对本项目的作用 |
|---|---|---|---|---|---|---|---|---|
| P09 OFDM PLC 信道估计 | 非拓扑重建 | 主动通信 | OFDM 前导/导频 | CFR、估计误差 | LS/LMMSE/插值 | 端到端收发 | 通信指标不等于拓扑指标 | 建立 $\hat H$ 模型 |
| P10 脉冲噪声与多径 OFDM | 非拓扑重建 | 主动通信 | OFDM | BER、ISI/ICI | 通信检测 | 端到端 | CP/BER结论不可直接感知化 | 噪声/CP边界 |
| P11 路径识别 | 路径/支路线索 | 主动测量 | CTF | CIR 路径时延/幅度 | FDML、Matrix Pencil | CTF 测量端 | 路径不等于唯一树 | 候选路径特征 |
| P12 拓扑变化检测 | 变化检测/定位 | 主动 PLC | 多次 CIR | PL ID、时延变化 | 量化、分布式 token | 多节点 | 负载变化假阳性 | 拓扑变化检测边界 |
| P13 全双工网络感知 | 阻抗/反射异常 | 主动同端 | FDR、$Z_{PL}$、$\rho$ | 反射峰 | 反射/阻抗分析 | 同端耦合器 | 非端到端 CFR | 观测方式区分 |
| P14 导纳 TLS | 节点/树关系 | 主动电气测量 | 节点导纳 | 复导纳 | ANIT、TLS | 节点电压电流 | 需要导纳装置 | 多节点反演对照 |
| P15 OFDM 线路诊断 | 点到点健康状态 | 复用通信 | PLC CFR | 差分/去卷积响应 | 正则化、平均 | 端到端 | 非复杂树唯一重建 | OFDM诊断可行性证据 |
| P16 PLC 信息推断综述 | 多层级 | 主动/被动 | CFR、FDR、导纳等 | 多类特征 | 分类综述 | 依方法不同 | 综述非原始参数证据 | 研究地图 |
| 中文传输线资料（P02 等） | 信道正向模型 | 主动/建模 | RLGC、线路参数 | CFR、阻抗 | ABCD/阻抗回推 | 端到端或节点 | 参数校准范围 | $H(G,\theta)$ 依据 |
| 被动电气量资料（P03--P06） | 馈线/户相/树 | 被动 | 电压、电流、功率、谐波 | 相关性/残差 | KCL/KVL/优化 | 智能表/开关 | 同步与数据质量 | 物理约束对照 |

---

## 3 研究空白与本文工作定位

### 3.1 研究空白

综合上述文献，可以得到六个需要由模型和实验共同检验的缺口。

1. 通信型 OFDM 主要为可靠数据传输设计；即使可获得 $\hat H[k]$，导频位置、频率缺口、估计误差和同步机制是否保留拓扑特征仍须验证。
2. 端到端 SISO CFR 不保证对拓扑和参数的映射是单射。对称网络、对称端接或未观测的内部节点可能产生结构等价。
3. 负载、长度、RLGC、端接与耦合器变化可形成类内变化，甚至盖过拓扑造成的类间差异。
4. 仅以名义参数做最近邻匹配会把参数失配当作拓扑变化；而过宽的参数搜索又可能拟合噪声并输出虚假的唯一编号。
5. “多视图更好”既可能来自额外观测信息，也可能来自内部接收机并联负载改变网络工作点，二者必须拆分。
6. 当前尚无公平的 NB/BB 数值识别对照，因而不能把“当前瓶颈不是带宽”写成结论。

### 3.2 本文定位

本文的模型层工作定位为：在固定的小型候选树集合上，建立可复现的 $H_O(G,\theta)$ 正向计算、OFDM 等效测量、特征距离和拓扑/等价类判定基线；比较 SISO、双向、双接收和多视图；审计参数不确定性与循环卷积边界。它为未来波形优化提供判据，但不替代真实 PLC PHY 或硬件协议。

### 3.3 对可能创新点的谨慎表述

若后续文献检索与实验继续支持，以下可作为**潜在研究贡献**：

- 以结构等价类、ambiguity 与 false-unique 而非单一准确率评价 PLC 拓扑感知；
- 在同一完整网络内区分 loaded/high-Z/counterfactual 多视图的物理含义；
- 用参数失配、观测方式和 OFDM 估计误差分层定位识别失败来源；
- 以相同候选网络、能量、频点和观测时间公平比较 NB/BB 或感知资源配置。

是否具有“首次性”尚需系统检索原始论文和标准，当前不能宣称。

---

## 4 问题定义与系统模型

### 4.1 统一符号、单位和观测协议

| 符号 | 中文（英文） | 单位/取值 | 说明 |
|---|---|---|---|
| $G=(\mathcal V,\mathcal E)$ | 候选网络拓扑 | 图 | 节点集与线路边集 |
| $\theta$ | 网络参数 | 混合 | 线长、$R',L',G',C'$、支路/终端负载、$Z_s,Z_r$、耦合误差等 |
| $O$ | 观测协议（observation protocol） | 枚举 | SISO、双向、双接收、多视图、反射或导纳等 |
| $f,\omega$ | 频率、角频率 | Hz, rad/s | $\omega=2\pi f$ |
| $R',L',G',C'$ | 单位长度串联电阻/电感、并联电导/电容 | $\Omega$/m, H/m, S/m, F/m | 频率模型输入 |
| $\gamma(f)$ | 传播常数 | 1/m | $\alpha+j\beta$ |
| $Z_c(f)$ | 复特性阻抗 | $\Omega$ | 逐频率计算，不等同名义 $Z_0$ |
| $T=[A\ B;C\ D]$ | ABCD/传输矩阵 | 混合量纲 | 本项目端口约定见第 5 节 |
| $H_{rt}$ | 端到端 CFR | 无量纲（电压比） | 发端 $t$ 到接收端 $r$ |
| $H_O$ | 协议 $O$ 下观测响应 | 向量/矩阵 | 不能脱离物理端口定义 |
| $X[k],Y[k],N[k]$ | OFDM 发射、接收、噪声 | 复数 | 有效子载波上的频域量 |
| $\hat H[k]$ | LS 估计 CFR | 复数 | 已知非零导频条件 |
| CIR | 循环带限冲激响应 | 复数序列 | 当前为 IFFT 代理 |
| circular-delay proxy | 循环时延代理 | sample/s | 不是真实 ToA |

内部频率统一为 Hz，长度为 m，RLGC 为 SI 单位。[代码静态核对：`cable_rlgc.m`、配置函数]

### 4.2 物理、通信与观测层的分离

物理网络层定义为

$$
H_{rt}(f;G,\theta),
$$

其中 $\theta$ 至少包括各边长度、单位长度 RLGC、支路/节点负载、源/接收端阻抗和可选耦合器误差。通信观测层定义为

$$
Y_{rt}[k]=X_t[k]H_{rt}(f_k;G,\theta)+N_{rt}[k].
$$

观测协议 $O$ 则决定激励位置、接收位置、端接、是否存在内部接收负载，以及将哪些端口响应拼接为 $H_O$。因此普通 OFDM 端到端 CFR、FDR/TFDR 反射、输入阻抗和节点导纳是不同测量算子，不能仅以“都和 PLC 有关”而合并。

### 4.3 拓扑观测等价类

对容差 $\varepsilon_O$，若在给定参数约束和观测协议下

$$
D\left(H_O(G_i,\theta_i),H_O(G_j,\theta_j)\right)\leq\varepsilon_O,
$$

则称 $G_i\sim_O G_j$ 属于同一观测等价类。严格拓扑编号、等价类和数值 tie 是三件不同的事：前者是标签，第二者来自结构/协议定义，第三者是某次浮点分数的近似相等。

---

## 5 电力线传输线与网络拓扑建模

### 5.1 RLGC 电报方程

对均匀有损线路，取 $x$ 正向为端口 1 指向端口 2 的传播方向，频域电压电流满足

$$
\frac{\mathrm d V(x)}{\mathrm d x}=-(R'+j\omega L')I(x),\qquad
\frac{\mathrm d I(x)}{\mathrm d x}=-(G'+j\omega C')V(x).
$$

从而

$$
\gamma(f)=\sqrt{(R'+j\omega L')(G'+j\omega C')},
$$

$$
Z_c(f)=\sqrt{\frac{R'+j\omega L'}{G'+j\omega C'}}.
$$

这里 $\gamma=\alpha+j\beta$ 表示衰减与相位传播，$Z_c$ 是逐频率、一般为复数的特性阻抗。[代码静态核对：`cable_rlgc.m`] `cable_parameters` 中的 `Z0_nominal_ohm` 仅为名义阻抗字段，不能替代 $Z_c(f)$。

当前实现要求 $f>0$，并把经验损耗因子 $k_G$ 乘入导纳经验项。$k_G$ 是经验损耗修正，既不是线路长度也不是普适物理常数；当频带、长度或参数超出来源论文校准范围时，结果必须标为参数外推。

### 5.2 均匀线 ABCD 二端口

项目使用如下端口定义：

$$
\begin{bmatrix}V_1\\I_1\end{bmatrix}
=T_{\mathrm{line}}
\begin{bmatrix}V_2\\I_2\end{bmatrix},\qquad
T_{\mathrm{line}}=
\begin{bmatrix}
\cosh(\gamma d)&Z_c\sinh(\gamma d)\\
\sinh(\gamma d)/Z_c&\cosh(\gamma d)
\end{bmatrix}.
$$

其中 $I_1,I_2$ 按项目约定均沿线路由发送侧指向接收侧定义。[代码静态核对：`transmission_line_abcd.m`] 因教材可能使用“端口电流均流入二端口”的不同约定，不能不检查符号就搬用端接公式。

在上述均匀线、当前端口约定与精确运算下，

$$
AD-BC=\cosh^2(\gamma d)-\sinh^2(\gamma d)=1.
$$

该行列式关系通常来自互易二端口结构；**无源性不是必要条件**。数值计算中 $AD-BC$ 偏离 1 可以是消减误差，不能直接解释为物理互易性破坏。

多段主线路径必须按物理顺序级联：

$$
T_{\mathrm{total}}=T_1T_2\cdots T_M.
$$

它不是把各段空载电压增益相乘，也不是微积分的 chain rule。

### 5.3 支路输入阻抗与并联导纳

长度为 $d_b$、末端负载为 $Z_L(f)$ 的支路，从接入主线的节点向内看，其输入阻抗为

$$
Z_{\mathrm{in}}=Z_c
\frac{Z_L+Z_c\tanh(\gamma d_b)}
{Z_c+Z_L\tanh(\gamma d_b)}.
$$

该式支持实/复标量负载、等长频率向量负载、开路 $Z_L=\infty$、短路 $Z_L=0$ 与零长度边界。[代码静态核对：`branch_input_impedance.m`] 对有限 $Z_{\mathrm{in}}$，主线连接点看到的是并联导纳

$$
Y_{\mathrm{branch}}=\frac1{Z_{\mathrm{in}}},\qquad
T_{\mathrm{shunt}}=
\begin{bmatrix}1&0\\Y_{\mathrm{branch}}&1\end{bmatrix}.
$$

多条同一节点的支路必须先在导纳域求和。支路本身仍是分布参数线路；“并联负载”只指已经回推到连接点后的等效行为。级联顺序若与实际网络不一致，即使矩阵计算正确，也不代表同一物理拓扑。

### 5.4 源端、端接与端口归一化

设总 ABCD 矩阵为 $[A\ B;C\ D]$，Thevenin 开路源电压为 $V_s$，源阻抗为 $Z_s$，接收端为 $Z_r$，则电压传递函数为

$$
H_V=\frac{V_r}{V_s}=
\frac{Z_r}{A Z_r+B+Z_s(CZ_r+D)}.
$$

开路接收端的极限为

$$
H_V\big|_{Z_r\to\infty}=\frac1{A+Z_sC}.
$$

若使用参考端口阻抗 $Z_{\mathrm{port,ref}}$ 定义端口响应，项目实现为

$$
H_{\mathrm{port}}=
\frac{Z_s+Z_{\mathrm{port,ref}}}{Z_{\mathrm{port,ref}}}H_V.
$$

故仅在 $Z_s=Z_{\mathrm{port,ref}}=50\ \Omega$ 时，$H_{\mathrm{port}}=2H_V$。[代码静态核对：`abcd_to_transfer.m`] 改变源阻抗、接收端阻抗或端口参考阻抗后，无条件保留 2 倍会导致不可解释的约 6.02 dB 偏差。有限输入阻抗接收机既测量网络，也以并联负载改变网络工作点。

### 5.5 长线路稳定递推

当 $\Re\{\gamma d\}$ 很大时，直接计算 $\cosh(\gamma d)$、$\sinh(\gamma d)$ 并重复矩阵相乘会出现大数相消。阶段 1.5 因此不把“没有 NaN/Inf”当作稳定性验收，而同时审计

$$
\epsilon_{\det}=\max_f|AD-BC-1|.
$$

`terminated_line_response.m` 采用衰减指数形式的端接电压比，`cascade_network_stable.m` 从接收端向前作阻抗/导纳回推并累计稳定电压比。[代码静态核对] 这避免先生成巨大双曲函数再相消，并保留物理端接关系。

历史测试给出的明确警示是：$k_G=5$ 时，传统 ABCD 的最大行列式残差在 500、800、1200 m 分别约为 $6.46\times10^1$、$1.55\times10^{12}$、$1.55\times10^{26}$，被标记为 `legacyReliable=0`；稳定递推仍用于正式结果。[历史日志：`core_derivation_review_full_test.log`] 这说明传统长线 ABCD 曲线不能继续作为正式物理结论；而稳定计算也不把参数外推变成已验证的现场传播模型。

### 5.6 完整节点导纳网络与多视图

阶段 2.2 后，完整树网络可写为

$$
Y_{\mathrm{net}}(f;G,\theta,O)V(f)=I_{\mathrm{exc}}(f).
$$

对于一条节点 $p,q$ 间的非零长度分布参数边，代码将其等效为频域节点导纳块；源的 $V_s,Z_s$ 用 Norton 等效注入，终端负载和真实内部接收机作为节点并联导纳加入 $Y_{\mathrm{net}}$。[代码静态核对：`plc_full_network_response.m`] 每个接收节点的电压与源电压之比构成一个视图，多个视图可拼接成联合观测。

`dual_receiver_complete` 的内部接收机是实际并联负载；`dual_receiver_highz_complete` 仅用高输入阻抗近似减小扰动；`dual_receiver_counterfactual` 是对同一完整网络解的分析性、无额外负载节点电压，不能视作可直接实现的无扰动硬件。阶段 2.1 曾有截断前缀网络，它已被明确排除，不能冒充完整多端口物理模型。

---

## 6 OFDM 信号与信道估计模型

### 6.1 频域 OFDM 等效测量

在有效子载波 $f_k$ 上，通信型 OFDM 的复基带等效模型为

$$
Y_{rt}[k]=X_t[k]H_{rt}(f_k;G,\theta)+N_{rt}[k].
$$

对已知且非零导频，LS CFR 估计为

$$
\hat H_{rt}[k]=\frac{Y_{rt}[k]}{X_t[k]}
=H_{rt}(f_k;G,\theta)+\frac{N_{rt}[k]}{X_t[k]}.
$$

这意味着导频幅度、噪声功率、有效载波集合与插值共同决定 $\hat H$ 的误差。若导频间隔大于 1，代码对已知导频的估计在频域作复数线性插值；这是稀疏导频 CFR 重建基线，不是标准规定的插值器或 LMMSE 实现。[代码静态核对：`stage3a_receive_ofdm.m`]

### 6.2 当前仿真假设与阶段差异

阶段 2 的 `ofdm_config.m` 使用 $N_{\rm FFT}=4096$、$F_s=64$ MHz、频带 2--30 MHz、全导频且 CP=0；阶段 3A 的 `stage3a_config.m` 使用相同频率框架而 CP=256。[代码静态核对] 两者的 CP 差异必须保留：CP=256 的字段来源为 `stage3a_project_simulation_assumption`，不是由物理时延扩展推导，也不是经标准确认的 PLC 参数。

`stage3_band_configs.m` 中 NB 的 42--472 kHz 被明确保留为候选研究频带，因 PHY、$F_s$、FFT、CP、导频和 PSD 未冻结而不可运行；BB 的 2--30 MHz、64 MHz、4096、256 亦只是项目仿真假设。当前没有 NB/BB 拓扑识别数值实验，不能由配置测试通过推出宽窄带结论。

### 6.3 噪声与同步误差的位置

当前阶段 3A 的**默认循环基线**等效链路为

```text
payload → circular frequency-domain filtering by H_full → filtered payload
        → append its own tail as the reported CP → noise → phase rotation
        → 去 CP、定时/采样误差处理、FFT → LS / 插值
```

也就是说，默认 `circular_sampled_cfr` 先对一个 $N_{\rm FFT}$ payload 做循环滤波，再把**滤波后** payload 的尾部作为接收帧前缀；它保留了循环频域基线，却不是“发射 CP 经过一个已校准的线性物理信道”的实现。只有 `linear_sampled_cfr` 审计模式才把 `symbol.tx_frame`（发射 CP 加 payload）同 $h_{\rm sampled}$ 做有限线性卷积。[代码静态核对：`stage3a_apply_ofdm_channel.m`] 这个区别进一步说明当前链路不应被包装成真实 PLC 时域收发机。

白噪声、有色高斯噪声和脉冲噪声仅是等效观测误差模型。定时偏移作用于去 CP/采样位置，采样时钟偏差通过采样重映射，导频相位旋转作为复相位误差作用于接收链路。[代码静态核对：`stage3a_apply_ofdm_channel.m`、`stage3a_receive_ofdm.m`] 它们用于分离机制，不构成完整同步器或现场 PLC 噪声模型。

### 6.4 循环前缀、循环卷积与循环带限 CIR

令 $H_{\rm full}[m]$ 为只在有效 2--30 MHz 频点填入响应、其他 FFT bin 为零的数组，

$$
h_{\rm sampled}[n]=\operatorname{IFFT}\{H_{\rm full}[m]\}.
$$

在默认 `circular_sampled_cfr` 模式，先对 payload 计算

$$
y_{\rm circ}[n]=\operatorname{IFFT}\{\operatorname{FFT}(x[n])H_{\rm full}[m]\}
=x[n]\circledast_N h_{\rm sampled}[n].
$$

然后代码从 $y_{\rm circ}$ 尾部生成 CP。显式 $N$ 点循环卷积与上式的频域相乘在同一离散模型内数值等价。[历史日志：最大误差约 $3.72\times10^{-16}$] 这只验证了 DFT 卷积定理，并不证明 $h_{\rm sampled}$ 是连续时间、因果、全频带、物理定时已校准的 PLC 冲激响应，更不等于默认 CP 已通过实际线路传播。

阶段 3A.2 还增设 `linear_sampled_cfr`：用同一 $h_{\rm sampled}$ 对包含 CP 的有限发射帧显式线性卷积并记录尾部。对 T2、CP=256，历史 CSV 给出物理时延支持为 NaN、99% 能量与 -40 dB 支撑均为 4095 samples、CP 能量覆盖为 0.691912、线性/循环相对 RMS 为 0.048204。[历史结果：`stage3a_2_model_validity_cp_metrics.csv`] 原因是单边 2--30 MHz 采样、未测频点置零和 IFFT 周期化会产生遍布周期的带限旁瓣，且当前没有物理时间原点。因此：

- NaN 是“当前模型不可给出物理延迟支撑”，不是计算失败；
- `cp_energy_fraction` 是当前峰值对齐的循环响应能量统计，不是现场 CP 覆盖率；
- $h_{\rm sampled}$ 应称为 **circular band-limited CIR**；
- `stage3a_toa_feature.m` 给出的是 **circular-delay proxy**，不能称真实 ToA、传播距离或测距。

---

## 7 拓扑特征、匹配与可辨识性分析

### 7.1 CFR/CIR 特征

给定响应向量 $a_k,b_k$，当前实现包括以下特征。

1. 幅值 $|H[k]|$、dB 幅值 $20\log_{10}|H[k]|$。raw dB 幅值保留绝对衰减，幅值形状归一化会刻意削弱统一增益信息。
2. 相位 $\angle H[k]$。低幅值频点的 unwrap 易出现大跳变，代码另提供掩膜/加权相位误差，不能把此类跳变直接解释成物理相位误差。
3. 归一化复数 CFR：先以 $\ell_2$ 范数归一化整个向量，再取逐频点 RMS 距离：

$$
D_{\rm complex,norm}=
\sqrt{\frac1N\sum_{k=1}^N\left|
\frac{a_k}{\|a\|_2}-\frac{b_k}{\|b\|_2}
\right|^2}.
$$

它强调复数形状或相对响应，而非绝对标定响应。
4. raw 复数 CFR：

$$
D_{\rm complex,raw}=
\sqrt{\frac1N\sum_{k=1}^N|a_k-b_k|^2},
$$

保留绝对电平，也更敏感于耦合增益、端接和负载变化。
5. 循环带限 CIR 及其 circular-delay proxy。其分辨率与带限采样相关，但当前不能等同物理路径时延。
6. 幅相联合特征：

$$
D_{\rm joint}=\sqrt{w_{\rm amp}D_{\rm amp}^2+w_{\rm phase}D_{\rm phase}^2}.
$$

权重是审计配置，不能写成已寻得最优权重。

上述距离均遵循 RMS 聚合。[代码静态核对：`topology_feature_distance.m`] “曲线不同”只说明候选样本间存在某种差异；是否可识别还需与同拓扑的负载、长度、RLGC 和端接扰动距离比较。

### 7.2 候选拓扑匹配与参数联合估计

名义最近邻匹配定义为

$$
\hat G=\arg\min_{G\in\mathcal G}D\left(\hat H,H_O(G,\theta_0)\right).
$$

为了处理参数失配，联合匹配定义为

$$
(\hat G,\hat\theta)=\arg\min_{G\in\mathcal G,\ \theta\in\Theta}
\left[D\{\hat H,H_O(G,\theta)\}+\lambda R(\theta)\right].
$$

其中 $\Theta$ 是集中配置的有界网格，$R$ 对偏离名义参数施加正则化。[代码静态核对：`topology_joint_match.m`] 阶段 2.2 的模板库为每拓扑 243 点；阶段 3A.2 的审计基线为 27 点，二者不能混写。27 点网格与 $\lambda$ 候选仅是可复现的有界基线，既不证明全局最优，也不保证不会以额外自由度拟合噪声。

### 7.3 可辨识性、等价类与 T3/T5

可辨识性的核心是映射

$$
(G,\theta)\longmapsto H_O(f;G,\theta)
$$

在所给候选域内是否单射，而不是“一个复函数信息维数低于拓扑自由度”的笼统计数。连续频率响应可以携带大量信息；但单端 SISO 没有一般性的唯一性保证。

当前候选集合中，T3/T5 在下列条件下形成明确镜像反例：均匀对称主线、相同线路参数、镜像支路位置、相同支路/终端负载、对称源/接收端端接，以及当前理想互易的端到端 SISO 定义。此时

$$
H_{O_{\rm siso},\mathrm{T3}}(f;\theta)
=H_{O_{\rm siso},\mathrm{T5}}(f;\theta).
$$

这里的等号是该候选模型和观测边界下的结构等价说明；它不宣称所有实际配电网络或所有端接下都对称。加噪后两个数值 score 不再严格相等，只代表噪声打破了**数值 tie**，并不使镜像网络获得新的物理可观测信息。

### 7.4 指标定义

设 $N$ 次试验中真实具体标签为 $G_i$、预测标签为 $\hat G_i$、其结构等价类为 $[G_i]_O$：

$$
\mathrm{strict\ accuracy}=\frac1N\sum_i\mathbf 1(\hat G_i=G_i),
$$

$$
\mathrm{equivalence\text{-}class\ accuracy}=
\frac1N\sum_i\mathbf 1(\hat G_i\in[G_i]_O).
$$

`unique strict accuracy` 只在输出非歧义时评价具体编号的正确性；`ambiguity rate` 是算法按 tie/等价规则拒绝唯一输出的比例；`false-unique rate` 是真实拓扑属于物理等价类而算法却输出单一候选的比例。还应报告 best/second-best distance margin，而非只看最小 score。

边级 Precision、Recall、F1 通过候选图边集合与真实边集合比较；CFR NMSE、幅值误差和相位误差属于通信/估计层指标，不能替代上述图层指标。

---

## 8 仿真设置与可复现性

### 8.1 模型、候选拓扑和数据来源

本项目的正式仿真基线包括阶段 1.5 至 3A.2：前者验证正向传输线、稳定递推及 OFDM 候选匹配，后者审计多视图、参数联合搜索、循环/线性模型与 CP 指标。阶段 3A.2 的正式协议使用候选 T2--T5、三个场景 `nominal_noise_20`、`load_error_10`、`joint_bounded`，每一测试设置为每拓扑 50 次独立试验，并将校准种子与测试种子分离。[历史报告/CSV：`report/stage3a_2_model_validity_and_observation_protocol.md`、`results/data/stage3a_2_protocol_summary.csv`]

当前频率仿真假设是：$F_s=64$ MHz、$N_{\rm FFT}=4096$、有效频带 2--30 MHz、频率间隔 15.625 kHz、1793 个频点；阶段 3A CP=256。它们是项目参数，而非已核实的 PLC 标准 PHY。[代码静态核对]

### 8.2 观测协议

| 协议 | 观测含义 | 是否改变网络工作点 | 本文解释限制 |
|---|---|---|---|
| `siso_forward` | 一个端到端 CFR | 仅端点端接 | 可能保留镜像等价 |
| `bidirectional_endpoint_fixed` | 两端角色固定的正反向端点观测 | 取决于端接定义 | 互易/对称端接下不一定消歧 |
| `dual_receiver_complete` | 完整网络中两个接收节点 | 是，内部接收机并联负载 | 不能当作无扰动传感器 |
| `dual_receiver_highz_complete` | 高阻内部接收近似 | 仍有有限/模型化扰动 | 不是实际耦合器参数验证 |
| `dual_receiver_counterfactual` | 计算性无负载内部节点电压 | 否（分析对照） | 不是硬件测量模型 |
| `three_view_complete` | 组合多个完整网络视图 | 依具体接收机而定 | 不等于完整 MIMO-PLC |

### 8.3 噪声与扰动

已有阶段包含白噪声、有色噪声、脉冲噪声、相位旋转、定时偏移、采样时钟偏差、负载、长度、RLGC 和端接扰动接口。[代码和历史测试] 其中阶段 3A.2 表中重点引用 20 dB 等效导频噪声，不能外推为实测 PLC 有色/脉冲噪声分布。载荷变化、端接变化和耦合器误差应被视为 $\theta$ 的变化，而非自动标记为拓扑变化。

### 8.4 可追溯图表与数据

本文引用的既有结果保留在以下文件，未重新生成或修改：

- 长线稳定性：`results/figures/exp05_long_line_stability_diagnostics.png`；
- OFDM 估计与候选匹配：`results/figures/exp07_ofdm_channel_estimation.png`、`exp08_ideal_pairwise_distances.png`；
- 多视图与参数匹配：`results/figures/stage3a_1_parameter_aware_measurement_comparison.png`；
- CP/卷积审计：`results/figures/stage3a_2_model_validity_cp_audit.png`、`results/data/stage3a_2_model_validity_cp_metrics.csv`；
- 观测协议：`results/figures/stage3a_2_protocol_observation_protocol.png`、`results/data/stage3a_2_protocol_summary.csv`。

---

## 9 仿真结果与讨论

### 9.1 正向模型与数值稳定性

**[历史日志或历史结果]** 阶段 1.5 的测试检查了 RLGC 单位、ABCD 行列式、分段等价、无支路与匹配线等极限。对 $k_G=1$，300--1200 m 的传统 ABCD 行列式残差虽随长度增加而增大，稳定递推与短线 ABCD 的 CFR 对照仍通过；对 $k_G=5$，500 m 及以上传统计算已出现显著消减误差，被正式标记为 legacy 不可靠。该结果支持“需要稳定回推”的数值结论，不能用来证明 $k_G=5$ 在 300--1200 m 具有已验证的现场物理意义。

### 9.2 OFDM CFR 估计与拓扑指标不可替代

**[历史日志或历史结果]** 阶段 2 无噪声 LS 恢复、噪声随 SNR 变化的 NMSE 趋势、CIR 维度和复杂负载边界均通过自动测试。阶段 3A.2 的 20 dB、SISO 名义匹配行中 CFR NMSE 为 0.004125，而 unique strict rate 只有 0.500、等价类正确率为 1.000。这是一个直接反例：$\hat H$ 的误差较小并不意味着 T3/T5 已可唯一识别。

### 9.3 循环卷积、线性卷积与 CP 审计

**[历史日志或历史结果]** `test_stage3a` 以显式循环卷积复核频域相乘，最大差约 $3.72\times 10^{-16}$。阶段 3A.2 将线性 `h_sampled` 卷积作为审计模式，在 T2、CP=256 下得到如下数据：

| 指标 | 历史数值 | 正确解释 |
|---|---:|---|
| 物理延迟支撑 | NaN / unavailable | 当前 sampled CFR 没有因果时间原点 |
| 99% 能量支撑 | 4095 samples | 带限 IFFT 的循环旁瓣覆盖近整个周期 |
| -40 dB 支撑 | 4095 samples | 同上，非真实多径长度 |
| CP 能量覆盖 | 0.691912 | 峰对齐循环响应的能量统计 |
| 线性/循环最大绝对差 | 0.002510 | 有限帧与周期化模型差异 |
| 线性/循环相对 RMS | 0.048204 | 同一 sampled CFR 下的数值审计 |

因此，本文只能说默认循环模型在其数学语义下自洽；不能依据该表宣布现场 CP=256 足够或不足，也不能把 CIR 主峰当真实 ToA。

### 9.4 SISO 等价类与有界参数搜索

**[历史结果：`stage3a_2_protocol_summary.csv`，20 dB、`nominal_noise_20`、每报告行 200 次测试样本]**

| 观测 | 方法 | strict accuracy | unique strict rate | equivalence-class rate | ambiguity rate | false-unique rate | CFR NMSE |
|---|---|---:|---:|---:|---:|---:|---:|
| SISO | `nominal_nearest` | 0.770 | 0.500 | 1.000 | 0.500 | 0 | 0.004125 |
| SISO | `topology_only` | 0.760 | 0.500 | 1.000 | 0.500 | 0 | 0.004125 |
| SISO | `nuisance_aware_joint` | 0.785 | 0.430 | 1.000 | 0.100 | 0.470 | 0.004125 |

名义方法的 0.5 唯一严格率应被解释为：在包含 T3/T5 的对称候选集中，模型能对非等价候选作出判断，而 T3/T5 只能落入 `{T3,T5}` 类。若以最小索引或某次噪声打破 tie 强制输出标签，会错误地抬高“唯一识别”的表观成绩。

联合方法在这个数据表中 strict accuracy 略高，但 unique strict rate 从 0.500 降到 0.430，false-unique 达 0.470，且参数边界率高（同一场景的历史证据矩阵为 0.945）。这支持的结论是：**当前有界网格和正则化下，参数自由度增加存在不可辨识/过拟合风险；它不是自动提升唯一拓扑识别的算法。**

对 `load_error_10` 和 `joint_bounded`，联合 SISO 历史行分别给出 $(\mathrm{strict},\mathrm{unique},\mathrm{ambiguity},\mathrm{false\ unique})=(0.780,0.395,0.470,0.135)$ 与 $(0.715,0.490,0.475,0.035)$。[历史结果] 它们说明负载与联合参数范围都会改变距离和判决关系；不能从单个场景推出普适的噪声单调规律或现场准确率。

### 9.5 多视图结果的物理解释

**[历史结果：同一 CSV、20 dB、`nominal_noise_20`]**

| 协议 | 名义 strict / unique | 联合 strict / unique | 主要解释 |
|---|---:|---:|---|
| `dual_receiver_complete` | 1.000 / 1.000 | 1.000 / 0.990 | 额外节点响应，同时内部接收机并联负载 |
| `dual_receiver_highz_complete` | 1.000 / 1.000 | 1.000 / 0.965 | 近似降低载荷扰动，仍非真实耦合器验证 |
| `dual_receiver_counterfactual` | 1.000 / 1.000 | 1.000 / 0.920 | 分析性无扰动上界，不是可直接部署硬件 |
| `three_view_complete` | 1.000 / 1.000 | 1.000 / 0.985 | 多个完整网络视图的模型内结果 |

这些结果表明，在当前候选、端接、特征和噪声假设下，增加视图可以打破 SISO 的 T3/T5 等价。它们**不**说明“加一个实际传感器即可达到 100% 严格率”：loaded 视图改变了网络负载，high-Z 是近似，counterfactual 不能实现为硬件。为判断改善主要来自额外信息还是工作点变化，必须使用经校准的耦合器和接收输入阻抗进行后续验证。

### 9.6 宽带与窄带阶段门控

**[代码静态核对/待验证]** `test_stage3_band_configs` 的通过只说明 NB/BB 配置边界与默认配置隔离；它不包含 NB/BB CFR、CIR、识别图或 CSV。当前尚无证据判断增加带宽、变密导频或提高探测功率是否会打破严格 SISO 等价。带宽可能改善时延分辨率和近似可分性，却不能保证消除传递函数完全相等的结构等价；后者通常需要改变 $O$，例如端接、端口、反射/导纳或多视图。

---

## 10 局限性与后续研究

### 10.1 当前模型边界

1. 物理网络是等效单导体/二端口和完整节点导纳模型，不是多导体 MIMO-PLC；
2. 2--30 MHz、64 MHz、4096、CP=256 是仿真假设；NB 42--472 kHz 仅是候选设计频带，尚不能运行；
3. 当前 OFDM 是频域导频等效链路，未实现实际标准帧、编码、完整同步、CFO、PAPR 与模拟前端；
4. 噪声是白/有色/脉冲的等效模型，未由现场噪声测量校准；
5. 循环带限 CIR 和 circular-delay proxy 不给出真实 ToA；
6. 当前没有真实耦合器、PSD、输入阻抗、FDR/TFDR 仪器模型或现场市电试验；
7. 接地阻抗和故障点尚未作为经过验证的参数反演目标；
8. 有界参数网格、$\lambda$ 和特征权重不是全局最优设计。

### 10.2 何时可以直接复用通信型 OFDM

**[模型推断]** 在以下条件同时满足时，通信型 OFDM 可作为拓扑感知的 CFR 测量基线：

- 导频覆盖和插值误差足以保留待用特征；
- 端口、端接、耦合和同步定义固定；
- 类间距离相对负载、RLGC、长度与噪声引起的类内距离有足够裕量；
- 识别输出至少包含等价类与歧义，不把随机 tie 解释为唯一结果；
- 多次测量、参数先验或额外视图能管理时变负载与噪声。

若主要失败来自结构等价或缺少内部观测，优先应改善测量节点、方向、端接状态或导纳/反射观测；若这些物理边界已冻结且类间差异仍受导频稀疏、有效带宽或信道估计误差限制，才有证据进入阶段 3B 研究子载波、导频密度、导频功率、带宽或探测符号。

### 10.3 宽窄带公平比较设计

进入 Level-A NB/BB 理想 CFR 实验前，导师需确认至少三项：

1. **NB PHY：** 采用何种真实或明确仿真协议（频带、$F_s$、FFT、CP、有效载波、导频和 PSD）；
2. **BB 范围：** 只比较 2--30 MHz，还是将 30--86 MHz/1.1--86 MHz 作为另一个受高频损耗和 PSD 约束的场景；
3. **实际观测方式：** 端到端 SISO、双向、内部接收、输入阻抗还是同端反射，及其耦合器/端接条件。

公平比较应固定候选拓扑、几何、参数扰动、总发送能量、PSD 或有效频点数（分别报告）、观测时间和重复测量次数，再分别比较理想 CFR、估计 CFR、类间/类内距离及等价类指标。不要只因宽带频点更多就宣称其更适合拓扑识别。

### 10.4 接地阻抗与故障定位的后续位置

在未来扩展中，可把接地/故障等效阻抗 $Z_g(f)$ 作为 $\theta$ 中的节点或支路并联项，使其通过 $Y_{\rm net}$、反射或端到端 $H$ 改变观测；然后以“拓扑变化”和“阻抗变化”两个假设族进行联合模型比较。该表述只是可实现的建模路径，尚未完成故障定位算法、现场安全测量或准确率验证。

---

## 11 结论

本文以现有代码、阶段报告、历史 CSV/日志和可追溯文献笔记为基础，形成了 PLC OFDM 拓扑感知的理论与仿真基线。

1. RLGC—ABCD—支路回推—稳定递推/节点导纳模型定义了 $H_{rt}(f;G,\theta)$；负载、长度、端接和接收机输入阻抗都可能改变 CFR，不能把变化自动归因于拓扑。
2. 当前 OFDM 导频模型能在离散频点上获得 LS CFR 估计；它是“通信型 OFDM 的频域等效测量”，不是完整商用 PLC 收发机，也不自动提供拓扑唯一性。
3. 当前 sampled-CFR 中频域相乘与显式循环卷积数值一致；线性/循环差与带限 IFFT 周期化和有限帧边界有关，当前 circular-delay proxy 不能作真实 ToA。
4. T3/T5 说明对称 SISO 下存在明确的结构观测等价。低 CFR NMSE 或较高 strict accuracy 不能替代等价类准确率、ambiguity 和 false-unique；带噪声后的随机编号选择不是物理唯一识别。
5. 多视图在当前模型内可以提高可分性，但必须区分额外独立信息、内部接收机负载扰动和 counterfactual 上界。参数联合搜索也必须报告边界率与 false-unique，不能被称为自动改进。
6. 阶段 3B 暂不应启动。首先需要冻结 NB/BB PHY、实际端口/耦合/端接、因果时域校准与参数先验；之后才能在公平条件下判定瓶颈是否确为 OFDM 资源不足。

---

## 参考文献

> 下列条目只使用当前 `notes/01_文献索引.md`、单篇笔记和项目文件中可见的元数据。没有在当前资料中核实的作者、页码、DOI、学位授予单位或年份均标为“待核对”，而非补写。

[1] Cortés, Cañete, Díez, et al. *Channel Estimation for OFDM-based Indoor Broadband Power Line Communication Systems*. Journal of Communications and Networks, vol. 25, no. 2, pp. 151--166, 2023. DOI：待核对。项目编号：P09。

[2] Ma, So, Gunawan. *Performance Analysis of OFDM Systems for Broadband Power Line Communications under Impulsive Noise and Multipath Effects*. IEEE Transactions on Power Delivery, vol. 20, no. 2, 2005. 页码与 DOI：待核对。项目编号：P10。

[3] Pagani, Ismail, Zeddam. *Path Identification in a Power-Line Network Based on Channel Transfer Function Measurements*. IEEE Transactions on Power Delivery, vol. 27, no. 3, 2012. 页码与 DOI：待核对。项目编号：P11。

[4] Fernandez, Omri, Di Pietro. *Power Grid Surveillance: Topology Change Detection System Using Power Line Communications*. International Journal of Electrical Power & Energy Systems, vol. 145, art. 108634, 2023. DOI: 10.1016/j.ijepes.2022.108634。项目编号：P12。

[5] Passerini, Tonello. *Full Duplex Power Line Communication Modems for Network Sensing*. IEEE SmartGridComm, 2017. 页码与 DOI：待核对。项目编号：P13。

[6] Passerini, Tonello. *Power Line Network Topology Identification Using Admittance Measurements and Total Least Squares Estimation*. IEEE ICC, 2017. 页码与 DOI：待核对。项目编号：P14。

[7] Lehmann, et al. *A Diagnostic Method for Power Line Networks by Channel Estimation of PLC Devices*. IEEE SmartGridComm, 2016. 完整作者、页码与 DOI：待核对。项目编号：P15。

[8] *Inferring Power Grid Information with Power Line Communications: Review and Insights*. arXiv:2308.10598v2, 2024-09-05. 作者与正式出版信息：待核对。项目编号：P16。

[9] 王新宇. *低压电力线通信信道建模及传输特性研究*. 学位论文/来源、年份与学位单位：待核对。项目编号：P02。

[10] 苏岭东. *低压电力线通信信道噪声特性及消除研究*. 学位论文/来源、年份与学位单位：待核对。项目编号：P08。

[11] 徐国庆. *多输入多输出电力线载波通信的噪声建模和消除研究*. 学位论文/来源、年份与学位单位：待核对。项目编号：P07。

[12] 卢文冰. *网络参数对低压宽带电力线信道的影响*. 来源、年份与 DOI：待核对。

[13] 谢志远. *基于传输线理论的信道幅频特性与负载阻抗关联机制分析*. 来源、年份与 DOI：待核对。

[14] 葛松. *使用电力线通信技术的配电网故障识别与定位研究*. 来源、年份与 DOI：待核对。

---

# 附录 A：理论公式—代码函数映射

| 理论对象 | 数学公式或操作 | 代码文件/函数 | 当前验证状态 | 局限 |
|---|---|---|---|---|
| RLGC | $R',L',G',C'$ 经验频率模型 | `src/cable_rlgc.m` | 阶段 1.5 测试通过[历史日志] | 参数外推需标记 |
| $\gamma,Z_c$ | 电报方程平方根关系 | `cable_rlgc.m` | 静态核对/单元测试 | 非名义 $Z_0$ |
| ABCD | $\cosh,\sinh$ 均匀线矩阵 | `transmission_line_abcd.m` | 行列式/分段测试通过 | 长线直接法失稳 |
| 支路阻抗 | $Z_{in}$ 的 tanh 变换 | `branch_input_impedance.m` | 开短路/复负载测试通过 | 需频率合法 |
| 并联节点 | $T_{shunt}=[1,0;Y,1]$ | `shunt_abcd.m` | 静态核对 | 零阻抗显式处理 |
| 端到端传递 | $H_V,H_{port}$ | `abcd_to_transfer.m` | 端口归一化测试通过 | 2 倍仅 50/50 |
| 稳定回推 | 阻抗+衰减电压递推 | `terminated_line_response.m`、`cascade_network_stable.m` | 长线诊断通过 | 物理参数外推未验证 |
| 完整网络 | $Y_{net}V=I$ | `plc_full_network_response.m` | 阶段 2.2 一致性测试通过 | 简化端口/非 MIMO |
| OFDM 设置 | $F_s,N_{FFT},$ pilots, CP | `ofdm_config.m`、`stage3a_config.m` | 配置静态核对 | 非真实标准 PHY |
| 双频段配置 | NB/BB 边界 | `stage3_band_configs.m` | 边界测试通过[历史日志] | 未完成双频段实验 |
| OFDM 信道 | 频域相乘/加噪 | `stage3a_apply_ofdm_channel.m` | 循环等价测试通过 | sampled CFR 非物理因果 CIR |
| 接收与 LS | 去 CP、FFT、$Y/X$、插值 | `stage3a_receive_ofdm.m` | 无噪声恢复测试通过 | 无完整同步器 |
| CP 审计 | 支撑、能量、线性/循环误差 | `stage3a_cp_coverage.m` | 历史 CSV 已保存 | 物理延迟不可用 |
| 时延代理 | CIR 峰位置 | `stage3a_toa_feature.m` | 非物理 ToA 测试通过 | 非真实 ToA |
| 特征距离 | RMS raw/norm/joint | `topology_feature_distance.m` | 阶段 2.3 特征测试通过 | 权重非最优 |
| 等价类 | 连通类/容差 | `topology_observability_classes.m` | T3/T5 测试通过 | 依候选和协议 |
| 名义匹配 | $\arg\min_GD$ | `topology_nearest_match.m` | 重复性测试通过 | 参数失配 |
| 联合匹配 | $D+\lambda R$ 网格搜索 | `topology_joint_match.m` | 接口/校准分离测试通过 | 网格过拟合风险 |
| 阶段 3A.1 | 参数感知实验 | `experiments/exp14_stage3a_1_parameter_aware.m` | 历史正式结果 | 非全局最优 |
| 阶段 3A.2 | CP/协议审计 | `experiments/exp16_stage3a_2_protocol_audit.m` | 历史正式结果 | 模型内多视图 |

# 附录 B：测试与日志状态

| 状态 | 命令/日志 | MATLAB 与退出码 | 覆盖范围 |
|---|---|---|---|
| [历史日志或历史结果] | `results/logs/core_derivation_review_config_test.log` | R2024a `24.1.0.2537033`；记录显示通过 | `test_stage3_band_configs`，仅配置边界/默认隔离 |
| [历史日志或历史结果] | `results/logs/core_derivation_review_full_test.log` | R2024a；日志记录完整 `run_tests` 通过 | 阶段 1.5、2、2.1、2.2、2.3、3A、3A.1、3A.2 和 band config |
| [历史日志或历史结果] | `results/logs/core_derivation_final_report_tests.log` | 日志记录通过；该日志未保存可靠 shell exit 字段 | 后续完整回归副本 |
| [历史失败尝试] | `results/logs/core_derivation_final_report_tests_failed.log` | probe exit 1 | MATLAB 启动时 `bind: Operation not permitted`；未修改系统/源码 |
| [本次实际运行] | 无 | 本报告撰写期未新运行 MATLAB | 仅文档与静态核对 |

因此，本报告不得把历史回归通过写成“本次重新运行所有宽窄带实验”；尤其 `test_stage3_band_configs` 不表示 NB/BB 拓扑识别已经完成。

# 附录 C：已验证、模型推断与待验证事项

| 类别 | 内容 |
|---|---|
| 已验证（代码/历史测试） | RLGC/ABCD 基线、支路/端接边界、稳定递推、SISO T3/T5 等价类统计、循环卷积数值等价、线性审计接口、参数网格与多视图接口均有历史测试/数据支持。 |
| 模型推断 | 在真实端口与参数冻结后，若类内扰动仍小于类间距离，通信 OFDM 可复用作拓扑感知测量；改变观测维度通常比单纯更换分类器更可能打破结构等价。 |
| 待验证 | NB/BB 公平比较、真实 PHY、耦合器与 PSD、现场噪声/负载、物理因果 CIR、同步/CFO、MIMO、FDR/TFDR 仪器和接地故障定位。 |
