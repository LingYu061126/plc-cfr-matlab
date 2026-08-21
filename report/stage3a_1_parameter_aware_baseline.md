# 阶段 3A.1：结果审计与参数感知基线

## 1. 研究目标与边界

阶段 3A.1 审计现有通信型 OFDM 等效链路，扩大统计规模，并比较名义拓扑匹配和有界线路/负载参数感知匹配。目标是判断当前瓶颈来自观测等价、参数失配、同步误差还是导频信息，而不是优化 OFDM 波形。

本报告不把当前实现表述为完整 PLC OFDM 收发机。模型使用 `NFFT=4096`、`Fs=64 MHz`、`2–30 MHz`、1793 个有效频点和 CP=256 的仿真假设；接收模型仍是 `Y=XH+N` 的频域等效信道测量。没有编码、PAPR、完整同步/CFO、真实耦合器、多导体 MIMO 或市电实验。

## 2. 修改前基线与实际运行

修改前先在 MATLAB R2024a `24.1.0.2537033`、MATLAB 基础许可下运行了原有 `test_stage3a`；原有 8 项 Stage 3A 测试全部通过，日志为 `results/logs/stage3a_1_prechange_tests.log`。阶段 1.5–2.3 的既有代码、结果和测试未被删除或覆盖。

本阶段新增/修改后的关键命令为：

```matlab
% 快速回归
addpath('src','config','experiments','tests'); test_stage3a; test_stage3a_1;

% 诊断 smoke（不作为正式统计）
run_stage3a('audit_smoke');

% 正式审计
run_stage3a('audit');

% 参数感知基线
run_stage3a('parameter_aware');

% 全部历史阶段回归
run_tests;
```

修改后的 3A.1 接口测试实际通过；正式 audit 和参数感知实验也实际完成。最终全量回归日志为 `results/logs/stage3a_1_final_run_tests.log`，阶段 1.5、2、2.1、2.2、2.3、3A 和 3A.1 全部通过。

## 3. 等效 OFDM 链路验证

当前实现先构造 `H_full`，计算 `ifft(fft(x).*H_full)`，再添加循环前缀。新增显式时域循环卷积函数逐样本计算同一 N 点周期卷积；测试中带 CP 帧最大绝对误差为 `3.72e-16`。

该结果只验证两种等效实现相同，不证明当前模型是物理时域 PLC 信道。CP 审计在 `-40 dB` 阈值下得到有效支撑 4095 个循环样本、CP 能量覆盖率约 0.727；因此 CP=256 不能被宣称为覆盖该单边带限循环响应的物理保护间隔。当前 `circular band-limited CIR` 主峰是循环时延指标，不是真实 ToA。

定时偏移和采样时钟偏差都在接收重采样/取样点阶段生效；公共相位旋转在接收帧上生效。它们是可重复的等效误差接口，未扩展为完整同步或 CFO 模型。

## 4. 正式 audit 设计与数据

`run_stage3a('audit')` 实际完成：

- SNR：5、10、15、20、30 dB；
- 导频间隔：1、2、4、8；
- 观测方式：`siso_forward`、`bidirectional_endpoint_fixed`、`dual_receiver_complete`、`three_view_complete`；
- 特征：`amplitude`、`amp_phase_joint_weighted`、`cir`、`toa`；
- 候选拓扑：T2/T3/T4/T5；
- 每个条件每个拓扑 50 个固定种子 trial。

输出为 64,000 条 feature-level trial 记录、320 条 summary 记录和 1,534 条非零混淆聚合记录，正式运行耗时约 702.624 s。64,000 是 5×4×4×4×4×50 的特征评价总数；每个 summary 的 `trials=200` 对应四个拓扑各 50 次。原始 CSV、轻量 MAT、配置、图和日志分别位于 `results/data/stage3a_1_audit_*`、`results/figures/stage3a_1_audit_snr_pilot_audit.png` 和 `results/logs/stage3a_1_audit_final.log`。

### 4.1 20 dB、全导频、主要特征

以下数值来自 `stage3a_1_audit_summary.csv`，是 50 次/拓扑汇总；`strict_accuracy` 是具体拓扑编号准确率，`strict_unique_rate` 是严格且没有唯一性歧义的正确率，`equivalence_class_rate` 是观测等价类准确率。

| 观测/特征 | strict | strict unique | equivalence class | ambiguity | false unique | CFR NMSE |
|---|---:|---:|---:|---:|---:|---:|
| SISO / amplitude | 0.730 | 0.500 | 1.000 | 0.500 | 0 | 0.004120 |
| SISO / amp-phase joint | 0.765 | 0.500 | 1.000 | 0.500 | 0 | 0.004120 |
| SISO / CIR | 0.750 | 0.500 | 1.000 | 0.500 | 0 | 0.004120 |
| SISO / circular-delay proxy | 0.250 | 0 | 0.250 | 1.000 | 0 | 0.004120 |
| dual receiver / amp-phase joint | 1.000 | 1.000 | 1.000 | 0 | 0 | 0.004121 |
| three view / amp-phase joint | 1.000 | 1.000 | 1.000 | 0 | 0 | 0.004124 |

SISO 中 T3/T5 的严格候选选择会在具体 trial 中随机分裂，但等价类率仍为 1、唯一率为 0.5；这不是算法已经获得了拓扑唯一信息。`toa` 只使用循环带限 CIR 的主峰，所以不能作为真实到达时间结论。

### 4.2 SNR 与导频间隔

当前 audit 的 CFR NMSE 随 SNR 从 5 dB 到 30 dB 总体下降，这是信道估计层面的结果。SISO 的 T3/T5 等价类不因 SNR 增加而消失；在全导频、20 dB、幅相联合特征下 SISO 严格率 0.765、唯一率 0.5。多视图在本模型中可达较高严格率，但不能据此把导频或通信性能直接写成现场拓扑识别性能。不同 trial 的严格率允许非单调，完整误差棒和置信区间保存在 summary CSV。

导频间隔 1、2、4、8 的差异应以 CSV 为准；本阶段没有根据测试结果优化导频间隔、子载波位置或功率。稀疏插值仍是简单复数线性插值基线。

## 5. 参数感知匹配

`stage3a_parameter_grid` 使用 27 个参数模板，边界为：主线/支路长度 ±2%、支路负载 ±10%、`kG` ±2%、RLGC ±2%、源/接收阻抗约 49–51 Ω、耦合器幅度 ±2%、相位 ±5°。固定正则化系数 `lambda=0.01`，正则项为按边界归一化的参数偏离名义值均方。参数范围和配置保存在 `stage3a_1_parameter_aware_config.csv`。

参数实验实际使用 7 个场景（名义噪声、负载 ±10%、长度 ±2%、RLGC ±2%、端接 ±2%、耦合器误差和联合有界扰动）、4 个观测方式、4 个拓扑、20 次/拓扑，共 6,720 条方法 trial 记录和 84 条 summary 记录。比较方法使用相同观测、相同噪声种子、相同频点和相同候选拓扑：

- `nominal_nearest`：幅相联合特征、名义参数；
- `topology_only`：幅值特征、名义参数；
- `nuisance_aware_joint`：幅相联合特征、27 点参数网格和正则项。

### 5.1 名义 20 dB SISO 与多视图

| 观测/方法 | strict | strict unique | equivalence class | ambiguity | false unique | theta RMSE | boundary rate |
|---|---:|---:|---:|---:|---:|---:|---:|
| SISO / nominal_nearest | 0.7125 | 0.5000 | 1.0000 | 0.5000 | 0 | 0 | 0 |
| SISO / topology_only | 0.7125 | 0.5000 | 1.0000 | 0.5000 | 0 | 0 | 0 |
| SISO / nuisance_aware_joint | 0.7125 | 0.1500 | 1.0000 | 0.8500 | 0 | 0.004691 | 0.1625 |
| dual receiver / nominal_nearest | 1.0000 | 1.0000 | 1.0000 | 0 | 0 | 0 | 0 |
| dual receiver / nuisance_aware_joint | 1.0000 | 0.5125 | 1.0000 | 0.4875 | 0 | 0.013929 | 0.475 |
| high-Z dual receiver / nuisance_aware_joint | 1.0000 | 0.0375 | 1.0000 | 0.9625 | 0 | 0.001083 | 0.0375 |
| three view / nominal_nearest | 1.0000 | 1.0000 | 1.0000 | 0 | 0 | 0 | 0 |
| three view / nuisance_aware_joint | 1.0000 | 0.5125 | 1.0000 | 0.4875 | 0 | 0.014795 | 0.5125 |

在这些结果中，joint 搜索没有减少严格拓扑误判；在已可分的多视图条件下，更多参数自由度反而提高了数值歧义和边界命中。这是参数搜索过拟合/不可辨识风险的证据，不是“参数感知算法优于基线”的证据。当前 `false_unique_rate` 按物理非单元素等价类但算法未报告歧义定义，正式汇总为 0；它与 `strict_unique_rate`、`ambiguity_rate` 分开保存，不能用严格率替代。

### 5.2 参数扰动结论

负载、长度、RLGC、端接、耦合器和联合扰动的逐场景结果见 `stage3a_1_parameter_aware_summary.csv`。这些结果只支持当前参数边界和模型内的鲁棒性审计。它们不能把 2% 或 10% 直接解释成现场不确定性的真实分布，也不能把参数拟合误差写成线路长度或负载已经被可靠估计。

## 6. 高输入阻抗与接收负载

`dual_receiver_complete` 的内部接收机是并联负载；`dual_receiver_highz_complete` 仅把内部接收阻抗设为 `1e6 ohm`，仍在同一完整网络中求解。两者都不是理想无扰动测量。观测比较中的变化来自额外视图、端接定义和接收负载对网络的共同作用，当前数据不能分解出“额外信息”与“负载扰动”各自的因果贡献。

## 7. 已验证结论、模型推断和待验证问题

### 已验证结论

1. 显式循环卷积与当前采样 CFR 频域实现的数值误差为 `3.72e-16`；CP 覆盖审计显示当前循环响应并未被 CP=256 完全覆盖。
2. 正式 audit 确实完成 50 次/拓扑/条件，输出 64,000 条 trial-level feature records；结果可由固定种子和配置复核。
3. 当前对称 SISO 的 T3/T5 仍只能在物理上识别等价类，不能靠算法把它变为可靠唯一识别。
4. 参数感知 joint 在本配置中没有显示出拓扑严格率改善，并引入了更高的歧义和边界命中风险。
5. 完整双接收/三视图在模型内改善了可分性，但内部接收负载会扰动网络，不能写成现场性能。

### 根据模型推断

- 当前主要瓶颈优先是 SISO 观测等价，其次是参数失配和同步假设；不是仅凭增加 OFDM 频点就能消除的结构信息缺失。
- 低 CFR NMSE 不保证拓扑唯一识别；SISO 20 dB 的 NMSE 约 0.0041 而唯一率仍为 0.5。
- 参数感知匹配在参数范围较宽或视图较多时可能用自由度拟合噪声，需要独立标定/验证数据和更严格的参数先验。

### 尚待验证

真实 PLC OFDM FFT/CP/导频、同步/CFO、采样时钟偏差、现场有色/脉冲/周期噪声、真实负载和耦合器、测量节点可用性、多导体/MIMO 以及真实市电实验均未验证。

## 8. 阶段 3B 门槛

当前不建议进入阶段 3B 的 OFDM 波形或资源优化。阶段 3A.1 已显示：在全导频和较低 CFR 估计误差下，SISO 的核心限制仍是 T3/T5 结构观测等价；参数感知自由度还可能增加歧义。下一步应先固定真实测量节点、端接、耦合器和同步假设。只有在这些因素固定后仍证明类间不可分主要由导频密度、探测功率、频带或资源配置造成，才有依据进入阶段 3B。
