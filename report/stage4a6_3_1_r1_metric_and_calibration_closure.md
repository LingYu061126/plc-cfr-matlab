# Stage 4A.6.3.1-R.1：指标语义、校准身份与独立统计闭环

## 1. 阶段结论

本阶段完成了 Stage 4A.6.3.1-R Pilot 的局部协议修正，并使用相同规模的 14 个 calibration 场景和 35 个 Pilot 场景在 A 网格上重新运行。历史 R 结果保留在 `results/data/stage4a6_3_1_r/`，R.1 结果写入 `results/data/stage4a6_3_1_r1/`，没有覆盖历史目录。[本次运行]

R.1 修正了 false-unique、拓扑与参数选择性风险、profile 可靠性硬门控、拓扑/参数 calibration 身份分离以及 observation-level 独立统计。Pilot 通过 MATLAB 运行并完成了 35 个独立场景的离线评分；完整 Final 未运行，Stage 4B 未启动。[本次运行]

本阶段判定为 **Stage 4A.6.3.1-R.1 partial / blocked**：协议修正和小规模验证完成，但 Pilot 样本量小，且参数域确定性 coverage 较低，尚不足以形成稳定的参数域性能结论。[本次运行]

## 2. 运行范围与身份

| 项目 | R.1 设置 |
|---|---|
| 频率网格 | `A_stage4a1_quick61` |
| 候选拓扑 | 7 个 P0 候选 |
| calibration | 14 个场景 |
| Pilot | 35 个场景 |
| final_reserved | 仅保存身份清单，未生成 CFR、未评分 |
| MATLAB | R2024a (`24.1.0.2537033`) |
| worker | 1，串行 |
| compatibility hash | `55f691362f90dee8dc3a7d00b73fd6ec79b4ccfb93e52b785f580e0d83c1f0ae` |
| source-tree hash | `d607e3ed652a8590efa42d22f73214bd9b9cc6ac2c7f491d2f3d358a54dc2d6f` |
| topology calibration hash | `4d1e6054e8ed31b5fe6f8f21efd3fbac73e154450346d5a1af8cbe057a44b3fb` |
| parameter calibration hash | `ed371b94bcae331c1fe84abdc22c7ebda20749dc59d75964016e83209b03cbaf` |

这些哈希分别记录科学配置、源码依赖、拓扑确认校准和参数域校准身份；缺失或不匹配时适配器直接失败。[代码静态核对]

## 3. false-unique 的最终定义

R.1 不再把参数域外样本或“输出唯一拓扑”作为 false-unique 的替代定义。只有在以下条件同时满足时才计为 false-unique：

1. 评分阶段具有真实观测等价类标签；
2. 该等价类包含多个成员；
3. 确认器输出单一 `unique_topology`；
4. 输出没有覆盖真实等价类。

参数 OOD 与 false-unique 是不同事件。若真实拓扑在当前观测下唯一，即使参数越出候选域，也不计为 false-unique。若等价类标签缺失，则指标为不可评价，而不是把分母设为参数 OOD 样本数。[代码静态核对]

R.1 Pilot 中五个分层的 false-unique 均为 `0/7`，且每个分层均有 7 个可评价场景。旧 R 结果中的 near `2/7`、medium `3/7`、far `1/7` 是旧实现使用参数 OOD 代理计算的结果，不能与新定义下的 false-unique 直接作性能比较。[历史结果][本次运行]

## 4. 拓扑与参数选择性风险

R.1 分别输出以下指标，均保存分子、分母、比例、Wilson 95% 区间、可评价样本数和定义版本：

- `topology_acceptance_coverage`：输出唯一拓扑或等价类的样本数除以全部独立场景数；
- `topology_selective_risk`：已接受样本中输出集合不包含真实拓扑集合的比例；
- `parameter_decision_coverage`：输出 `parameter_in_domain` 或 `parameter_out_suspected` 的适用样本比例；
- `parameter_selective_risk`：已作出确定参数域判断的样本中，参数域判断错误的比例；
- `end_to_end_coverage`：同时接受拓扑并作出确定参数判断的样本比例；
- `end_to_end_selective_risk`：端到端确定输出中拓扑或参数域任一错误的比例。

R.1 Pilot 分层结果如下。分层每行包含 7 个独立场景，区间见 `pilot_metrics.csv`。

| 类别 | 拓扑接受 | 拓扑 selective risk | 参数确定性 coverage | 参数 OOD recall | 参数 OOD false acceptance | 参数 indeterminate |
|---|---:|---:|---:|---:|---:|---:|
| in-domain interior | 6/7 | 0/6 | 3/7 | 不适用 | 不适用 | 4/7 |
| in-domain boundary | 7/7 | 0/7 | 3/7 | 不适用 | 不适用 | 4/7 |
| out-of-domain near | 5/7 | 0/5 | 1/7 | 1/7 | 0/7 | 6/7 |
| out-of-domain medium | 4/7 | 0/4 | 0/7 | 0/7 | 0/7 | 7/7 |
| out-of-domain far | 4/7 | 0/4 | 0/7 | 0/7 | 0/7 | 7/7 |

这里的零 OOD false acceptance 不能单独解释为检测器性能优良，因为 medium/far 场景没有产生确定的参数域输出；其结果主要体现为 `indeterminate`。这也是本阶段不能进入完整 Final 的原因。[本次运行]

## 5. profile 可靠性硬门控

R.1 的类级参数状态遵循以下规则：

- 拓扑被拒绝：`parameter_not_evaluated`；
- 接受成员数与实际评估成员数不一致：`parameter_domain_indeterminate`；
- 任一接受成员缺少 profile 或 `profile_reliable=false`：`parameter_domain_indeterminate`；
- 成员结论冲突：`parameter_domain_indeterminate`；
- 只有所有必要成员可靠且类级证据一致时，才允许输出 `parameter_in_domain` 或 `parameter_out_suspected`。

样本 `r_pilot_G006_main_length_scale_near_upper_01` 的最终结果为：拓扑确认 `unique_topology`，接受/评估成员数为 `1/1`，成员 profile 为 `not_reliable`，类级参数状态为 `parameter_domain_indeterminate`。因此不可靠 profile 不再产生确定的参数库外结论。[本次运行]

## 6. calibration 身份与阈值

拓扑确认和参数域诊断使用不同校准身份：

- `topology_calibration_hash`：Stage 4A.5.1 拓扑确认规则和阈值；
- `parameter_calibration_hash`：参数 profile 阈值、可靠性规则和类级聚合；
- `compatibility_hash`：共享科学配置兼容性；
- `source_tree_hash`：影响本阶段结果的源码与配置依赖。

R.1 的拓扑阈值表记录 `status=calibrated`、14 个 calibration 样本和拓扑 hash；参数阈值表记录五个参数的 `status=calibrated`、17 个证据样本、13 个可靠样本以及参数 calibration hash。参数 profile 入口同时核对 compatibility hash 和 parameter calibration hash。[本次运行]

## 7. 独立统计单位

统计不再只依赖 `physical_scenario_id`。每个场景同时保存：

```text
physical_scenario_id
parameter_vector_hash
noiseless_cfr_hash
observation_hash
```

R.1 的 calibration 与 Pilot 交叉审计显示四类 hash 均无重复。`final_reserved` 只保存身份，未生成 CFR，因此 calibration/final_reserved 和 pilot/final_reserved 的 CFR 重复被明确标记为 `not_evaluated_final_reserved`，而不是写成零。[本次运行]

## 8. R 与 R.1 对照

| 指标 | R 历史结果 | R.1 修正结果 | 变化性质 |
|---|---:|---:|---|
| topology-set accuracy | 各分层与 R.1 相同：interior 6/7、boundary 7/7、near 5/7、medium 4/7、far 4/7 | 同左 | 不是算法性能变化；确认路径相同 |
| strict unique accuracy | 旧 R 表中为 interior 2/7、boundary 3/7、near 2/7、medium 3/7、far 1/7 | 新定义下由 `pilot_metrics.csv` 给出 | 指标输出结构修正 |
| topology acceptance coverage | 旧 `coverage` 与参数判断耦合，不能直接解释为拓扑 coverage | interior 6/7、boundary 7/7、near 5/7、medium 4/7、far 4/7 | 定义修正 |
| false-unique | near 2/7、medium 3/7、far 1/7 | 各分层 0/7，均可评价 | 旧定义错误，非算法改善 |
| parameter decision coverage | 旧 R 未独立定义 | interior 3/7、boundary 3/7、near 1/7、medium 0/7、far 0/7 | 新增独立指标 |
| parameter selective risk | 旧 R 未独立定义 | 当前确定性参数判断样本中未观察到错误，但 medium/far 无确定性输出 | 新增独立指标 |
| parameter indeterminate rate | 旧 R 有混合 `indeterminate_rate` | interior 4/7、boundary 4/7、near 6/7、medium 7/7、far 7/7 | profile 硬门控后重新定义 |

旧 R 与 R.1 使用相同规模的 Pilot 设计，但 R.1 的主要变化是评分语义和可靠性门控，不应把数值差异宣传为识别算法改进。[历史结果][本次运行]

## 9. 测试与运行证据

已运行：

```text
/home/chidan/.local/bin/matlab -batch "addpath('src');addpath('config');addpath('experiments');addpath('tests'); root=pwd(); r=test_stage4a6_3_1_r1_metrics_and_identity(root); disp(r); q=test_stage4a6_3_1_r_protocol(root); disp(q);"
/home/chidan/.local/bin/matlab -batch "diary('results/logs/stage4a6_3_1_r1/pilot_run_final.log'); t=tic; out=run_stage4a6_3_1_r1_metric_calibration_closure(); fprintf('R1_RUNTIME_S=%.6f\\n',toc(t)); disp(out.metrics); diary off;"
```

定向测试退出状态为 0，R.1 Pilot 退出状态为 0，Pilot 计算耗时约 70.7 s。随后使用隔离 MATLAB 偏好目录重新运行完整历史回归，退出状态为 0，测试耗时约 7.4 s；日志为 `results/logs/stage4a6_3_1_r1/full_regression_final2.log`。[本次运行]

本阶段未进行 1/4 worker benchmark。样本量小、当前串行运行已在约 70.7 s 完成，且已有历史证据显示小任务并行可能增加启动和数据复制成本；扩大样本前仍应重新 benchmark。[本次运行][模型内推断]

## 10. 未完成项与边界

1. 35 场景 Pilot 不足以给出稳定性能结论；
2. medium/far 参数库外场景在当前配置下主要输出不可判定，不能据此声称已实现可靠 OOD 拒绝；
3. 完整独立 Final 尚未运行；
4. 结果仍基于受限径向候选库、合成先验和模型生成的无噪声复 CFR；
5. 确认器接受候选不等于物理唯一性已证明；
6. 参数 profile 收敛不等于参数全局可辨识；
7. 当前方法不构成真实配电网或真实 PLC 收发机验证；
8. Stage 4B 未启动。

下一步如需继续，应先在人工确认后运行更大规模、身份兼容的 calibration/final 验证，并保持本报告中的指标定义和独立统计单位不变。[待验证]
