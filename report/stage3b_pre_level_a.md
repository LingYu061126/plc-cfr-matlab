# Stage 3B-pre：标准派生 Level-A 宽窄带可辨识性诊断

## 1. 阶段与范围

当前阶段是 **Stage 3A.2 收尾 + Stage 3B-pre**。本轮执行的是“标准派生、模型限定的 Level-A 宽窄带公平可辨识性实验准备与执行”，不是正式 Stage 3B 的波形、导频、子载波或功率优化，也不是真实 PLC 收发机或现场拓扑验证。

已保留的历史阶段为 Stage 1.5、2、2.1、2.2、2.3、3A、3A.1、3A.2 和 NB/BB 双频段配置边界测试。配置边界测试通过只说明接口与隔离规则正确，不等于完成 NB/BB 数值识别。

本次新增结果统一标记为 `analytic_extrapolation_diagnostic`。原因是当前 RLGC/线路模型的项目证据窗口是 2--30 MHz；CENELEC-A 的低频计算可以由解析公式数值求值，但缺少在该频段的物理校准证据。因此本报告中的 NB 数值**不构成物理 NB/BB 比较**。

## 2. 配置与证据等级

| 项目 | BB 标准派生参考 | NB 标准派生参考 | 证据等级/边界 |
|---|---|---|---|
| 名称 | `BB_Ghn_standard_derived_reference` | `NB_G3PLC_CENELEC_A_standard_derived_reference` | 两者均为模型限定参考，非硬件复现 |
| 来源 | ITU-T G.9960/G.9964 | ITU-T G.9903 | 标准派生字段；硬件前端未冻结 |
| NFFT / Fs | 4096 / 100 MHz | 256 / 0.4 MHz | 标准派生 |
| 子载波间隔 | 24.4140625 kHz | 1.5625 kHz | 标准派生 |
| 观测频带 | 2--30 MHz 研究窗口 | 35.9375--90.625 kHz、36 个 CENELEC-A 派生 tone | BB 不是完整 G.hn PHY；NB 不是实际项目硬件 |
| CP/重叠 | 本轮不实例化 payload/前导/PROBE | 记录 `NCP=30`、overlap=8，但本轮不实例化帧 | 标准字段不等于本轮完成完整 PHY |
| 端口 | 相同 50 ohm 数学 SISO 正向端口 | 同左 | 项目假设，未标定 |
| RLGC | 现有项目 2--30 MHz 模型窗口 | 同一解析函数在低频求值 | NB 为频率外推诊断 |

标准参数与硬件参数必须分开：本轮没有填入实际 active carrier/notch、GI、PSD、发射功率、耦合器、灵敏度、真实端接、CFO 或同步时间原点。

## 3. 模型适用性门槛

| 项目 | BB | NB | 证据等级 | 能否进入正式物理 Level-A |
|---|---|---|---|---|
| RLGC 频率适用范围 | 2--30 MHz 既有项目模型窗口 | 低于现有证据窗口，仅解析外推 | 代码/历史模型边界 | 否：NB 未校准 |
| 负载模型 | 标量/复数负载接口 | 同一数学接口，无现场低频阻抗分布 | 代码接口 | 否 |
| 源/接收阻抗 | 50 ohm 数学假设 | 同一假设，无硬件校准 | 项目假设 | 否 |
| 频率网格 | G.hn 派生索引 | G3 CENELEC-A 派生 36 tone | 标准派生 | 仅网格可用 |
| 噪声定义 | 接收端 CFR 样本域受控复高斯扰动 | 同一定义 | 本轮仿真定义 | 非现场噪声 |
| 观测端口 | SISO forward 完整网络电压 CFR | 同左 | 模型观测定义 | 真实端口待确认 |

结论：本轮不能称为“模型内物理 NB/BB Level-A 比较”；允许且已经执行的是带有明确标签的**解析外推诊断**。

## 4. Level-A0/A1 公平性定义

两个层级均固定候选集 T2/T3/T4/T5、真实测试拓扑、三组扰动（名义、全线/支路长度 `+2%`、支路负载 `-10%`）、SISO 正向端口、50 ohm 源/接收端假设、随机种子构造、复数 CFR 匹配器及评价指标。

`Level-A0_matched_points`：BB 与 NB 都取 36 个有效 CFR 点。BB 从 2--30 MHz 的标准派生频率网格均匀抽取 36 点；NB 使用其 36 个 CENELEC-A 派生 tone。因此它隔离了“点数”而非“频带位置”。

`Level-A1_native_points`：BB 使用 1147 个 2--30 MHz 标准派生网格点，NB 使用其原生 36 点。这一层展示原生频率资源差异，不是完全单因素因果对照。

总注入能量定义为每次观测 `E_total=1`；每个“点×重复”的名义能量为 `1/(N_point N_rep)`。为接近 3.2 ms 的统一观测时间，BB 使用 78 个 `4096/100 MHz=40.96 us` payload 时长（3.19488 ms），NB 使用 5 个 `256/0.4 MHz=640 us` payload 时长（3.2 ms）。这些字段是公平性元数据；因为本轮使用理想已知 CFR 探测点，它们没有被误写成真实 payload、PSD 或导频实现。

有限 SNR 时，噪声加在**线路响应后的 CFR 样本域**：

$$
\mathrm{SNR}=\frac{\operatorname{mean}|H_{\rm true}[k]|^2}
{\operatorname{mean}|N[k]|^2}.
$$

这只是为 BB/NB 采用相同的接收端样本误差定义；不代表注入端 SNR、标准 PSD、接收机噪声系数或现场脉冲噪声。

## 5. MATLAB 运行与新增资产

- MATLAB：R2024a（由启动日志及既有环境确认）。
- 最终入口：`run_stage3b_pre`。
- 命令：`env MATLAB_PREFDIR=/tmp/matlab-pref-stage3b-pre5 LD_LIBRARY_PATH=/home/chidan/.local/share/matlab-r2024a/compat/lib QT_QPA_PLATFORM=xcb /home/chidan/Matlab/bin/matlab -nodisplay -nosplash -softwareopengl -batch "... run_stage3b_pre ..."`。
- 最终退出状态：`0`。
- 单元测试：`test_stage3b_pre` 通过。
- 最终成功日志：[stage3b_pre_final_run.log](../results/logs/stage3b_pre_final_run.log)，只记录通过的重跑；原始调试日志保留在本地但不作为最终运行证据。历史阶段日志未修改。
- 数据：[stage3b_pre_summary.csv](../results/data/stage3b_pre_summary.csv)、[stage3b_pre_applicability.csv](../results/data/stage3b_pre_applicability.csv)、`stage3b_pre_results.mat`；图：[stage3b_pre_accuracy.png](../results/figures/stage3b_pre_accuracy.png)。

## 6. 关键结果与等价类审计

所有数值见 summary CSV；以下仅列出最能说明边界的条件。

| 条件 | strict accuracy | equivalence-class accuracy | ambiguity | false-unique | 类内/最近类间比 | 解释 |
|---|---:|---:|---:|---:|---:|---|
| A0，BB，名义，理想 | 1.000 | 1.000 | 0.500 | 0 | 0 | T3/T5 仍是 `{T3,T5}` 等价类；strict 不能解释为唯一识别 |
| A0，NB 外推，名义，理想 | 1.000 | 1.000 | 0.500 | 0 | 0 | 相同的 T3/T5 等价状态；且仅为解析外推 |
| A0，BB，长度 +2%，理想 | 0.750 | 1.000 | 0.500 | 0 | 0.888 | 参数扰动已接近最近类间间隔 |
| A0，NB 外推，长度 +2%，理想 | 0.500 | 0.500 | 0 | 0.500 | 0.238 | 外推模型中参数变化可造成 false-unique，不能外推为物理 NB 结论 |
| A1，BB 原生点，名义，20 dB | 0.750 | 1.000 | 0.500 | 0 | 0.252 | 更多 BB 点未消除对称 SISO 等价 |
| A1，NB 外推，名义，20 dB | 0.488 | 0.613 | 0.338 | 0.275 | 0.908 | 外推低频响应在此受控样本噪声下类间/类内间隔很小 |

每行还保存了最近竞争拓扑字段；例如 A0 BB 名义理想行的最近非同类竞争为 T4（T3/T5 彼此属于同一等价类）。完整复数 CFR 的 T3/T5 等价类在所有本轮配置行中仍为 `{T3,T5}`。

因此本轮最重要的模型内结论不是“宽带必然更好”，而是：在相同对称 SISO 端口下，增加带宽或有效 CFR 点数不能保证消除严格结构观测等价。NB 外推行中出现的性能差异也不能被解释为真实物理频段优势或劣势。

## 7. 结论边界与 Stage 3B 判断

本轮只在冻结模型假设下比较宽窄带频率资源；不等于真实 PLC 收发机验证，不等于拓扑已被现场唯一识别，也不自动构成导频、功率或子载波优化依据。

**Stage 3B 仍被阻塞。** 至少还需冻结：真实 NB 硬件/PHY 与低频 RLGC/端接校准、BB active-carrier/GI 的实际来源、测量节点与方向、耦合器/参考面、同步时间原点及公平能量/时间/SNR 口径。确认这些条件后，第一项工作应是重新运行有物理依据的 Level-A0/A1，而不是直接优化任何 OFDM 资源。
