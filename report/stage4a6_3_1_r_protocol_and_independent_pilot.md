# Stage 4A.6.3.1-R：协议与独立样本 Pilot 记录

## 1. 范围与阶段结论

本阶段补齐 Stage 4A.6.3.1 的复现入口、候选确认适配、等价类成员执行、独立物理场景身份和统计分母审计。实验范围限定为 A 网格（当前快速研究配置），不运行完整 Final，不使用 `final_reserved` 场景，不启动 Stage 4B。[代码静态核对]

MATLAB R2024a 已完成受控 calibration/Pilot 和完整历史回归。当前状态为 **Stage 4A.6.3.1-R Pilot 完成，完整 Final 保留未运行**；这不是现场验证，也不是完整 Final。[本次运行]

## 2. 研究协议

R 版入口使用新的 `stage4a6_3_1_r_protocol_config`，固定 A 网格、串行 worker=1，并将 calibration、pilot 和 `final_reserved` 使用不同主种子。`final_reserved` 只写入身份清单，不生成观测、不校准阈值、不参与评分。[代码静态核对]

场景生成器 `stage4a6_3_1_r_generate_independent_scenarios` 对真实参数向量进行分层扰动，公共函数 `stage4a6_3_1_r_materialize_scenario` 将参数实际送入正向 CFR 计算。实验入口在 materialize 阶段保存参数向量哈希、无噪声 CFR 哈希和 observation 哈希；标签只在离线评分表中生成。[代码静态核对]

R 版确认流程为：

```text
观测 CFR
→ 新建并校验的 Stage 4A.5.1 模板缓存
→ score_stage4a5_observation
→ apply_stage4a5_confirmation
→ 唯一拓扑 / 等价类 / 拒判
→ 对每个 accepted member 单独 profile
→ 保守聚合参数域证据
→ 离线评分与独立场景统计
```

适配器要求 calibration、cache 和 evaluation 使用相同 compatibility hash；不匹配时直接报错。参数 profile 入口还显式校验 parameter calibration model 的 compatibility hash。拒判样本不执行参数 profile，等价类成员数必须与实际执行成员数一致，否则参数状态为 `parameter_domain_indeterminate`。[代码静态核对]

## 3. 文献方法边界

本阶段实际可读取的原始 PDF 支持两类方法边界：

1. 先验约束路线：空间先验、节点清单、允许边和径向性用于缩小可行候选空间；当前代码只实现合成图语法和受限径向枚举，尚未接入真实 GIS、台账或开关状态。[论文明确陈述][代码静态核对]
2. 直接重构路线：PLC 多节点测距、全节点导纳、全节点电压或 FDR/ToF 等方法能够直接恢复路径、树或连接关系，但它们需要当前单端口复 CFR 模型不具备的观测。[论文明确陈述][模型内推断]

当前匹配器使用的是约束复残差、异类间隔、子带/邻域/块稳定性和拒判规则；它不是带噪声协方差模型下的最大似然或正式 profile likelihood。缺少明确的 (p(\hat H\mid G,\theta,\Sigma_N)) 时，代码和报告均使用 `profile residual` 或 `constrained residual profile`。[代码静态核对]

## 4. 复现缺口与处理

上一轮 Stage 4A.6.3.1 的若干 profile MAT、Pilot MAT、配置和源码在本地存在但未被 Git 跟踪。其用途、大小、SHA-256、是否可重建和处理建议见：

`report/stage4a6_3_1_r_reproducibility_audit.md`。[代码静态核对]

R 版不把这些历史 MAT 作为必要输入，而是通过已提交的配置、候选生成器、缓存构建器、场景生成器和独立入口重新生成小型 Pilot。大型历史 profile 目录不直接纳入本阶段提交范围；若要归档，应另行采用 Git LFS 或外部对象存储，并保存清单与哈希。[模型内推断]

## 5. 轻量检查与 MATLAB 状态

GNU Octave 先完成了轻量协议检查；MATLAB 启动修复后又完成了正式针对性测试和完整回归：

| 检查 | 结果 |
|---|---|
| 场景生成器协议测试 | 通过，35 个 pilot 场景；GNU Octave，不等同 MATLAB 验证 |
| 独立场景参数变化测试 | 通过，35 个 pilot 场景；GNU Octave，不等同 MATLAB 验证 |
| 等价类成员计数/不完整证据测试 | 通过；GNU Octave，不等同 MATLAB 验证 |
| R 版针对性测试 | MATLAB 通过，退出状态 0 |
| Stage 1.5～Stage 4A.6.3.1 完整回归 | MATLAB 通过，退出状态 0 |
| MATLAB 最小启动 | R2024a 正常输出版本，退出状态 0 |
| R 版独立 Pilot | MATLAB 通过，退出状态 0；14 calibration、35 Pilot |

启动修复采用可恢复备份隔离用户级 ServiceHost 和 MATLAB 偏好目录；项目文件和历史结果未被修改。启动验证日志为 `/tmp/matlab-startup-default-after-reset.log` 和 `/tmp/matlab-startup-launcher-after-reset.log`。[本次运行]

正式测试日志：

`results/logs/stage4a6_3_1_r/matlab_protocol_tests_final.log`、
`results/logs/stage4a6_3_1_r/full_regression_after_pilot.log`。[本次运行]

Pilot 日志：

`results/logs/stage4a6_3_1_r/matlab_independent_pilot_run_v5.log`。[本次运行]

## 6. 指标和独立统计单位

R 版指标函数保留 nominal row count、physical scenario 去重后的 effective denominator、duplicate observation count、topology set accuracy、strict unique accuracy、false-unique、OOD recall、OOD false acceptance、in-domain false alarm、indeterminate rate、coverage 和 selective risk，并为二项比例提供 Wilson 区间。重复 `physical_scenario_id` 不扩大统计分母。[代码静态核对]

本次 Pilot 产生 35 个独立物理场景，其中 26 个进入参数 profile，9 个因拓扑拒判未执行参数 profile。独立性审计中 calibration 14/14、Pilot 各类别 7/7 的参数哈希和 CFR 哈希均唯一，未发现重复物理场景或重复观测。[本次运行]

Pilot 拓扑决策计数为：`unique_topology=11`、`equivalence_class=15`、`reject_model_mismatch=1`、`reject_subband_mismatch=4`、`reject_low_stability=1`、`reject_neighborhood_mismatch=3`。[本次运行]

在分层指标中，库内 interior 的 topology-set accuracy 为 6/7，库内 boundary 为 7/7；参数域 near OOD 的 out-suspected 为 2/7，medium/far 本次均未形成可靠的确定性 out 结论。由于 Pilot 样本量小且部分样本被拒判或标记为 indeterminate，这些数字仅用于协议验证，不构成稳定性能结论。[本次运行]

## 7. 时间记录

| Phase | 预计时间 | 实际时间 | 状态/偏差 |
|---|---:|---:|---|
| 仓库与静态核对 | 5–10 min | 已完成，约数分钟 | 低于估计 |
| PDF 与证据核对 | 20–45 min | 已完成，约数十分钟 | 依据本地 PDF 可提取性变化 |
| R 版代码与报告 | 20–45 min | 已完成，约数十分钟 | 增加了源码树哈希和缓存身份修正 |
| 轻量协议检查 | 5–15 min | 秒级 Octave 检查 | 未替代 MATLAB |
| MATLAB targeted tests | 5–15 min | 约 12 s | 低于估计；退出状态 0 |
| 独立 Pilot（首次成功运行） | 5–20 min（小规模） | 约 131 s | cache 重建和 profile 完成 |
| 独立 Pilot（哈希字段修正后重跑） | 2–4 min | 约 66 s | cache 命中；低于估计 |
| 完整历史回归 | 3–10 min | 约 12 s | 低于估计；退出状态 0 |
| 完整 Final | 本阶段不计划 | 未运行 | 按协议禁止 |

## 8. 当前阻塞与下一入口

以下条件已通过：冻结确认器进入主流程、accepted equivalence members 全部执行、参数和 CFR 哈希独立性通过、compatibility hash 写入结果、拒绝和不可判定保留在分母、针对性测试和完整历史回归通过。[本次运行]

完整 Final 尚未运行，原因是本阶段只要求受控 Pilot；因此 Stage 4A.6.3.1-R 的协议闭环和 Pilot 证据已完成，但不能把它扩写为完整统计验证。下一入口是人工确认后再决定是否进行多拓扑、多 seed Final。[模型内推断]

## 9. 研究边界

当前结果仍属于受限径向候选库、合成参数、合成先验和模型生成的复 CFR。确认器接受候选不等于真实物理唯一性已经证明；参数 profile 收敛不等于参数全局可辨识；CFR 或 OFDM 可用不等于真实 PLC 拓扑识别性能已验证。本阶段不是现场配电网验证，也不是完整 Final；Stage 4B 未启动。[模型内推断]
