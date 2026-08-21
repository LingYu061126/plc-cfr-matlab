# 阶段 3A.2：OFDM 链路物理有效性与观测协议确定

## 1. 研究目标与修改边界

本阶段对阶段 3A 的“采样 CFR + OFDM CP/FFT/LS”链路进行物理有效性审计，并用独立校准/测试种子建立参数感知拓扑匹配基线。目标是明确当前循环等效模型能支持什么结论、哪些观测配置具有清晰的物理含义，以及是否已有证据进入阶段 3B。没有优化 OFDM 波形、导频密度、子载波位置、功率或带宽。

阶段 1.5--3A.1 的代码、正式结果、候选拓扑、T3/T5 等价类和基础 RLGC/稳定递推未被删除或重写。新增代码只通过可选 `channel_mode`、观测配置和独立实验入口扩展接口。

## 2. 修改前基线

修改前先用本机 MATLAB R2024a（24.1.0.2537033）和 MATLAB 基础许可运行 `run_tests`，阶段 1.5、2、2.1、2.2、2.3、3A、3A.1 测试全部通过；日志为 `results/logs/stage3a_2_prechange_tests.log`。阶段 3A.2 接口测试在正式实验前也通过，日志为 `results/logs/stage3a_2_interface_tests.log`。

## 3. 链路模型审计

### 3.1 当前循环基线

当前链路为：

```text
X[k] -> IFFT + CP -> sampled-CFR circular filtering -> noise/phase
     -> remove CP and sample -> FFT -> LS/interpolated CFR
```

`H_active` 被放入 `NFFT` 点 `H_full`，当前默认 `circular_sampled_cfr` 计算 `ifft(fft(payload).*H_full)`。测试同时用显式 N 点循环卷积复核了该实现；两者最大误差约 `3.72e-16`。这证明频域乘法和同一采样模型的循环卷积数值等价，不证明连续时间传输线的物理冲激响应已被构造出来。

### 3.2 新增线性审计模式

`linear_sampled_cfr` 使用同一 `H_full` 的 `ifft` 作为有限采样冲激响应，对完整发射 CP 帧做显式有限线性卷积，再截取接收帧边界。`linear_full_frame` 和 `linear_tail` 被保存在 details 中；旧默认模式和阶段 3A 结果不变。该模式用于比较 CP/边界效应，不宣称是现场已校准的时域 PLC 信道。

### 3.3 CP 指标和实际结果

`exp15_stage3a_2_model_validity` 扫描 CP=0、64、128、256、512、1024，并写出：

- `physical_delay_support_samples` / `physical_delay_support_s`；
- `energy_99_support_samples`；
- `threshold_support_samples`（阈值为 -40 dB）；
- `cp_energy_fraction`、`cp_covers_threshold_support`；
- `linear_circular_max_abs`、`linear_circular_rms`、`linear_circular_relative_rms`；
- 采样 CFR、`h_sampled`、配置和图。

本次 T2 结果中 CP=256 的关键数值为：

| 指标 | 数值 |
|---|---:|
| 物理延迟支撑 | 不可用（NaN；采样 CFR 无物理时间原点） |
| 99% 能量支撑 | 4095 samples |
| -40 dB 阈值支撑 | 4095 samples |
| CP 能量覆盖率 | 0.691912 |
| 线性/循环最大绝对误差 | 约 0.002510 |
| 线性/循环 RMS | 约 0.0001402 |
| 线性/循环相对 RMS | 约 0.048204 |

因此，CP=256 在“相同 N 点循环频域模型”的数值等价语义下可以运行，但在本次带限采样响应的 `-40 dB`/99% 支撑定义下并未覆盖全部循环支撑。它不能被表述为现场 OFDM 系统 CP 不足，因为当前模型没有物理因果时延支持。阶段 3A.1 报告中的 CP 覆盖率约 0.727 属于另一拓扑/响应；本报告不将两个响应的数值混为一个常数。

频带只有 2--30 MHz，未测频点在构造 `H_full` 时置零。由此得到的长循环旁瓣是带限 IFFT 的数学支撑，应与真实线路传播时延、仪器窗函数和同步共同产生的物理响应区分。当前 `CIR` 和主峰只能命名为 circular band-limited CIR / circular-delay proxy；不能写成真实 ToA 或测距。

## 4. 参数感知协议

### 4.1 配置

`exp16_stage3a_2_protocol_audit` 固定：

- 场景：`nominal_noise_20`、`load_error_10`、`joint_bounded`；
- 观测：`siso_forward`、`dual_receiver_complete`、`dual_receiver_highz_complete`、`dual_receiver_counterfactual`、`three_view_complete`；
- 4 个候选拓扑；
- 20 dB 接收信号功率归一化白噪声；
- 27 点有界参数网格；
- 校准每拓扑 10 次，测试每拓扑 50 次；
- lambda 候选 `{0, 0.001, 0.01, 0.05}`；
- 校准种子偏移 52000，测试种子偏移 6200000，且两集合不重叠；该分区覆盖场景/观测/拓扑的内部步长后仍保持不重叠。

联合目标为

\[
 (\hat G,\hat\theta)=\arg\min_{G,\theta}
 D(\hat H,H(G,\theta))+\lambda R(\theta),
\]

其中 `R` 是按配置边界归一化的参数偏离名义值惩罚。27 点、边界和 lambda 不是优化器调参后的最优设置，而是审计用有界基线。

### 4.2 实际运行规模

正式命令实际完成：

```matlab
addpath('src','config','experiments','tests');
result = exp16_stage3a_2_protocol_audit(pwd);
```

输出 `stage3a_2_protocol_calibration_selection.csv`、`config.csv`、`trial_metrics.csv`、`summary.csv`、`confusion.csv`、轻量 `raw.mat` 和两张图。校准记录为 `3 scenarios × 5 views × 4 topologies × 10 trials × 4 lambdas = 2400`；测试记录为 `3 × 5 × 4 × 50 × 3 methods = 9000`。测试 summary 共 45 行，连同校准 lambda 汇总共 105 行；修正 seed 分区后的测试 confusion 共 220 条非零聚合记录。校准有 600 个独立 seed，测试有 3000 个独立 seed，交集为 0。

校准选择的 λ 和下表数值以修正 seed 分区后的最终运行文件为准。该选择只反映本次校准种子、目标和候选网格，不能称为一般最优正则化。正式测试没有使用校准试验的随机种子。

### 4.3 20 dB 名义场景关键结果

下表来自独立 test split 的 `stage3a_2_protocol_summary.csv`。`strict_unique_rate`、`equivalence_class_rate`、`ambiguity_rate`、`false_unique_rate` 是拓扑层指标；`cfr_nmse` 是信道估计层指标，两者不等价。

| 观测 | 方法 | strict | strict unique | class | ambiguity | false unique | CFR NMSE |
|---|---|---:|---:|---:|---:|---:|---:|
| siso_forward | nominal_nearest | 0.770 | 0.500 | 1.000 | 0.500 | 0 | 0.004125 |
| siso_forward | topology_only | 0.760 | 0.500 | 1.000 | 0.500 | 0 | 0.004125 |
| siso_forward | nuisance_aware_joint | 0.785 | 0.430 | 1.000 | 0.100 | 0.470 | 0.004125 |
| dual_receiver_complete | nominal_nearest | 1.000 | 1.000 | 1.000 | 0 | 0 | 0.004116 |
| dual_receiver_complete | nuisance_aware_joint | 1.000 | 0.990 | 1.000 | 0.010 | 0 | 0.004116 |
| dual_receiver_highz_complete | nominal_nearest | 1.000 | 1.000 | 1.000 | 0 | 0 | 0.004120 |
| dual_receiver_highz_complete | nuisance_aware_joint | 1.000 | 0.965 | 1.000 | 0.035 | 0 | 0.004120 |
| dual_receiver_counterfactual | nominal_nearest | 1.000 | 1.000 | 1.000 | 0 | 0 | 0.004120 |
| dual_receiver_counterfactual | nuisance_aware_joint | 1.000 | 0.920 | 1.000 | 0.080 | 0 | 0.004120 |
| three_view_complete | nominal_nearest | 1.000 | 1.000 | 1.000 | 0 | 0 | 0.004131 |
| three_view_complete | nuisance_aware_joint | 1.000 | 0.985 | 1.000 | 0.015 | 0 | 0.004131 |

这里的三种多视图配置不是同一种物理测量：loaded/high-Z 视图的内部接收机是并联负载；counterfactual 只是同一完整网络解中的分析性无负载节点电压。多视图严格率为 1 是模型内、20 dB、当前参数边界和特征下的结果，不能直接写成现场传感器性能。

对于 SISO，T3/T5 的等价类率均为 1；联合搜索虽然 strict accuracy 为 0.790，却把一部分物理等价的 noisy observation 变成非 tie 的唯一候选，故 `false_unique_rate=0.460`、unique rate 下降到 0.420。这是参数自由度造成的不可辨识/过拟合风险，不是算法已经打破物理等价。名义匹配和 amplitude topology-only 的严格率也不等于 T3/T5 的唯一可辨识性。

`load_error_10` 和 `joint_bounded` 的逐场景结果在 summary/trial CSV 中保存。它们用于显示负载/参数不确定性和测量误差如何改变距离与歧义，不代表现场参数分布。所有方法使用相同观测信号、噪声种子、频点和候选集合；nominal 与 joint 只在匹配器和特征定义上按配置明确区分，不能把不同特征的结果当成公平的单一算法比较。

## 5. 多视图与协议结论

### 已验证结论（MATLAB 实际运行支持）

1. 阶段 1.5--3A.1 全部回归测试在修改前通过；阶段 3A.2 接口测试通过。
2. 频域乘法与同一采样 CFR 的显式循环卷积数值一致，最大误差约 `3.72e-16`。
3. 当前采样 CFR 没有可报告的物理延迟支持；CP=256 的能量/阈值审计结果已写入 CSV，而非把它解释成现场 CP 结论。
4. 正式协议使用了独立校准和测试种子；校准 2400 条、测试 9000 条，实际测试每拓扑 50 次。
5. 对称 SISO 仍只能可靠报告 T3/T5 等价类；参数感知搜索不能把物理等价变成可信唯一识别。
6. 在当前完整网络模型，多视图在名义 20 dB 测试中严格率为 1，但 joint 的唯一率略低；该结果与参数自由度、观测负载和额外视图共同相关。

### 根据模型推断

- 现阶段首要瓶颈是观测等价和端口/节点协议，而非已经被证明的 OFDM 资源不足；参数失配和同步是次级但重要的模型风险。
- 多视图的改善不能只归因于“信息增加”：有限输入阻抗会作为并联负载改变完整网络；high-Z 和 counterfactual 的差异表明负载模型必须独立报告。
- 联合匹配的参数自由度可以降低 ambiguity，却增加 false-unique 或边界命中风险；因此不能根据 strict accuracy 单项宣称算法改进。

### 尚待验证

真实 PLC OFDM 的 FFT/采样率/CP/导频，完整 CP 时域卷积、同步和 CFO/SCO，现场有色/脉冲/周期噪声，耦合器寄生和参考平面，真实负载时变、多导体/MIMO、可用接收节点以及市电实验均未验证。当前模型也没有通信编码、BER、PAPR 或完整收发机。

## 6. 阶段 3B 门槛与建议

当前**不建议进入阶段 3B**。虽然普通通信型 OFDM 等效导频能够在本模型中估计 CFR，且多视图可在理想配置下区分候选拓扑，但还没有同时固定真实测量节点、端接、耦合器、物理 CP/时延定义和同步假设。SISO 的主要障碍是 T3/T5 结构观测等价，不能靠波形优化消除。

只有当真实观测协议、参数边界和同步误差被固定，并且独立测试仍显示剩余类间不可分主要来自导频密度、频带、功率或其他 OFDM 资源时，才建议阶段 3B 优先研究导频位置/密度、探测功率或带宽。当前证据不足以在这些方向中选择一个，也不足以把阶段 3B 写成必要步骤。

## 7. 文件、命令和运行状态

新增/修改的主要文件：

- `src/stage3a_apply_ofdm_channel.m`、`src/stage3a_explicit_linear_convolution.m`、`src/stage3a_cp_coverage.m`；
- `src/plc_counterfactual_multiview_response.m`、`src/plc_measurement_bundle.m`、`src/stage3a_observation_config.m`、`src/stage3a_compute_observations.m`；
- `src/stage3a_config.m`、`run_stage3a.m`、`tests/test_stage3a_2.m`、`tests/run_tests.m`；
- `experiments/exp15_stage3a_2_model_validity.m`、`experiments/exp16_stage3a_2_protocol_audit.m`；
- `notes/stage3a_2_model_validity.md` 和本报告；
- `results/data/stage3a_2_*`、`results/figures/stage3a_2_*`、`results/logs/stage3a_2_*`。

实际运行命令：

```matlab
run_tests
run_stage3a('model_validity')
exp16_stage3a_2_protocol_audit(pwd,1,2) % smoke，1/2 次，仅接口诊断
exp16_stage3a_2_protocol_audit(pwd)     % formal，10/50 次
run_tests                              % 文档更新后的最终回归
```

已实际运行：修改前全量 `run_tests`、阶段 3A.2 接口测试、model-validity 实验、protocol smoke、protocol formal，以及最终 seed 分区修复后的全量回归。正式协议日志为 `results/logs/stage3a_2_protocol_formal_final.log`，smoke 日志为 `results/logs/stage3a_2_protocol_smoke_final.log`，最终全量回归日志为 `results/logs/stage3a_2_final_run_tests_seedfix.log`。此前 seed 分区存在碰撞的 formal 文件已由修正后的入口重新生成，不再作为最终统计依据。第一次未加入 MATLAB path 的调用错误保留在 `results/logs/stage3a_2_final_run_tests.log`，不计为测试通过；修正 path 后全量回归退出码为 0。
