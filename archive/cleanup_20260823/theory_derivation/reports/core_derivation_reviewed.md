# PLC 拓扑识别核心理论推导：外部初稿审阅与修订版

> 本文件是对外部 AI 初稿的独立审阅版，不是对外部初稿的覆盖或续写。
> 外部初稿保留在 `report/电力线载波拓扑识别核心理论推导.md`。

## 0. 审阅范围、文件来源与证据标签

### 0.1 文件来源

用户指定的文件名为 `report/电力线载波拓扑识别核心理论推导(1).md`。在当前仓库及其项目目录中没有找到带 `(1)` 后缀的同名文件；实际存在并被审阅的是：

```text
report/电力线载波拓扑识别核心理论推导.md
```

该文件被视为外部理论初稿处理，未被修改。若带 `(1)` 后缀的文件在其他位置另有副本，应在提交导师材料前再次逐段比对。

当前 Git 仓库根目录内没有 `AGENTS.md`。本工作集的父目录存在 `../AGENTS.md`，本次已阅读其项目约束；该父目录文件不属于当前 `matlab_plc_cfr_publish` 仓库的提交内容，因此不能假设其他克隆者会自动获得它。

本次审阅使用了当前仓库的源代码、报告、文档、测试和日志，重点包括：

- `README.md`、`PUBLISHING.md`；
- `report/core_derivation.md`、`report/stage15_acceptance.md`、`report/stage2_baseline.md`、`report/stage2_1_audit.md`、`report/stage2_2_physical_multiview.md`、`report/stage2_3_observability.md`；
- `report/stage3a_communication_baseline.md`、`report/stage3a_2_model_validity_and_observation_protocol.md`；
- `docs/宽窄带OFDM与PLC拓扑感知文献综合.md`、`docs/宽窄带双频段研究设计.md`；
- `src/cable_rlgc.m`、`src/transmission_line_abcd.m`、`src/branch_input_impedance.m`、`src/shunt_abcd.m`、`src/abcd_to_transfer.m`、`src/cascade_network_stable.m`、`src/plc_full_network_response.m`；
- `src/ofdm_config.m`、`src/stage3a_config.m`、`src/stage3a_apply_ofdm_channel.m`、`src/stage3a_receive_ofdm.m`、`src/stage3a_cp_coverage.m`、`src/stage3a_toa_feature.m`；
- `src/topology_feature_distance.m`、`src/topology_observability_classes.m`、`src/topology_nearest_match.m`、`src/topology_joint_match.m`、`src/topology_evaluation_metrics.m`；
- `results/logs/core_derivation_review_config_test.log`、`results/logs/core_derivation_review_full_test.log`及阶段历史日志。

### 0.2 证据标签

全文使用以下标签，防止把不同来源的结论混写：

- **[本次运行]**：本轮 MATLAB 命令实际产生的输出；
- **[历史日志]**：本轮没有重新运行，但仓库已有正式日志、CSV 或报告记录；
- **[代码静态核对]**：由当前源代码接口、公式和参数检查支持；
- **[模型推断]**：由物理模型或已有仿真合理推断，尚无现场证据；
- **[本次未运行]**：本轮明确没有运行；
- **[待人工核对]**：需要回到论文正文、标准或硬件协议确认。

本文件不把“测试入口通过”扩大解释为“宽窄带拓扑识别已完成”，也不把历史结果改写成本次重新生成的结果。

### 0.3 本次测试复核

MATLAB 启动方式使用仓库此前验证过的批处理入口 `/home/chidan/.local/bin/matlab -batch`，未修改 MATLAB 启动器、系统库或源代码。两项命令均在仓库根目录执行，并使用独立的 MATLAB 偏好目录。

#### 新增配置边界测试

命令的核心部分为：

```matlab
cd('matlab_plc_cfr_publish');
diary('results/logs/core_derivation_review_config_test.log');
disp(version);
disp(['MATLAB_LICENSE=' num2str(license('test','matlab'))]);
addpath('src'); addpath('config'); addpath('experiments'); addpath('tests');
test_stage3_band_configs;
diary off
```

结果：

- MATLAB：`24.1.0.2537033 (R2024a)`；
- MATLAB 基础许可测试：`1`；
- 测试输出：`PASS Stage3 dual-band configuration boundaries and default isolation`；
- shell 退出码：`0`；
- 完整 MATLAB 输出：`results/logs/core_derivation_review_config_test.log`；
- **[本次运行]** 该测试只验证 NB/BB 配置边界、默认配置隔离和 CP 来源字段，不验证 NB/BB 拓扑识别实验。

#### 完整 `run_tests`

命令的核心部分为：

```matlab
cd('matlab_plc_cfr_publish');
diary('results/logs/core_derivation_review_full_test.log');
disp(version);
disp(['MATLAB_LICENSE=' num2str(license('test','matlab'))]);
addpath('src'); addpath('config'); addpath('experiments'); addpath('tests');
run_tests;
diary off
```

结果：

- MATLAB：`24.1.0.2537033 (R2024a)`；
- MATLAB 基础许可测试：`1`；
- shell 退出码：`0`；
- **[本次运行]** 阶段 1.5、2、2.1、2.2、2.3、3A、3A.1、3A.2 及 `test_stage3_band_configs` 均通过；
- 完整 MATLAB 输出：`results/logs/core_derivation_review_full_test.log`；
- MATLAB 输出中的平台警告 `Unable to load ApplicationService for command client-v1` 没有导致测试失败，但应作为本机运行环境记录保留。

本轮没有运行 NB/BB 数值识别实验、宽窄带图表生成、OFDM 波形优化、现场测量或接地故障定位。

## 1. 研究对象、统一符号与观测边界

### 1.1 拓扑—参数—观测三元关系

理论对象统一写为：

$$
H_{rt}(f;G,\theta,O),
$$

其中：

- $G$：候选电力线网络拓扑，包括节点、边、主线和支路连接关系；
- $\theta$：线路长度、单位长度 $R'(f),L'(f),G'(f),C'(f)$、负载阻抗 $Z_L(f)$、源阻抗 $Z_s$、接收端阻抗 $Z_r$、端口归一化参考阻抗和耦合器/测量误差等；
- $O$：观测方式，包括单端 SISO、双向测量、双接收节点、多端口、端到端 CFR、输入阻抗/导纳和反射/FDR 等；
- $t,r$：发送端和接收端或观测端口索引。

因此，本项目的识别问题不是无条件的 $\hat G=\arg\min_GD(H,H_G)$，而是：

$$
(\hat G,\hat\theta,\hat{\mathcal C})
 =\operatorname{Match}\bigl(\hat H;G,\theta,O\bigr),
$$

并且在给定 $O$ 下优先输出拓扑观测等价类 $\mathcal C$。只有当类内不存在结构等价且距离间隔足够大时，才可以讨论具体拓扑的唯一识别。

### 1.2 OFDM 等效观测方程

通信型 OFDM 的统一频域模型为：

$$
Y_{rt}[k]=X_t[k]H_{rt}(k;G,\theta,O)+N_{rt}[k],
$$

已知导频非零时，逐子载波最小二乘估计为：

$$
\hat H_{rt}[k]=\frac{Y_{rt}[k]}{X_t[k]}
       =H_{rt}(k;G,\theta,O)+\frac{N_{rt}[k]}{X_t[k]}.
$$

当前 MATLAB 项目首先使用阶段 2 的频域等效模型；阶段 3A 另外加入 IFFT、CP、等效循环采样 CFR、去 CP、FFT 和 LS 的链路审计。两者都不是完整商用 PLC 收发机。

### 1.3 四层证据模型

为了避免把不同实验层级混淆，当前模型应分为：

| 层级 | 输入和假设 | 可以回答的问题 | 不能直接回答的问题 |
|---|---|---|---|
| Level A | 已知 $G,\theta$，无噪声真实 CFR | 结构是否在观测 $O$ 下等价 | 现场鲁棒性、真实 PHY 性能 |
| Level B | 长度、RLGC、负载、端接和耦合误差 | 参数扰动是否掩盖拓扑差异 | 真实参数分布和硬件误差 |
| Level C | OFDM 符号、导频、采样、CP、LS/插值和同步误差 | 通信型信号能否稳定估计 CFR 特征 | 标准 PHY 或真实同步性能 |
| Level D | SISO、双向、双接收节点、多端口、反射或导纳 | 增加观测维度是否改变等价类 | 未实现仪器的现场性能 |

## 2. RLGC、电报方程与频率相关特性阻抗

### 2.1 单位长度参数

均匀线路以单位长度参数描述：

$$
R'(f)\ [\Omega/\mathrm m],\quad
L'(f)\ [\mathrm H/\mathrm m],\quad
G'(f)\ [\mathrm S/\mathrm m],\quad
C'(f)\ [\mathrm F/\mathrm m].
$$

在当前 `src/cable_rlgc.m` 中，频率必须为有限且严格正的 Hz 值。当前项目实现的示例模型为：

$$
R'(f)=R_0 10^{-5}\sqrt f,
\qquad
G'(f)=G_0k_G10^{-14}\,2\pi f,
$$

其中 $L'$、$C'$ 为代码配置的 SI 常数；具体缩放是项目/Cañete 参数化模型的一部分，不应外推为所有电缆的普适规律。$k_G$ 是经验电导修正因子，不是线路长度。

### 2.2 电报方程、传播常数和特性阻抗

在相量约定下，电报方程可写为：

$$
\frac{\mathrm dV(x)}{\mathrm dx}=-(R'+j\omega L')I(x),
\qquad
\frac{\mathrm dI(x)}{\mathrm dx}=-(G'+j\omega C')V(x).
$$

传播常数和有损特性阻抗为：

$$
\gamma(f)=\sqrt{(R'+j\omega L')(G'+j\omega C')},
$$

$$
Z_c(f)=\sqrt{\frac{R'+j\omega L'}{G'+j\omega C'}}.
$$

本项目后续统一用频率相关复数 $Z_c(f)$ 表示实际计算使用的特性阻抗。`cable_parameters.m` 中的 `Z0_nominal_ohm` 只是 270/234 Ω 一类的名义参考字段；它不是 `cable_rlgc.m` 在每个频点实际计算的 $Z_c(f)$。因此下文不再把名义 $Z_0$ 和频率相关 $Z_c(f)$ 混作同一个量。

零频率会使上述有损模型的复阻抗分支出现未定义或 $0/0$，所以代码拒绝 $f\le 0$；这不是对零频率作数值截断。

## 3. ABCD 二端口、端口方向和级联

### 3.1 当前端口约定

代码固定使用：

$$
\begin{bmatrix}V_1\\I_1\end{bmatrix}
=T
\begin{bmatrix}V_2\\I_2\end{bmatrix},
\qquad
T=\begin{bmatrix}A&B\\C&D\end{bmatrix},
$$

其中端口 1 是发送侧，端口 2 是接收侧；代码注释将电流定义为由发送端指向接收端。这个约定必须在传输线、支路并联、端接公式和图注中保持一致。不同教材可能把端口 2 电流定义为流入二端口，使用教材公式时不能直接混换符号。

### 3.2 均匀传输线矩阵

长度 $d$ 的均匀线矩阵为：

$$
T_{line}(d,f)=
\begin{bmatrix}
\cosh(\gamma d)&Z_c\sinh(\gamma d)\\
\sinh(\gamma d)/Z_c&\cosh(\gamma d)
\end{bmatrix}.
$$

在当前端口约定下，互易二端口通常满足：

$$
AD-BC=1.
$$

更准确地说，对于当前均匀线矩阵，这个等式可由 $\cosh^2x-\sinh^2x=1$ 直接得到；对互易二端口它是常见的行列式条件。**无源性不是该行列式等式的必要条件**，无源性主要用于稳定递推中的衰减和被动性检查。

`cascade_network.m` 对总矩阵计算 $\max_f|AD-BC-1|$。短线测试中最大残差达到机器精度量级；长线直接 ABCD 乘法中，大的双曲函数项相减会放大浮点误差。因此行列式残差是数值条件诊断，不是物理互易性被破坏的证据。

### 3.3 支路阻抗回推和并联矩阵

支路末端负载为 $Z_L$、长度为 $d_b$ 时，输入阻抗可写为：

$$
Z_{in}=Z_c\frac{Z_L+Z_c\tanh(\gamma d_b)}
                         {Z_c+Z_L\tanh(\gamma d_b)}.
$$

开路、短路和零长度由 `branch_input_impedance.m` 显式处理：

$$
Z_L=\infty\Rightarrow Z_{in}=Z_c/\tanh(\gamma d_b),
$$

$$
Z_L=0\Rightarrow Z_{in}=Z_c\tanh(\gamma d_b),
\qquad
d_b=0\Rightarrow Z_{in}=Z_L.
$$

在主线连接点，支路不是一段可以脱离节点直接串接的主路径矩阵，而是从连接节点看进去的并联输入导纳：

$$
Y_{branch}=1/Z_{in},
\qquad
T_{shunt}=\begin{bmatrix}1&0\\Y_{branch}&1\end{bmatrix}.
$$

多个同节点支路先在导纳域相加，再与主路径二端口按物理顺序级联。开路等效为零导纳；零欧姆支路在有限 ABCD 表示中是奇异输入，代码会明确拒绝该有限矩阵表示，而不是静默产生 Inf 参与计算。

### 3.4 端接和端口归一化

给定总 ABCD 矩阵和源/负载阻抗，代码使用开路 Thevenin 源电压 $V_s$ 定义：

$$
H_V=\frac{V_r}{V_s}
 =\frac{Z_r}{AZ_r+B+Z_s(CZ_r+D)},
$$

有限 $Z_r$ 时成立；$Z_r=\infty$ 时使用代码的极限式：

$$
H_V=\frac{1}{A+Z_sC}.
$$

端口归一化结果为：

$$
H_{port}=\frac{Z_s+Z_{port,ref}}{Z_{port,ref}}H_V.
$$

只有在 $Z_s=Z_{port,ref}=50\ \Omega$ 时，才有常用的 $H_{port}=2H_V$。如果改变 $Z_s$ 或参考阻抗，不能无条件继续使用这个 2 倍关系。

### 3.5 直接 ABCD 与稳定递推

当 $|\gamma d|$ 很大时，直接形成 $\cosh(\gamma d)$ 和 $\sinh(\gamma d)$ 并继续矩阵相乘，虽然可能暂时没有 NaN/Inf，却会让 $AD-BC$ 变成病态的大数相减。当前代码保留普通 ABCD 作为短线路和审计基线，同时使用 `terminated_line_response.m` 与 `cascade_network_stable.m` 进行稳定计算：

$$
Z_{in}=Z_c\frac{Z_L+Z_c\tanh(\gamma d)}
                         {Z_c+Z_L\tanh(\gamma d)},
$$

并使用衰减指数形式的右端/左端电压比，避免显式生成增长的双曲函数项：

$$
\frac{V_{out}}{V_{in}}
=\frac{2Z_L e^{-\gamma d}}
{(Z_L+Z_c)+(Z_L-Z_c)e^{-2\gamma d}}.
$$

网络从接收端向发送端递推；每到主线节点，先把下游等效阻抗与支路输入导纳相加，再继续向前。验收依据是短线复数 CFR 与 ABCD 一致、长线有限、被动输入阻抗实部不出现明显负值、长线分段不改变结果，而不是只看矩阵行列式。

当前测试日志给出的长线审计显示：$k_G=5$、800 m 和 1200 m 的旧 ABCD 行列式残差分别达到约 $1.55\times10^{12}$ 和 $1.55\times10^{26}$，但稳定方法的相对 CFR 交叉误差仍约为 $10^{-15}$ 量级。这些是本次完整测试输出中的数值诊断；$k_G=5$ 外推到长线路仍属于参数外推，不能当成现场可测性结论。

## 4. 完整网络与节点导纳

阶段 2.2 起，`plc_full_network_response.m` 用同一个完整网络组装节点导纳矩阵。每一段线路都通过二端口/端口导纳转换进入同一网络；内部接收机以实际并联负载进入网络方程。因此 `dual_receiver_complete` 不是把网络截断后分别算两条曲线。

节点方程抽象写为：

$$
Y_{net}(f;G,\theta,O)V(f)=I_{exc}(f),
$$

端口传递函数从解出的节点电压和激励定义得到。内部接收机有限输入阻抗会改变 $Y_{net}$ 和工作点；高阻版本只是一种近似减小扰动的模型；`dual_receiver_counterfactual` 是同一完整网络解中的分析性无负载观测，不是可直接安装的物理传感器。

## 5. OFDM、循环卷积和 CIR 边界

### 5.1 阶段 2 与阶段 3A 的参数必须分开

| 配置 | NFFT/Fs/频带 | CP | 含义 |
|---|---|---:|---|
| 阶段 2 `ofdm_config` | 4096 / 64 MHz / 2–30 MHz | 0 | 历史频域等效模型，不实例化 CP |
| 阶段 3A `stage3a_config` | 继承 4096 / 64 MHz / 2–30 MHz | 256 | 项目采样 CFR/ IFFT/CP 审计的仿真假设 |
| NB 候选 | 42–472 kHz 设计范围 | 待确认 | 不可运行，PHY 参数尚未冻结 |

阶段 3A 的 CP=256 不是由物理线路时延扩展反推得到，也不是已确认的 PLC 标准参数。`src/stage3a_config.m` 和 `src/stage3_band_configs.m` 现在分别保存 CP 来源字段，避免与阶段 2 的 CP=0 静默混淆。

### 5.2 频域乘法与显式循环卷积

把有效采样 CFR 嵌入 $N$ 点频域向量 $H_{full}[k]$，并令：

$$
h_{sampled}[n]=\operatorname{IDFT}_N\{H_{full}[k]\},
$$

则当前循环基线的 payload 输出为：

$$
y_{circ}=\operatorname{IDFT}_N
\{\operatorname{DFT}_N(x)H_{full}\}
       =x\circledast_N h_{sampled}.
$$

`stage3a_apply_ofdm_channel.m` 的 `circular_sampled_cfr` 与 `stage3a_explicit_circular_convolution.m` 实现的是同一 $N$ 点循环运算。**[本次运行]** 完整测试报告最大差异约 $3.72\times10^{-16}$，因此数值等价成立。

这只证明离散数学实现一致，不证明从连续传输线模型得到的真实因果时域冲激响应已经被完整构造。

### 5.3 线性审计模式和 CP 物理条件

`linear_sampled_cfr` 使用同一 `H_full` 的 IFFT 响应，对带 CP 的整帧做显式有限线性卷积，再截取接收帧。它用于审计循环边界和 CP 影响，不是已校准的连续时间 PLC 信道。

若要由 CP 消除线性卷积导致的符号间干扰，必须知道一个具有物理时间原点的因果信道响应，其有效时延扩展不超过 CP 长度，并且同步、采样时钟、滤波器尾部和保护间隔定义相容。当前 `h_sampled` 来自 2–30 MHz 有限频带的正频率采样，未测频点置零，且被 IFFT 周期化；因此它没有可直接解释的物理传播起点。

当前 CP 审计中的 `physical_delay_support_samples` 为 NaN 是有意的模型边界，不是计算失败。99% 能量支持和 $-40$ dB 阈值支持可能接近整个 IFFT 长度，是有限带宽、频点嵌入、周期化和旁瓣的结果。`cp_energy_fraction` 只表示在当前循环旋转支撑定义下，前 `CP+1` 个采样承载的离散能量比例，不能直接等价为现场 CP 覆盖率。

因此：

- 当前循环模型与显式循环卷积一致；
- 线性模式可以量化当前采样响应的边界差异；
- CP=256 在项目等效模型中可运行，但其“物理充分性”尚未建立；
- 当前不能据此宣称真实 PLC 系统 CP 不足或足够。

### 5.4 CFR、循环带限 CIR 和时延代理

当前仅把有效正频率复数 CFR 放入 `NFFT` 频域向量，再做 IFFT；没有负频率共轭补全、完整模拟滤波器、时域同步和物理时间零点。因此输出统一命名为：

> circular band-limited CIR（循环带限信道冲激响应）。

`stage3a_toa_feature.m` 的主峰输出统一称为 **circular-delay proxy（循环时延代理）**，不能称真实 ToA、传播距离或物理测距。当前 `src/` 没有独立实现 $\tau_g(f)=-\mathrm d\phi/\mathrm d\omega$ 的群时延函数；配置中的 `toa_or_group_delay_proxy` 只是观测类型枚举。因此在没有新增源代码前，报告中不能写“已实现群时延”，只能写“循环时延代理”。

## 6. 拓扑匹配、距离和可辨识性

### 6.1 候选集合与拓扑变量

候选库 `topology_candidates.m` 包含 T1–T6 六个小型树拓扑。阶段 3A 的部分正式实验使用 `candidate_indices=[2,3,4,5]`，因此报告中必须区分“候选库 T1–T6”和“某一实验实际使用的 T2–T5”。线路参数、负载和端接应作为 $\theta$ 或实验扰动，而不是把所有 CFR 差异都称为拓扑差异。

### 6.2 特征距离

项目同时保留绝对量和形状量：

归一化复数 CFR 形状距离：

$$
D_{complex,norm}(a,b)=
\left\|\frac{a}{\|a\|_2}-\frac{b}{\|b\|_2}\right\|_2.
$$

它对整体复数尺度不敏感，适合比较相对频率形状，但会丢失绝对衰减和端口标定信息。

未归一化绝对复数距离：

$$
D_{complex,raw}(a,b)=\|a-b\|_2.
$$

它保留绝对复数幅相差异，但对源/负载、耦合器增益和测量标定误差更敏感。阶段 2.3 的等价类定义主要基于归一化复数 CFR 形状；因此“等价”应准确写成“归一化复数 CFR 形状或相对响应等价”，不能扩大为“原始绝对标定复数 CFR 完全等价”。

其他距离包括归一化/未归一化 dB 幅值、掩膜或加权相位、循环带限 CIR 和幅相联合距离。例如幅相联合可写为：

$$
D_{ap}=w_aD_a+w_\phi D_\phi,
\qquad w_a+w_\phi=1,
$$

当前权重和正则化参数是审计配置，不是经过充分优化得到的“最优”设置。

### 6.3 联合拓扑—参数匹配

参数感知基线使用有界网格和正则项：

$$
(\hat G,\hat\theta)=
\arg\min_{G,\theta\in\Theta}
\left[D\bigl(\hat H,H(G,\theta,O)\bigr)
      +\lambda R(\theta)\right].
$$

其中 $\Theta$ 包含长度比例、支路长度比例、负载比例以及端接参数等边界。27 点参数网格和 $\lambda=0.01$ 是有界审计基线，不是最优算法证明。增加自由度可能把噪声或模型误差拟合成参数变化，降低 ambiguity 却增加 false-unique 风险。

### 6.4 指标定义

- `strict_accuracy`：具体候选编号预测正确的比例；
- `equivalence_class_accuracy`：预测落入真实结构观测等价类的比例；
- `unique_strict_accuracy` / `strict_unique_rate`：不处于结构/数值歧义时的具体编号正确率或正式配置中的唯一识别率，报告时必须注明分母定义；
- `ambiguity_rate`：算法按 tie 容差或等价类规则报告无法唯一决定的比例；
- `false_unique_rate`：真实处于结构等价类、但算法因噪声或参数自由度给出某个成员的唯一选择比例；
- `distance_margin`：最优和次优候选距离间隔；
- `edge_precision`、`edge_recall`、`edge_F1`：把预测拓扑和真实拓扑转换为边集合后的指标。

通信层的 CFR NMSE、幅值误差和相位误差只评价信道估计，不能替代上述拓扑层指标。

## 7. T3/T5 对称等价：严格的模型内反例

### 7.1 不使用错误的“信息维数”证明

外部初稿把“一个标量复函数的信息量低于拓扑自由度”作为严格不可识别证明。这不是可靠的严格证明：函数空间可能携带无限多个频率样本，参数维数也不能直接推出两个物理模型必然产生相同观测。

正确表述是：

> 单端 SISO 端到端观测不能保证映射 $(G,\theta)\mapsto H_{rt}(f;G,\theta,O)$ 是单射。是否可唯一识别必须由具体网络、端口、端接和观测频带验证。

### 7.2 T3/T5 的结构等价反例

当前候选拓扑中，T3 与 T5 在均匀 80 m 主线、相同支路参数、相同负载以及对称 $Z_s=Z_r=50\ \Omega$ 端接下，是关于端点反转的镜像网络。对互易线路，端点交换和主线方向反转不改变该对称单端 SISO 端到端传递关系；在当前归一化复数 CFR 定义下，它们构成明确的结构观测等价反例：

$$
H_{T3}(f;\theta,O_{siso})
=H_{T5}(f;\theta,O_{siso})
$$

在理想数学模型中成立，数值计算只应留下浮点误差量级的距离。这个反例足以说明唯一性不能由分类器算法单独创造。

带噪声时，两个候选分数可能不再精确相等；此时随机选中 T3 或 T5 不是物理可辨识。正式评价应报告 `{T3,T5}` 等价类、ambiguity 和 false-unique，而不能把一次浮点最小值当成唯一拓扑。

### 7.3 观测配置的作用

不对称端接、固定角色的反向测量、端点固定双向测量、完整网络内部接收节点和多视图可能改变观测映射。但必须分清：

1. 是否新增了独立的电压/电流/传递观测；
2. 是否改变了接收机并联负载和网络工作点；
3. 是否只是 counterfactual 的数学计算；
4. 是否仍然是端到端 CFR，而不是输入阻抗、反射或节点导纳。

阶段 3A.2 多视图严格率为 1 的结果是当前完整网络、端接、参数边界和模型噪声下的模型内结果，不是现场硬件可达到的保证。

## 8. 阶段结果和证据分层

### 8.1 本次运行直接支持

1. MATLAB R2024a 下，完整 `run_tests` 以及独立的 `test_stage3_band_configs` 均退出码 0。
2. 阶段 1.5 的基础 RLGC、ABCD、分段等价、无支路、负载极限、稳定递推和长线诊断测试通过；长线旧 ABCD 的病态残差被保留为诊断，不被当作正式稳定结果。
3. 阶段 2–2.3、3A、3A.1 和 3A.2 测试通过，包括 T3/T5 等价、结构等价与数值 tie 分离、完整网络多视图、等效 OFDM 链路、线性/循环审计接口和配置边界。
4. 频域乘法与同一采样 CFR 的显式循环卷积最大误差约 $3.72\times10^{-16}$。
5. `stage3a_toa_feature` 被测试为非物理 ToA 接口；当前输出应称循环时延代理。
6. 配置边界测试通过不代表 NB/BB 双频段实验完成。当前 NB 仍是不可运行的待确认配置，BB 仍是项目仿真假设。

### 8.2 历史正式结果和代码报告支持

以下数字来自既有阶段报告/CSV/正式日志，不是本轮重新运行实验：

| 条件 | 方法 | strict | unique | class | ambiguity | false unique | 说明 |
|---|---|---:|---:|---:|---:|---:|---|
| 20 dB，`siso_forward` | `nominal_nearest` | 0.770 | 0.500 | 1.000 | 0.500 | 0 | 阶段 3A.2 独立测试 split |
| 20 dB，`siso_forward` | `topology_only` | 0.760 | 0.500 | 1.000 | 0.500 | 0 | 同一观测和特征接口 |
| 20 dB，`siso_forward` | `nuisance_aware_joint` | 0.785 | 0.430 | 1.000 | 0.100 | 0.470 | 有界参数自由度增加了 false-unique 风险 |
| 20 dB，`dual_receiver_complete` | `nominal_nearest` | 1.000 | 1.000 | 1.000 | 0 | 0 | 完整网络、并联接收负载 |
| 20 dB，`three_view_complete` | `nominal_nearest` | 1.000 | 1.000 | 1.000 | 0 | 0 | 多视图完整网络模型 |

上表数字应追溯到 `results/data/stage3a_2_protocol_summary.csv` 和 `report/stage3a_2_model_validity_and_observation_protocol.md`。它们是历史正式结果，不应写成此次核心推导审阅新生成的实验。

### 8.3 根据模型推断

- 观测等价、端接和节点配置是当前拓扑唯一性的首要限制；不能据此推出 NB/BB 带宽一定不重要。
- 全导频仿真目前没有证据表明导频密度是主要瓶颈，但 NB/BB 带宽、频率采样和真实标准 PHY 的影响尚未做公平实验，因此不能写成“瓶颈不是带宽不足”。
- 宽带可能提高近似路径和时延特征的分辨率，但不能消除严格的端到端 SISO 结构等价。
- 参数联合搜索可能减少名义参数失配，但自由度增加会把噪声、负载或模型误差解释为参数变化，因而可能降低唯一识别可信度。

### 8.4 本次未运行或尚未完成

- NB/BB 理想 CFR、OFDM 估计、拓扑识别的双频段数值比较；
- 30–86 MHz 扩展实验；
- 真实 G.hn、HomePlug AV2、IEEE P1901 或 NB-PLC PHY 复现；
- 真实耦合器、现场端接、现场有色/脉冲噪声、完整同步/CFO、MIMO 多导体测量；
- FDR/TFDR 仪器模型、输入阻抗/导纳硬件观测；
- 接地故障定位；
- 阶段 3B 导频、子载波、功率、带宽或波形优化。

## 9. 外部初稿与本修订稿的主要差异

1. **运行状态修正**：外部初稿写“静态检查、未运行 MATLAB”；本轮实际运行了配置测试和完整 `run_tests`，新状态由两个 `core_derivation_review_*` 日志支持。
2. **AGENTS 位置修正**：当前仓库没有嵌套 `AGENTS.md`；仅父工作集存在该文件，不能写成仓库内或克隆后自动存在。
3. **SISO 证明修正**：删除“标量复函数信息量低于拓扑自由度”的严格证明，改用“映射不保证单射 + T3/T5 镜像等价反例”。
4. **带宽结论收窄**：不再断言当前瓶颈已经与带宽无关；只记录全导频仿真尚无证据表明导频密度是主要瓶颈，NB/BB 尚未验证。
5. **互易性表述修正**：改为“当前端口约定下，互易二端口通常满足 $AD-BC=1$；无源性不是必要条件”，并区分理论恒等式与病态矩阵的浮点残差。
6. **$Z_0/Z_c$ 统一**：实际逐频率计算统一使用复数 $Z_c(f)$，名义 `Z0_nominal_ohm` 仅作参考。
7. **CP 边界修正**：明确阶段 2 CP=0、阶段 3A CP=256；CP=256 是仿真假设，没有由物理时延扩展推出。
8. **时延术语修正**：当前没有独立群时延实现，统一使用“循环带限 CIR”和“循环时延代理”，不称真实 ToA。
9. **文献编号修正**：双频段文档中的新增文献统一使用 P09–P16；42–472 kHz 的项目候选说明使用 P12，不再使用含混的 P1/P8。
10. **多节点模型修正**：将阶段 2.1 历史截断前缀网络与阶段 2.2 起的完整网络模型分开；截断模型不能作为真实多端口证据。
11. **距离定义补充**：明确归一化复数 CFR 形状距离和 raw 绝对复数距离的不同，等价类结论不能扩大为绝对标定等价。
12. **结果来源修正**：把阶段 3A.2 数字标记为历史正式 CSV/报告来源，并保留 `false_unique=0.470` 的解释；不把本轮测试通过写成重新完成实验。

## 10. 代码函数对应关系

| 理论对象 | 代码 | 当前边界 |
|---|---|---|
| RLGC、$\gamma$、$Z_c(f)$ | `cable_rlgc.m` | $f>0$，SI 单位；项目经验参数化 |
| 名义参考阻抗 | `cable_parameters.m` | `Z0_nominal_ohm` 不是逐频率计算的 $Z_c$ |
| 均匀线 ABCD | `transmission_line_abcd.m` | 当前 `[V1;I1]=T[V2;I2]` 约定 |
| 支路输入阻抗 | `branch_input_impedance.m` | 标量/复数/频率向量、开路、短路、零长度 |
| 并联支路 | `shunt_abcd.m` | 导纳矩阵；零欧姆有限 ABCD 奇异 |
| 端接和端口归一化 | `abcd_to_transfer.m` | $H_V$ 与 $H_{port}$；$2H_V$ 仅适用于特定 50 Ω 关系 |
| 普通级联审计 | `cascade_network.m` | 长线可病态；保留作短线基线 |
| 稳定阻抗/电压比递推 | `terminated_line_response.m`、`cascade_network_stable.m` | 长线正式计算和物理约束审计 |
| 完整多节点网络 | `plc_full_network_response.m` | 内部接收负载进入同一网络 |
| 频域 OFDM 导频 | `ofdm_apply_channel.m`、`ofdm_channel_estimate_ls.m` | 阶段 2 等效模型 |
| IFFT/CP/循环采样 CFR | `stage3a_apply_ofdm_channel.m` | 不是连续时间物理信道 |
| 去 CP/FFT/LS/插值 | `stage3a_receive_ofdm.m` | 简化同步和采样误差接口 |
| CP 支撑审计 | `stage3a_cp_coverage.m` | 无物理时间原点，支持长度是循环模型指标 |
| 时延特征 | `stage3a_toa_feature.m` | circular-delay proxy，不是 ToA |
| 距离和特征 | `topology_feature_distance.m` | 同时支持形状、raw 幅值、复数和联合特征 |
| 结构等价类 | `topology_observability_classes.m` | 主要按归一化复数 CFR 形状和容差定义 |
| 最近邻和等价评价 | `topology_nearest_match.m`、`topology_equivalence_evaluation.m` | 分开 strict、class、ambiguity、false-unique |
| 参数联合匹配 | `topology_joint_match.m` | 有界网格基线，不是全局最优或统计最优证明 |

## 11. 统一的已验证、推断和待验证清单

### 11.1 已验证

- 正频率输入、RLGC、短线 ABCD、分段等价、支路极限和稳定递推测试通过；
- 阶段 2 与阶段 3A 的 OFDM 等效链路测试通过；
- 频域乘法与显式循环卷积在同一采样模型下数值一致；
- T3/T5 在对称 SISO 下应作为结构等价类报告，带噪随机二选一不改变这一物理结论；
- 当前配置测试明确区分阶段 2 CP=0 与阶段 3A CP=256；
- 新增配置边界和完整回归测试在 MATLAB R2024a 中本轮通过。

### 11.2 根据模型推断

- 增加端接方向、接收节点或多视图有可能打破当前 T3/T5 的等价，但效果取决于新增观测是否独立以及接收机是否改变网络负载；
- 参数感知匹配可以减少部分名义参数失配，但不能创造不存在于观测中的信息；
- 更宽频带可能提高有限带宽下的路径分辨率，不能保证消除严格端到端 SISO 等价；
- 负载变化、线路参数变化和拓扑变化必须分开建模，否则会产生拓扑变化假阳性。

### 11.3 待验证

- 真实 NB/BB PHY、有效子载波、PSD 缺口、导频结构、CP 和同步方式；
- 2–30 MHz 与 NB 候选频带在相同有效点数、总能量、观测时间和参数扰动下的公平识别比较；
- 真实耦合器、端接、输入阻抗/导纳和反射测量；
- 现场有色、脉冲、周期噪声和负载时变；
- 多导体/MIMO-PLC 的独立观测自由度；
- 真实市电实验和接地故障定位。

## 12. 当前阶段门控结论

本次工作不启动阶段 3B。当前可以提交的成果是“传输线/ABCD—OFDM 等效 CFR—拓扑等价类”的模型内理论和测试审计，不能提交为宽窄带拓扑识别已经完成。

进入 Level-A 双频段理想 CFR 实验之前，至少需要导师确认：

1. 采用哪一个真实 NB-PLC PHY 或明确声明为纯研究候选配置；
2. BB 是否只研究 2–30 MHz，还是扩展到 30–86 MHz，并确认对应 RLGC、PSD 和耦合器适用范围；
3. 实际可用观测方式是端到端 SISO、双向、双接收节点、多端口、输入导纳还是 FDR/TFDR。

在上述问题冻结后，NB/BB 比较必须使用相同候选拓扑、相同线路/负载扰动、相同总发送能量、相同有效频点数量和相同观测时间。只有在这些因素固定后，若类间不可分仍主要由频率资源不足造成，才有充分理由讨论阶段 3B 的导频或子载波设计。

## 13. 可转换为 Word 的最终章节目录

1. 研究问题、观测方式和拓扑等价类定义
2. 统一符号、单位和模型层级
3. RLGC 参数、电报方程、传播常数与复特性阻抗
4. 均匀传输线 ABCD 矩阵、端口约定与互易性
5. 支路阻抗回推、并联导纳和树网络级联
6. 长线路数值病态与稳定阻抗/电压比递推
7. 完整节点导纳网络与多视图观测
8. OFDM 导频、LS 信道估计和循环采样 CFR 模型
9. CP、线性/循环卷积、循环带限 CIR 与循环时延代理
10. CFR 特征、距离函数、拓扑/参数联合匹配
11. 结构观测等价、T3/T5 反例和等价类评价
12. 阶段 1.5–3A.2 的代码验证与正式历史结果
13. 已验证结论、模型推断和待验证问题
14. 宽窄带双频段实验的前置条件与阶段 3B 门控
15. 附录：公式—代码映射、测试命令、日志和人工核对清单

## 14. 仍需人工核对的公式、数字和文献编号

1. 用于论文引用的 RLGC 参数、Cañete 模型校准长度和 $k_G$ 适用范围，应回到原始论文正文确认页码和公式号；本文件只核对当前代码实现。
2. P09–P16 的统一编号应与 `notes/01_文献索引.md` 和各篇笔记逐项核对；若外部初稿的 `(1)` 文件是另一版本，应重新核对所有 P 编号。
3. 阶段 3A.2 的 0.770、0.500、0.785、0.430、0.100、0.470 等数字应以 `stage3a_2_protocol_summary.csv` 的列定义为准，提交 Word 前核对分母和四舍五入。
4. `CP=256`、`Fs=64 MHz`、`NFFT=4096`、`2–30 MHz` 只能作为当前项目仿真假设；不能在没有标准或论文直接证据时写成标准 PHY 参数。
5. 任何把 `H_{rt}`、输入阻抗 $Z_{PL}$、反射系数 $\rho$、FDR trace 或节点导纳 $Y$ 放在同一公式中的写法，都应再次核对其端口激励、测量位置和耦合器假设。

