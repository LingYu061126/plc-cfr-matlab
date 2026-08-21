# Stage 3A.1 审计与参数感知实验说明

## 1. 范围

本阶段只审计阶段 3A 的通信型 OFDM 拓扑感知基线，并增加有界的线路/负载参数感知匹配。没有进入阶段 3B，也没有修改阶段 1.5 的 RLGC、传播常数、ABCD 或稳定阻抗递推公式，没有修改候选拓扑和 T3/T5 等价类定义。

代码仍是等效链路：

```text
X[k] -> IFFT -> 循环前缀 -> 采样 CFR 的循环频域滤波 -> 噪声
     -> 去 CP -> FFT -> LS/稀疏复数插值 -> CFR/CIR/循环延迟特征
     -> 完整网络拓扑匹配
```

其中网络响应是 `H(f;G,theta)`，观测方式 `O` 选择端口、端接和完整网络视图。普通 OFDM 端到端 CFR 不等同于 FDR/TFDR 反射响应。

## 2. 固定配置

`src/stage3a_config.m` 集中保存 Stage 3A.1 配置：

- `NFFT=4096`、`Fs=64 MHz`、有效频带 `2–30 MHz`、1793 个有效频点；
- `CP=256` 个采样，仍是仿真假设；
- audit SNR 为 `5/10/15/20/30 dB`；
- 规则导频间隔为 `1/2/4/8`；
- audit 每个 SNR、导频间隔、观测方式、特征和拓扑使用 50 个独立 trial；
- 固定随机种子为 `20260821`，白噪声定义为当前接收信号功率归一化的等效 AWGN；
- 观测方式为 `siso_forward`、`bidirectional_endpoint_fixed`、`dual_receiver_complete`、`three_view_complete`；
- 特征为 `amplitude`、`amp_phase_joint_weighted`、`cir`、`toa`。

审计入口：

```matlab
run_stage3a('audit')
```

`run_stage3a('audit_smoke')` 只用于诊断文件格式和链路，不能作为正式统计结果。正式 audit 结果写入 `results/data/stage3a_1_audit_*.csv`、`stage3a_1_audit_raw.mat`、`results/figures/stage3a_1_audit_snr_pilot_audit.png` 和 `results/logs/stage3a_1_audit_final.log`。

## 3. 等效 OFDM 链路审计

`stage3a_apply_ofdm_channel` 对 `NFFT` 点有效频域采样 CFR 做循环滤波，再添加 CP；`stage3a_explicit_circular_convolution` 用显式求和计算同一个 N 点循环卷积。测试中，两者构造的带 CP 帧最大绝对误差为 `3.72e-16`。

这证明的是“采样 CFR 的循环频域滤波”和“同一采样模型的显式循环时域卷积”一致，不是完整时域 PLC 线路卷积的证明。当前模型没有建立因果、有限长度、连续时间的物理冲激响应；因此 `stage3a_cp_coverage` 的能量覆盖率和阈值支撑只用于数值审计。

在当前 2–30 MHz 单边有效频带、其余频点置零的构造下，CP=256 的 `-40 dB` 阈值支撑为 4095 个循环样本，能量覆盖率约 `0.727`。这说明不能把 CP=256 写成已经覆盖当前带限循环响应的物理保护间隔。循环 CIR 主峰仍只能称为 `circular delay`，不能称为真实 ToA 或测距。

定时偏移在接收端去 CP/采样位置选择时作用；采样时钟偏差在接收采样位置插值时作用；公共导频相位旋转在发送帧经过噪声模型后乘到接收帧上。它们是等效误差接口，不是完整同步器、CFO 或采样时钟环路。

## 4. 参数感知匹配

`stage3a_parameter_grid` 生成固定的 27 点、有边界、以名义点加单因素扰动为主的参数网格。当前边界包括：主线/支路长度 `±2%`、支路负载 `±10%`、`kG` `±2%`、RLGC 各分量 `±2%`、源/接收阻抗约 `49–51 ohm`、耦合器幅度 `±2%` 和相位 `±5 deg`。这些是仿真配置，不是现场校准区间。

联合目标写为：

$$
J(G,\theta)=D\left(\hat H,H(G,\theta)\right)+\lambda R(\theta),
\qquad \lambda=0.01,
$$

其中 `D` 是多视图幅相联合距离，`R` 是按各参数边界归一化后的偏离名义值均方。网格、边界和正则化在结果配置中保存。匹配方法保持同一观测和同一频率网格：

1. `nominal_nearest`：名义 CFR + 幅相联合特征；
2. `topology_only`：名义 CFR + 幅值特征；
3. `nuisance_aware_joint`：同一幅相联合特征下搜索 `(G,theta)`。

第三种方法的自由度更高，可能拟合噪声或把拓扑差异吸收到参数中；它不被称为最优方法。

## 5. 接收节点模型

`dual_receiver_complete` 中内部接收节点使用有限输入阻抗并联进入完整网络，因此观测本身会改变网络。新增的 `dual_receiver_highz_complete` 使用 `1e6 ohm` 的内部接收负载作为高输入阻抗等效对照，但仍不是理想无扰动探头，也没有耦合器寄生、参考平面和校准误差模型。多视图改善不能直接解释为现场只需增加一个传感器即可复现。

## 6. 证据边界

### 已验证

- 显式循环卷积与当前 CFR 频域实现数值一致；
- audit 的配置、固定种子、50 次统计和 CSV/MAT/图/日志输出实际运行；
- 参数网格、完整网络模板、nominal/joint 匹配接口和高输入阻抗观测接口通过 MATLAB 回归测试；
- Stage 3A.1 使用的观测仍保留对称 SISO 的 T3/T5 物理等价类统计。

### 根据模型推断

- 当 CFR 估计误差已经较小而 SISO 严格唯一率仍受 T3/T5 等价类限制时，主要瓶颈不是单纯 LS 误差；
- 参数自由度增加可能提高拟合能力，却降低唯一报告率；
- 多视图结果同时包含额外观测信息和接收负载对网络的扰动。

### 尚待验证

真实 PLC OFDM 的 FFT、采样率、导频、CP、同步/CFO、现场有色/脉冲噪声、真实负载时变、耦合器寄生、多导体/MIMO 和市电实验均未验证。
