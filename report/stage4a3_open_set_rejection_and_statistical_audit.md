# Stage 4A.3：观测驱动的开放集拒判与统计覆盖审计

## [代码静态核对]

开放集匹配器 `match_composite_topology_library_open_set.m` 的函数签名仅接收观测 CFR、候选库、参数网格、物理配置和冻结阈值。它不接收覆盖状态、真值图、真值参数、真值等价类或先验情景名称。非空候选库始终完成模板距离搜索，并由最佳类残差、异类次优距离和间隔输出 `reject_model_mismatch`、`equivalence_class` 或 `unique_topology`；只有候选集为空才输出 `reject_no_feasible_candidate`。

实验将匹配输出写入 `stage4a3_match_decisions.csv`，将真值和覆盖标签单独写入 `stage4a3_scoring_labels.csv`，只在离线统计时关联。合成先验均标注为 `synthetic_demo_prior_not_field_data`。

## [本次运行]

本次成功运行使用 MATLAB R2024a（24.1.0.2537033），运行入口为：

```matlab
addpath('src'); addpath('config'); addpath('experiments');
out = run_stage4a3_open_set_audit();
```

退出状态为 0，总运行时间为 561.183913 s。固定校准种子为 `20261001`，测试种子为 `20261002`；每个 P0 图使用 1 个校准样本和 1 个测试样本，测试池另含 1 个结构库外样本和 1 个参数库外样本。该样本规模是为控制完整 1793 点频率网格的运行时间而采用的最小固定演示配置，比例指标的统计精度有限，不构成现场统计结论。

两个频率网格和候选规模如下：

| 网格 | 频点数 | 来源 | P0 图数/复合模板数 | P1/P2 图数/复合模板数 |
|---|---:|---|---:|---:|
| `A_stage4a1_quick61` | 61 | Stage 4A.1 快速网格 | 7 / 1701 | 4 / 972 |
| `B_ofdm_active_subcarriers` | 1793 | `default_config.ofdm.active_frequency_hz` | 7 / 1701 | 4 / 972 |

B 网格由当前 MATLAB 配置导出，记录为 `NFFT=4096`、`Fs=64 MHz`、有效子载波数 1793、频带 2–30 MHz；这些数值仅属于当前仿真配置。匹配采用分批流式模板计算，未在内存中建立全部 CFR 模板库。

校准得到的模型内阈值为：

| 网格 | 残差阈值 | 类间隔阈值 | 校准样本数 |
|---|---:|---:|---:|
| A | 0.2671302279 | 0.0064297191 | 7 |
| B | 0.2684048712 | 0.0065976736 | 7 |

P0/P1/P2 的测试候选数分别为 7、4、4。P0 的 7 个图均覆盖；P1 和 P2 均覆盖 4/7 个图，覆盖率为 4/7。该覆盖下降由硬先验过滤造成，不能解释为识别能力提升。

在库内连续参数测试中，A/B 网格的等价类准确率均为 1；P0 的严格图准确率分别为 5/7 和 4/7，P1 分别为 4/4 和 4/4，P2 分别为 4/4 和 3/4。P0 的库内拒判率为 1/7（两网格相同），P1/P2 为 1/4。库外单样本审计显示，参数库外样本两网格均拒判，结构库外样本两网格均未被拒判，因此当前配置下结构开放集拒判尚不足，不能宣称开放集可靠识别。

当前观测等价类审计仍识别出 `{G002,G005}` 和 `{G004,G007}`；它们表示在冻结的对称 SISO 观测、端接、频率网格和 `tie_tolerance=1e-10` 下的观测等价，不是图同构证明，也不是现场线路必然相同。

结果文件包括 `stage4a3_trial_bank.csv`、`stage4a3_match_decisions.csv`、`stage4a3_scoring_labels.csv`、`stage4a3_thresholds.csv`、`stage4a3_metrics.csv`、`stage4a3_frequency_grid_manifest.csv`、`stage4a3_equivalence_audit.csv`、`stage4a3_results.mat`；成功运行日志为 `results/logs/stage4a3_full_run_fixed2.log`，新增测试日志为 `results/logs/stage4a3_unit_test_fixed.log`。

## [模型内推断]

校准样本只来自候选库内七个 P0 图，连续参数从当前搜索范围抽取且避免离散网格点；结构库外和参数库外样本不参与阈值校准。两个频率网格分别由 Stage 4A.1 快速 61 点配置和当前 OFDM 有效子载波配置导出。`{G002,G005}` 与 `{G004,G007}` 仍是当前对称 SISO 条件下应报告的观测等价类。

## [待验证]

结果只能支持当前受限径向候选语法、完整树正向模型、端接和频率网格下的模型内审计；不代表真实 GIS/台账先验、现场拓扑恢复、真实 PLC 收发机、FDR/TFDR、绝对 ToF、全节点导纳/TLS、机器学习或 Stage 3B 资源优化。
