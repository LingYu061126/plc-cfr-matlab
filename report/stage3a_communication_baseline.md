# 阶段 3A：通信型 OFDM 拓扑感知基线

## 1. 结论摘要

本阶段完成了“通信型 OFDM 频域导频是否包含拓扑信息”的等效基线验证，但没有实现完整 PLC 收发机，也没有进行波形或导频优化。

在当前完整树网络和参数配置下，结论是：

- 50 Ω 对称端接的单端 SISO 中，T3/T5 的物理观测等价仍然存在。formal 结果在理想真实 CFR 和 20 dB 全导频 OFDM 条件下，等价类准确率为 1，严格唯一率为 0.5；这不是算法把两个拓扑区分得不够好，而是观测本身没有提供唯一信息。
- `dual_receiver_complete` 和 `three_view_complete` 在当前完整网络模型中使用额外的真实节点/方向视图，20 dB 全导频联合幅相特征的严格准确率为 1；该结果是模型内结果，不是现场性能。
- 全导频 OFDM 的 CFR 估计仍可以较好恢复信道。在 `siso_forward`、20 dB、白噪声、全导频条件下，幅相联合特征的平均 CFR NMSE 为 `4.179e-3`，加权相位 RMSE 为 `3.878 deg`，但严格唯一率仍为 0.5。这直接说明信道估计性能不能替代拓扑可辨识性。
- 稀疏导频间隔 4 的当前线性插值基线在 SISO、20 dB 下的幅相联合 CFR NMSE 为 `9.204e-4`，严格率为 0.75、等价类率为 1；这个单次配置结果不代表稀疏导频优于全导频，原因包括噪声实现和当前插值/频域模型，不能据此优化波形。
- 线路长度误差、RLGC 误差和定时偏移会造成不同类型的失败。SISO 幅相联合特征下，长度误差案例严格率为 0.50、等价类率为 0.75；RLGC 误差为 0.625/0.875；2 个采样定时偏移的当前等效接收链为 0.125/0.50，CFR NMSE 为 `2.138`。这些结果表明参数失配和同步假设必须先被隔离，不能简单归因于导频不足。

formal 不是大规模统计实验：每个场景、测量方式和拓扑使用 2 个可复现 trial，因此结果用于实现审计和基线比较，不用于宣称一般化概率性能。

## 2. 模型假设修订

基础物理信道统一写为

$$
H(f)=H(f;G,\theta),
$$

其中 `G` 是拓扑，`theta` 包括主线/支路长度、单位长度 `R'、L'、G'、C'`、负载、源/接收端阻抗和可配置的耦合器幅相误差。观测方式 `O` 是测量算子和端口配置，不被混入基础物理参数；它选择 `r,t`、端接、接收节点和视图组合。普通 OFDM 观测写为

$$
Y_{rt}[k]=X_t[k]H_{rt}(k;G,\theta)+N_{rt}[k].
$$

阶段 3A 的具体假设和待核对文献内容见 [`notes/模型假设修订说明.md`](../notes/模型假设修订说明.md)。

四层证据边界为：

- Level A：已知参数、无噪声真实 CFR，判定物理等价类；
- Level B：长度、RLGC、负载、端接和耦合器误差鲁棒性；
- Level C：IFFT/CP/去 CP/FFT/LS，稀疏导频插值和等效噪声/同步误差；
- Level D：SISO、双向、双接收和三视角完整网络观测比较。

## 3. 实现内容

新增入口和模块：

- `run_stage3a.m`、`experiments/exp12_stage3a_communication_baseline.m`；
- `stage3a_config`、`stage3a_observation_config`、`stage3a_apply_parameters`；
- `stage3a_generate_symbol`、`stage3a_apply_ofdm_channel`、`stage3a_receive_ofdm`、`stage3a_interpolate_cfr`；
- `stage3a_compute_observations`、`stage3a_toa_feature`、`stage3a_match_toa`；
- `tests/test_stage3a.m`。

普通 OFDM-CFR 观测调用阶段 2.2 的完整网络接口；没有重新引入阶段 2.1 的截断前缀网络。`cascade_network_stable` 和 `plc_full_network_response` 仅增加可选 RLGC 缩放字段，默认旧配置行为不变。

固定配置为：`NFFT=4096`、`Fs=64 MHz`、2–30 MHz、1793 个有效频点、CP=256、全导频间隔 1、稀疏导频间隔 4。普通 OFDM、FDR/TFDR 反射和输入导纳在 `O` 接口中分开；后两者当前只是由完整网络输入阻抗派生的 proxy，不是完整 FDR/TFDR 仪器模型。

## 4. 实验与数据来源

正式入口：

```matlab
run_stage3a('formal')
```

本机实际使用 MATLAB R2024a、MATLAB 基础许可和固定随机种子 `20260821`。formal 最终运行命令记录于 `results/logs/stage3a_formal_final.log`，生成：

- `stage3a_formal_trial_metrics.csv`：1088 条 trial/特征评价记录；
- `stage3a_formal_summary.csv`：136 个场景/观测/特征汇总组；
- `stage3a_formal_confusion.csv`：593 条非零混淆聚合记录；
- `stage3a_formal_config.csv`：34 个配置行，含参数、频点、CP、噪声和观测方式；
- `stage3a_formal_example_cfr.csv`：一个完整 CFR 原始示例；
- `stage3a_formal_raw.mat`：本机保存的 H_true/H_hat/CIR/延迟/噪声/参数原始结构，约 185 MB，按发布策略不纳入轻量代码仓库。

smoke 使用每个场景 1 个 trial，仅用于链路和文件检查；最终代码补充端接和耦合器案例后已重新执行，生成 544 条 trial/特征评价、136 条 raw、136 条 summary 和 544 条 confusion 记录。smoke 仍不作为正式统计结论。

## 5. 关键 formal 结果

下表使用 `amp_phase_joint_weighted`，除理想场景外为 20 dB 白噪声或指定扰动。`strict` 是具体拓扑编号准确率，`unique` 是在当前匹配未报告歧义且预测类为单元素时的严格唯一率，`class` 是观测等价类准确率。

| 场景/观测 | strict | unique | class | ambiguity | CFR NMSE |
|---|---:|---:|---:|---:|---:|
| ideal / siso_forward | 1.000 | 0.500 | 1.000 | 0.500 | 0 |
| white_dense_20 / siso_forward | 0.875 | 0.500 | 1.000 | 0.500 | 0.004179 |
| white_dense_20 / bidirectional_endpoint_fixed | 0.625 | 0.500 | 1.000 | 0.500 | 0.004144 |
| white_dense_20 / dual_receiver_complete | 1.000 | 1.000 | 1.000 | 0 | 0.004161 |
| white_dense_20 / three_view_complete | 1.000 | 1.000 | 1.000 | 0 | 0.004087 |
| white_sparse_20 / siso_forward | 0.750 | 0.500 | 1.000 | 0.500 | 0.000920 |
| length_error_20 / siso_forward | 0.500 | 0.375 | 0.750 | 0.500 | 0.004089 |
| rlgc_error_20 / siso_forward | 0.625 | 0.500 | 0.875 | 0.375 | 0.004180 |
| timing_offset_20 / siso_forward | 0.125 | 0 | 0.500 | 1.000 | 2.138290 |

`toa` 在本阶段仅使用循环带限 CIR 的主峰，是 `circular_delay` 指标，不是真实 ToA、距离或同步结果。理想 SISO `toa` 的严格率仅为 0.25；因此不能把该特征写成拓扑识别成功。

参数和误差案例还包括有色高斯噪声、脉冲噪声、支路负载变化、相邻符号负载变化代理、采样时钟偏差、导频相位旋转、端接阻抗误差和耦合器幅相误差。它们的逐行结果以 CSV 为准，不能从一条曲线外推现场性能。

## 6. 已验证、模型推断和待验证

### 已验证结论

- 修改前完整阶段 1.5、2、2.1、2.2、2.3 测试实际通过；阶段 3A 新测试实际通过；formal 入口实际完成并写出数据。
- SISO T3/T5 的等价类统计没有被新 OFDM 链路消除；额外完整网络观测可以在当前模型中提供区分信息。
- OFDM LS、稀疏复数插值、白/有色/脉冲噪声、CP、定时/采样时钟/相位误差接口均有代码测试和可复现输出。

### 根据模型推断

- 在 CFR NMSE 较小但 SISO 唯一率仍为 0.5 时，瓶颈主要是观测维度和结构等价，而不是通信信道估计精度。
- 完整双接收节点结果包含并联接收负载对网络的扰动，因此改善同时来自额外节点信息和网络状态变化；不能把它直接解释为“增加一个理想无扰动传感器”。
- 长度/RLGC/端接/负载误差可能把参数变化误判为拓扑变化；当前名义匹配器没有进行 Level B 的联合参数反演。

### 待验证问题

真实 PLC OFDM 的 FFT/采样率/导频/CP、同步和 CFO，现场有色/脉冲/周期噪声，真实负载与时变分布，耦合器寄生和参考平面，多导体/MIMO 端口，以及真实市电实验均未验证。当前也没有 BER、编码、PAPR 或完整通信链路。

## 7. 阶段 3B 判断

当前不建议直接进入波形优化。已有通信型 OFDM 在当前频带和全导频等效条件下能够估计 CFR，但 SISO 的主要限制已被证明是 T3/T5 观测等价，另有参数失配和同步误差影响。下一步应先确认真实测量节点、端接和波形参数；只有在这些因素固定后仍显示稀疏导频、带宽或功率造成类内/类间不可分，才有充分依据进入阶段 3B 的导频或资源配置研究。

## 8. 修改文件和运行状态

新增/修改包括模型假设说明、阶段设计说明、阶段 3A 源码、测试入口、两个旧网络函数的可选 RLGC 缩放、CSV/图/日志和本报告。旧阶段 1.5–2.3 物理公式、候选拓扑和等价类定义没有重写或删除。

实际命令和状态：

```matlab
% 修改前基线
run_tests

% 阶段 3A 单元测试
test_stage3a

% 阶段 3A smoke/formal
run_stage3a('smoke')
run_stage3a('formal')
```

修改前回归和阶段 3A 测试日志分别为 `stage3a_prechange_tests.log`、`stage3a_postchange_tests.log`、`stage3a_unit_tests_final.log`；最终全量回归为 `stage3a_final_run_tests.log`，formal 为 `stage3a_formal_final.log`，最终 smoke 为 `stage3a_smoke_final.log`。最终全量回归、smoke 和 formal 均已实际运行并通过。
