# Stage 4A.3.1：开放集指标修正、模板缓存与重复统计验证

## 1. 阶段定位与问题定义

[代码静态核对]

本阶段在 Stage 4A.1、Stage 4A.2 和 Stage 4A.3 的候选图、参数化复合库、观测等价类审计和开放集匹配接口之上，验证以下模型内问题：当真实图或参数不在当前复合候选库内时，匹配器是否可以只依据观测 CFR、最佳残差、异类次优残差和类间隔进行拒判。候选图均属于当前完整树正向模型可表示的低复杂度径向结构；合成先验统一标记为 `synthetic_demo_prior_not_field_data`。

本阶段不把匹配结果解释为真实配电网拓扑恢复能力，也不扩大 Stage 3B 的研究边界。研究链条仍为：

```text
资产/工程先验
→ 可行图集合
→ 量测约束筛选
→ 图—参数复合库
→ CFR 匹配与唯一/等价类/拒判输出
```

当前实现仍不包含真实 GIS、资产台账、现场测量、真实 PLC 收发机、FDR/TFDR、绝对 ToF、全节点导纳/TLS、机器学习分类器或 OFDM 资源优化。

## 2. 匹配决策与真值评分分离

[代码静态核对]

`match_cached_composite_library_open_set` 的输入只有观测视图、候选模板缓存和冻结阈值选项。函数接口及其调用链不接受 `coverage_status`、真实拓扑 ID、真实参数或情景标签；`stage4a3_1_match_decisions.csv` 也不保存这些离线评分字段。真值只在匹配完成后由独立的 `build_stage4a3_1_truth_equivalence_labels` 和 `evaluate_stage4a3_1_metrics` 使用。

非空候选库会对全部缓存模板完成距离计算，并形成：

\[
d_1=\min_{c}d(\hat H,H_c),\qquad
d_2=\min_{c\notin C_1}d(\hat H,H_c),\qquad
\Delta=d_2-d_1.
\]

其中 \(C_1\) 是最佳观测等价类。最终输出集合是 `accepted_topology_set`，而不是内部最近模板的标签。

决策顺序为：

1. 候选集为空：`reject_no_feasible_candidate`；
2. \(d_1\) 超过冻结残差阈值：`reject_model_mismatch`；
3. \(\Delta\) 小于冻结间隔阈值：`reject_low_margin`；
4. 最佳当前类为多成员：`equivalence_class`；
5. 当前类为单成员、但 P0 基线类为多成员：`unique_given_prior`；
6. 其余情况：`unique_topology`。

因此，内部最近图命中可以在最终拒判时仍为真，但只能计入 `nearest_topology_hit_rate` 或 `nearest_class_hit_rate` 诊断指标，不能计入严格识别准确率。

## 3. 等价类定义与先验条件

[本次运行]

在两个频率网格上，P0 完整候选集均为 7 个图，冻结容差为 `1e-10`。基线观测等价类一致为：

```text
{G001}, {G002,G005}, {G003}, {G004,G007}, {G006}
```

这表示在当前对称 SISO 观测、端接、频带、正向模型和数值容差下的模型观测不可区分；它不是图同构结论，也不是实际线路必然相同的结论。

P1 条件候选集为 4 个图，条件类为：

```text
{G001}, {G003}, {G005}, {G007}
```

P1 将两个基线二元等价类各压缩为单成员，因此产生 `unique_given_prior`。这种输出表示“先验条件下的单成员”，不表示仅由 CFR 完成了物理唯一识别。

P2 条件候选集为 4 个图，条件类为：

```text
{G001}, {G002,G005}, {G006}
```

其中一个二元类仍保留；另有库内真值被陈旧硬先验排除。所有等价类均通过 `stage4a3_1_equivalence_audit.csv` 保存。

## 4. 校准—测试设计

[本次运行]

正式配置使用两个相互独立的随机种子：校准种子 `20261101`，测试种子 `20261102`。每个 P0 图有 8 个校准样本和 12 个库内连续参数测试样本，分别得到 56 个校准样本和 84 个库内测试样本；此外有 20 个结构库外样本和 20 个参数库外样本。测试总量为 124 个样本，三个先验情景和两个频率网格共完成 744 次测试匹配。校准 ID 与测试 ID 不重叠，两个频率网格和 P0/P1/P2 共用同一测试真值样本池。

库内参数在当前 Stage 2.3 搜索范围内连续抽取，并避开离散网格点。样本覆盖主线长度比例、支路长度比例、支路负载比例、源阻抗和接收阻抗五个维度。结构库外样本为合法径向树，具有至少 3 个不同的规范键；参数库外样本共 20 个，覆盖单参数越界和多参数联合越界。所有库外样本均保持有限且可由当前物理正向模型计算。

残差阈值和间隔阈值分别对每个频率网格独立校准，但 P0/P1/P2 共用对应网格的 P0 校准阈值。阈值只使用 P0 校准集：残差采用经验 95% 分位数乘安全系数 1.10；间隔采用“基线等价类为单成员且最佳类命中真值”的校准样本间隔 5% 分位数。该阈值的语义是 `model-internal calibration threshold`，不是现场置信度阈值。

| 频率网格 | 频点数 | 残差阈值 | 间隔阈值 | 残差校准数 | 有效间隔校准数 |
|---|---:|---:|---:|---:|---:|
| A_stage4a1_quick61 | 61 | 0.1925762602 | 0.0063014973 | 56 | 23 |
| B_ofdm_active_subcarriers | 1793 | 0.1959301164 | 0.0061276652 | 56 | 23 |

## 5. 模板缓存与频率网格

[代码静态核对]

`build_stage4a3_1_template_cache` 针对“频率网格 × 先验情景”只构建一次图—参数复合模板及其无噪声复 CFR。缓存保存模板 ID、拓扑 ID、参数索引、等价类、复 CFR、频率网格 ID、情景配置哈希和缓存不含真值标签的标志。匹配阶段只对测试观测与缓存矩阵计算距离；处理完每个情景后释放缓存。

正式参数网格为 243 个模板。P0 的复合模板数为 \(7\times243=1701\)，P1/P2 的复合模板数均为 \(4\times243=972\)。正式缓存和匹配运行记录如下；时间为本次运行记录，缓存文件大小受 MATLAB MAT 存储方式影响。

| 网格 | 情景 | 图数 | 复合模板数 | 缓存构建/s | 测试匹配/s | 缓存文件/MB |
|---|---|---:|---:|---:|---:|---:|
| A | P0 | 7 | 1701 | 4.27 | 2.96 | 16.54 |
| A | P1 | 4 | 972 | 1.76 | 1.78 | 9.48 |
| A | P2 | 4 | 972 | 1.65 | 1.77 | 9.49 |
| B | P0 | 7 | 1701 | 15.44 | 17.34 | 53.68 |
| B | P1 | 4 | 972 | 7.54 | 9.87 | 29.75 |
| B | P2 | 4 | 972 | 8.33 | 10.45 | 28.44 |

A 网格来自 `stage4a1_config.frequency_hz`，为 2–30 MHz 的 61 点快速审计网格。B 网格直接读取 `default_config.ofdm.active_frequency_hz`，包含当前配置的 4096 点 FFT、64 MHz 采样率、1793 个有效子载波，频率间隔为 15.625 kHz。B 的频率数组和有效 bin 索引以完整字符串和 MAT 配置结构保存，代码没有手写 OFDM 频点列表。这里的 NFFT、采样率、频带和有效子载波数量仅是当前仿真配置，不是已核实的真实 PLC 设备参数。

## 6. 指标定义

[代码静态核对]

对每个“先验情景 × 频率网格 × 样本类别”分别统计：

* `truth_coverage_rate`：离线判断真值图和参数是否被当前库覆盖；
* `unique_accuracy_given_covered`：覆盖样本中，最终接受为唯一图且图正确的比例；
* `set_accuracy_given_covered`：覆盖样本中，最终接受集合包含真值图的比例；
* `nearest_topology_hit_rate`、`nearest_class_hit_rate`：内部最佳图/类命中诊断；
* `in_library_reject_rate`：覆盖样本的最终拒判比例；
* `false_unique_rate_given_nonunique`：P0 冻结真值类为多成员且最终决策为 `unique_topology` 的比例；
* `unique_given_prior_rate`、`unique_given_prior_accuracy`：依赖先验条件消歧的比例及其中图正确比例；
* `structure_out_false_accept_rate`、`parameter_out_false_accept_rate`、`excluded_by_prior_false_accept_rate`：相应非覆盖或先验排除样本被最终接受的比例；
* `reject_model_mismatch_rate`、`reject_low_margin_rate`：两类观测驱动拒判比例；
* `mean_best_distance`、`mean_margin`：残差和异类类间隔均值。

比例字段同时保存分子、分母和 95% Wilson 区间；分母为零时保存 `NaN`。拒判样本不会进入严格唯一准确率或集合准确率分子。

## 7. 正式结果

[本次运行]

下表给出库内连续参数样本的主要指标。准确率和集合准确率均以覆盖样本为分母；P1/P2 的覆盖率为 48/84，P0 为 84/84。

| 情景/网格 | 候选图数 | 覆盖率 | 唯一准确率 | 集合准确率 | 最近图命中 | 库内拒判 | false-unique | 先验条件唯一率/其中正确率 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| P0/A | 7 | 1.000 | 0.321 | 0.833 | 0.750 | 0.167 | 0 | — |
| P0/B | 7 | 1.000 | 0.321 | 0.845 | 0.738 | 0.155 | 0 | — |
| P1/A | 4 | 0.571 | 0.833 | 0.833 | 1.000 | 0.167 | 0 | 0.714 / 0.400 |
| P1/B | 4 | 0.571 | 0.813 | 0.813 | 1.000 | 0.188 | 0 | 0.702 / 0.390 |
| P2/A | 4 | 0.571 | 0.375 | 0.875 | 0.833 | 0.125 | 0.500 | 0 / — |
| P2/B | 4 | 0.571 | 0.375 | 0.875 | 0.813 | 0.125 | 0.500 | 0 / — |

P1 的唯一接受率上升同时伴随覆盖率降至 48/84，且 `unique_given_prior` 输出中的图正确率仅约 0.40；这不能被解释为 CFR 单独实现了唯一拓扑识别。P2 的陈旧先验造成覆盖下降，并使基线非唯一真值出现 0.50 的 `false_unique_rate_given_nonunique`，说明错误硬先验会改变输出语义和风险。

库外与先验排除结果如下：

| 情景/网格 | 结构库外误接受 | 参数库外误接受 | 被先验排除真值的误接受 |
|---|---:|---:|---:|
| P0/A | 0.550 | 0.550 | — |
| P0/B | 0.550 | 0.550 | — |
| P1/A | 0.600 | 0.550 | 1.000 |
| P1/B | 0.750 | 0.550 | 1.000 |
| P2/A | 1.000 | 0.500 | 0.861 |
| P2/B | 0.950 | 0.450 | 0.861 |

结构库外样本中只有 45%（A、B）被 P0 拒判，说明当前残差—间隔阈值对合法但未入库的结构开放集仍不足；P1/P2 的缩库会进一步改变误接受率。参数库外样本在 A、B 的 P0 拒判率均为 0.45，其中 0.40 为残差拒判、0.05 为低间隔拒判。正式试验未出现空候选集，因此 `reject_no_feasible_candidate` 在本次结果中为零；该分支仍由单元测试覆盖。

两网格比较不能仅依据频点数量下结论。P0 下 B 的集合准确率为 0.845，高于 A 的 0.833，但唯一准确率相同；B 的结构库外和参数库外 P0 误接受率也均为 0.550。B 的计算和缓存开销明显更高，且 P1/P2 的接受与拒判变化并不一致。因此，本次配对实验只支持“有效频点网格改变残差和间隔统计”，不支持“频点更多必然改善开放集拒判”。

## 8. 失败样本与解释

[模型内推断]

当前最主要的失败是结构库外合法树被现有候选吸收：P0/A 和 P0/B 的误接受率均为 0.55。该现象表明有限候选库上的复 CFR 残差在部分库外结构上仍低于模型内阈值，当前匹配器不能据此宣称结构开放集可靠拒判。

第二类失败来自 P2 的陈旧硬先验。P2 的覆盖率只有 48/84，且被排除真值被其他候选接受的比例为 0.861；这反映的是先验覆盖不足带来的错误可行集，不是物理识别率提升。P1 也有 36/84 库内真值被当前硬先验排除，故其较高的条件唯一率必须和覆盖损失一起报告。

第三类现象是当前 SISO 条件下的 `{G002,G005}` 与 `{G004,G007}` 等价性。P0 的集合准确率明显高于唯一准确率，正是因为输出等价类比强行选择一个图更符合当前观测可辨识性。

## 9. 结果文件与可追溯性

[本次运行]

正式输出使用独立 `stage4a3_1_` 前缀：

```text
results/data/stage4a3_1_trial_bank.csv
results/data/stage4a3_1_match_decisions.csv
results/data/stage4a3_1_scoring_labels.csv
results/data/stage4a3_1_truth_equivalence_labels.csv
results/data/stage4a3_1_thresholds.csv
results/data/stage4a3_1_metrics.csv
results/data/stage4a3_1_runtime_and_cache.csv
results/data/stage4a3_1_frequency_grid_manifest.csv
results/data/stage4a3_1_equivalence_audit.csv
results/data/stage4a3_1_parameter_summary.csv
results/data/stage4a3_1_results.mat
results/data/stage4a3_1_cache/*.mat
results/logs/stage4a3_1_unit_test.log
results/logs/stage4a3_1_formal_run.log
results/logs/stage4a3_1_full_regression.log
results/logs/stage4a3_1_smoke_run.log
```

哈希由现有 SHA-256 实现扩展为完整规范化配置摘要，输入包括候选图语法、完整先验、参数网格、精确频率数组、NFFT、采样率、有效 bin、观测与端接、距离权重、容差、阈值方法、随机种子、样本设计和代码版本。正式结果中的哈希为 64 字符十六进制 SHA-256 摘要。MAT 和缓存文件按仓库现有规则不纳入普通 Git 跟踪，但仍保存在上述结果目录并由 MAT 配置结构保留精确数组和配置。

Stage 4A.3 的 `stage4a3_` CSV、MAT、日志和报告未被本阶段覆盖。全历史回归只新增了 `stage4a3_1_full_regression.log`；没有重写旧阶段结果。

## 10. 运行与验证记录

[本次运行]

MATLAB 版本为 `24.1.0.2537033 (R2024a)`，当前 Git HEAD 为 `cfcaeaf27f5db0b6a4cc1a72c22bef8b45f87f97`，分支为 `main`。以下命令均从仓库根目录执行并退出状态为 0：

```bash
/home/chidan/Matlab/bin/matlab -batch "cd('.../matlab_plc_cfr_publish'); addpath('src'); addpath('config'); addpath('experiments'); addpath('tests'); test_stage4a3_1_statistical_open_set_audit;"
/home/chidan/Matlab/bin/matlab -batch "cd('.../matlab_plc_cfr_publish'); addpath('src'); addpath('config'); addpath('experiments'); run_stage4a3_1_statistical_open_set_audit('smoke');"
/home/chidan/Matlab/bin/matlab -batch "cd('.../matlab_plc_cfr_publish'); addpath('src'); addpath('config'); addpath('experiments'); run_stage4a3_1_statistical_open_set_audit('formal');"
/home/chidan/Matlab/bin/matlab -batch "cd('.../matlab_plc_cfr_publish'); diary('results/logs/stage4a3_1_full_regression.log'); addpath('src'); addpath('config'); addpath('experiments'); addpath('tests'); run_tests; diary('off');"
```

单元测试、smoke、正式重复试验和 Stage 1.5 至 Stage 4A.3.1 全历史回归均通过。最新正式入口总耗时为 127.998 s；六个缓存情景的构建时间合计 39.005 s、测试匹配时间合计 44.173 s，细项见 `stage4a3_1_runtime_and_cache.csv`。Smoke 运行耗时约 48.8 s。正式样本设计和频点规模以本报告第 4 节为准。

## 11. 阶段判断与后续接口

[模型内推断]

Stage 4A.3.1 的基础设施和统计闭环已完成：匹配器不依赖真值标签；最终准确率、拒判和 nearest-hit 已分离；false-unique 使用冻结的 P0 真值等价类；`unique_topology` 与 `unique_given_prior` 已区分；校准与测试严格分离；每个 P0 图有重复样本；A/B 网格完成配对运行；缓存匹配和旧流式匹配的小规模一致性测试通过。

但是，结构库外误接受率仍较高，P2 显示陈旧先验会造成明显覆盖损失和错误接受。因此本阶段可以作为“指标、缓存和重复统计验证”交付，不能把当前拒判器当作已解决的开放集拓扑判定器，也不建议据此直接扩展为真实拓扑恢复结论。进入下一研究阶段前，应先由人工检查候选库覆盖边界、残差模型失配来源和先验排除风险；Stage 4B 仍未启动。

## 12. 适用条件与待验证事项

[待验证]

需要真实资产/工程资料验证的内容包括节点和边先验的来源可靠性、实际端接阻抗、参考面、测量节点、线路参数范围、负载时变和现场噪声。当前结果也没有验证真实 PLC 设备的有效频点、同步、耦合、功率和接收机误差。后续若开展现场或硬件工作，必须在隔离、耦合和保护条件下按实验室规范进行。

本报告支持的范围仅是：在给定受限径向候选语法、参数网格、观测端接、频率数组、完整树正向模型和冻结阈值下，对候选库内外样本进行可追溯的模型内匹配与统计审计。
