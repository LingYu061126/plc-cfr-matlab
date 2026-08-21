# PLC CFR MATLAB 仿真：阶段 1.5–2.3

本目录包含低压电力线载波（PLC）信道频率响应（CFR）的稳定正向模型，以及阶段 2/2.1/2.2 的 OFDM 等效导频信道估计和可解释拓扑识别基线。阶段 2.2 在不改动阶段 1.5 稳定传输线模型的前提下，新增完整树网络节点导纳求解、物理标注的多视图观测和离散拓扑/参数联合匹配。项目仍不包含完整 PLC 收发机、波形优化、机器学习或接地故障定位。

阶段 2.3 增加配置相关的拓扑等价类评价、七种完整网络观测配置和 100 次统计公平比较。详细结果见 `report/stage2_3_observability.md`。`run_stage2_3('smoke')` 只读取/生成 `stage2_3_smoke_partial_*` 批次并写出 `stage2_3_smoke_fixed_*` 结果；`run_stage2_3('formal')` 只接受 14 个 `stage2_3_formal_partial_*` 批次，绝不混用旧 smoke、formal 或未标记数据。发布版不含大型 formal MAT，因此克隆后直接重汇总仍会明确报“缺少批次”；本仓库已附带使用本机 formal MAT 生成的 `stage2_3_formal_fixed_*` CSV 和图。修复后的 pairwise 输出同时包含归一化 `complex_distance` 和绝对未归一化 `complex_distance_raw`。

最终审计已在 MATLAB R2024a 实际完成：阶段 1.5、2、2.1、2.2、2.3 测试全部通过；`run_stage2_3('smoke')` 的完整重试生成 7 个 sealed batch，并汇总为 42 条 pairwise、371 条 summary、1456 条 confusion 聚合记录。formal fixed 不是本次从头重跑，而是由本机旧 formal MAT 保留 trial/summary/confusion，并用当前模型补算 raw pairwise；公开仓库不含这些大型 MAT。归一化复数距离只支持 CFR 形状/相对响应等价，`complex_distance_raw` 才是不归一化的绝对 CFR 差异。

## MATLAB 运行

主环境为 MATLAB R2024a，项目代码只依赖基础 MATLAB，不需要额外工具箱。将当前目录切换到本目录后运行：

```matlab
run_all
```

从项目根目录运行也可以：

```matlab
addpath('matlab_plc_cfr')
run_all
```

`run_all` 会加入 `src/`、`config/`、`experiments/` 和 `tests/`，先执行测试，再生成实验图和数据。所有路径由入口脚本计算，项目移动后不依赖绝对路径。

只运行阶段 2.2 回归测试和正式实验：

```matlab
run_stage2_2
```

阶段 2.2 正式日志为 `results/logs/stage2_2_final_run.log`；修改前回归日志和基线说明分别为 `results/logs/stage2_2_prechange_tests.log` 和 `results/baseline_pre_stage22/README.txt`。

阶段 2.3 的独立 smoke 和 formal 汇总命令为：

```matlab
run_stage2_3('smoke')
addpath('src','config','experiments')
compile_stage2_3_results(default_config(pwd),'formal')
```

后一个命令需要同版本的 14 个 `stage2_3_formal_partial_*_results.mat` 和相应 trial CSV；发布包不附带它们。当前仓库的 `stage2_3_formal_fixed_*` 是基于本机旧 formal MAT、经过 `stage2_3_upgrade_legacy_pairwise` 补算 raw pairwise 后的正式汇总，不是克隆者重新加载 MAT 得到的结果。`topology_feature_distance(...,'complex')` 是单位范数归一化后的复数 CFR 形状距离；`'complex_raw'` 是未归一化绝对复数 CFR 距离。二者不可混称为“绝对标定 CFR 等价”。

阶段 2 运行入口仍然是：

```matlab
addpath('matlab_plc_cfr')
run_all
```

本机实际运行命令和完整阶段 2.1 实验日志位于 `results/logs/stage2_1_final_run.log`，最终测试日志位于 `results/logs/stage2_1_final_tests.log`；exp07 刷新日志位于 `results/logs/stage2_1_exp07_refresh.log`。阶段 2.1 修改前基线位于 `results/baseline_pre_stage21/README.txt` 及 `results/logs/stage2_1_prechange_run_tests*.log`；原阶段 2 文件仍可由 Git 提交 `8306506` 和 `results/SHA256SUMS_final.txt` 恢复/核对。

## 数学约定

内部单位为：频率 Hz、长度 m、`R/L/G/C` 分别为 ohm/m、H/m、S/m、F/m。二端口方向固定为

```text
[V1; I1] = [A B; C D] [V2; I2]
```

`I1`、`I2` 均按从发送端指向接收端的参考方向。线路矩阵为

```text
[cosh(gamma*d), Zc*sinh(gamma*d); sinh(gamma*d)/Zc, cosh(gamma*d)]
```

支路先回推为节点输入阻抗，再使用 `[1 0; 1/Zin 1]` 插入主线；矩阵按从发送端到接收端的物理顺序级联。“级联”是二端口矩阵乘法，不是微积分链式法则。

`cable_rlgc` 只接受严格正的有限频率。零频率不属于本宽带 RLGC 模型的适用域；如果需要 DC 模型，应另行指定集总电阻/电感假设。

## 端接与归一化

总 ABCD 矩阵为 `[A B; C D]` 时：

```text
H_V = Vr/Vs = Zr/(A*Zr+B+Zs*(C*Zr+D))
```

`H_port` 使用参考端接 `Zport_ref` 定义为

```text
Vref   = Vs*Zport_ref/(Zs+Zport_ref)
H_port = Vr/Vref = ((Zs+Zport_ref)/Zport_ref)*H_V
```

默认 `Zs=Zr=Zport_ref=50 ohm`，此时且仅此时 `H_port=2*H_V`。若改变 `Zs`，不能继续无条件使用因子 2。图形默认绘制 `H_port` 的 `20*log10(abs(H_port))` 和 `unwrap(angle(H_port))`。

## 长线路稳定性

`cascade_network` 保留为直接 ABCD 参考实现，并记录 `AD-BC-1` 的最大值、中位数和最差频点；超过 `cfg.abcd_det_warning_threshold=1e-6` 时发出警告。它不再被用作长线路正式结果。

正式长线路结果使用 `cascade_network_stable`：从接收端开始递推下游输入阻抗，并用

```text
Vout/Vin = 2*ZL*exp(-gamma*d) / ((ZL+Zc)+(ZL-Zc)*exp(-2*gamma*d))
```

计算电压比，避免直接构造和相乘巨大 `cosh/sinh` 矩阵。支路节点使用导纳并联。该方法在短线路上与 ABCD 复数 CFR 交叉验证，在长线路上另外检查有限性、被动网络输入阻抗实部和线路分段不变性。

## 负载接口

支路负载支持：

- 标量实阻抗或标量复阻抗；
- 与频率向量等长的复阻抗 `Z_L(f)`；
- `Inf` 开路和 `0` 短路极限；
- 零长度支路直接返回终端负载。

`parallel_rlc_load` 实现 Cañete 论文中的频率选择性并联 RLC 模型：

```text
Z(f) = R/(1 + j*Q*(f/f0 - f0/f))
```

实验六采用 `R=500 ohm, Q=5, f0=15 MHz`，这是文献模型/仿真参数，不是现场实测负载。

## 阶段 2：OFDM 导频与拓扑识别基线

项目原有代码中没有通信型 OFDM 波形实现，因此阶段 2 明确采用“复基带频域信道估计等效模型”，不是已经完成的真实 PLC 收发机。默认配置集中在 `src/ofdm_config.m` 和 `config/default_config.m`：

- `NFFT=4096`、`Fs=64 MHz`、子载波间隔 `15.625 kHz`；
- 有效频带 `2–30 MHz`，共 1793 个有效子载波；
- `pilot_spacing=1`，所有有效子载波均为已知确定性 QPSK 导频；
- `Y=X.*H+N`，其中有限 SNR 使用复高斯白噪声，SNR 按接收导频平均功率定义；
- `H_hat=Y./X` 为 LS 估计；当前输出命名为 **circular band-limited CIR（循环带限信道冲激响应）**，使用有效 CFR 嵌入 `NFFT` 频域向量后的 IFFT；没有循环前缀、负频率共轭补全或时域同步，因此主峰只是循环时延指标，不是真实 ToA/测距；
- 当前 OFDM 参数是仿真假设，实际通信波形的 FFT、采样率、导频密度和功率仍待确认。

核心接口：

- `ofdm_config`、`ofdm_generate_pilot`、`ofdm_apply_channel`；
- `ofdm_channel_estimate_ls`、`ofdm_cfr_to_cir`；
- `topology_candidates`、`topology_reference_cfr`；
- `topology_feature_distance`、`topology_nearest_match`、`topology_evaluation_metrics`；
- `cfr_phase_error_metrics`、`cfr_estimation_metrics`、`topology_multiview_match`。`topology_prefix_network` 仅保留用于复现阶段 2.1 历史 C3，不得作为当前物理多端口结论。

候选拓扑为 T1–T6，均采用 80 m 主线和 20/40/60 m 的公共主线节点，只改变支路数量或连接位置，从而将拓扑变量与线路长度、负载和电缆参数分开。T3 的 60 m 单支路和 T5 的 20 m 单支路在当前 50 Ω 对称端接的单 SISO 观测下构成镜像等价类；程序会输出 `group_accuracy` 和 `ambiguous_rate`，不能将浮点 tie-break 当作唯一拓扑识别。

阶段 2 实验：

- `exp07_ofdm_channel_estimation`：无噪声导频 LS、CFR 幅相、复数误差、IFFT CIR 和循环 ToA；
- `exp08_topology_baseline`：理想 CFR、无噪声导频、30/20/10/0 dB SNR、负载变化和线路/kG 扰动；
- 五种基线距离扩展为：归一化/未归一化 dB/标准化幅值、原始展开相位、幅值掩膜相位、幅值加权圆周相位、单位范数复数 CFR、循环带限 CIR，以及多种幅相联合权重。幅值归一化会丢失绝对衰减信息，未归一化 dB 幅值作为对照，不宣称任何权重最优。

## 阶段 2.1：统计稳健性与可辨识性审计

`experiments/exp09_stage2_1_audit.m` 使用阶段 1.5 的 `cascade_network_stable` 生成参考 CFR，默认每个 SNR/拓扑 50 次独立、可复现试验，测试 30/20/10/0 dB。`ofdm_apply_channel` 的噪声模式明确区分：

- `fixed_received_snr`：每个拓扑按自身接收导频功率设置噪声方差；
- `fixed_noise_power`：按参考拓扑的接收功率设置一个共同噪声底。

阶段 2.1 还记录原始展开相位 RMSE、幅值掩膜/加权相位 RMSE 和有效频点比例；严格候选准确率、基线结构观测组准确率、当前测量视图有效结构组准确率、数值 tie 率、距离间隔、组内/组间距离及边级 P/R/F1 分开保存。带噪声时 T3/T5 的一次随机候选选择不改变其物理结构等价结论。

测量审计包括对称端接下 TX→RX/RX→TX/双向 SISO 和 `Zs=50 Ω,Zr=75 Ω` 不对称端接。阶段 2.1 C3 使用的前缀网络会丢弃下游支路，已被阶段 2.2 判定为非物理多节点模型；其 100% 理想识别率只是历史简化结果，不是真实多端口性能。

阶段 2.1 结果文件以 `stage2_1_` 开头：`results/data/stage2_1_audit.mat`、统计 CSV、混淆矩阵、`stage2_1_edge_summary.csv`，以及 `results/figures/stage2_1_*.png`。详细结论见 `report/stage2_1_audit.md`。

阶段 2 的完整结论见 `report/stage2_baseline.md`。结果图和原始数据位于 `results/figures/` 与 `results/data/`，其中 `exp08_snr_summary.csv` 同时记录 CFR 估计 NMSE、幅值 RMSE、相位 RMSE、完整拓扑识别率、等价类识别率、歧义率和边级指标。

## 阶段 2.2：完整网络多视图与参数鲁棒匹配

`plc_full_network_response` 把所有主线和支路分布参数线段组装为节点导纳矩阵，支路终端和接收端均以实际并联负载进入同一完整网络。`plc_multiview_response` 支持同一激励下多个同时加载接收节点，以及多个方向明确的激励状态；不再截断下游网络。

阶段 2.2 参数库对主线长度比例、支路长度比例、负载比例、`Zs` 和 `Zr` 做独立网格搜索，每个拓扑 243 个参数点；匹配目标为数据距离加参数偏离正则项。正式实验使用 T2/T3/T4/T5、1793 个全导频子载波、每条件 20 次可复现试验，共保存 4800 条方法评价记录和完整混淆矩阵。对称 50 Ω SISO 下 T3/T5 仍等价；完整网络的内部节点视图在当前理想模型中打破该 tie，但不等于现场节点已可用。详见 `report/stage2_2_physical_multiview.md` 和 `report/stage2_2_README.md`。

## 实验、测试和结果

- `tests/run_tests.m`：在阶段 1.5/2/2.1 回归基础上，新增完整网络与稳定端到端 CFR 一致性、反向端接语义、不截断多接收节点、绝对/形状幅值、幅相加权特征、参数网格/缓存匹配一致性和输入边界测试。
- `experiments/exp01`–`exp04`：基础参数、单分支幅相、负载扫描和损耗因子。
- `experiments/exp05`：300/500/800/1200 m 文献参数外推，正式曲线使用稳定递推，旧 ABCD 仅审计。
- `experiments/exp06`：频率选择性并联 RLC 负载。
- `experiments/exp07`、`exp08`：OFDM 等效信道估计和拓扑匹配基线；`exp09_stage2_1_audit`：统计稳健性、噪声定义、测量配置、参数不确定性和特征审计。
- `report/core_derivation.md`：代码一致的公式和稳定递推推导。
- `report/experiment_results.md`：实际 MATLAB 数值结果和可保留/排除结论。
- `report/stage15_acceptance.md`：阶段验收、修改前后对比、日志和限制。
- `report/stage2_baseline.md`：阶段 2 流程、距离定义、候选拓扑、实际结果、混淆矩阵和失败边界。
- `report/stage2_1_audit.md`：阶段 2.1 实际测试、50 次统计、双噪声定义、可辨识性、参数不确定性、已验证结论和待验证问题。
- `report/stage2_2_physical_multiview.md`：阶段 2.1 残留问题、完整网络多视图推导、联合反演、实际统计结果、失败情形和证据等级。

图像位于 `results/figures/`，复数 CFR、幅值、相位和诊断数据位于 `results/data/`。`results/baseline_pre_stage15/` 保存修改前结果快照、SHA-256 清单、MATLAB 版本/依赖和基线控制台日志。

长线使用的 Cañete 原始校准线段范围是 0.5–50 m；300–1200 m 全部是参数外推。`-120 dB` 只作为报告中的参考筛查门限，项目没有给定真实硬件动态范围，因此不能把该门限称为实际测量极限。

## 阶段 3A：通信型 OFDM 拓扑感知基线

阶段 3A 在不优化波形的前提下增加了 IFFT/循环前缀/去循环前缀/FFT/LS 的通信型等效链路：

```text
X[k] -> IFFT+CP -> 完整网络 H(f;G,theta) -> 噪声/测量误差
    -> 去CP+FFT -> H_hat[k] -> CFR/CIR/circular-delay -> 拓扑/等价类匹配
```

这里 `H(f;G,theta)` 是基础物理模型，观测配置 `O` 负责端口、端接和多视图组合。当前配置为 `NFFT=4096`、`Fs=64 MHz`、`2–30 MHz`、1793 个有效频点和仿真假设 `CP=256`。普通 OFDM 端到端 CFR 与 FDR/TFDR 反射代理、输入导纳代理分开命名；后两者不是完整 FDR/TFDR 仪器模型。CIR 使用循环带限定义，主峰只是循环延迟指标，不是真实 ToA/测距。

运行：

```matlab
run_stage3a('smoke')   % 少量试验，检查全链路和文件格式
run_stage3a('formal')  % 当前配置的基线统计
```

阶段 3A formal 的轻量输出包括 `results/data/stage3a_formal_{config,trial_metrics,summary,confusion,example_cfr}.csv` 和 `results/figures/stage3a_formal_*.png`。完整 `stage3a_formal_raw.mat` 会保存 H_true、H_hat、CIR、循环延迟、噪声和参数，但约 185 MB，按发布策略由 `.gitignore` 排除；因此克隆者可审阅 CSV/图/日志，不能仅凭仓库重建全部原始 MAT。

阶段 3A 的正式结果显示：对称 SISO 下 T3/T5 仍只能报告为等价类；在 20 dB 白噪声下 `dual_receiver_complete` 和 `three_view_complete` 的当前模型严格率为 1，而 `siso_forward` 的等价类率为 1、严格唯一率为 0.5。该结果不等于现场拓扑识别性能，也不等于已经完成完整 PLC OFDM 收发机。详细假设、实际运行状态和阶段 3B 判断见 [`report/stage3a_communication_baseline.md`](report/stage3a_communication_baseline.md) 与 [`notes/阶段3A实验设计.md`](notes/阶段3A实验设计.md)。

## 阶段 3A.1：结果审计与参数感知基线

阶段 3A.1 不优化波形。新增 `run_stage3a('audit')`，固定使用 5/10/15/20/30 dB、导频间隔 1/2/4/8、4 种完整网络观测和 amplitude/amp-phase/CIR/circular-delay 四类特征，每个条件每个拓扑 50 次。正式 audit 已实际生成 `stage3a_1_audit_trial_metrics.csv`（64,000 条 feature-level 记录）、summary、confusion、配置、原始轻量 MAT、图和日志。`run_stage3a('audit_smoke')` 仅是诊断模式，不能当作正式统计。

新增 `run_stage3a('parameter_aware')`，比较 `nominal_nearest`、`topology_only` 和有界 `nuisance_aware_joint`。当前参数网格为 27 点，范围、正则化 `lambda=0.01` 和随机种子写入 `stage3a_1_parameter_aware_config.csv`；参数感知匹配不是经过充分校准的最优算法，存在拟合噪声风险。新增 `dual_receiver_highz_complete` 作为 1e6 Ω 内部接收负载对照；`dual_receiver_complete` 和 high-Z 观测均来自完整网络，接收机负载会改变网络，不能直接解释为现场无扰动传感器。

运行命令：

```matlab
run_stage3a('audit_smoke')       % 诊断，不作正式统计
run_stage3a('audit')             % 正式 50 次/拓扑/条件审计
run_stage3a('parameter_aware')   % 参数感知基线
```

完整方法、实际数值、证据等级和阶段 3B 门槛见 [`notes/stage3a_1_audit.md`](notes/stage3a_1_audit.md) 与 [`report/stage3a_1_parameter_aware_baseline.md`](report/stage3a_1_parameter_aware_baseline.md)。当前结论是不建议直接进入阶段 3B：主要限制仍是对称 SISO 的观测等价、参数不确定性和同步/测量模型边界，而不是已经证实的 OFDM 资源不足。
