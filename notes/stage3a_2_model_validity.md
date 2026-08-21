# 阶段 3A.2：模型有效性与观测协议说明

## 范围

本阶段审计阶段 3A 的 OFDM 等效链路和观测配置，不优化导频、子载波、功率或带宽，也不进入阶段 3B。阶段 1.5 的 RLGC、传播常数、ABCD 参考实现、稳定阻抗递推、候选拓扑和 T3/T5 等价类定义均保留。

统一的物理信道接口仍为

\[
H(f;G,\theta),
\]

其中 `G` 是拓扑，`theta` 至少包含线路长度、单位长度 `R'、L'、G'、C'`、负载、源/接收端阻抗和耦合器幅相参数。普通 OFDM 端到端观测写为

\[
Y_{rt}[k]=X_t[k]H_{rt}(k;G,\theta)+N_{rt}[k].
\]

`O` 是观测方式变量，区分端到端 SISO、双向、多接收节点和其他 proxy；普通 OFDM CFR 不等同于 FDR/TFDR 反射响应或输入导纳仪器测量。

## 循环与线性卷积

`stage3a_apply_ofdm_channel` 默认的 `circular_sampled_cfr` 是阶段 3A 的基线：把有效 CFR 嵌入 `NFFT` 点频域向量，计算 `ifft(fft(x).*H_full)`，再形成 CP 帧。`stage3a_explicit_circular_convolution` 的逐样本实现与该频域乘法是同一 N 点循环卷积；这是数值等价检查，不是完整连续时间 PLC 信道的证明。

新增的 `linear_sampled_cfr` 使用同一 `H_full` 的 `ifft` 得到 `h_sampled`，对有限 CP 帧显式做线性卷积，并保留帧边界内输出。它是审计模式，不是经过因果校准的现场时域信道。线性卷积的尾部被单独保存为 `linear_tail`，没有用裁剪或平滑改善结果。

CP 足以消除一个物理 OFDM 符号的线性卷积符号间干扰，需要它覆盖具有物理时间原点的有效因果时延扩展；循环频域乘法本身只需要采用 N 点周期模型。当前单边 `2--30 MHz` CFR 在其余频点置零，所得 `h_sampled` 是循环带限响应，缺少因果时间原点。因此代码分别报告：

- `physical_delay_support_samples`：当前模型不可提供，值为 `NaN`，`physical_delay_available=false`；
- `energy_99_support_samples`：循环响应峰值对齐后达到 99% 累积能量的样本长度；
- `threshold_support_samples`：峰值下 `-40 dB` 阈值的循环支撑长度；
- `cp_energy_fraction` 和线性/循环输出最大误差、RMS、相对 RMS。

本机 MATLAB R2024a 实际运行的 T2 示例中，`NFFT=4096`、`Fs=64 MHz`、CP=256、`-40 dB` 阈值下：99% 能量支撑为 4095 样本，阈值支撑为 4095 样本，CP 能量覆盖率约 0.691912，线性/循环输出相对 RMS 约 0.048204。不同拓扑和 CFR 会改变数值；这些数字只说明当前带限循环审计结果，不能推断现场 CP 不足。阶段 3A.1 的约 0.727 是另一拓扑/响应的历史审计值，不与本次结果混用。

频带截断造成的长支撑和旁瓣是有限频带 IFFT 的数值现象；它不能直接解释为真实电缆的物理多径或传播时延。当前 CIR 主峰只能称为循环带限 CIR 的循环时延指标，不能称真实 ToA、测距或现场 CP 设计依据。

## 参数感知匹配与独立评价

协议审计固定 27 点参数网格，边界为主线/支路长度约 ±2%、支路负载 ±10%、`kG`/RLGC 约 ±2%、源/接收端约 49--51 Ω，并带耦合器幅度/相位有界参数。目标函数为

\[
J(G,\theta)=D(\hat H,H(G,\theta))+\lambda R(\theta).
\]

本配置用校准种子选择 `lambda_grid={0,0.001,0.01,0.05}`，再用完全不重叠的测试种子评价 `nominal_nearest`、`topology_only` 和 `nuisance_aware_joint`。正式校准集为每种场景/观测/拓扑 10 次，测试集为 50 次；测试集未用于选择 lambda。实际选择 λ=0，不能称作一般最优值；27 点和该选择只是有界基线。联合匹配仍有额外自由度，若严格唯一率下降，应解释为参数不可辨识或拟合噪声风险。

## 多视图观测边界

`dual_receiver_complete` 与 `dual_receiver_highz_complete` 均在完整网络中求解，内部接收机作为并联负载，会改变网络。`dual_receiver_counterfactual` 是分析专用的无内部接收负载节点电压对照：端点接收机仍保留，内部节点电压从同一个完整网络解中读取，但不是可直接实现的零负载传感器。它不能与物理硬件结果混写，也不能把模型内严格率 1 解释为现场性能。

阶段 3A.2 的观测协议包括 `siso_forward`、`dual_receiver_complete`、`dual_receiver_highz_complete`、`dual_receiver_counterfactual` 和 `three_view_complete`。这些结果同时受观测信息、端接、接收负载、参数自由度和噪声影响；不能将多视图改善归因于单一因素。

## OFDM 边界与待确认项

`NFFT=4096`、`Fs=64 MHz`、`2--30 MHz`、CP=256 和 20 dB 白噪声是仿真假设，不代表某一 PLC 标准波形。当前没有完整通信收发机、同步/CFO/SCO 环路、编码、PAPR、真实有色/脉冲/周期噪声、耦合器寄生、多导体/MIMO 或市电测试。真实 FFT/采样率/导频位置和密度/CP、参考平面、端接、耦合器、现场负载、测量节点和同步方式均待确认。

阶段 3B 只有在这些测量协议和参数边界固定后，独立测试仍显示类间不可分主要来自导频密度、频带、探测功率或其他资源配置，才有充分证据启动。本阶段不作该假设。
