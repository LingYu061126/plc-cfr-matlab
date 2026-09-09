# Stage 4A.7.3：参数域拒绝与非唯一性验证

## 研究问题与冻结流程

本阶段检验：在冻结的候选拓扑确认器已经输出候选集合后，独立的 profile-distance 参数域分数能否识别主路径长度尺度超出
\([0.95,1.05]\) 的观测，并在已知观测等价控制中避免假唯一输出。

流程为：独立 development → 独立 calibration → 冻结参数域阈值 → 独立 Pilot。候选确认器、候选缓存和其 calibration 模型来自只读的 R2.1.1 `final_source_v3`；参数域模块只接受 profile-distance，未向候选确认、profile 距离或阈值函数传递真值拓扑、域标签或 OOD severity。

[代码静态核对] `exp_stage4a7_3_domain_rejection_and_nonunique_validation.m` 以每个候选自身的 243-template CFR cache 计算 profile distance，并把 topology set 与 `parameter_domain_status` 分开保存。`stage4a7_3_calibrate_domain_model.m` 仅使用 in-domain calibration score；`stage4a7_3_apply_domain_model.m` 输出 `in_parameter_domain`、`near_parameter_boundary` 或 `out_of_parameter_domain`。

## 设计与身份

| 项目 | 正式值 |
|---|---:|
| 冻结评分候选数 | 87 |
| frequency grid | A-grid，61 点 |
| development 场景 | 783 |
| 参数 calibration 场景 | 3,480（40/候选） |
| Pilot 场景 | 783（9 个类别 × 87） |
| Pilot 非唯一控制 | 120（40/噪声级） |
| 噪声 | 频域复高斯等效噪声，30 dB 与 10 dB；控制另含无噪声 |
| worker | 1；未启动并行池 |

正式域阈值选择 `profile_relative_distance`；calibration quantile 为 0.95，阈值 0.110340450651554，near-boundary 阈值 0.104446064804368，参数 calibration hash 为 `0829042b4eaa7f045282fbc9fe08c209fd5c7d2b1197539791792966f906954c`。development 中两个预注册分数均通过 in-domain gate，但没有科学唯一优胜者；`profile_relative_distance` 仅作为确定性 execution fallback。

## 域内、边界与双侧 OOD

严格边界点仍属于域内；near/medium/far OOD 在 lower 和 upper 两侧分别评价。下表的拒绝率是 `out_of_parameter_domain` 的比例；Wilson 区间按候选 ID cluster（87 个）计算。

| 类别 | 参数域拒绝 | 95% CI |
|---|---:|---:|
| 域内随机 | 7/87 = 8.0% | [2.3%, 13.8%] |
| 精确下边界 | 6/87 = 6.9% | [2.3%, 12.6%] |
| 精确上边界 | 6/87 = 6.9% | [2.3%, 12.6%] |
| near lower OOD | 11/87 = 12.6% | [6.9%, 20.7%] |
| near upper OOD | 19/87 = 21.8% | [13.8%, 31.0%] |
| medium lower OOD | 45/87 = 51.7% | [41.4%, 62.1%] |
| medium upper OOD | 43/87 = 49.4% | [39.1%, 59.8%] |
| far lower OOD | 68/87 = 78.2% | [70.1%, 86.2%] |
| far upper OOD | 79/87 = 90.8% | [83.9%, 96.6%] |

[本次运行] 域内接受率为 80/87（92.0%）；精确下、上边界的接受率均为 81/87（93.1%）。远离域边界的 OOD 更容易触发拒绝，而 near OOD 的拒绝覆盖不足。这是负面但可采用的结果：当前单一 profile-distance 阈值不支持“near OOD 已可靠拒绝”的结论。

候选 topology-set coverage 同时随参数失配降低，例如 in-domain 为 85/87，而 far lower / upper OOD 分别为 2/87 和 1/87。单例或低 residual 不能覆盖这种参数域失配；若真拓扑不在候选集合，单例输出只能视为高置信度错误风险，不能视为可靠确认。

## 数值非唯一控制与 false-unique

T3/T5 被用作正控制，但只在**源端与接收端阻抗匹配的同一参数点**下成立。对 81 个匹配端接模板，最大复 CFR 差为 \(8.47\times10^{-16}\)，相对差为 \(1.26\times10^{-15}\)，低于冻结数值容差 \(10^{-10}\)。这证明的是 parameter-specific SISO mirror control；它不主张 T3/T5 在独立端接阻抗全域的 profile 等价。

| SNR | false unique | 完整等价集合覆盖 | singleton |
|---|---:|---:|---:|
| 无噪声 | 0/40 | 40/40 | 0/40 |
| 30 dB | 0/40 | 40/40 | 0/40 |
| 10 dB | 1/40 = 2.5% [0%, 7.5%] | 39/40 | 1/40 |

[本次运行] 非唯一分母为 40，而非零；被拒绝或多候选的样本没有从该分母删除。结论是：在该严格且狭窄的数值对称正控制内，校准候选集合大多保留完整等价类；它不是对 ENWL 共享候选空间所有潜在非唯一性的全局证明。

## 运行、测试与数据

MATLAB R2024a（24.1.0.2537033）以 `-nodisplay -nosplash -nojvm -singleCompThread` 运行。正式入口 `run_stage4a7_3_domain_rejection_and_nonunique_validation(pwd,'formal')` 运行 360.683 s。Stage 4A.7.3 smoke 运行 110.162 s。未执行并行 benchmark：此前相同量级任务中多 worker 未改善 wall-clock 且提高内存/swap 风险。

[本次运行] `test_stage4a7_3_domain_nonunique`、`test_stage4a7_2_r2_1_2_statistics` 以及完整 `tests/run_tests.m` 均通过。结果目录为 `results/data/stage4a7_3/{smoke,formal}`；日志为 `results/logs/stage4a7_3/`。

候选对等价性的全量审计范围仍以 Stage 4A.7.2-R.2.1.1 的 nearest-competitor / pairwise evidence 文件为准；本阶段没有把“最近竞争者”扩写成所有候选对的全局 profile 等价证明。T3/T5 是单独的逐场景正控制，不能替代 87 候选库的全对全物理等价审计。

完整回归的最终修复后日志为 `results/logs/stage4a7_3/full_regression_postfix.log`；其中包含新增 R.2.1.2 与 4A.7.3 测试的逐项 PASS 记录，退出状态为 0。

## 研究边界

- 当前候选库、参数范围、观测端口、频率点和噪声均为模型内冻结设置。
- 噪声是频域等效复高斯噪声，不是完整真实 PLC OFDM 收发机或现场噪声。
- 参数 profile 收敛不等于参数全局物理可辨识；参数 OOD 拒绝不等于准确恢复真实参数。
- 结果不是现场配电网或真实 PLC 硬件验证；Stage 4B 与完整 Final 均未启动。
