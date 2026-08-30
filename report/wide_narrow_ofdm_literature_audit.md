# 宽窄带 OFDM 联合文献、模型修正与双频段设计审计

## 1. 本轮交付范围

本轮完成文献正文整理、模型假设修正表和 NB/BB 研究设计；没有开始阶段 3B 的波形、导频功率、子载波或资源优化，也没有覆盖阶段 1.5–3A.2 的数据、图和报告。

统一模型为

$$H_{rt}(f)=H_{rt}(f;G,\theta),\quad
Y_{rt}[k]=X_t[k]H_{rt}(k;G,\theta)+N_{rt}[k].$$

`O` 显式区分普通端到端 OFDM-CFR、CIR/路径代理、输入阻抗/反射、节点导纳和多端口观测。

## 2. 读取文件与受限情况

### 新增英文论文

已读取 P09–P16 八篇正文：

1. `10.1016_j.ijepes.2022.108634.pdf`
2. `2308.10598v2.pdf`
3. `Performance_analysis_of_OFDM_systems_for_broadband_power_line_communications_under_impulsive_noise_and_multipath_effects.pdf`
4. `Path_Identification_in_a_Power-Line_Network_Based_on_Channel_Transfer_Function_Measurements.pdf`
5. `Full_duplex_power_line_communication_modems_for_network_sensing.pdf`
6. `Power_line_network_topology_identification_using_admittance_measurements_and_total_least_squares_estimation.pdf`
7. `A_diagnostic_method_for_power_line_networks_by_channel_estimation_of_PLC_devices.pdf`
8. `Channel_estimation_for_OFDM-based_indoor_broadband_power_line_communication_systems.pdf`

本地实际文件名没有用户消息中的 `(2)` 后缀；`pdfinfo` 显示文件未加密，`pdftotext` 成功。逐篇证据、章节/公式/表位置见 `notes/papers/`。

### 已有中文资料

已对照读取：王新宇、苏岭东、徐国庆、卢文冰、谢志远和葛松列出的六份 PDF，以及项目已有阶段报告和 PLC/OFDM/拓扑资料。王、苏、徐、葛的 PDF 标记为加密但文本抽取可用；公式、图和页码排版需导师汇报前按原 PDF 视觉复核。没有根据文件名或摘要补写内容。

## 3. 文献驱动的模型修正

- PLC 信道不再写成只依赖拓扑的 `H(G)`，而写成 `H(f;G,theta)`。
- 负载、线路参数、端接、噪声、耦合器、故障和拓扑变化分开记录；不把负载变化自动称为拓扑变化。
- 端到端 `H_rt` 不等于 `Z_PL`、反射系数 `rho`、FDR trace 或节点导纳 `Y`。
- 通信型 OFDM 导频可以提供 CFR 估计输入，但不等于完整 PLC 收发机，也不保证唯一树识别。
- 宽带可能提高频率/路径分辨率，但不能消除端口下严格相同的 T3/T5 观测。
- P10 的 CP 结论针对 BER/ISI；P09 的 CP 和 CIR 统计针对其室内协议/测量场景，均不直接证明当前 `CP=256` 适用于现场。

## 4. 双频段配置

`src/stage3_band_configs.m` 返回：

- `cfg_nb`：42–472 kHz 候选范围，但 `Fs/NFFT/CP/有效载波/导频/PSD` 保持待确认，禁止直接运行成伪标准。
- `cfg_bb`：继承项目 2–30 MHz、64 MHz、4096 点、256 点 CP 和现有有效频点；全部标为项目仿真假设而非标准参数。
- `cfg_bb.extension_band_hz=[30e6,86e6]` 仅为扩展字段，未运行。

两套配置共享阶段 1.5 的 RLGC/ABCD、稳定网络、支路阻抗和拓扑匹配接口，不复制或修改物理模型。

来源说明：42–472 kHz 是 P12 文献场景对照下的候选研究频带，不代表已确认 PRIME、G3 或其他 NB-PLC 标准；2–30 MHz、Fs=64 MHz、NFFT=4096、CP=256 是项目 BB 仿真假设。

## 5. 运行与测试状态

### 5.1 修复前历史记录（保留）

本小节记录修复前的启动失败，不代表当前 MATLAB 状态。

当时尝试的基线命令：

```bash
timeout -k 10s 900s env LD_LIBRARY_PATH=/home/chidan/.local/share/matlab-r2024a/compat/lib \
  QT_QPA_PLATFORM=xcb /home/chidan/Matlab/bin/matlab -batch \
  "cd('matlab_plc_cfr_publish'); run_tests"
```

结果：MATLAB 启动失败，报 `Unable to load ApplicationService for command client-v1` 和 `failed to load settings errors_warnings plugin`，退出码 1；无 JVM 探针也超时。完整记录见 `results/logs/wide_narrow_literature_audit.log` 和 `wide_narrow_literature_prechange_tests.log`。

| 项目 | 状态 |
|---|---|
| 历史阶段 1.5–3A.2 测试 | 本轮未重跑；历史 `stage3a_2_closeout_final_tests.log` 记录此前 R2024a 通过 |
| 新增 `test_stage3_band_configs` | 未运行，因 MATLAB 启动失败 |
| GNU Octave 新增配置兼容性 smoke | 通过；仅作语法/结构辅助检查，不替代 MATLAB 验收 |
| 本轮双频段数值实验 | 未运行 |
| 新增双频段图/CSV/MAT | 未生成 |
| 静态代码/文档/Git 检查 | 已执行，结果见最终交付摘要 |

因此在修复前不能声称“全部测试通过”或“NB/BB 识别结果已验证”。

### 5.2 修复后最终状态

用户修复 MATLAB 启动器后，已使用仓库既定启动方式和全新 MATLAB_PREFDIR 实际运行完整测试。证据文件为：

- results/logs/wide_narrow_literature_final_verify.log；
- results/logs/wide_narrow_literature_gate_final_verify_v2.log；
- report/matlab启动故障诊断.md 第 8 节；
- 同时保留的 results/logs/wide_narrow_literature_recheck_full.log。

最终日志记录 MATLAB R2024a 24.1.0.2537033、MATLAB_LICENSE=1，并通过了阶段 1.5、2、2.1、2.2、2.3、3A、3A.1、3A.2 测试以及 test_stage3_band_configs。配置边界测试通过只表示 NB/BB 配置接口和边界检查通过，不表示已经完成宽窄带拓扑识别。

本轮仍未完成：

- NB/BB 双频段数值实验；
- 双频段识别图、CSV 或 MAT；
- OFDM 波形、导频、子载波、功率或资源优化。

因此当前交付是文献审计、模型边界和设计配置收尾，不是双频段识别结果。

## 6. 当前科学结论

### 已验证/已有项目结果支持

- 阶段 2.3/3A 的对称 SISO T3/T5 等价类结果仍成立：低 CFR 估计误差不等于唯一识别。
- 文献明确区分 CFR/CIR、FDR/反射和导纳等观测任务。
- 项目代码现在有独立的 NB/BB 设计配置接口，且不改变旧默认配置。

### 根据文献和模型推断

- 在参数、端口和同步固定后，BB 更宽的频带可能增加可分的路径/凹口信息；若观测函数严格等价，频带扩展仍不能单独打破等价。
- 双向、节点、反射或导纳视图可能比单端 CFR 提供更直接的信息，但它们需要额外硬件/负载并可能改变网络工作点。
- 负载变化、线路变化和故障都可能改变 CFR/CIR，因此必须用联合参数和多视图做区分。

### 尚待真实测量验证

真实 NB/BB OFDM 参数、有效子载波/PSD 缺口、CP、同步/CFO、耦合器、端接、现场有色/脉冲噪声、多导体/MIMO、节点可用性和市电实验均未验证。

## 7. 当前最值得优先实现的一个实验

在不优化波形的前提下，先由导师确认 NB/BB PHY 后，做“相同候选树、相同参数扰动、相同总发送能量、相同有效频点数、相同观测时间、同一 50 Ω SISO 端口”的 Level-A 双频段理想 CFR 实验；同时加入 T3/T5、负载扰动和参数扰动，并报告复数 CFR/CIR 的类间/类内距离、严格率、等价类率和 false-unique。该实验最先区分“频带/采样不足”与“结构性 SISO 等价”。

## 8. 需要向导师确认的三个问题

1. NB 研究对象是具体 PRIME/G3/其他设备，还是只做 42–472 kHz 的抽象受控频带？对应 `Fs/NFFT/CP/导频/PSD` 是什么？
2. BB 是否只研究 2–30 MHz，还是扩展到 30–86 MHz？可用的 RLGC、PSD、耦合器和户外线路依据是什么？
3. 实际可获得的观测是单端 SISO、双向、内部节点、线间 MIMO、输入导纳还是反射/FDR？端接和同步参考面如何定义？

进入 Level-A 双频段理想 CFR 实验前，必须由导师确认：

1. NB PHY：具体设备/标准、Fs/NFFT/CP、有效子载波、导频和 PSD；
2. BB 频带范围：仅 2–30 MHz，还是包含 30–86 MHz 扩展，以及对应 RLGC/PSD 依据；
3. 实际观测方式：SISO、双向、节点、多端口、输入导纳或反射/FDR，以及端接和耦合器参考面。

## 9. 阶段 3B 判断

目前不建议启动阶段 3B。进入 3B 前至少需要冻结真实观测协议和参数，完成可运行的 NB/BB 公平实验，并证明在这些因素固定后剩余不可分主要来自导频、频带、功率或资源配置，而不是 T3/T5 结构等价、节点不足、参数失配或同步误差。
