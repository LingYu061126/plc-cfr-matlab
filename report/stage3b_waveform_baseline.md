# Stage 3B 前的标准派生 G.hn 波形级基线

## 1. 当前阶段与任务边界

当前阶段为：

```text
Stage 3B-pre 已完成并收尾；正式 Stage 3B 尚未启动。
```

本轮实现的是 **Stage 3B 前的波形级基线实现准备**。新模型名为
`Ghn_100MHz_powerline_SISO_standard_derived_reference`：它是标准/资料派生的
G.hn 波形级参考平台，不是完整 G.hn PHY、HomePlug PHY 或商用 modem 复现。
本项目尚未采购、接线或标定真实 G.hn 收发机；波形级模型也不等于已经证明 PLC
具有拓扑感知能力。

本报告与 [主基线证据冻结](stage3b_transceiver_baseline_freeze.md)、
[Stage 3B-pre 理想 CFR 诊断](stage3b_pre_level_a.md)、
[Stage 3B 进入门槛](stage3b_entry_gate.md) 和
[项目交接快照](project_handoff.md) 一致。旧 Stage 1--Stage 3A.2 代码、配置、
结果和报告均未修改；稳定的 RLGC 正向模型仅作为只读的 `H(f;G,theta)` 提供者。

## 2. 新旧模型差异与隔离

| 项目 | Stage 3A 历史链路 | 本轮 `stage3b_waveform_*` 链路 |
|---|---|---|
| 网格 | `64 MHz / 4096 / CP=256` 项目仿真假设 | `100 MHz / 4096 / 24.4140625 kHz` 标准派生网格 |
| 频带 | 旧项目有效频段设置 | 显式 2--30 MHz 研究 mask；不是完整 power-line bandplan |
| 发射/接收 | 采样 CFR 的既有 OFDM 审计 | 抽象训练符号→IFFT→候选 GI/CP→线性卷积→FFT/LS |
| 时域解释 | 已审计为循环、带限 CIR | 明确区分解析测试 FIR 与 sampled-CFR IFFT；后者没有物理时间零点 |
| 新误差接口 | Stage 3A 历史接口不变 | 整数/分数定时、CFO、SCO、相位、彩色和脉冲接收端等效噪声 |

新文件均以 `stage3b_waveform_` 命名；`tests/run_tests.m` 只追加
`test_stage3b_waveform()` 调用，未改变旧测试逻辑。

## 3. 参数来源、证据等级和实现状态

证据等级沿用主基线冻结报告：`[A]` 标准/官方资料明确规定，`[B]` 论文实验设置，
`[C]` 基于资料的受限推断，`[D]` 未找到可靠证据。资料链接与页码以
[`stage3b_transceiver_baseline_freeze.md`](stage3b_transceiver_baseline_freeze.md)
第 3--6 节为准；本轮没有把搜索摘要当作标准正文。

| 参数/接口 | 本轮值或实现 | 证据与状态 | 使用边界 |
|---|---|---|---|
| 平台名、SISO | `Ghn_100MHz_powerline_SISO_standard_derived_reference` | `[C]`，G.9960/G.9964 与公开 AFE 资料的受限主线选择 | 单 TX/单 RX 数学观测，不是已购设备 |
| FFT 与采样 | `NFFT=4096`、`Fs=100 MHz`、`Delta_f=24.4140625 kHz` | `[A]`，G.9960 公开 Table 7-67 | 标准派生模型参数，不是实测时钟 |
| 研究频带 | 2--30 MHz 的正频率 bin，共 1147 个 | `[C]` 项目研究 mask | 不是完整 G.hn active carrier 或区域 notch map |
| GI/CP | `beta=512`、`N_GI=1024`、候选 `N_CP=1536` | `[A]`，G.9964 Table 6-4 / G.9960 Table 7-68 的既有核验 | 具体 payload profile、实际有效 GI 和物理时延仍待确认；绝非旧 `CP=256` |
| 训练符号 | 所有研究 mask bin 上的确定性 QPSK 已知训练 | 项目暂定假设 | 仅抽象训练块，不能称 G.hn 通用前导/导频图样 |
| Hermitian 映射 | 正频率 bin 的共轭镜像、DC/Nyquist 为零 | 项目暂定假设 | 形成实值离散波形；不是经验证的 G.hn 映射或模拟前端实现 |
| PSD 接口 | 可配置约束接口，默认不作用于波形 | `[A]` 的合规参考框架 | `-55 dBm/Hz`、`+20 dBm`、100 ohm 只作合规参考，不是实际注入电压、线路负载或耦合器 |
| `C_tx,C_rx,H_frontend,Zs,Zr` | 单位传递、50 ohm 数学参考占位 | `[D]` / 待实测 | 明确标记 `placeholder / assumption / requires measurement` |
| CFO/SCO/定时/相位 | 可关闭接口，默认全零 | `[A]/[D]`：时钟容差可作扫描起点，其余未校准 | 抽象的接收机域离散误差，不是某 modem 同步器 |
| 噪声 | 接收波形域白/彩色高斯、脉冲接口 | 项目暂定假设 | 不是由 PSD、耦合损耗、NF 或现场统计推导 |

## 4. 发射、信道和接收定义

### 4.1 抽象训练发射端

训练、数据和禁用 carrier mask 独立保存。对于启用的正频率 bin，发射端生成确定性
单位能量 QPSK `X[k]`，再写入其共轭镜像：

\[
X[N-k] = X[k]^* .
\]

因此 `ifft(X)` 是实值的**离散抽象波形**。实现顺序为

```text
training/data mask -> Hermitian frequency vector -> IFFT -> optional diagnostic window -> CP/GI -> frame
```

默认窗为矩形窗；仅提供 `raised_cosine_diagnostic` 的可选接口，未实现或声称任何
已核验 G.hn WOLA/帧 profile。`N_CP=N_GI+beta` 被参数化，而非硬编码历史 CP。

### 4.2 CFR 映射与线性卷积

稳定正向模型在正频率研究 bin 上给出 `H(f;G,theta)`。新模块将该采样值和其共轭
镜像嵌入 4096 点频栅格，形成 `H_full[k]`，并计算

\[
h_{\rm sampled}[n]=\operatorname{IFFT}\{H_{\rm full}[k]\},\qquad
y[n]=x[n]*h_{\rm sampled}[n].
\]

这里使用的是**线性卷积**。不过当 `h_sampled` 来自有限频带 CFR 的 IFFT 时，它是
带限、循环离散响应；并没有经过 TX/RX 时间参考面校准，不能写成物理因果 CIR、
ToA 或线路传播时延。本轮另以已知因果 FIR 仅做 FFT/CP 数学极限测试，绝不把该
FIR 当作 PLC 线路。

### 4.3 接收与 LS CFR

接收端按名义帧起点去 CP、FFT、剔除 mask 外 bin，并使用已知训练符号得到：

\[
\widehat H[k]=Y[k]/X[k].
\]

无效/缺失训练 bin 会显式标为无效；本版不以插值填补它们。输出为复数 CFR 与
`cfr_nmse`。后者只是**通信信道估计层**的误差，不能替代 strict accuracy、
equivalent-class accuracy、ambiguity rate 或 false-unique rate 等拓扑层指标。

## 5. 误差、噪声、耦合与端接边界

整数/分数定时偏移、CFO、SCO 和相位偏置均在**线路线性卷积之后、ADC/FFT 之前**
施加。分数定时和 SCO 是离散插值接口，不是实测同步算法。白/彩色/脉冲噪声同样
在线路卷积和同步接口之后、FFT 之前，以固定种子加到接收波形；它们不是“等效 CFR
样点噪声”，也不能被包装为真实收发机噪声。

`C_tx(f)`、`C_rx(f)`、`H_frontend(f)` 与 `Z_s(f),Z_r(f)` 均有参数位置，但默认
单位传递/50 ohm 数学端口。100 ohm 标准测量端接不是此端口的替代值。实际耦合器、
保护网络、参考面、端接、AGC、动态范围和可导出 CFR/IQ 格式均未冻结。

## 6. CP 审计和实际运行结果

运行环境：MATLAB `24.1.0.2537033 (R2024a)`；工作目录为仓库根目录。完整命令、
版本、入口和最终 `EXIT_STATUS=0` 记录于
[`results/logs/stage3b_waveform_final_run.log`](../results/logs/stage3b_waveform_final_run.log)：

```matlab
addpath('src','config','experiments','tests');
run_tests;
test_stage3b_waveform;
exp_stage3b_waveform_baseline(pwd);
```

全量既有回归和新测试均通过。新测试覆盖：历史配置隔离、IFFT/FFT 闭环、CP 去除、
充分/不足 CP 的解析 FIR 极限、LS 恢复、carrier mask、五类同步误差接口、三种可重复
噪声、T3/T5 SISO 等价类。

已生成的独立结果为：

- [`stage3b_waveform_cfr_closure.csv`](../results/data/stage3b_waveform_cfr_closure.csv)
- [`stage3b_waveform_network_sampled_cfr_diagnostic.csv`](../results/data/stage3b_waveform_network_sampled_cfr_diagnostic.csv)
- [`stage3b_waveform_t3_t5_equivalence.csv`](../results/data/stage3b_waveform_t3_t5_equivalence.csv)
- [`stage3b_waveform_cfr_nmse.png`](../results/figures/stage3b_waveform_cfr_nmse.png)

| 抽象因果 FIR 闭环/误差条件 | CFR NMSE | CP 数学覆盖 |
|---|---:|---:|
| clean | `6.75e-32` | 是 |
| integer timing = 2 samples | `2.279` | 是 |
| CFO = 5 kHz | `1.754` | 是 |
| SCO = 100 ppm | `0.1981` | 是 |
| colored Gaussian, 20 dB | `8.44e-3` | 是 |
| impulsive, 20 dB | `1.05e-2` | 是 |

这张表只验证接口是否会按定义改变已知训练的 CFR 估计，不能用于给真实 G.hn modem
或实际 PLC 噪声排序。

对当前正向网络模型的 sampled-CFR IFFT，T2/T3/T4/T5 的有效支撑均为 4095 samples，
而候选 CP 为 1536 samples，故均为“CP 数学不覆盖”。相应无误差波形 LS NMSE 约为
`5.60e-5` 到 `9.20e-5`。这不是链路失败或真实 GI 结论，而是直接证明：当前有限带
采样 CFR 的 IFFT 不能未经因果/时间参考面校准就当作完整物理时域信道。

## 7. T3/T5 与可辨识性边界

使用当前稳定正向模型在同一 2--30 MHz、SISO 正频率网格上审计候选 T2--T5，结果为：

| 拓扑 | SISO CFR 等价类 | 类大小 |
|---|---|---:|
| T2 | `{T2}` | 1 |
| T3 | `{T3,T5}` | 2 |
| T4 | `{T4}` | 1 |
| T5 | `{T3,T5}` | 2 |

因此增加这个标准派生网格、波形闭环或训练 LS 并没有打破 T3/T5 的当前 SISO 结构观测
等价。带宽/采样点更多也不能保证消除这种等价；同步误差和参数失配反而可能扩大
类内距离或制造 false-unique 风险。没有把任何 `cfr_nmse` 曲线转换为拓扑准确率。

## 8. 仍须实测的参数与正式 Stage 3B 门槛

仍必须在受导师和实验室安全规范约束的隔离实验中标定：

1. 实际 TX/RX 测量节点、方向、CFR/IQ 可访问性和时间零点；
2. 耦合器、隔离/保护、TX/RX switch 的复传递函数与线路侧参考面；
3. `Z_s(f)`、`Z_r(f)`、实际负载与 2--30 MHz RLGC；
4. 实际 active carrier、区域 notch、GI/profile、训练图样、PSD/功率和接收机行为；
5. CFO/SCO/触发/AGC，以及背景、有色、周期和脉冲噪声的现场统计；
6. 若开展 NB 比较，低频 RLGC、端接和可运行 NB PHY 的独立校准。

因此本轮**不能进入正式 Stage 3B 的导频、功率或子载波优化**。只有先冻结上述观测
协议与硬件/线路参数，并经独立测试证明剩余主要瓶颈确为导频密度、频带、功率或资源
配置，才可开始正式资源优化。

## 9. 结论

本轮已建立可重复的、标准参数可追溯的抽象波形级 CFR 基线，并验证其数学闭环和错误
接口。通信标准参数和理想/抽象 CFR 可辨识性诊断只提高收发机模型与实验设置的可追溯性；
它们**不等于真实 PLC 拓扑识别性能已经被验证**，也不等于真实拓扑已被现场唯一识别。
