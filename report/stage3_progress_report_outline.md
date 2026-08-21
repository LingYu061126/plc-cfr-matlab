# PLC 拓扑感知项目阶段 3 汇报提纲

本提纲用于后续 Word 汇报，数字应从仓库中的 CSV、日志和报告引用，不应在 Word 中手工改写。

## 1. 研究问题和总体链路

### 1.1 研究问题

- 现有通信型 OFDM 导频是否包含拓扑感知信息？
- 在什么观测方式和参数假设下可以识别拓扑等价类？
- 何时需要增加测量节点/方向，何时才有必要修改波形？

### 1.2 统一链路

```text
探测信号 X -> H(f;G,theta) -> Y=XH+N -> H_hat
             -> CFR/CIR/循环时延/阻抗特征 -> 拓扑或等价类匹配
```

必须在开头声明：当前阶段是频域等效 OFDM 导频模型，不是完整 PLC 收发机。

## 2. RLGC/ABCD 正向模型

### 2.1 参数与传输线

- `R'、L'、G'、C'`、传播常数 `gamma`、特性阻抗 `Zc`；
- 线路二端口 ABCD 矩阵；
- 支路输入阻抗回推和节点并联导纳；
- 端接公式、`H_V` 与 `H_port` 的归一化适用条件。

### 2.2 数值稳定性

- 长线路直接 ABCD 的 `AD-BC` 消减误差；
- 稳定阻抗递推在阶段 1.5 的验证；
- 本阶段不重写基础物理模型。

### 2.3 拓扑和参数

- 候选树拓扑、主线/支路/负载；
- `G` 与 `theta` 的区分；
- T3/T5 对称拓扑的结构观测等价。

## 3. OFDM 信道估计

### 3.1 等效通信链路

- `NFFT=4096`、`Fs=64 MHz`、2--30 MHz、1793 个有效频点；
- 导频 `X[k]`、接收 `Y[k]` 和 LS `H_hat=Y/X`；
- 普通 OFDM CFR 与 FDR/TFDR、输入导纳 proxy 的区别。

### 3.2 循环和线性卷积审计

- 频域乘法与显式循环卷积的数值一致性；
- sampled CFR 的 IFFT 周期化和有限带宽旁瓣；
- `physical_delay_support=NaN` 的原因；
- 99% 能量支撑、-40 dB 支撑、CP energy coverage 和线性/循环 RMS；
- 明确 CP 结果不是现场 CP 设计验证。

推荐图表：

- `results/figures/stage3a_2_model_validity_cp_audit.png`；
- `results/data/stage3a_2_model_validity_cp_metrics.csv`。

## 4. 拓扑匹配方法

### 4.1 三种基线

1. `nominal_nearest`：名义参数最近邻；
2. `topology_only`：单一幅值特征；
3. `nuisance_aware_joint`：拓扑和有界参数联合搜索。

### 4.2 目标与指标

\[
J(G,theta)=D(\hat H,H(G,theta))+lambda R(theta)
\]

指标包括 strict accuracy、strict unique rate、equivalence-class rate、ambiguity、false unique、CFR NMSE、theta RMSE、边界命中率和边级 P/R/F1。强调参数自由度可能造成不可辨识或过拟合。

## 5. 阶段 3A、3A.1、3A.2 实验设计

### 5.1 阶段 3A

- 现有通信型 OFDM 等效链路；
- SISO、双向、双接收、三视角；
- 全导频/稀疏导频、噪声和同步误差基线；
- 主要结果：SISO T3/T5 等价，多视角模型内可分。

### 5.2 阶段 3A.1

- 统计扩大到多随机种子；
- 审计 SNR、导频间隔、特征和参数感知匹配；
- 得出观测等价、参数失配和同步边界优先于波形优化的判断。

### 5.3 阶段 3A.2

- CP/循环/线性 sampled CFR 审计；
- `nominal_noise_20`、`load_error_10`、`joint_bounded`；
- `siso_forward`、loaded/high-Z dual receiver、counterfactual、three-view；
- 校准 10 次/拓扑、测试 50 次/拓扑、27 点参数网格、独立 seed；
- 正式文件：`results/data/stage3a_2_protocol_summary.csv`、`...trial_metrics.csv`、`...confusion.csv`、`...config.csv`。

## 6. 关键图表和正式数字

- CP 审计图：`stage3a_2_model_validity_cp_audit.png`；
- 观测协议比较图：`stage3a_2_protocol_observation_protocol.png`；
- lambda 校准图：`stage3a_2_protocol_calibration_selection.png`；
- 正式日志：`stage3a_2_protocol_formal_final.log`、`stage3a_2_final_run_tests_seedfix.log`；
- 证据矩阵：`report/stage3a_2_final_evidence_matrix.md`。

Word 中应使用 CSV 的正式四舍五入数字，并注明 `trials=200` 是每个场景/观测/方法下四个拓扑合计。

## 7. 失败案例和对称不可辨识

- SISO T3/T5 结构等价：class rate 1、unique rate约 0.5；
- joint 参数自由度造成 false unique；
- CP/线性卷积差异不能直接解释为现场 CP 失败；
- loaded 多接收机改变网络工作点；
- counterfactual 只是分析性对照；
- 低 CFR NMSE 不等于拓扑唯一识别。

## 8. 证据等级

### 已验证

MATLAB 测试、CSV、日志和当前完整网络模型直接支持的内容。

### 根据模型推断

观测等价是主要瓶颈、参数自由度的副作用、多视角改善的机制解释。

### 尚待验证

真实 PLC OFDM 参数、因果时域信道、同步/CFO、现场噪声、耦合器、端接、内部节点、多导体/MIMO 和硬件实验。

## 9. 下一步研究路线

1. 导师确认真实 OFDM 和测量协议；
2. 固定端接、耦合器、节点和同步模型；
3. 若固定后瓶颈仍为 OFDM 资源，再设计阶段 3B 的导频/子载波/功率实验；
4. 若瓶颈来自观测节点或参数不确定性，优先完善多视图测量和联合先验；
5. 阶段 3B 之前不宣称真实 PLC 拓扑唯一识别。
