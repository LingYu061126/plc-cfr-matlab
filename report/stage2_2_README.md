# 阶段 2.2 运行说明

## 范围

本阶段实现“完整树网络的物理一致多视图观测 + 离散拓扑/参数联合匹配”。OFDM 部分仍是频域等效导频测量 `Y=X.*H+N`，不是完整收发机。本阶段没有优化波形、没有使用机器学习，也没有接地故障定位。

## 运行

在 `matlab_plc_cfr` 目录中：

```matlab
run_stage2_2
```

该入口先运行阶段 1.5、2、2.1 和 2.2 全部测试，再运行 `experiments/exp10_stage2_2_physical_multiview.m`。仅运行测试：

```matlab
run('tests/run_tests.m')
```

正式配置位于 `config/default_config.m` 的 `cfg.stage2_2`。当前固定配置为：

- MATLAB R2024a，项目计算不需要额外工具箱；
- `NFFT=4096`、`Fs=64 MHz`、`2–30 MHz`、1793 个全导频子载波；
- 候选 T2/T3/T4/T5；
- SNR `30/20/10/0 dB`，同时运行固定接收 SNR 和固定噪声功率；
- 每条件 20 次独立可复现试验，项目随机种子 `20260819`；
- 每个拓扑 243 个参数模板：主线/支路长度比例独立取 `0.95/1/1.05`，负载比例 `0.8/1/1.2`，`Zs/Zr=45/50/55 Ω`；
- 联合匹配使用幅值形状与幅值加权圆周相位距离，默认权重 `0.5/0.5`。该权重只是配置，不是最优性结论。

## 主要接口

- `plc_full_network_response`：完整树网络分布参数节点导纳求解；
- `plc_measurement_bundle`：定义正向、两种反向端接语义、双向和完整网络多接收点；
- `plc_multiview_response`：在同一完整网络中计算多激励/多接收视图；
- `topology_parameter_grid`、`topology_parameter_library`：生成离散参数模板；
- `topology_prepare_parameter_library`：为 Monte Carlo 批量匹配缓存等价特征；
- `topology_joint_match`：最小化特征距离加参数正则项。

`topology_prefix_network` 仅用于复现阶段 2.1 的历史 C3，不属于阶段 2.2 多端口模型。

## 输出

数据：

- `results/data/stage2_2_results.mat`：配置、候选、原始试验、汇总、混淆矩阵和运行时间；
- `stage2_2_trials.csv`：4800 条方法评价记录；
- `stage2_2_summary.csv`：准确率均值/标准差/95% CI、边级 P/R/F1、CFR 误差、距离比和参数 RMSE；
- `stage2_2_confusion.csv`：每个实验/噪声/视图/SNR/方法的完整混淆计数；
- `stage2_2_physical_audit.csv`：无噪声理想可分性、T3/T5 距离和 tie；
- `stage2_2_parameter_sweeps.csv`、`stage2_2_feature_audit.csv`：参数和特征审计。

图：`results/figures/stage2_2_*.png`。日志：`results/logs/stage2_2_final_run.log`。

## 解读边界

- `strict_accuracy` 是精确候选编号准确率；无噪声审计另有 `unique_strict_accuracy`，数值 tie 不计作唯一识别。
- `group_accuracy` 沿用阶段 2.1 的 T3/T5 对称 SISO 结构组，在多视图已打破 tie 时它只是历史可比指标。
- 内部节点接收机以明确的并联负载进入网络，会扰动原网络；不能将它当成无限高阻、无扰动的现场探头。
- 线路长度 RMSE 是当前候选边长度的仿真估计误差；负载误差是标量缩放因子误差，不是任意复负载参数识别。
- 本阶段没有真实现场数据，不得将理想多视图的 100% 写成现场性能。
