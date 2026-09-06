# Stage 4A.6.1 连续参数优化器稳定化与参数剖面可信度审计

## 摘要

本阶段针对 Stage 4A.6 中连续参数拟合状态混合、无效参数参与优化、未收敛剖面进入校准以及参数域指标语义不清等问题，新增了拓扑相关有效参数掩码、复 CFR 实数残差优化、分层可靠性状态和单参数 profile likelihood 接口。实现保留 `lsqnonlin` 优先、无工具箱时的有界 `fminsearch` 回退，并提供外层案例级并行入口。

[本次运行] MATLAB R2024a 的四项 Stage 4A.6.1 单元测试、完整历史回归和一个当前源码哈希下的 no-profile smoke 均完成。独立单拓扑 profile 单元实验也得到有限曲线和 `scan_reliable=1`。但是，完整多案例 profile experiment 在当前 MATLAB 进程环境中仍出现无错误栈的中止，因而没有运行正式 final 统计，也没有把 profile 覆盖率写成阶段通过结论。

## 1. 研究边界

本阶段仍使用受限径向候选图、合成参数、合成先验和单发送端—单接收端复数 CFR。当前 61 点频率网格和完整 OFDM 有效子载波网格仍是仿真配置；结果不能解释为真实 PLC 收发机、现场拓扑恢复或真实参数辨识能力。Stage 4B 未启动。

## 2. 实现内容

### 2.1 拓扑相关的有效参数掩码

`topology_active_parameter_mask.m` 将参数分成：

- 主线长度、源端阻抗、接收端阻抗：在当前候选语法中始终有效；
- 支路长度、支路负载：仅在候选实际含有支路时有效；
- 不存在于拓扑的参数：标记为 inactive，不参加 Jacobian、profile 或参数域分母。

这避免了无支路拓扑中的零 Jacobian 列把整个 profile 错判为不可信。

### 2.2 连续参数拟合

`optimize_stage4a6_1_parameters.m` 将复 CFR 差异转换为实数残差：

$$
r(\theta)=\left[
\operatorname{Re}(H_{\mathrm{obs}}-H_{\mathrm{mod}}),
\operatorname{Im}(H_{\mathrm{obs}}-H_{\mathrm{mod}})
\right]^T.
$$

当前目标仍与复 CFR RMS 距离一致；没有改变候选拓扑排序的物理定义。求解器优先使用 `lsqnonlin`，不可用时回退到 logistic 有界变量变换加 `fminsearch`。每次拟合保存 solver、起点、终点、距离、exit flag、迭代数、函数评价数、边界状态和运行时间。

求解状态被拆分为：

```text
optimizer_converged
multistart_consistent
residual_finite
active_parameters_identifiable
profile_reliable
```

多起点一致性只在近最佳解簇内判断；这不把较差局部解静默改写为收敛，也不把求解器 exit flag 与参数可辨识性混为一项。

### 2.3 单参数 profile

`compute_stage4a6_1_profile.m` 对每个 active 参数计算：

$$
d_i(v)=\min_{\theta_{-i}}D\left[H_{\mathrm{obs}},H(G,\theta_i=v,\theta_{-i})\right].
$$

扫描同时保留候选域和预先定义的扩展域，并记录域内/扩展域最小距离、相对改善、域外最优、平坦性和扫描有限性。`calibrate_stage4a6_1_parameter_domain.m` 仅使用 `profile_reliable=true` 的 calibration 证据；有效样本不足时返回 `insufficient_calibration`，不产生伪阈值。

### 2.4 指标语义

`evaluate_stage4a6_1_metrics.m` 对不提供参数域判断的 M0 输出：

```text
parameter_status = not_applicable
parameter_ood_recall = NaN
parameter_in_domain_false_alarm = NaN
parameter_ood_miss_rate = NaN
```

这一区分了“不适用”“未检出”“证据不足”和“优化失败”。

## 3. 代码静态核对

| 环节 | 文件 | 状态 |
|---|---|---|
| 参数名称与固定顺序 | `src/stage4a6_1_parameter_names.m` | 已实现 |
| active parameter mask | `src/topology_active_parameter_mask.m` | 已实现 |
| 有界连续拟合 | `src/optimize_stage4a6_1_parameters.m` | 已实现，含串行 fallback |
| 实数 CFR 残差 | 同上 | 已实现 |
| 局部 Jacobian | `src/compute_stage4a6_1_jacobian.m` | 仅 active 参数 |
| profile likelihood | `src/compute_stage4a6_1_profile.m` | 粗网格、候选域/扩展域 |
| 可信 calibration | `src/calibrate_stage4a6_1_parameter_domain.m` | 只用可靠 profile |
| 参数域决策 | `src/apply_stage4a6_1_parameter_decision.m` | 不读取真实标签 |
| 指标汇总 | `src/evaluate_stage4a6_1_metrics.m` | M0 使用 NaN/not_applicable |
| 外层案例批处理 | `src/run_stage4a6_1_member_batch.m` | 串行与 outer-case 并行入口 |
| 阶段配置与入口 | `config/stage4a6_1_optimizer_config.m`、`run_stage4a6_1_optimizer_stabilization.m` | 已新增 |

## 4. 本次运行证据

### 4.1 环境与版本

[本次运行]

- MATLAB：R2024a，`24.1.0.2537033`；
- 分支：`main`；
- 起始和当前 Git HEAD：`448892202c1490c73067b2dd39c5c4f9c5cd9901`；
- `origin/main`：同一提交；
- 当前源码树哈希：`7e3ef1d5cadf1b0b3f6b0ad57354297ce731a3d3f5b16bd883a9262aa44d96f4`；
- 当前实验 scientific hash（current no-profile smoke）：`ddcc533a338b31c9c6bc787b5c3d59f8817898069ba7998eb5fa6849325a0df6`。

工作树包含本阶段未提交的新代码和结果，未自动提交或推送。

### 4.2 单元测试与回归

[本次运行] 以下新增测试均通过：

```text
test_stage4a6_1_active_mask
test_stage4a6_1_optimizer_stability
test_stage4a6_1_profile_metrics
test_stage4a6_1_protocol
```

[本次运行] 完整 `run_tests` 日志中，Stage 1.5、Stage 2、Stage 2.1、Stage 2.2、Stage 2.3、Stage 3A、Stage 3A.1、Stage 3A.2、Stage 3B-pre、Stage 3B waveform baseline、Stage 4A.1～4A.6 和四项 Stage 4A.6.1 测试均显示通过。日志：`results/logs/stage4a6_1_full_regression.log`。

### 4.3 Smoke 与 profile 单元实验

[本次运行] 当前源码 no-profile smoke：

- 网格：`A_stage4a1_quick61`；
- 样本数：11；
- 候选图：7；
- 参数模板：243/图；
- solver：`lsqnonlin`；
- profile：关闭，仅验证优化器和拓扑层输出；
- 实验 runtime：`4.7873 s`；
- 结果前缀：`stage4a6_1_smoke_current_no_profile_*`。

[本次运行] 独立单拓扑 profile 单元实验使用 9 个频点和 3 个 active 参数，得到 3 条 profile 曲线，曲线均有限，`scan_reliable=1`。这证明 profile 函数在小规模调用下可运行，但不代表完整多案例 profile 实验已稳定。

### 4.4 Profile experiment 的限制

[本次未运行] 完整多案例 profile-enabled experiment 在当前 MATLAB 进程环境中出现无 MATLAB 错误栈的提前中止，未生成可用于正式统计的完整 A/B final 结果。若干小规模旧调试结果曾显示 profile 可靠性较低，但这些结果使用较早源码哈希，不能替代当前代码的正式 final 结果。

因此，本阶段没有报告 profile reliability 的正式覆盖率，也没有使用 profile 结果校准正式参数域阈值。

## 5. 目前能得出的结论

[模型内推断]

1. active parameter mask、实数 CFR 残差、可靠性状态拆分和 NaN 指标语义已形成可执行接口。
2. 无支路拓扑不会因为无效支路参数列而自动降低 active parameter rank。
3. 近最佳解簇一致性比“所有局部解必须相同”更适合表示多起点证据，但它仍不是全局唯一性证明。
4. 单拓扑、小频点 profile 可以得到有限扫描曲线；完整多案例 profile 的资源和进程稳定性仍未达到可报告状态。
5. 并行化和连续优化只能改善计算流程，不能提升当前 SISO CFR 的物理可辨识性。

## 6. 阶段门槛判断

当前判断：

```text
B. Stage 4A.6.1 部分通过，需要继续优化器/profile 开发。
```

通过部分：代码结构、active mask、状态拆分、NaN 指标语义、单元测试、完整历史回归、单拓扑 profile 和串行 smoke。

未通过部分：完整 profile-enabled 多案例运行稳定性、正式 calibration/final 分离统计、A/B 两网格正式 profile 比较以及基于可靠 profile 的参数域检测率。

在这些内容完成前，不建议进入正式论文定稿，也不建议启动 Stage 4B。

## 7. 下一步

优先将 profile 计算拆成独立、可释放的案例级 MATLAB 进程或小批次文件，避免一个 MATLAB 进程同时保留多个案例的嵌套 solver 诊断结构；每批只输出紧凑摘要，再由主进程汇总。随后用全新 calibration/final seed 运行 A/B 网格，并报告 profile coverage-aware 指标。若仍无法稳定获得可靠 profile，应把参数域判断降级为 `indeterminate`，而不是用优化器失败推断参数库外。
