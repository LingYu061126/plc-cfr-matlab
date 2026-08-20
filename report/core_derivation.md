# PLC CFR 正向模型核心推导（阶段 1.5）

## 1. 范围、单位和端口方向

本阶段计算固定线路拓扑和端接条件下的复数信道频率响应 `H(f)`。频率 `f` 严格使用正的 Hz，长度 `d` 使用 m，单位长度参数使用 `R [ohm/m]`、`L [H/m]`、`G [S/m]`、`C [F/m]`。Cañete 等人的室内模型频带约到 30 MHz，典型线段范围为 0.5–50 m；任务书中的 300–1200 m 是参数外推。

二端口统一采用

$$
\begin{bmatrix}V_1\\I_1\end{bmatrix}=
\begin{bmatrix}A&B\\C&D\end{bmatrix}
\begin{bmatrix}V_2\\I_2\end{bmatrix}.
$$

两端电流参考方向都从发送端指向接收端。该约定使支路并联矩阵和端接公式保持一致。

## 2. RLGC、传播常数和特性阻抗

令 `omega=2*pi*f`。任务书给出

$$
R(f)=R_0 10^{-5}\sqrt{f},\qquad L(f)=L_0,
$$

$$
G(f)=G_0 k_G 10^{-14} 2\pi f,\qquad C(f)=C_0.
$$

代码将 `L0` 从 uH/m 换为 H/m，将 `C0` 从 pF/m 换为 F/m。`kG` 只修正经验电导项，不代表线路长度。随后

$$
\gamma=\sqrt{(R+j\omega L)(G+j\omega C)},\qquad
Z_c=\sqrt{\frac{R+j\omega L}{G+j\omega C}}.
$$

`gamma` 单位为 1/m，`Zc` 单位为 ohm。零频率会使本式出现 `0/0` 或未定义的阻抗分支，因此 `cable_rlgc` 明确拒绝 `f<=0`，而不是依靠浮点结果。

## 3. 均匀线路 ABCD 矩阵

长度为 `d` 的均匀线路为

$$
\Phi_{line}=
\begin{bmatrix}
\cosh(\gamma d)&Z_c\sinh(\gamma d)\\
Z_c^{-1}\sinh(\gamma d)&\cosh(\gamma d)
\end{bmatrix}.
$$

理论上 `AD-BC=1`。短线路测试使用该互易性、整段/分段等价性和无支路基线验证矩阵方向。多个二端口按物理顺序相乘，例如 `Tline1*Tshunt*Tline2`。

## 4. 支路输入阻抗和节点并联

支路终端阻抗可以是标量或与频率向量等长的复向量。对支路长度 `d_b`：

$$
Z_{in,b}=Z_{c,b}\frac{Z_b+Z_{c,b}\tanh(\gamma_b d_b)}
{Z_{c,b}+Z_b\tanh(\gamma_b d_b)}.
$$

开路、短路和零长度分别按

$$
Z_{in,b}=Z_{c,b}/\tanh(\gamma_b d_b),\quad
Z_{in,b}=Z_{c,b}\tanh(\gamma_b d_b),\quad
Z_{in,b}=Z_b
$$

处理。节点并联矩阵为

$$
\Phi_{shunt}=\begin{bmatrix}1&0\\1/Z_{in,b}&1\end{bmatrix}.
$$

多个支路等价于导纳相加。理想零欧姆且零长度的支路会使有限 ABCD 表示奇异，代码会报错；非零长度短路支路可以正常回推。

## 5. 端接与传递函数

接收端满足 `I2=Vr/Zr`。戴维南源满足 `Vs=V1+Zs*I1`，因此

$$
H_V=\frac{V_r}{V_s}=\frac{Z_r}
{A Z_r+B+Z_s(C Z_r+D)}.
$$

代码还定义一个参考端接 `Zport_ref`：若相同开路源 `Vs` 直接驱动该参考端接，则

$$
V_{ref}=V_s\frac{Z_{port\_ref}}{Z_s+Z_{port\_ref}},
$$

$$
H_{port}=\frac{V_r}{V_{ref}}=
\frac{Z_s+Z_{port\_ref}}{Z_{port\_ref}}H_V.
$$

默认 `Zs=Zport_ref=50 ohm` 时才有 `H_port=2H_V`。测试显式改变 `Zs=75 ohm`，验证此时比例为 2.5 而不是 2。

## 6. 长线路为什么不能只看有限性

当 `x=gamma*d` 的实部变大时，

$$
\cosh x\sim\frac{e^x}{2},\qquad \sinh x\sim\frac{e^x}{2}.
$$

直接 ABCD 级联会产生很大的 `A,B,C,D`。理论上的 `AD-BC=1` 变成两个大数相减，舍入误差会把行列式残差放大；因此“矩阵元素没有 NaN/Inf”并不能证明矩阵仍然满足互易性。当前数值审计阈值为 `max|AD-BC-1|<=1e-6`，这是数值完整性筛查阈值，不是物理测量精度。

## 7. 稳定阻抗/电压比递推

`cascade_network_stable` 不构造总 ABCD。令线路右端看到的下游阻抗为 `Z_L`，`x=gamma*d`，输入阻抗仍用 `tanh(x)` 计算；右端电压与左端电压的比改写为

$$
\frac{V_{out}}{V_{in}}=
\frac{2Z_L e^{-x}}
{(Z_L+Z_c)+(Z_L-Z_c)e^{-2x}}.
$$

该式与 `1/(cosh(x)+(Zc/ZL)sinh(x))` 等价，但只使用衰减指数，避免显式产生 `e^x`。对每个主线段从接收端向发送端处理：

1. 用下游 `Z_L` 回推当前线路输入阻抗，并累乘 `Vright/Vleft`；
2. 到达节点后，把当前下游阻抗与各支路输入阻抗转换为导纳并相加；
3. 继续处理上一段主线；
4. 最后用 `Zin/(Zs+Zin)` 得到 `V1/Vs`，再得到 `H_V` 和 `H_port`。

稳定方法的验收不是行列式，而是：短线与 ABCD 的复数 CFR 一致；长线不产生非有限值；被动网络输入阻抗实部非负；把一段长线拆成两段后 CFR 和输入阻抗不变；匹配长线满足 `Zin=Zc`、`Vout/Vin=e^{-gamma*d}`。

## 8. 频率选择性负载

代码实现 Cañete 论文中的并联 RLC 型模型

$$
Z(\omega)=\frac{R}{1+jQ(\omega/\omega_0-\omega_0/\omega)}.
$$

在 `exp06` 中使用 `R=500 ohm`、`Q=5`、`f0=15 MHz`。这些是文献模型/仿真参数，不是现场负载实测值。接口同时覆盖标量实阻抗、标量复阻抗、逐频率复阻抗、开路和短路。

## 9. 结果边界

稳定递推显示所有 300–1200 m、`kG=1/5` 组合仍可在双精度下计算，且当前稳定物理检查通过；但全部超出 Cañete 校准范围。`kG=5` 的 500/800/1200 m 曲线分别有约 39.9%、65.6%、80.0% 的频点低于报告用 `-120 dB` 参考门限。项目没有给定实际硬件动态范围，因此这只能说明“在该参考门限下可能不可测”，不能替代硬件测量结论。下一阶段接入 OFDM 时，导频只是采样本阶段得到的 `H(f)`，不会改变正向物理模型。

## 10. 阶段 2 OFDM 频域等效信道估计

阶段 2 没有重新实现传输线模型，而是在阶段 1.5 的
`cascade_network_stable` 输出频率点上建立复基带频域观测：

$$
Y[k]=X[k]H(k;G,\theta)+N[k].
$$

当前配置使用 `NFFT=4096`、`F_s=64 MHz`，所以
`\Delta f=F_s/NFFT=15.625 kHz`；`2–30 MHz` 范围内的 1793 个子载波全部设置为已知导频。该设置是为了先隔离信道估计误差，不代表实际通信系统的导频密度或功率配置。

导频非零时，最小二乘估计逐子载波为

$$
\hat H_{LS}[k]=\frac{Y[k]}{X[k]}.
$$

在无噪声情况下，代码测试验证 `\hat H=H` 达到双精度数值误差；有噪声时采用复高斯白噪声，噪声方差按接收导频平均功率与指定 SNR 设置。该模型没有实现 IFFT/FFT 收发链、循环前缀、同步、载波频偏或插值，因此只能称为“频域信道估计等效模型”。

## 11. CFR 到 CIR

测得的导频 CFR 按配置中的 FFT bin 嵌入长度为 `NFFT` 的频域向量，未测子载波置零：

$$
H_{full}[k_b]=\hat H[k],\qquad
\hat h_{circ}[n]=\operatorname{IFFT}\{H_{full}[k]\}.
$$

测试用 `FFT(IFFT(H_full))=H_full` 检查数值一致性。由于当前只放置正频率复基带子载波，得到的是复数、带限、循环 CIR；其峰值位置只能作为当前等效模型的循环 ToA 指标，不能直接表述为已完成真实 PLC 测距。

## 12. 拓扑匹配距离

对观测 CFR `H_o` 和候选参考 CFR `H_i`，代码使用以下归一化距离：

$$
D_{amp}=\left\|\frac{|H_o|}{\||H_o|\|_2}-
\frac{|H_i|}{\||H_i|\|_2}\right\|_{RMS},
$$

$$
D_{phase}=\frac{1}{\pi}
\left\|\tilde\phi_o-\tilde\phi_i\right\|_{RMS},
\quad \tilde\phi=\operatorname{unwrap}(\angle H)-\phi[1],
$$

$$
D_{complex}=\left\|\frac{H_o}{\|H_o\|_2}-
\frac{H_i}{\|H_i\|_2}\right\|_{RMS},
$$

$$
D_{CIR}=\left\|\frac{h_o}{\|h_o\|_2}-
\frac{h_i}{\|h_i\|_2}\right\|_{RMS}.
$$

幅相联合距离为

$$
D_{joint}=\sqrt{w_aD_{amp}^2+w_pD_{phase}^2},
\qquad (w_a,w_p)=(0.5,0.5).
$$

最近邻输出为

$$
\hat G=\arg\min_i D(H_{obs},H_i).
$$

程序还以 `1e-10` 的距离 tie 容差报告歧义候选。T3/T5 的 20 m 与 60 m 单支路在当前均匀 80 m 主线、相同支路参数和 `Z_s=Z_r=50 Ω` 条件下是端到端镜像，五类理想 CFR 距离均接近数值零；因此需要报告观测等价类，而不能把最近邻的浮点先后顺序解释为唯一拓扑信息。

## 13. 误差与识别指标边界

信道估计指标使用复数 CFR NMSE、dB 幅值 RMSE 和去公共初相位的展开相位 RMSE。拓扑识别另行报告完整拓扑准确率、混淆矩阵、边级 Precision/Recall/F1、观测等价类准确率和歧义率。边级 F1 只反映候选图边集合重合，不能替代完整拓扑准确率；尤其当前候选共享四条主线边，边级指标可能在完整分类失败时仍然较高。
