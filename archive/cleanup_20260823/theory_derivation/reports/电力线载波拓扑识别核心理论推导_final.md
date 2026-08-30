# 电力线载波拓扑识别核心理论推导报告

## ——从 RLGC/ABCD 正向模型到 OFDM 信道估计、拓扑匹配与可辨识性

**面向导师汇报版本**

> 本报告只讨论拓扑变化下的 PLC/OFDM 理论与 MATLAB 仿真模型。它不声称已经完成接地故障定位、商用 PLC 收发机、现场耦合器或真实市电实验。

## 摘要

本项目研究的问题是：在给定电力线网络拓扑、线路参数、负载和端口观测条件下，能否利用 PLC 信号的信道频率响应（channel frequency response, CFR）及其派生特征，识别候选网络拓扑或至少识别其观测等价类。

报告建立统一链条：

```text
探测信号/OFDM 导频 X
→ 电力线网络 H_rt(f;G,theta,O)
→ 接收信号 Y
→ CFR 估计 H_hat
→ CFR/CIR/循环时延代理/阻抗等特征
→ 候选拓扑匹配和参数联合搜索
→ 严格拓扑、等价类和边级指标
```

核心结论是：当前传输线、支路阻抗回推、稳定递推、完整节点网络和 OFDM 等效信道估计接口已经形成可测试的模型链；在 50/50 Ω 对称端接的单端 SISO 观测下，T3/T5 镜像拓扑构成结构观测等价类，不能通过改变最近邻算法而获得可信的唯一识别。阶段 3A.2 的历史正式结果显示，参数联合搜索可能降低 ambiguity，却可能增加 false-unique；多视图在当前完整网络模型中改善可分性，但有限输入阻抗会改变网络工作点。

当前报告没有完成 NB/BB 双频段数值比较。NB 的 42–472 kHz 只是候选研究频带，BB 的 2–30 MHz、$F_s=64$ MHz、NFFT=4096 和 CP=256 是项目仿真假设，不是已确认的标准 PHY 参数。因此，本报告支持的是模型内阶段性结论，而不是现场拓扑识别性能结论。

---

## 0. 资料、证据和运行状态说明

### 0.1 输入资料检查

本次检查的 Git 仓库提交号为：

```text
f663bda04f9ef541db28be2cff9aeb5399577150
```

工作区在写作前已有用户修改，状态不是干净工作树。本报告没有覆盖这些修改，没有修改论文原件、MATLAB 源代码或已有 MAT/CSV 结果。

当前仓库根目录没有嵌套的 `AGENTS.md`。父工作集存在 `../AGENTS.md`，本次已按其研究、证据和文件安全要求工作；但该父目录文件不属于当前仓库提交，因此其他克隆者不能假定会自动获得它。

用户指定的 `core_derivation_reviewed_corrected.md` 在当前仓库和可见项目目录中未找到，也没有可读取的本地附件副本。本报告没有假定该缺失文件的内容；实际参考的是仓库现有的 `report/core_derivation_reviewed.md`、`report/core_derivation.md`、阶段报告、源代码和结果日志。若导师提供的 corrected 文件与现有 reviewed 版本不同，应在正式提交前再做逐段差异审阅。

### 0.2 证据标签

全文按以下方式区分证据：

- **[本次运行]**：本次命令实际进入 MATLAB 并产生的输出；
- **[历史日志]**：此前已经生成的正式日志、CSV、MAT 或报告记录；
- **[代码核对]**：由当前源码接口和公式静态核对得到；
- **[模型推断]**：物理模型内的合理推论，不等于现场证据；
- **[本次未运行]**：本轮没有重新运行；
- **[待确认]**：需要导师、原始论文、标准或硬件协议进一步确认。

### 0.3 MATLAB 测试状态

上一轮在当前项目代码上实际运行并保存了：

- `results/logs/core_derivation_review_config_test.log`：`test_stage3_band_configs`，MATLAB R2024a `24.1.0.2537033`，退出码 0；
- `results/logs/core_derivation_review_full_test.log`：完整 `run_tests`，MATLAB R2024a `24.1.0.2537033`，退出码 0。
- `results/logs/core_derivation_final_report_tests.log`：本轮报告写作前启动的完整 `run_tests` diary，日志末尾包含阶段 1.5–3A.2 和双频段配置边界测试的全部 PASS 输出；本轮 shell 回传的退出码未可靠保留，因此退出码以同一代码状态下的上一份完整日志（退出码 0）为准，不把 diary 内容外推为新的退出码证据。

这些历史日志显示阶段 1.5、2、2.1、2.2、2.3、3A、3A.1、3A.2 和双频段配置边界测试均通过。

在上述完整测试 diary 之后，本轮又尝试用最小启动探针复核 MATLAB，但启动探针在进入解释器前失败：

```text
Fatal Error:
Unable to launch /home/chidan/Matlab/bin/glnxa64/MATLAB
because: bind: Operation not permitted [system:1]
```

退出码为 1，完整记录在 `results/logs/core_derivation_final_report_tests_failed.log`。因此，失败的是后续最小启动探针，而不是把已有完整 diary 的 PASS 输出改写成失败；但由于探针失败，本轮没有再生成一份带可靠 shell 退出码回传的独立全量测试记录。测试数值引用均明确标为日志或历史正式结果。

---

# 1. 研究问题与总体流程

## 1.1 研究对象

电力线载波通信（power line communication, PLC）拓扑识别的目标，是利用电力线作为传输介质时产生的电压、电流、传递函数、反射响应或节点导纳变化，判断候选网络的连接关系、支路位置、节点关系或拓扑变化。

当前项目只研究**拓扑发生变化**这一主线。负载变化、线路长度变化、RLGC 参数变化和端接变化作为参数扰动或混淆因素处理；接地阻抗变化和接地故障定位只作为后续研究问题，不写成已经完成的功能。

## 1.2 拓扑、参数、观测与信道

统一物理响应写为：

$$
H_{rt}(f;G,\theta,O),
$$

其中：

- $G$ 是拓扑结构，包含节点、边、主线和支路连接关系；
- $\theta$ 是线路长度、$R',L',G',C'$、负载、端接、耦合器和测量误差等参数；
- $O$ 是观测方式，决定发送端、接收端、节点、端口和测量算子；
- $t$、$r$ 分别表示发射和接收角色；
- $H_{rt}$ 可以是端到端 CFR、多个传递函数组成的多视图向量，或在另一个测量模型下的输入阻抗/导纳等。

观测方式不是脱离端口边界的“额外信息源”。改变 $O$ 可能同时改变端接条件、接收机负载、激励方向和测量量，必须把这些物理边界写入 $\theta$ 和观测配置。

## 1.3 完整研究流程

### 物理正向层

给定 $(G,\theta,O)$，由 RLGC、传输线、ABCD、节点导纳或完整网络方程生成：

$$
H_{rt}(f;G,\theta,O).
$$

### 通信观测层

在 OFDM 有效子载波 $f_k$ 上发送已知导频：

$$
Y_{rt}[k]=X_t[k]H_{rt}(f_k;G,\theta,O)+N_{rt}[k].
$$

### 估计和特征层

由导频获得：

$$
\hat H_{rt}[k]=Y_{rt}[k]/X_t[k],
$$

再提取幅值、相位、复数 CFR、循环带限 CIR、循环时延代理，或在有对应测量硬件时提取输入阻抗、反射系数或节点导纳。

### 反演和评价层

把观测特征与候选库比较：

$$
\hat G=\operatorname{Match}(\hat H,O),
$$

同时输出具体拓扑编号、物理等价类、歧义率、false-unique 和边级 Precision/Recall/F1。

## 1.4 研究链条和真实商用 PHY 的区别

当前模型分为三层：

1. **物理网络模型**：RLGC、传播常数、复特性阻抗、ABCD、稳定递推和完整节点网络；
2. **通信型 OFDM 等效模型**：在离散频点使用 $Y=XH+N$，阶段 3A 增加 IFFT/CP/FFT/LS 的循环采样 CFR 链路；
3. **真实商用 PLC PHY**：需要确认标准、有效子载波、前导、导频、PSD notches、同步、CFO、PAPR、编码和耦合器。

项目目前只完成前两层的模型内基线，不能称为完整商用 PLC 收发机。

---

# 2. 统一符号、单位和假设

## 2.1 符号表

| 符号 | 中文/英文含义 | 单位或类型 |
|---|---|---|
| $G$ | 电力线拓扑 / network topology | 图结构 |
| $\theta$ | 线路、负载、端接和耦合参数 / physical parameters | 参数集合 |
| $O$ | 观测方式 / observation configuration | 配置 |
| $f$ | 频率 / frequency | Hz |
| $\omega=2\pi f$ | 角频率 / angular frequency | rad/s |
| $R'$ | 单位长度电阻 / resistance per unit length | $\Omega$/m |
| $L'$ | 单位长度电感 / inductance per unit length | H/m |
| $G'$ | 单位长度电导 / conductance per unit length | S/m |
| $C'$ | 单位长度电容 / capacitance per unit length | F/m |
| $\gamma$ | 传播常数 / propagation constant | 1/m |
| $Z_c(f)$ | 频率相关复特性阻抗 / complex characteristic impedance | $\Omega$ |
| $T=[A,B;C,D]$ | ABCD 二端口矩阵 / transmission matrix | 无量纲/混合单位 |
| $Z_s$ | 源阻抗 / source impedance | $\Omega$ |
| $Z_r$ | 接收端负载 / receiver termination | $\Omega$ |
| $Z_{port,ref}$ | 端口归一化参考阻抗 / port reference impedance | $\Omega$ |
| $H_V$ | 开路 Thevenin 源电压到接收电压的传递函数 | 复数 |
| $H_{port}$ | 端口归一化 CFR | 复数 |
| CFR | 信道频率响应 / channel frequency response | 复数随频率变化 |
| CIR | 信道冲激响应 / channel impulse response | 离散或连续时域 |
| ToA | 到达时间 / time of arrival | s |
| circular-delay proxy | 循环时延代理 | 样点或 s |
| $X_t[k]$ | 发射 OFDM 导频 / known pilot | 复数 |
| $Y_{rt}[k]$ | 接收频域样本 / received subcarrier | 复数 |
| $N_{rt}[k]$ | 等效噪声/测量误差 | 复数 |

频率在 MATLAB 内部统一为 Hz，长度统一为 m，RLGC 统一使用 SI 单位。所有带宽、采样率和 CP 数值都必须标注其来源是标准、论文、代码默认值还是仿真假设。

## 2.2 统一信道和观测表示

物理端到端信道写为：

$$
H_{rt}(f;G,\theta).
$$

在给定端口和测量操作 $O$ 后，观测响应写为：

$$
H_O(f;G,\theta)=\mathcal M_O\left(H_{rt},Z_s,Z_r,Z_L,\text{coupler}\right).
$$

这里的 $\mathcal M_O$ 不是凭空增加信息，而是说明端口边界、源激励、负载和观测组合。例如：

- 普通 OFDM 端到端 CFR：$H_{rt}$；
- 双接收节点：多个完整网络节点电压传递函数组成的向量；
- 输入导纳：由节点电压/电流测量定义的 $Y_{in}$；
- FDR/TFDR：同端激励、反射或输入阻抗测量下的另一种观测模型。

普通端到端 OFDM CFR 不能自动等同于 FDR/TFDR、输入阻抗或节点导纳。

## 2.3 当前假设

- 拓扑为小规模树网络，候选库包含 T1–T6；部分阶段 3A 正式实验使用 T2–T5；
- 线路采用频率相关或项目经验 RLGC；
- 支路通过分布参数线路先回推为输入阻抗，再并入连接节点；
- 端到端默认使用 50 Ω 源/接收端，但实验可以显式改变端接；
- 阶段 2 使用纯频域等效信道；阶段 3A 使用采样 CFR 的等效 IFFT/CP/FFT 链路；
- 当前白噪声/有色噪声/脉冲噪声主要是等效仿真模型，不等于现场 PLC 噪声；
- 当前没有完整多导体传输线、MIMO 耦合器寄生、CFO、完整同步、编码和 PAPR；
- 当前不包含接地故障定位的完整测量模型。

---

# 3. 传输线 RLGC 模型

## 3.1 单位长度参数

均匀传输线由单位长度参数描述：

$$
R'(f)\ [\Omega/\mathrm m],\quad
L'(f)\ [\mathrm H/\mathrm m],\quad
G'(f)\ [\mathrm S/\mathrm m],\quad
C'(f)\ [\mathrm F/\mathrm m].
$$

代码 `cable_rlgc.m` 对输入频率执行有限性和严格正值检查。当前工程经验模型示例为：

$$
R'(f)=R_0\,10^{-5}\sqrt f,
$$

$$
G'(f)=G_0 k_G\,10^{-14}(2\pi f),
$$

而 $L'$ 与 $C'$ 从电缆配置换算为 H/m 和 F/m。这里的具体形式是项目使用的经验参数化，不应被表述为所有电缆的普适模型。

## 3.2 电报方程

在相量约定下，电报方程为：

$$
\frac{\mathrm dV(x)}{\mathrm dx}=-(R'+j\omega L')I(x),
$$

$$
\frac{\mathrm dI(x)}{\mathrm dx}=-(G'+j\omega C')V(x).
$$

从而有：

$$
\frac{\mathrm d^2V}{\mathrm dx^2}=\gamma^2V,
\qquad
\frac{\mathrm d^2I}{\mathrm dx^2}=\gamma^2I.
$$

## 3.3 传播常数和复特性阻抗

传播常数为：

$$
\boxed{\gamma(f)=
\sqrt{(R'+j\omega L')(G'+j\omega C')}}.
$$

复特性阻抗为：

$$
\boxed{Z_c(f)=
\sqrt{\frac{R'+j\omega L'}{G'+j\omega C'}}}.
$$

代码实际逐频率使用的是复数 $Z_c(f)$。`cable_parameters.m` 中的 `Z0_nominal_ohm` 是名义参考值，例如 270 Ω 或 234 Ω，不替代上述计算结果。名义值和频率相关复数不能在公式或图例中混写。

## 3.4 适用范围和参数外推

当前模型的 Cañete/工程经验参数有原始校准范围。项目报告已明确，0.5–50 m 是原始校准线段范围；300–1200 m、$k_G=5$ 等属于参数外推。对于 NB 42–472 kHz 或 BB 30–86 MHz，必须重新核对 RLGC、负载模型、耦合器和衰减适用性。

$k_G$ 是经验电导损耗修正因子，不是长度，也不应与线路长度混为一个“损耗参数”。

---

# 4. 均匀传输线 ABCD 模型

## 4.1 端口约定

当前代码使用：

$$
\begin{bmatrix}V_1\\I_1\end{bmatrix}
=T
\begin{bmatrix}V_2\\I_2\end{bmatrix},
$$

端口 1 为发送侧，端口 2 为接收侧；代码文档将电流定义为由发送端指向接收端。该约定必须和支路、端接、级联顺序一起使用。

不同教材常把端口 2 电流定义为流入二端口，因而会在矩阵的第二列或第二行出现符号差异。不能只复制教材公式而不重新核对端口电流方向。

## 4.2 线路 ABCD 矩阵

长度 $d$ 的均匀线路矩阵为：

$$
\boxed{
T_{line}(d,f)=
\begin{bmatrix}
\cosh(\gamma d)&Z_c\sinh(\gamma d)\\
\sinh(\gamma d)/Z_c&\cosh(\gamma d)
\end{bmatrix}.}
$$

代码对应 `transmission_line_abcd.m`。

## 4.3 $AD-BC=1$、互易性与无源性

对当前均匀线路矩阵：

$$
AD-BC
=\cosh^2(\gamma d)-\sinh^2(\gamma d)=1.
$$

在当前端口约定下，互易二端口通常满足 $AD-BC=1$。这里需要区分：

- 互易性是端口传输关系的对称约束；
- 无源性是能量不主动产生的物理约束；
- 无源性不是 $AD-BC=1$ 的必要条件。

当前测试的短线路矩阵行列式残差达到机器精度量级。长线路直接计算中，$\cosh$ 和 $\sinh$ 的大项相减会放大浮点误差，导致巨大残差；这首先是数值条件问题，不能单独解释为物理互易性失效。

---

# 5. 支路、并联负载与网络级联

## 5.1 支路输入阻抗

支路长度为 $d_b$，终端负载为 $Z_L(f)$，则回推到连接节点的输入阻抗为：

$$
\boxed{
Z_{in}(f)=Z_c(f)
\frac{Z_L(f)+Z_c(f)\tanh(\gamma(f)d_b)}
     {Z_c(f)+Z_L(f)\tanh(\gamma(f)d_b)}.}
$$

### 有限负载

有限标量复阻抗或频率向量负载直接代入上式。代码允许标量实阻抗、标量复阻抗或与频率向量等长的复数 $Z_L(f)$。

### 开路

$$
Z_L=\infty\Rightarrow
Z_{in}=\frac{Z_c}{\tanh(\gamma d_b)}.
$$

### 短路

$$
Z_L=0\Rightarrow
Z_{in}=Z_c\tanh(\gamma d_b).
$$

### 零长度

$$
d_b=0\Rightarrow Z_{in}=Z_L.
$$

代码对上述极限显式分支处理，并拒绝负长度、NaN 负载或不匹配的频率向量。

## 5.2 并联输入导纳

支路在主线连接点看起来是并联负载：

$$
Y_{branch}(f)=\frac{1}{Z_{in}(f)}.
$$

在当前端口约定下，支路并联矩阵为：

$$
\boxed{
T_{shunt}(f)=
\begin{bmatrix}
1&0\\Y_{branch}(f)&1
\end{bmatrix}.}
$$

多个同节点支路先在导纳域相加：

$$
Y_{node}=Y_{branch,1}+Y_{branch,2}+\cdots.
$$

然后才能将节点矩阵按主路径顺序放入级联。支路内部仍是分布参数线路，不是一个与长度无关的标量负载。

## 5.3 级联顺序

若从发送端到接收端依次经过主线段、支路节点和主线段，则：

$$
T_{total}=T_1T_{shunt,1}T_2T_{shunt,2}\cdots T_n.
$$

矩阵相乘顺序必须与真实网络顺序一致。不能把各段空载电压增益相乘后再事后添加支路；支路和端接会改变每一段的工作点。

---

# 6. 端接、源阻抗与传递函数

## 6.1 有限接收负载

总矩阵为：

$$
T=\begin{bmatrix}A&B\\C&D\end{bmatrix},
$$

接收端满足 $V_r=Z_rI_2$ 的端接关系。开路 Thevenin 源电压为 $V_s$，则：

$$
\boxed{
H_V=\frac{V_r}{V_s}
=\frac{Z_r}{AZ_r+B+Z_s(CZ_r+D)}.}
$$

## 6.2 开路接收极限

当 $Z_r\to\infty$ 时，代码使用：

$$
\boxed{H_V=\frac{1}{A+Z_sC}.}
$$

## 6.3 端口归一化

端口归一化参考电压为：

$$
V_{ref}=V_s\frac{Z_{port,ref}}{Z_s+Z_{port,ref}}.
$$

因此：

$$
\boxed{
H_{port}=\frac{V_r}{V_{ref}}
=\frac{Z_s+Z_{port,ref}}{Z_{port,ref}}H_V.}
$$

只有当 $Z_s=Z_{port,ref}=50\ \Omega$ 时，才有：

$$
H_{port}=2H_V.
$$

改变源阻抗或端口参考阻抗后，不能无条件使用 $2H_V$。此外，有限接收机输入阻抗是网络的并联负载，会改变完整网络工作点，不能简单看成“不扰动的额外传感器”。

---

# 7. 长线路数值稳定性

## 7.1 直接 ABCD 的病态来源

当 $|\gamma d|$ 增大时：

$$
\cosh(\gamma d),\ \sinh(\gamma d)
$$

可能具有很大的中间量。总矩阵的 $AD-BC$ 是大数相减，浮点误差会被放大。此时：

- 没有 NaN/Inf 不是稳定性充分条件；
- 行列式残差很大不一定说明物理线路不再互易；
- 直接 ABCD 结果不应继续作为长线路正式结论。

## 7.2 稳定阻抗回推

输入阻抗仍可使用双曲正切形式：

$$
Z_{in}=Z_c\frac{Z_L+Z_c\tanh(\gamma d)}
                         {Z_c+Z_L\tanh(\gamma d)}.
$$

它避免了同时构造巨大 $\cosh$ 和 $\sinh$。对于电压比，代码采用衰减指数形式：

$$
\frac{V_{out}}{V_{in}}
=\frac{2Z_L e^{-\gamma d}}
{(Z_L+Z_c)+(Z_L-Z_c)e^{-2\gamma d}}.
$$

在 `cascade_network_stable.m` 中，网络从接收端向发送端递推：

1. 用端接阻抗初始化等效负载；
2. 将等效负载通过每段线路回推；
3. 累乘稳定电压比；
4. 在节点处把支路输入导纳加到主线等效导纳；
5. 最后应用源分压和端口归一化。

## 7.3 验证关系

代码和测试分别检查：

- 短线路稳定方法与普通 ABCD 的复数 CFR 一致；
- 匹配长线满足解析衰减极限；
- 长线路拆分成多段后结果不变；
- 被动输入阻抗满足合理的实部约束；
- 长线路不通过简单截断异常值来“修复”。

已有完整测试日志显示 $k_G=5$、800 m 和 1200 m 的普通 ABCD 行列式残差约为 $1.55\times10^{12}$ 和 $1.55\times10^{26}$，而稳定递推的复数 CFR 相对交叉误差仍为约 $10^{-15}$ 量级。这是数值稳定性审计结果；相关长度和 $k_G$ 仍属于参数外推。

---

# 8. 完整多节点网络模型

## 8.1 节点导纳方程

阶段 2.2 起，不再使用“截断下游支路”的前缀模型作为物理多节点证据，而是把完整网络写成：

$$
\boxed{Y_{net}(f;G,\theta,O)V(f)=I_{exc}(f).}
$$

每一条分布参数线路通过两端节点导纳矩阵进入 $Y_{net}$。对于长度 $d$ 的线路，代码利用衰减指数形式计算其两端自导纳和互导纳，避免大双曲函数矩阵造成的数值问题。

## 8.2 源阻抗的 Norton 等效

若源节点的 Thevenin 源为 $V_s$、源阻抗为 $Z_s$，则：

$$
Y_s=1/Z_s,
\qquad
I_N=V_s/Z_s.
$$

代码把 $Y_s$ 加到源节点对角线上，把 $I_N$ 加到激励向量中。

## 8.3 接收机和端点负载

接收机输入阻抗、支路末端负载和终端负载都以节点并联导纳进入方程。有限接收机阻抗将改变 $Y_{net}$，因而双接收机结果同时含有两种影响：

1. 新增了一个观测节点或观测视角；
2. 额外接收负载改变了网络电压和传播工作点。

## 8.4 `dual_receiver_complete` 与 `dual_receiver_counterfactual`

- `dual_receiver_complete`：第二个接收节点以实际有限输入阻抗接入完整网络，是带负载的物理模型内观测；
- `dual_receiver_highz_complete`：用很大的输入阻抗近似减小接收机负载扰动；
- `dual_receiver_counterfactual`：从同一个完整网络解中读取分析性节点电压，但不把额外接收机负载接入网络，是反事实对照，不是现场硬件结果；
- `three_view_complete`：在完整网络下组合多个视角，但仍受端口、节点和负载定义限制。

阶段 2.1 的截断前缀网络会丢弃下游支路，不能再把其理想 100% 结果写成真实多端口性能。

---

# 9. OFDM 等效模型与信道估计

## 9.1 频域 OFDM 模型

在有效子载波频率 $f_k$ 上：

$$
\boxed{
Y_{rt}[k]=X_t[k]H_{rt}(f_k;G,\theta,O)+N_{rt}[k].}
$$

这里 $X_t[k]$ 是已知非零导频，$N_{rt}[k]$ 是噪声或测量误差。OFDM 的作用是把宽带信道响应离散采样到一组子载波上；OFDM 本身不会改变物理网络的 $H$。

## 9.2 LS 信道估计

逐点最小二乘估计为：

$$
\boxed{
\hat H_{rt}[k]=\frac{Y_{rt}[k]}{X_t[k]}
=H_{rt}(f_k;G,\theta,O)+\frac{N_{rt}[k]}{X_t[k]}.}
$$

如果无噪声且 $X_t[k]\ne0$，则可以达到数值精度级恢复；有噪声时估计误差方差受 $|X_t[k]|^2$ 影响。

## 9.3 导频和插值

当前阶段 2 默认所有有效子载波为已知 QPSK 导频，优先隔离信道估计误差。阶段 3A 另外审计导频间隔 1、2、4、8，并在复数频率网格上做线性插值。

真实商用 PLC 中还需要考虑：

- 前导、头符号和数据符号的结构；
- 有效子载波、PSD notches 和非均匀频率缺口；
- 导频功率和总发送能量；
- 实际同步、采样时钟偏差和 CFO；
- 耦合器幅相误差及参考平面。

这些都尚未由当前项目标准 PHY 复现。

## 9.4 误差来源

当前接口可以表示：

- 白高斯、彩色或脉冲等效噪声；
- 定时偏移；
- 采样时钟偏差；
- 导频公共相位旋转；
- 稀疏导频插值误差。

但这些是等效仿真接口，不等于已经完成现场同步、真实 PLC 频率选择性噪声或完整收发机。

---

# 10. 循环前缀、循环卷积和 CIR

## 10.1 阶段 2 与阶段 3A 的 CP

| 阶段 | CP | 解释 |
|---|---:|---|
| 阶段 2 `ofdm_config` | 0 | 纯频域等效基线，不实例化 CP |
| 阶段 3A `stage3a_config` | 256 | 采样 CFR/IFFT/CP/FFT 审计的项目仿真假设 |

CP=256 没有由物理线路的最大传播时延或时延扩展推导，也不是已经确认的标准 PLC 参数。`ofdm_config.m` 保存的是阶段 2 的 `cyclic_prefix_samples=0` 及其历史基线说明，`stage3a_config.m` 保存的是阶段 3A 的 `cyclic_prefix_samples=256` 和 `cyclic_prefix_source`；当前代码没有一个统一、独立的通用 `cp_source` 字段，`stage3_band_configs.m` 只在 BB 配置层把来源映射为 `cp_source`。因此报告中仍必须保留这一物理边界，不能把字段名当成标准来源证明。

## 10.2 频域乘法与循环卷积

设 $H_{full}[k]$ 是嵌入 NFFT 点网格后的完整 CFR，定义：

$$
h_{sampled}[n]=\operatorname{IDFT}_N\{H_{full}[k]\}.
$$

则：

$$
\begin{aligned}
y_{circ}[n]
&=\operatorname{IDFT}_N\{\operatorname{DFT}_N(x)[k]H_{full}[k]\}\\
&=x[n]\circledast_N h_{sampled}[n].
\end{aligned}
$$

`stage3a_apply_ofdm_channel.m` 的频域乘法和显式循环卷积实现的是同一离散运算。[历史日志] 完整测试记录最大差异约 $3.72\times10^{-16}$。

这证明的是离散算法等价，不是连续时间因果 PLC 信道的完整时域建模。

## 10.3 线性卷积与 CP 条件

CP 消除线性卷积的符号间干扰，需要：

1. 信道响应有物理时间原点和有效因果支撑；
2. 有效时延扩展不超过 CP；
3. CP 复制和去除边界正确；
4. 同步、采样时钟和滤波器尾部与 CP 定义一致。

当前 `linear_sampled_cfr` 只是对同一采样 CFR 的 IFFT 响应做有限线性卷积，不能把其差异直接解释成真实 PLC CP 设计失败。

## 10.4 带限采样 CFR 的 CIR 边界

当前只把 2–30 MHz 的有效正频率采样放入 NFFT 网格，未测频点置零，没有负频率共轭补全，也没有物理同步和时间零点。因此输出应命名为：

> circular band-limited CIR（循环带限信道冲激响应）。

`stage3a_cp_coverage.m` 报告的 `physical_delay_support_samples` 为 NaN 是有意的模型边界。99% 能量支撑和 $-40$ dB 阈值支撑可能接近整个 IFFT 长度，是有限带宽、周期化和旁瓣的数学结果。

阶段 3A.2 历史 CSV 中，T2、CP=256 的代表性结果为：

| 指标 | 数值 | 来源和解释 |
|---|---:|---|
| physical delay support | NaN | 采样 CFR 没有物理时间原点 |
| 99% energy support | 4095 samples | 当前循环采样响应的支撑定义 |
| -40 dB threshold support | 4095 samples | 当前阈值和周期化定义 |
| CP energy fraction | 0.691912 | 当前循环旋转支撑下的离散能量比例 |
| linear/circular max abs | 0.00250991 | 同一采样 CFR 的线性/循环输出差异 |
| linear/circular relative RMS | 0.0482038 | 同一模型定义下的相对 RMS |

这些数值是历史正式 CSV 的审计结果，不是现场 CP 结论。

## 10.5 循环时延代理

`stage3a_toa_feature.m` 通过循环带限 CIR 主峰得到一个时间索引。它的正确名称是：

> circular-delay proxy（循环时延代理）。

当前实现没有负频率共轭补全、完整模拟滤波器、物理同步或独立群时延计算，因此该主峰不能称为真实 ToA、传播距离或现场测距结果。

---

# 11. CFR 特征与距离函数

## 11.1 幅值和 dB 幅值

代码中的归一化幅值特征为：

$$
a_{norm}[k]=\frac{|H[k]|}{\sqrt{\sum_k|H[k]|^2}}.
$$

它强调频率形状，丢失整体绝对衰减。未归一化 dB 幅值为：

$$
A_{dB}[k]=20\log_{10}\bigl(\max(|H[k]|,\epsilon)\bigr),
$$

保留绝对电平，但更容易受端接、耦合器增益、源功率和标定误差影响。逐向量标准化还会去掉均值和尺度，不能被称为保留绝对电平。

## 11.2 相位

当前代码同时保留：

- 原始展开相位 RMSE；
- 按幅值阈值掩膜的相位 RMSE；
- 幅值加权圆周相位误差；
- 可选去除公共常数相位和线性相位的接口。

低幅值频点上的相位本来就不稳定，不能把 unwrap 产生的巨大跳变直接解释为真实传播相位。

## 11.3 归一化复数 CFR 距离

代码 `topology_feature_distance.m` 的 `complex` 特征先做单位二范数归一化，再计算逐频点 RMS：

$$
\boxed{
D_{complex,norm}(a,b)=
\sqrt{\frac{1}{N}\sum_{k=1}^{N}
\left|\frac{a_k}{\|a\|_2}-\frac{b_k}{\|b\|_2}\right|^2}.}
$$

它保留相对频率形状和相对复相位，但丢失整体绝对电平。因此阶段 2.3 的等价类应写成：

> 归一化复数 CFR 形状或相对响应等价。

不能把它直接扩大为原始绝对标定复数 CFR 完全等价。

## 11.4 raw 复数 CFR 距离

`complex_raw` 不做单位范数归一化：

$$
\boxed{
D_{complex,raw}(a,b)=
\sqrt{\frac{1}{N}\sum_{k=1}^{N}|a_k-b_k|^2}.}
$$

它保留绝对复数幅相差异，但对端口标定和负载变化更敏感。两种距离应并行记录，不能把一个距离的等价类结论自动转移到另一个距离。

## 11.5 CIR 特征

当选择 `cir` 特征时，代码把 CFR 转换为循环带限 CIR，并对 CIR 作相应距离计算。其物理解释仍受第 10 节限制；它是当前等效模型下的形状特征，不是真实反射测距。

## 11.6 幅相联合特征

当前幅相联合距离为：

$$
\boxed{
D_{joint}=\sqrt{w_{amp}D_{amp}^2+w_{phase}D_{phase}^2},
\qquad w_{amp}+w_{phase}=1.}
$$

代码还支持掩膜相位、加权圆周相位和绝对 dB 幅值联合版本。权重和相位阈值是仿真配置，不是经过充分搜索得到的最优参数。

## 11.7 “曲线不同”不等于“拓扑可识别”

拓扑曲线差异只有在以下条件同时满足时才有拓扑意义：

- 候选拓扑的线路和负载参数控制一致；
- 同一观测配置和端口边界；
- 类间距离大于同拓扑的类内扰动距离；
- 噪声和估计误差下仍有稳定距离间隔；
- 结构等价类已经单独处理。

CFR NMSE 低只说明信道估计较准；不等于具体拓扑唯一识别。

---

# 12. 拓扑匹配与参数联合估计

## 12.1 名义最近邻

给定观测 $\hat H$ 和每个候选拓扑的名义参考 $H_G$：

$$
\boxed{
\hat G=\arg\min_{G\in\mathcal G}D(\hat H,H_G).}
$$

`topology_nearest_match.m` 保存所有候选分数、最佳分数、次佳分数、tie 候选、等价类最佳分数和距离间隔。

## 12.2 参数联合匹配

当线路长度、负载、端接或耦合参数不完全已知时：

$$
\boxed{
(\hat G,\hat\theta)=
\arg\min_{G\in\mathcal G,\theta\in\Theta}
\left[D\bigl(\hat H,H_O(G,\theta)\bigr)
      +\lambda R(\theta)\right].}
$$

其中 $\Theta$ 是显式配置的边界，$R(\theta)$ 是相对标称参数的归一化偏离惩罚。

## 12.3 243 点与 27 点网格不可混写

- 阶段 2.2 的参数库对主线长度比例、支路长度比例、负载比例、源阻抗和接收阻抗等使用每拓扑 243 个参数点；
- 阶段 3A/3A.1/3A.2 的参数感知基线使用 27 点有界网格，并在配置中记录边界和 $\lambda$；
- 27 点和 243 点服务于不同阶段，不能在总结中合并为一个参数搜索规模。

阶段 3A.2 的正式协议使用独立校准/测试种子：校准用于从候选 $\lambda\in\{0,0.001,0.01,0.05\}$ 中选择配置，测试种子不参与选择。这个划分支持审计公平性，但不证明该搜索器是全局最优或现场最优。

## 12.4 参数自由度的副作用

参数搜索可能把噪声或模型误差拟合为参数变化：

- ambiguity 可能下降；
- theta 估计可能撞到边界；
- false-unique 可能上升；
- 严格准确率可能提高，但物理唯一性并未改善。

因此，参数联合方法必须同时报告拓扑指标、参数 RMSE、边界命中率和等价类指标。

---

# 13. 拓扑可辨识性与 T3/T5 等价类

## 13.1 识别的数学条件

拓扑唯一识别要求在给定观测 $O$ 和允许参数集合 $\Theta$ 下，映射：

$$
(G,\theta)\longmapsto H_O(f;G,\theta)
$$

至少在候选集合上近似单射。

单端 SISO 观测**不能保证**该映射是单射，但不能用“一个标量复函数的信息量低于拓扑自由度”作为严格证明。函数空间维数与物理映射的单射性不是这样比较的。

## 13.2 T3/T5 镜像反例

当前候选拓扑中，T3 与 T5 使用同一均匀主线、相同线路参数、相同支路参数和相同负载，只在主线对称位置形成镜像。若：

- 主线参数关于端点方向一致；
- 支路长度、支路电缆和负载相同；
- 源端和接收端对称，$Z_s=Z_r=50\ \Omega$；
- 观测是当前端到端单端 SISO CFR；
- 线路模型是理想互易模型；

则端点反转把 T3 映射为 T5，而端到端响应保持不变：

$$
\boxed{
H_{O_{siso},T3}(f;\theta)
=H_{O_{siso},T5}(f;\theta).}
$$

这是真正的模型内结构等价反例。它不依赖于分类器、随机种子或数值 tie-break。

## 13.3 四种概念必须分开

### 结构等价

由拓扑、参数和观测方式决定的不可区分关系。T3/T5 在上述对称 SISO 条件下属于同一物理等价类。

### 数值 tie

一次具体观测中，多个候选的数值距离落在设定容差内。噪声可能减少精确 tie，但不改变结构等价。

### ambiguity

算法按照 tie 或等价类规则报告无法唯一选择的比例。

### false-unique

观测真实处于结构等价类，但算法由于噪声、浮点差异或参数自由度给出某个成员作为唯一预测的比例。

带噪声随机选出 T3 或 T5，不等于物理上已经唯一识别。

## 13.4 多视图和端接

不对称端接、反向测量、内部接收节点或多视图可能改变观测映射，但必须写清其代价：

- 反向测量是否交换源/负载角色；
- 内部接收机是否作为并联负载；
- 高阻接收是否只是近似；
- counterfactual 是否只是模型计算；
- 是否真的新增独立电压/电流观测。

因此多视图严格率 1 只能称为当前完整网络模型、端接和参数边界下的模型内结果。

---

# 14. 评价指标和已有仿真结果

## 14.1 指标定义

- **strict accuracy**：预测具体候选编号正确的比例；
- **equivalence-class accuracy**：预测属于真实结构等价类的比例；
- **unique strict accuracy / strict unique rate**：在定义为非歧义的样本中，具体编号唯一且正确的比例；报告时必须说明分母；
- **ambiguity rate**：算法报告 tie 或结构等价类、不能唯一选择的比例；
- **false-unique rate**：真实属于多成员物理等价类，但算法给出某一成员唯一结果的比例；
- **distance margin**：最佳候选与次佳候选之间的距离差；
- **edge Precision/Recall/F1**：预测拓扑边集合相对于真实边集合的精确率、召回率和 F1；
- **CFR NMSE**：信道估计层的归一化均方误差；
- **幅值/相位误差**：特征估计层指标，不是拓扑层指标。

## 14.2 阶段 3A.2 历史正式结果

下面数字来自历史 `results/data/stage3a_2_protocol_summary.csv` 和阶段报告，不是本轮理论写作重新生成的实验。该协议为 20 dB、4 个候选拓扑、1793 个有效频点、固定观测配置；阶段 3A.2 正式测试每拓扑 50 次，校准与测试种子分离。

| 观测配置 | 方法 | strict | unique | class | ambiguity | false-unique | CFR NMSE | theta RMSE | boundary rate |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
| `siso_forward` | nominal_nearest | 0.770 | 0.500 | 1.000 | 0.500 | 0 | 0.004125 | 0 | 0 |
| `siso_forward` | topology_only | 0.760 | 0.500 | 1.000 | 0.500 | 0 | 0.004125 | 0 | 0 |
| `siso_forward` | nuisance_aware_joint | 0.785 | 0.430 | 1.000 | 0.100 | 0.470 | 0.004125 | 0.012124 | 0.945 |
| `dual_receiver_complete` | nominal_nearest | 1.000 | 1.000 | 1.000 | 0 | 0 | 0.004116 | 0 | 0 |
| `dual_receiver_complete` | nuisance_aware_joint | 1.000 | 0.990 | 1.000 | 0.010 | 0 | 0.004116 | 0.023094 | 0.960 |
| `dual_receiver_highz_complete` | nominal_nearest | 1.000 | 1.000 | 1.000 | 0 | 0 | 0.004120 | 0 | 0 |
| `dual_receiver_highz_complete` | nuisance_aware_joint | 1.000 | 0.965 | 1.000 | 0.035 | 0 | 0.004120 | 0.010132 | 0.935 |
| `dual_receiver_counterfactual` | nominal_nearest | 1.000 | 1.000 | 1.000 | 0 | 0 | 0.004120 | 0 | 0 |
| `dual_receiver_counterfactual` | nuisance_aware_joint | 1.000 | 0.920 | 1.000 | 0.080 | 0 | 0.004120 | 0.010046 | 0.905 |
| `three_view_complete` | nominal_nearest | 1.000 | 1.000 | 1.000 | 0 | 0 | 0.004131 | 0 | 0 |
| `three_view_complete` | nuisance_aware_joint | 1.000 | 0.985 | 1.000 | 0.015 | 0 | 0.004131 | 0.022748 | 0.990 |

### 结果解释

1. SISO 的等价类准确率为 1，说明算法能识别 `{T3,T5}` 这个类；strict unique 约 0.5，符合结构等价预期。
2. `nuisance_aware_joint` 的 strict accuracy 0.785 不能被解释为打破 T3/T5；它的 false-unique 为 0.470，且参数边界率为 0.945，说明自由度带来明显的不可辨识和拟合风险。
3. 多视图 nominal 方法在本模型中严格率为 1，但 `dual_receiver_complete` 的第二接收机是并联负载；`counterfactual` 是反事实模型；二者不能写成同一种现场测量性能。
4. CFR NMSE 在不同匹配器间基本不变，因为它评价的是同一信道估计观测；拓扑算法的变化不能由 NMSE 单独推导。

## 14.3 历史阶段 2/3A 的辅助结果

历史阶段报告还支持：

- 理想 CFR 匹配中，T3/T5 结构等价类准确率为 1；严格最近邻的浮点 tie-break 不是唯一识别证据；
- 阶段 2.1 的多随机种子实验覆盖 30、20、10、0 dB，每个条件每拓扑至少 50 次；
- 阶段 3A 使用 $NFFT=4096$、$F_s=64$ MHz、2–30 MHz、1793 个有效频点和 CP=256 仿真假设；
- 阶段 3A.2 线性/循环审计和参数感知协议已生成正式 CSV、图和日志。

这些都是已有阶段结果，不能称作本次最终理论报告重新运行的实验。

---

# 15. 宽窄带研究边界与阶段门控

## 15.1 窄带候选

当前 `cfg_nb` 的 42–472 kHz 是候选设计频带：

- 不代表已经确认 PRIME、G3-PLC 或其他标准；
- Fs、NFFT、CP、有效子载波、导频和 PSD 尚未冻结；
- `cfg_nb` 保持不可运行状态，避免编造一套伪标准 NB OFDM。

## 15.2 宽带主线

当前 `cfg_bb` 使用项目现有的：

- 2–30 MHz；
- $F_s=64$ MHz；
- NFFT=4096；
- CP=256；
- 全有效子载波导频作为现有基线。

这些是项目仿真假设，不是已确认的标准参数。30–86 MHz 只作为设计扩展，必须先确认 RLGC、PSD、耦合器和高频适用性。

## 15.3 尚未完成的双频段实验

当前尚未完成：

- 相同候选拓扑、参数扰动和端口条件下的 NB/BB 理想 CFR 比较；
- OFDM 导频估计 NMSE、CIR 和循环时延代理的双频段比较；
- 相同总能量、有效频点数和观测时间的公平拓扑识别；
- 真实窄带/宽带 PHY、PSD 缺口、噪声和同步复现。

因此当前不能说“带宽不足是主要瓶颈”，也不能说“宽带一定解决拓扑不可辨识”。全导频仿真尚无证据表明导频密度是主要瓶颈，但带宽影响尚未通过 NB/BB 实验验证。

## 15.4 阶段 3B 门槛

暂不启动阶段 3B。只有同时满足以下条件，才有理由研究导频、子载波、功率、带宽或符号结构优化：

1. 真实或明确的 NB/BB PHY 参数已冻结；
2. 端接、耦合器、同步和观测节点已冻结；
3. 物理因果时延和 CP 定义已明确；
4. 参数感知匹配已使用独立测试集评价；
5. 在上述因素固定后，类间不可分仍主要来自导频密度、带宽、功率或频率资源。

如果瓶颈仍是 T3/T5 结构等价，则应优先增加观测节点、方向、端接或反射/导纳测量，而不是只优化 OFDM 波形。

---

# 16. 代码—公式映射表

| 理论对象 | 数学公式 | 代码文件/函数 | 当前验证状态 | 局限 |
|---|---|---|---|---|
| RLGC | $R',L',G',C'$ | `src/cable_rlgc.m` | 正频率、单位和数值测试通过 | 工程经验模型，频带外推需标记 |
| 传播常数 | $\gamma=\sqrt{(R'+j\omega L')(G'+j\omega C')}$ | `cable_rlgc.m` | 已由阶段 1.5 测试使用 | 依赖 RLGC 参数适用范围 |
| 复特性阻抗 | $Z_c=\sqrt{(R'+j\omega L')/(G'+j\omega C')}$ | `cable_rlgc.m` | 短线和稳定递推测试通过 | 不等于名义 `Z0_nominal_ohm` |
| ABCD 线路 | $T_{line}$ 双曲函数矩阵 | `transmission_line_abcd.m` | 短线、分段和行列式测试通过 | 长线直接矩阵病态 |
| 支路阻抗 | $Z_{in}=Z_c(Z_L+Z_c\tanh\gamma d)/(Z_c+Z_L\tanh\gamma d)$ | `branch_input_impedance.m` | 实/复/向量/开路/短路/零长度通过 | 零欧姆节点需显式奇异处理 |
| 并联导纳 | $Y_{branch}=1/Z_{in}$，$T_{shunt}=[1,0;Y,1]$ | `shunt_abcd.m` | 支路和矩阵测试通过 | 有限 ABCD 不表示零欧姆无限导纳 |
| 端到端电压传递 | $H_V=Z_r/[AZ_r+B+Z_s(CZ_r+D)]$ | `abcd_to_transfer.m` | 端接和极限测试通过 | 端口电流符号必须一致 |
| 开路极限 | $H_V=1/(A+Z_sC)$ | `abcd_to_transfer.m` | 开路接口测试通过 | 仅是 $Z_r\to\infty$ 极限 |
| 端口归一化 | $H_{port}=((Z_s+Z_{ref})/Z_{ref})H_V$ | `abcd_to_transfer.m` | 50 Ω 适用性测试通过 | $2H_V$ 仅为特例 |
| 稳定递推 | $Z_{in}$ 双曲正切和衰减电压比 | `terminated_line_response.m`、`cascade_network_stable.m` | 长线、分段、被动性测试通过 | 依赖被动传播假设 |
| 完整节点导纳 | $Y_{net}V=I_{exc}$ | `plc_full_network_response.m` | 阶段 2.2/3A.2 测试通过 | 不是多导体 MIMO 或现场耦合器 |
| OFDM 等效模型 | $Y=XH+N$ | `ofdm_apply_channel.m`、`stage3a_apply_ofdm_channel.m` | 阶段 2/3A 测试通过 | 不是完整商用 PLC PHY |
| LS 信道估计 | $\hat H=Y/X$ | `ofdm_channel_estimate_ls.m`、`stage3a_receive_ofdm.m` | 无噪声和噪声测试通过 | 依赖非零已知导频 |
| IFFT/CP 循环链路 | $y=\operatorname{IDFT}(\operatorname{DFT}(x)H)$ | `stage3a_apply_ofdm_channel.m` | 历史测试最大误差约 $3.72\times10^{-16}$ | 采样 CFR 循环等效，不是连续时域信道 |
| CP 审计 | 支撑、能量比例、线性/循环误差 | `stage3a_cp_coverage.m`、`exp15_stage3a_2_model_validity.m` | 历史 CSV 和测试通过 | 无物理时间原点，不能给现场 CP 结论 |
| CIR | $h=\operatorname{IDFT}(H_{full})$ | `ofdm_cfr_to_cir.m` | 维度和 FFT 一致性通过 | circular band-limited CIR |
| 时延特征 | 循环 CIR 主峰 | `stage3a_toa_feature.m` | 非物理 ToA 测试通过 | circular-delay proxy，无独立群时延 |
| CFR 距离 | 归一化/ raw 复数、幅值、相位和 CIR | `topology_feature_distance.m` | 多特征测试通过 | 每种距离保留的信息不同 |
| 结构等价类 | 固定观测下 pairwise 距离连通分量 | `topology_observability_classes.m` | T3/T5 测试通过 | 主要依据归一化复数形状 |
| 最近邻匹配 | $\arg\min_GD$ | `topology_nearest_match.m` | tie、margin、等价类接口通过 | 不能创造物理信息 |
| 参数联合搜索 | $\arg\min_{G,\theta}[D+\lambda R]$ | `topology_joint_match.m`、`exp14...`、`exp16...` | 有界网格和独立 split 通过 | 不是全局/最优证明，可能过拟合 |

---

# 17. 结论、已验证内容和待验证问题

## 17.1 已由代码或已有测试支持的结论

1. RLGC、传播常数、复特性阻抗、短线 ABCD、分支回推、端接和稳定长线递推已经形成一致的 MATLAB 接口；
2. 长线路直接 ABCD 的巨大 $AD-BC$ 残差可以由数值病态解释，稳定递推通过短线交叉、匹配极限和分段不变性检查；
3. 阶段 2 的频域 $Y=XH+N$ 与阶段 3A 的采样 CFR/IFFT/CP/FFT/LS 等效接口均有历史测试支持；
4. 频域乘法与同一采样 CFR 的显式循环卷积数值一致；
5. 当前 CIR 是 circular band-limited CIR，`stage3a_toa_feature.m` 只产生 circular-delay proxy；
6. 50/50 Ω 对称端接下 T3/T5 是结构观测等价类，带噪声随机选中其中一个编号不能被解释为唯一识别；
7. 参数联合搜索不是自动提高可辨识性的算法；阶段 3A.2 的 `false_unique=0.470` 说明自由度可能削弱唯一识别可信度；
8. 多视图可以在当前完整网络模型中提供额外模型内区分信息，但有限接收机输入阻抗会改变网络工作点。

## 17.2 根据模型得到但尚未充分验证的推断

1. 增加不对称端接、反向方向、内部节点或多端口观测，可能打破部分 SISO 等价类；
2. 宽带可能提高近似路径和时延特征分辨率，但不能保证消除严格 SISO 传递函数等价；
3. 负载和线路参数扰动可能使类内距离大于类间距离，从而造成拓扑混淆；
4. 当前全导频模型尚无证据显示导频密度是主要瓶颈，但这一结论不能推广到真实稀疏导频或 NB/BB 频带；
5. 输入阻抗、反射/FDR 和节点导纳有望提供不同于端到端 CFR 的观测信息，但需要额外物理测量链路。

## 17.3 待文献、实验或导师确认的问题

- `core_derivation_reviewed_corrected.md` 的附件版本及其与当前 reviewed 文档的差异；
- 真实 NB-PLC PHY、频段、采样率、FFT、有效子载波、导频、CP 和 PSD；
- BB 是否仅采用 2–30 MHz，还是扩展到 30–86 MHz；
- RLGC 参数在 NB、BB 扩展频段和长线路上的校准范围；
- 真实源/接收端阻抗、耦合器参考平面和内部节点可用性；
- 是否可以进行双向、双接收节点、多端口、输入导纳或 FDR/TFDR 测量；
- 真实同步、CFO、采样时钟偏差、现场有色/脉冲/周期噪声和负载时变；
- 多导体传输线和 MIMO-PLC 的实际独立观测维度；
- 真实市电实验的隔离、耦合和安全测试方案；
- 是否在上述物理协议冻结后才进入阶段 3B 波形或资源配置优化。

## 17.4 当前模型不能回答的问题

当前模型不能证明：

- 某个真实商用 PLC 标准的拓扑识别性能；
- 现场完整树拓扑一定能够由单端 CFR 唯一重建；
- 任何 BER、CFR NMSE 或曲线差异直接等价于拓扑识别率；
- circular-delay proxy 是真实 ToA 或物理测距；
- FDR/TFDR 或输入导纳 proxy 已经等于完整仪器测量；
- 已经完成接地故障定位；
- 宽带必然优于窄带，或 OFDM 波形优化已经必要。

## 17.5 导师汇报建议

当前可向导师提交的阶段性成果应表述为：

> 已建立并通过 MATLAB 回归测试的 PLC 传输线/完整树网络—OFDM 等效 CFR—拓扑等价类基线；证明了对称 SISO 下 T3/T5 的结构不可唯一识别，并量化了参数自由度和多视图观测的模型内影响。真实 NB/BB PHY、公平双频段实验、现场测量和阶段 3B 波形优化仍需在观测协议和参数来源确认后进行。

这一表述不会把通信信道估计性能、历史仿真结果或模型内多视图识别率扩大为完整现场拓扑识别结论。
