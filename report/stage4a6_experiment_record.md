# Stage 4A.6 联合拓扑确认与参数域诊断实验记录

## 1. 研究问题与边界

[代码静态核对] Stage 4A.6 将输出拆为两个正交部分：拓扑判定和参数域判定。对固定拓扑，分别在原参数域和预先定义的扩展域中拟合 CFR，并记录边界命中、向域外移动的残差趋势、拟合改善和局部归一化灵敏度。

[模型边界] 本实验使用 P0 的 7 个合成候选图、每图 243 个离散参数模板、单端口复数 CFR 和两个仿真频率网格。所有资产约束均为 `synthetic_demo_prior_not_field_data`；没有接入 GIS、线路台账、现场端接或真实 PLC 收发机。

## 2. 冻结协议

[本次运行] development 使用种子 `20261601, 20261602`；final 使用 `20261701`～`20261705`。development/final 样本 ID 不重叠。每个 final replicate 包含 7 个图的域内样本、连续参数域内样本，以及 6 个参数越界维度的 near/medium/far 轮换样本；A/B 网格使用相同的真值样本池。

[本次运行] development 在两个网格上比较扩展系数 `eta={0.5,1.0}`，均选择 `eta=0.5`。final 阶段冻结以下规则：

- 有界变量 logistic 变换加 `fminsearch`；
- 2 个确定性起点，包含候选模板起点和域中心；
- 最大 60 次迭代、180 次函数评价；
- 原参数区间外扩展采用 `eta=0.5`；
- 参数状态还受边界、向外残差下降、扩展域拟合改善和归一化灵敏度共同约束；
- final 数据未用于选择 eta、阈值或方法。

## 3. 输出语义

拓扑输出为 `unique_topology`、`unique_given_prior`、`equivalence_class` 或 `reject_*` 的映射；参数输出为：

```text
parameter_in_domain
parameter_out_suspected
parameter_domain_indeterminate
parameter_not_evaluated
```

[代码静态核对] 匹配决策函数只接收观测、候选缓存、校准模型和候选定义，不接收 `truth_topology_id`、真实参数或覆盖标签。等价类成员参数结论不一致时输出 `parameter_domain_indeterminate`。

## 4. 方法变体

| 方法 | 内容 |
|---|---|
| `A6_M0_topology_only` | 只输出 M3 拓扑结果，参数不评估 |
| `A6_M1_boundary` | 增加域内最优点边界命中和向外残差趋势 |
| `A6_M2_extended_profile` | 增加域内/扩展域拟合改善 |
| `A6_M3_joint_diagnostic` | 联合使用拟合改善、边界趋势和局部灵敏度 |

## 5. final 结果

| 网格 | 方法 | 域内拓扑集合命中率 | 参数域外 recall | 域内误报警 | indeterminate | 优化失败率 |
|---|---|---:|---:|---:|---:|---:|
| A：61 点 | M0 | 0.9429 | — | 0 | 0 | 1.0000 |
| A：61 点 | M1 | 0.9429 | 0 | 0 | 0.9429 | 1.0000 |
| A：61 点 | M2 | 0.9429 | 0 | 0 | 0.9429 | 1.0000 |
| A：61 点 | M3 | 0.9429 | 0 | 0 | 0.9429 | 1.0000 |
| B：1793 点 | M0 | 0.9429 | — | 0 | 0 | 1.0000 |
| B：1793 点 | M1 | 0.9429 | 0 | 0 | 0.9429 | 1.0000 |
| B：1793 点 | M2 | 0.9429 | 0 | 0 | 0.9429 | 1.0000 |
| B：1793 点 | M3 | 0.9429 | 0 | 0 | 0.9429 | 1.0000 |

[本次运行] 上表中的“优化失败率”表示至少一个参与该样本联合诊断的成员优化没有达到当前稳定收敛条件；B 网格的总体记录中该值约为 0.97～1.00。M1～M3 因此主要输出 `parameter_domain_indeterminate`，不能将参数域外 recall=0 解读为“所有参数均在域内”，也不能将其解读为参数域诊断已经成功。

[本次运行] 参数域外样本仍然保持较高的拓扑集合命中：A 约 0.70，B 约 0.67，说明参数超域和拓扑结构错误是两个不同问题。当前结果支持“拓扑可以命中而参数域外报警缺失”的风险判断，但不支持稳定的参数域外检测。

## 6. 灵敏度和不可辨识性

[本次运行] 归一化有限差分雅可比使用主线长度、支路长度、支路负载、源阻抗和接收阻抗五列，并通过 SVD 保存奇异值、有效秩、条件数、右奇异向量、列相关性和灵敏度范数。无支路拓扑的支路负载列出现零灵敏度；等价拓扑成员的参数结论可能不同，联合输出按规则转为 indeterminate。

[模型推断] 局部雅可比的有效秩不能推出全局参数唯一可辨识。尤其在单端口 CFR 下，负载和端口阻抗可能通过传播与端接效应互相补偿；需要输入阻抗、导纳、反向 CFR 或多端观测才能检验更强的可辨识性。

## 7. 运行与测试

[本次运行] smoke 入口为 `run_stage4a6_parameter_domain_diagnostic('smoke')`，退出码 0，约 36.3 s。development 入口为 `run_stage4a6_parameter_domain_diagnostic('development')`，源码哈希同步后退出码 0，约 270.4 s。61 点 final 入口为 `run_stage4a6_parameter_domain_diagnostic('formal_a')`，退出码 0，约 40.0 s；1793 点 final 入口为 `run_stage4a6_parameter_domain_diagnostic('formal_b')`，退出码 0，约 155.1 s。

[本次运行] 最终完整回归入口为 `run_tests`，退出码 0；Stage 1.5 至 Stage 4A.6 测试全部通过。MATLAB 版本为 R2024a `24.1.0.2537033`。

主要结果文件：

- [stage4a6_final_A_metrics.csv](../results/data/stage4a6_final_A_metrics.csv)
- [stage4a6_final_B_metrics.csv](../results/data/stage4a6_final_B_metrics.csv)
- [stage4a6_final_A_parameter_profiles.csv](../results/data/stage4a6_final_A_parameter_profiles.csv)
- [stage4a6_final_B_parameter_profiles.csv](../results/data/stage4a6_final_B_parameter_profiles.csv)
- [stage4a6_final_A_identifiability.csv](../results/data/stage4a6_final_A_identifiability.csv)
- [stage4a6_final_B_identifiability.csv](../results/data/stage4a6_final_B_identifiability.csv)
- [stage4a6_final_A_run.log](../results/logs/stage4a6_final_A_run.log)
- [stage4a6_final_B_run.log](../results/logs/stage4a6_final_B_run.log)

## 8. 阶段结论

[本次运行] Stage 4A.6 的代码接口、数据隔离、双域拟合、边界和灵敏度输出已经实现并通过测试；但本轮 final 的连续优化稳定性不足，参数域外检测没有达到可接受的算法冻结条件。因此 Stage 4A.6 不能宣称完成“稳健参数域诊断”，也不建议据此进入正式理论报告定稿。

[模型推断] 下一步应先修复有界连续优化的稳定性并进行独立 calibration/validation，或改用更稳健的 profile/网格局部精化；如果同一 SISO CFR 仍无法区分参数补偿，应优先增加输入阻抗、反向传输或多端观测，而不是继续叠加判据。

[本次未运行] 真实 GIS/台账先验、真实 PLC 收发机、现场拓扑恢复、FDR/TFDR、全节点导纳/TLS、Stage 4B 和 OFDM 资源优化。
