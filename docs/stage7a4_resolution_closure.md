# Stage 7A.4 输入阻抗分辨率与连续参数拟合归档

## 范围与身份

本归档并列保存 [R.1 分辨率实验](stage7a4_impedance_resolution_report.md)和 [R.2 连续拟合实验](stage7a4_continuous_fit_report.md)。两轮均以 `b69d109c9b2773dbd46858778ca532b3d4f7e13e` 为验证前基线；这个提交并不包含本归档的新源码。MATLAB 环境为 R2024a `24.1.0.2537033`、`glnxa64`，串行、0 worker。Stage 4A 至 Stage 7A.4 的已有正式结果和科学定义未改动。

这里的 **1 Ω** 始终是单次、每频点复输入阻抗 `Zin` 的合成测量误差 RMS，不是原镜像拓扑的物理阻抗差。研究只用 50/50 Ω 端口、2–30 MHz 的 61 个频点、两个已知镜像拓扑，以及 1e9 Ω、0.1–10 mm 的极弱支路构造数值分辨率控制。该支路不代表常见低压配网结构。重复测量的 `1/√R` 缩放依赖独立、无漂移、无系统偏差的假设，并未验证真实仪器可达到此条件。

## 并列结果

每轮正式 T 集在每个条件下对 M1、M3 各测试 100 次。经验“通过”要求**两侧各自**正确唯一至少 90/100、错误唯一至多 5/100；这不是总体概率保证。`ΔZ` 是两图固定相同名义参数时、61 频点的复 `Zin` RMS 差。

|实验和方法|参数域|单次测量最小已测通过 `ΔZ`|256 次均值最小已测通过 `ΔZ`|关键反例|
|---|---|---:|---:|---|
|R.1，45 点网格后的成对差判据|on-grid|0.331879 Ω|0.016596 Ω|off-grid 的全部 7×6 条件均未通过|
|R.2，有界连续剖面后的成对差判据|off-grid|0.331879 Ω|0.016596 Ω|最小差值的 on-grid、R=256 新 T 集未通过|
|R.2，有界连续剖面后的原四状态语义|off-grid|未通过已测三档|1.659574 Ω|在 0.331879 Ω、R=256 时 M3 仅 87/100 正确唯一|

R.1 与 R.2 使用**不同种子与校准样本量**，不能把两行直接相减当作配对处理效应。R.2 内的网格与连续方法才共用同一 T 观测并各自独立校准。R.2 的 60 个独立无噪声 off-grid D 样本，真类平均网格残差为 **83.882 Ω**，连续拟合后为 **6.16×10⁻⁵ Ω**；24 个 D 样本候选拟合的密集主线扫描未发现更低盆地。这是“网格近似误差是本控制条件失败机制”的直接数值支持，不是任意二维参数全局最优证明。

R.2 的 `off-grid, R=256, ΔZ=0.016596 Ω` 在独立 T 集中分别得到 M1/M3 正确唯一 **91/100、94/100**，错误唯一 **5/100、3/100**。M1 错误唯一的 95% Wilson 区间约 **2.2%–11.2%**；点估计刚触及预设上限。相同最小差值、同轮 `on-grid, R=256` 连续方法仅为 **91/100、83/100** 正确唯一及 **6/100、7/100** 错误唯一，未通过。因此不把 0.016596 Ω 写成稳定、通用或现场可达的分辨极限。成对差判据无候选库外拒识门，不能替代原完整四状态流程。

完整可追溯的紧凑机器数据：R.1 [设计](../results/data/stage7a_4_resolution/formal/resolution_design.csv)、[逐组汇总](../results/data/stage7a_4_resolution/formal/resolution_summary.csv)、[最小已测通过点](../results/data/stage7a_4_resolution/formal/resolution_frontier.csv)；R.2 [设计](../results/data/stage7a_4_continuous/formal/continuous_design.csv)、[逐组汇总](../results/data/stage7a_4_continuous/formal/continuous_summary.csv)、[最小已测通过点](../results/data/stage7a_4_continuous/formal/continuous_frontier.csv)、[无噪声 D 诊断](../results/data/stage7a_4_continuous/formal/continuous_clean_diagnostics.csv)和[密集扫描审计](../results/data/stage7a_4_continuous/formal/continuous_dense_audit.csv)。

## 复现与归档边界

R.1 正式运行的 MATLAB 内部时间为 **15.402 s**；R.2 为 **182.197 s**，另有密集审计 **12.22 s**。R.2 每个 T 样本的两个候选合计平均约 98 次优化正向计算。以上均不含 MATLAB 启动及真实重复采集时间。两轮的配置快照、元数据、源文件 SHA-256 身份、紧凑正式 CSV 和实际日志均纳入 Git。大型正式逐样本 CSV 与 smoke 数据留在本地，按仓库既有 Stage 7A.4 归档规则由以下入口重建：

```matlab
run_stage7a4_impedance_resolution(pwd,'smoke')
run_stage7a4_impedance_resolution(pwd,'formal')
run_stage7a4_continuous_fit(pwd,'smoke')
run_stage7a4_continuous_fit(pwd,'formal')
addpath('experiments')
exp_stage7a4_continuous_dense_audit(pwd)
```

入口会写各自独立的 Stage 7A.4-R.1/R.2 结果目录；复现时应使用独立 worktree，避免覆盖已经归档的本地原件。当前本地未入 Git 的原始逐样本文件身份如下；SHA-256 按原始字节计算，重新运行的 MATLAB 运行时间及 MAT 时间元数据不要求逐字节一致。

|本地可重建逐样本文件|字节数|SHA-256|
|---|---:|---|
|`results/data/stage7a_4_resolution/formal/resolution_samples.csv`|11,175,693|`0c437fde5caa3948d04400d3e02b39289e123f40d4fac807bdabb212693c6635`|
|`results/data/stage7a_4_continuous/formal/continuous_samples.csv`|3,716,567|`c1fbb36d733ca4df5d60d2f7e9a20bbdeeff0acf55563ec665e6f5d7110eddf1`|

测试命令（仓库根目录，在 `-batch` 中执行）：

```matlab
addpath('tests')
test_stage7a4_impedance_resolution(pwd,'unit')
run_stage7a4_impedance_resolution(pwd,'smoke')
test_stage7a4_impedance_resolution(pwd,'smoke')
run_stage7a4_impedance_resolution(pwd,'formal')
test_stage7a4_impedance_resolution(pwd,'formal')
test_stage7a4_continuous_fit(pwd,'unit')
run_stage7a4_continuous_fit(pwd,'smoke')
test_stage7a4_continuous_fit(pwd,'smoke')
run_stage7a4_continuous_fit(pwd,'formal')
test_stage7a4_continuous_fit(pwd,'formal')
test_stage7a4_forward_state()
test_stage7a4_joint_profile()
test_stage7a4_result_integrity(pwd,'formal')
```

上述定向、smoke、formal 与相关旧结果完整性检查均已在 MATLAB R2024a 实际退出码 0；日志分别见 [R.1](../results/logs/stage7a_4_resolution/)和 [R.2](../results/logs/stage7a_4_continuous/)。完整 `tests/run_tests.m` 未在含新未提交文件的主工作区运行；相关回归不能误称为全量回归。Stage 4A/5B.1/6A/6B/7A 至原 Stage 7A.4 的冻结源码或正式数值没有被本阶段修改。

## 适用边界与后续关口

所有数据均来自受控 MATLAB 模型内合成观测，并非真实 PLC 收发机或现场台区测量。61 频点独立复噪声、1 Ω 单次 `Zin` 误差、256 次无漂移相干均值、精确端口参考面及高阻微小 stub 都是未获硬件验证的假设。已知二图间可分不意味着任意候选库有覆盖、未知拓扑可拒识或物理图全局唯一；`UNIQUE_CONFIDENT` 仅相对于本次候选库、模型和局部校准域成立。

连续拟合在本受控参数失配条件下值得保留为**待扩展的诊断候选**，但尚不构成替换现行主线算法的证据。下一关应预先固定实际候选规模、库外拓扑、参数域外与非唯一正控制，再独立校准并比较真值集合覆盖、错误唯一、库外误接受和运行成本；在通过这些安全性检查前不改变 Stage 6B baseline 或 Stage 7A.4 正式定义。
