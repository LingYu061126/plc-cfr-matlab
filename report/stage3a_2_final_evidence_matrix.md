# 阶段 3A.2 最终证据矩阵

## 1. 审计范围和数据来源

本文件是阶段 3A.2 的收尾证据索引，不新增实验、不修改正式数据，也不进入阶段 3B。正式数字优先取自：

- `results/data/stage3a_2_protocol_summary.csv`：正式校准/测试汇总；
- `results/data/stage3a_2_model_validity_cp_metrics.csv`：CP、采样响应和线性/循环差异；
- `results/logs/stage3a_2_protocol_formal_final.log`：正式运行规模、lambda 和运行状态；
- `results/logs/stage3a_2_final_run_tests_seedfix.log`：最终 MATLAB 回归；
- `experiments/exp15_stage3a_2_model_validity.m`、`experiments/exp16_stage3a_2_protocol_audit.m`：实验定义和固定配置。

正式 protocol 结果来自修正后的 seed 分区：校准 600 个独立 seed，测试 3000 个独立 seed，交集为 0；校准记录 2400 条，测试方法记录 9000 条，summary 105 条，confusion 220 条。报告正文的本次数字修正只是 CSV 对齐，没有重新运行实验。

## 2. 证据矩阵

| 结论/问题 | 直接证据 | 当前结论 | 证据等级 | 不能外推的部分 |
|---|---|---|---|---|
| 频域乘法是否实现正确 | Stage 3A.2 测试；频域乘法与显式循环卷积最大误差约 `3.72e-16` | 在同一 `NFFT` 采样模型内一致 | MATLAB 直接验证 | 不等于已建立连续时间、因果、现场 PLC 时域信道 |
| 线性与循环模式是否被区分 | `stage3a_apply_ofdm_channel` 的 `channel_mode`、`linear_full_frame`、`linear_tail`；CP metrics CSV | 两种模式使用同一 sampled CFR，但线性卷积保留有限帧边界和尾部 | MATLAB 代码/数据验证 | 不等于物理线路冲激响应校准 |
| CP=256 是否覆盖物理时延 | `physical_delay_support_samples=NaN`、`physical_delay_available=false` | 当前模型没有可报告的物理时延支持 | MATLAB 直接验证模型边界 | 不能写成现场 CP 不足 |
| sampled CFR 的数值支撑 | T2、CP=256：99% 支撑 4095，-40 dB 支撑 4095，CP energy coverage `0.691912` | 单边 2--30 MHz 带限 IFFT 产生接近全 NFFT 的循环支撑 | MATLAB 直接验证 | 不能把旁瓣当真实多径或传播时延 |
| SISO T3/T5 是否唯一可辨识 | nominal SISO：class `1.000`，strict unique `0.500`；joint class `1.000`，unique `0.430` | 可识别等价类，不能可靠唯一选择 T3 或 T5 | MATLAB 直接验证 + 结构定义 | 噪声下随机选中一个编号不代表物理可辨识 |
| joint 是否自动改善唯一识别 | nominal SISO joint strict `0.785`、unique `0.430`、false unique `0.470`；nominal nearest unique `0.500` | 增加参数自由度没有证明唯一识别改善，并产生 false-unique 风险 | MATLAB 直接验证 | 27 点网格和 lambda=0 不是最优算法结论 |
| 多视角是否改善模型内可分性 | nominal 20 dB 下 loaded/high-Z/counterfactual/three-view 的 nominal strict unique 均为 `1.000` | 当前完整网络模型中额外视角可提供区分信息 | MATLAB 直接验证 | loaded 视图改变网络负载；counterfactual 不是硬件测量 |
| OFDM CFR 估计是否等于拓扑识别 | SISO nominal CFR NMSE `0.004125`，但 strict unique `0.500` | 信道估计误差较小仍不能保证唯一拓扑识别 | MATLAB 直接验证 | 不代表 BER、现场性能或完整收发机 |

## 3. 模型有效性：循环、线性和 CP

当前循环模式是：

```text
H_active -> H_full(NFFT) -> ifft/fft circular filtering -> CP
```

显式循环卷积只是在时域逐项计算同一个 N 点周期卷积，因此误差接近双精度数值误差。新增线性模式则对发射 CP 帧和 `h_sampled=ifft(H_full)` 做有限线性卷积；它产生 `linear_tail`，并将帧边界内的结果作为审计输出。两者的差异包含 sampled CFR 的周期化、带限截断和有限帧边界效应。

物理 CP 设计需要具有因果时间原点的有效时延扩展。当前 `H_full` 只有 2--30 MHz 有效频带，其他频点为零；IFFT 的响应是循环带限响应，没有可用于物理时延标定的时间原点。因此：

- `physical_delay_support_samples` 为 NaN 是模型能力边界，不是计算失败；
- `energy_99_support_samples=4095` 和 `threshold_support_samples=4095` 说明在当前峰值对齐的循环支撑定义下，带限旁瓣遍布整个 NFFT；
- `cp_energy_fraction=0.691912` 只表示 CP 前 257 个循环采样（含峰值样本的实现定义）占当前旋转 sampled response 能量的比例；
- `linear_circular_relative_rms=0.048204` 是 T2 这个 sampled CFR、CP=256 和有限帧设置下的数值比较，不是现场信道的 CP 误差。

## 4. 正式观测协议和拓扑结果

### 4.1 协议定义

| measurement_kind | 观测含义 | 是否改变网络工作点 | 证据边界 |
|---|---|---:|---|
| `siso_forward` | 端到端单向普通 OFDM CFR | 端点端接保持 | T3/T5 对称等价仍存在 |
| `dual_receiver_complete` | 完整网络中端点和内部节点接收视角 | 是，内部接收机为并联负载 | 额外视角和负载扰动共同作用 |
| `dual_receiver_highz_complete` | 内部接收机约 `1e6 ohm` 的高阻近似 | 是，但扰动较小而非零 | 不是理想无扰动探头 |
| `dual_receiver_counterfactual` | 同一完整网络解中的无内部接收负载节点电压 | 分析性反事实 | 不是可直接实现的零负载仪器 |
| `three_view_complete` | 完整网络的三视角联合观测 | 是，视图中的接收负载进入网络 | 模型内多视角结果 |

### 4.2 20 dB nominal_noise_20（正式测试）

以下全部来自 `stage3a_2_protocol_summary.csv`，每行 `trials=200`：

| 观测 | 方法 | strict | strict unique | equivalence class | ambiguity | false unique | CFR NMSE |
|---|---|---:|---:|---:|---:|---:|---:|
| SISO | nominal_nearest | 0.770 | 0.500 | 1.000 | 0.500 | 0 | 0.004125 |
| SISO | topology_only | 0.760 | 0.500 | 1.000 | 0.500 | 0 | 0.004125 |
| SISO | nuisance_aware_joint | 0.785 | 0.430 | 1.000 | 0.100 | 0.470 | 0.004125 |
| dual receiver loaded | nominal_nearest | 1.000 | 1.000 | 1.000 | 0 | 0 | 0.004116 |
| dual receiver loaded | nuisance_aware_joint | 1.000 | 0.990 | 1.000 | 0.010 | 0 | 0.004116 |
| dual receiver high-Z | nominal_nearest | 1.000 | 1.000 | 1.000 | 0 | 0 | 0.004120 |
| dual receiver high-Z | nuisance_aware_joint | 1.000 | 0.965 | 1.000 | 0.035 | 0 | 0.004120 |
| counterfactual | nominal_nearest | 1.000 | 1.000 | 1.000 | 0 | 0 | 0.004120 |
| counterfactual | nuisance_aware_joint | 1.000 | 0.920 | 1.000 | 0.080 | 0 | 0.004120 |
| three view | nominal_nearest | 1.000 | 1.000 | 1.000 | 0 | 0 | 0.004131 |
| three view | nuisance_aware_joint | 1.000 | 0.985 | 1.000 | 0.015 | 0 | 0.004131 |

“strict=1” 的多视角结果是当前模型、当前端接、20 dB 白噪声、当前参数边界和当前特征的结果；不能写成现场增加接收机即可达到的性能。

### 4.3 三类参数/负载场景

正式测试实际覆盖 `nominal_noise_20`、`load_error_10` 和 `joint_bounded`。SISO 的 `nuisance_aware_joint` 结果如下，便于区分名义条件与参数扰动：

| 场景 | strict | strict unique | class | ambiguity | false unique | theta RMSE | boundary rate |
|---|---:|---:|---:|---:|---:|---:|---:|
| nominal_noise_20 | 0.785 | 0.430 | 1.000 | 0.100 | 0.470 | 0.012124 | 0.945 |
| load_error_10 | 0.780 | 0.395 | 1.000 | 0.470 | 0.135 | 0.009115 | 1.000 |
| joint_bounded | 0.715 | 0.490 | 1.000 | 0.475 | 0.035 | 0.025293 | 0.590 |

这些数字表示当前有界网格/正则化基线在不同仿真场景中的行为，不是现场负载分布或参数估计性能。其余观测方式和方法保存在 summary CSV；本矩阵不把一行结果外推为普遍规律。

## 5. 证据等级和结论分栏

### 已验证结果

- MATLAB R2024a 实际通过阶段 1.5、2、2.1、2.2、2.3、3A、3A.1 和 3A.2 全部测试。
- 当前 `circular_sampled_cfr` 的频域乘法与显式循环卷积一致，误差约 `3.72e-16`。
- 当前 sampled CFR 没有物理时延支持；CP/能量/阈值/线性-循环误差指标已经写入 CSV。
- SISO 下 T3/T5 可以识别到正确等价类，但不能据此唯一识别具体编号。
- joint 结果包含独立校准/测试分离，且 formal 结果显示额外参数自由度会造成唯一性和 false-unique 的权衡。
- 额外视角在当前完整网络模型中提高了候选拓扑的模型内可分性；loaded/high-Z/counterfactual 的物理含义已经分别记录。

### 根据模型推断

- 当前首要限制是观测等价和测量协议，其次是参数不确定性、接收负载和同步/时域模型边界；不能仅依据 CFR NMSE 判断波形信息不足。
- SISO 下改变算法不能消除由对称网络和对称端接造成的观测等价；若算法输出唯一 T3/T5，应优先检查 false-unique 或 tie 容差。
- 多视角改善的因果来源不能仅由当前实验分解为“额外信息”或“工作点改变”，因为物理 loaded 视图同时改变两者；counterfactual 只能作为分析对照。

### 待真实测量验证

- 实际 PLC OFDM 的 FFT、采样率、CP、导频、同步/CFO/SCO、噪声和耦合器；
- 现场负载和端接是否对称、内部节点是否可接入、传感器输入阻抗及其校准；
- 真实因果时域信道、传播时延和物理 CP 设计；
- 多导体/MIMO、耦合器寄生和参考平面；
- 真实市电或硬件实验中的拓扑、负载时变和测量重复性。

## 6. 阶段提交和阶段 3B 门槛

阶段 3A.2 可以作为“模型内阶段性成果”提交导师：它已经给出了可复现的模型审计、等价类结论、独立参数感知基线、正式日志和证据边界。但它不能作为“真实 PLC 拓扑已唯一识别”或“CP 已经完成物理验证”的结论提交。

阶段 3B 暂不启动。前置条件是先由导师确认实际 OFDM 参数、端接/耦合器/参考平面、可用测量节点、同步假设和是否采用有物理时间原点的因果信道模型；只有这些固定后，独立测试仍显示瓶颈主要来自导频密度、带宽、探测功率或资源配置，才有依据进入波形优化。
