# Stage 3B-pre：标准派生理想 CFR 带宽可辨识性诊断

## 1. 阶段与范围

当前阶段是 **Stage 3A.2 收尾 + Stage 3B-pre（带宽可辨识性前置诊断）**。正式 Stage 3B 的波形、导频、功率或子载波优化尚未启动。

本实验是基于当前传输线正向模型、标准参数可追溯的**理想 CFR 解析外推诊断**：候选库使用 nominal 参数，测试样本施加参数扰动；有限 SNR 条件在接收端 CFR 样点加入等效复高斯噪声。它不是实际 PLC 收发机比较、实测验证、完整 NB PHY，也不证明拓扑已被唯一识别。

已保留的历史阶段为 Stage 1.5、2、2.1、2.2、2.3、3A、3A.1、3A.2 和 NB/BB 双频段配置边界测试。后者只验证配置接口与隔离边界，不能替代 NB/BB 数值识别实验。

所有本轮 NB 行均标记为 `analytic_extrapolation_diagnostic`：现有 RLGC/线路证据窗口为 2--30 MHz，CENELEC-A 的低频响应只是解析函数的数值外推，缺少低频实测或独立参数标定。因此 NB 结果**不构成物理 NB/BB 比较**。

## 2. 标准派生配置与证据等级

| 项目 | BB 标准派生参考 | NB 标准派生参考 | 证据等级与边界 |
|---|---|---|---|
| 名称 | `BB_Ghn_standard_derived_reference` | `NB_G3PLC_CENELEC_A_standard_derived_reference` | 模型限定参考，不是硬件复现 |
| 来源 | ITU-T G.9960/G.9964 | ITU-T G.9903 | 标准派生字段；硬件前端未冻结 |
| NFFT / Fs | 4096 / 100 MHz | 256 / 0.4 MHz | 标准派生 |
| 子载波间隔 | 24.4140625 kHz | 1.5625 kHz | 标准派生 |
| 观测范围 | 2--30 MHz 研究窗口 | 35.9375--90.625 kHz、36 个 CENELEC-A 派生 tone | BB 不是完整 G.hn PHY；NB 不是已确认项目硬件 |
| CP/重叠 | 本轮不生成 payload、前导或 PROBE | 仅记录 `NCP=30`、overlap=8，不生成帧 | 标准字段不等于完整 PHY 实现 |
| 端口 | 相同 50 ohm 数学 SISO 正向端口 | 同左 | 项目假设，未标定 |
| RLGC | 既有项目 2--30 MHz 模型窗口 | 同一解析函数向低频求值 | NB 为频率外推诊断 |

本轮未填入实际 active carrier/notch、GI、PSD、发射功率、耦合器、灵敏度、真实端接、CFO 或同步时间原点；不得把标准字段写成某一商用 modem 的实际参数。

## 3. 模型适用性门槛

| 项目 | BB | NB | 证据等级 | 能否进入正式物理 Level-A |
|---|---|---|---|---|
| RLGC 频率适用范围 | 2--30 MHz 既有模型窗口 | 低于证据窗口，仅解析外推 | 历史模型边界 | 否：NB 未校准 |
| 负载模型 | 标量/复数负载数学接口 | 同一接口，无现场低频阻抗分布 | 代码接口 | 否 |
| 源/接收阻抗 | 50 ohm 数学假设 | 同一假设，无硬件校准 | 项目假设 | 否 |
| 频率网格 | G.hn 派生索引 | G3 CENELEC-A 派生 36 tone | 标准派生 | 仅网格可用 |
| 噪声定义 | 接收端 CFR 样点域等效复高斯扰动 | 同一定义 | 本轮仿真定义 | 非现场噪声 |
| 观测端口 | SISO forward 完整网络电压 CFR | 同左 | 模型观测定义 | 真实端口待确认 |

结论：只能执行带有明确标签的解析外推诊断，不能称作物理、硬件或现场的 NB/BB Level-A 比较。

## 4. Level-A0/A1 的实际采样定义

两个层级均固定候选集 T2/T3/T4/T5、测试拓扑、三组参数条件（名义、全线/支路长度 `+2%`、支路负载 `-10%`）、SISO 正向端口、50 ohm 数学端接、随机种子构造、复数 CFR 匹配器和指标。

- `Level-A0_matched_points`：BB 与 NB 各取 36 个 CFR 点；BB 在 2--30 MHz 标准派生网格均匀取样，NB 使用 36 个 CENELEC-A tone。这是**匹配 CFR 频点数 + 共同接收端 CFR 样点 SNR**的理想诊断，不隔离频带位置。
- `Level-A1_native_points`：BB 使用 1147 个研究窗口内网格点，NB 仍为 36 个。故 A1 相对 A0 的主要点数/采样密度变化只发生在 BB 侧；它显示原生频率资源差异，不是完全公平的单因素因果对照。

有限 SNR 时，一次测试 CFR 向量的每个样点只施加一次后置等效复高斯扰动：

$$
\mathrm{SNR}_{\rm CFR}=
\frac{\operatorname{mean}|H_{\rm true}[k]|^2}
{\operatorname{mean}|N[k]|^2}.
$$

该 SNR 定义位于接收端 CFR 样点，不是注入端 SNR、标准 PSD、接收机噪声系数或现场脉冲噪声。`cfr_sampling_nmse_ideal_input=0` 只表示无噪声条件直接抽取理想已知 CFR，**不是**信道估计器 NMSE。

代码保留的 `future_waveform_fairness_placeholder` 仅为未来物理波形级设计保留元数据接口。当前不分配总发送能量、不生成 OFDM 符号、不使用 `repetitions` 平均、不使观测时间影响噪声方差、观测或匹配；因此**等总注入能量、等观测时间及重复平均增益均未实现，也不能用于解释本轮结果**。

## 5. 运行、测试与结果可追溯性

- MATLAB：`24.1.0.2537033 (R2024a)`。
- 工作目录：仓库根目录 `matlab_plc_cfr_publish`。
- 最终入口：`run_stage3b_pre`，该入口先运行 `run_tests`，随后运行 Stage 3B-pre 实验。
- 完整命令、起止时间、版本、测试入口和退出状态见：[stage3b_pre_final_run.log](../results/logs/stage3b_pre_final_run.log)。本次退出状态为 `0`；日志中的 `ApplicationService` 是启动环境提示，未导致测试失败。
- `test_stage3b_pre` 已纳入 [tests/run_tests.m](../tests/run_tests.m)，并在本次总回归中通过。
- 发布的数据为：[stage3b_pre_summary.csv](../results/data/stage3b_pre_summary.csv) 与 [stage3b_pre_applicability.csv](../results/data/stage3b_pre_applicability.csv)；图为 [stage3b_pre_accuracy.png](../results/figures/stage3b_pre_accuracy.png)。
- `results/data/stage3b_pre_results.mat` 在每次本地运行时生成，但受 `.gitignore` 的 `results/data/*.mat` 规则忽略，**未纳入版本库、不是仓库内可下载结果**。可使用日志中完整命令重新生成。

## 6. 关键结果与等价类审计

| 条件 | strict accuracy | equivalence-class accuracy | ambiguity | false-unique | 类内/最近类间比 | 边界解释 |
|---|---:|---:|---:|---:|---:|---|
| A0，BB，名义，理想 | 1.000 | 1.000 | 0.500 | 0 | 0 | T3/T5 仍为 `{T3,T5}`；strict 不能解释为唯一识别 |
| A0，NB 外推，名义，理想 | 1.000 | 1.000 | 0.500 | 0 | 0 | 同一等价状态，仅为解析外推 |
| A0，BB，长度 +2%，理想 | 0.750 | 1.000 | 0.500 | 0 | 0.888 | 参数失配接近最近类间间隔 |
| A0，NB 外推，长度 +2%，理想 | 0.500 | 0.500 | 0 | 0.500 | 外推模型可出现 false-unique，不能外推为物理 NB 结论 |
| A1，BB 原生点，名义，20 dB | 0.750 | 1.000 | 0.500 | 0 | 0.252 | BB 点数增加没有打破对称 SISO 等价 |
| A1，NB 外推，名义，20 dB | 0.488 | 0.613 | 0.338 | 0.275 | 0.908 | 仅为受控接收端样点噪声下的外推诊断 |

候选参考库为 nominal library，而测试样本包含参数扰动，故表中数值是“名义库匹配受扰测试”的结果，不能笼统写成真实噪声性能比较。每一行保留最近竞争拓扑字段；完整复数 CFR 的 T3/T5 等价类在所有行中仍为 `{T3,T5}`。

本轮模型内结论不是“宽带必然更好”：相同对称 SISO 端口下，增加带宽或 CFR 点数不能保证消除结构观测等价；NB 行的任何差异也不能解释为真实频段优劣。

## 7. 正式 Stage 3B 判断

**正式 Stage 3B 仍不启动。** 仍需确认或标定真实测量节点与方向、端接/耦合器/TX-RX switch 及参考面、NB 可运行 PHY 与低频 RLGC/负载、BB active carrier/GI 的明确来源、同步时间原点，以及能实际作用于观测统计的能量/时间/SNR 公平口径。

确认上述条件后，且独立测试表明剩余瓶颈主要来自频带、导频或资源配置时，第一项工作应是重建具有物理依据的 Level-A0/A1 观测模型；不是直接优化导频、功率或子载波。

通信标准参数和理想 CFR 可辨识性诊断，只提高收发机模型与实验设置的可追溯性；它们不等于真实 PLC 拓扑识别性能已经被验证。
