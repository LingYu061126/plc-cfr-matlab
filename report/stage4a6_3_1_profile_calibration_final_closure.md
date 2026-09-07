# Stage 4A.6.3.1 Profile Calibration/Final 收尾记录

## 1. 范围与证据边界

[本次运行] 本记录收尾的是此前已经生成的 Stage 4A.6.3.1 A 网格多案例 profile 证据，不包含后续电源模式对照重跑。分析对象为 12 个 calibration profile 文件、原 pilot 评价表中的 139 条拓扑确认记录，以及其中已经完成的 88 个 profile evaluation 文件。

[代码静态核对] 88 个 profile 文件内部字段仍标记为 `split=pilot`，因此本记录将其称为“profile evaluation pilot”，不将目录名 `profile_final_A` 解释为独立 Final split。此前的正式大规模 Final 未被本次汇总伪造或替换。

当前冻结身份为：

| 项目 | 值 |
| --- | --- |
| MATLAB | 24.1.0.2537033 (R2024a) |
| frequency grid | A_stage4a1_quick61 |
| frozen compatibility hash | `a6c12facc0071f4fc59858c331eb2300d3cdbab4674021ee777808a9a37d2194` |
| source tree hash | `59e8fe95438713dcd4b8735e350162b395f75e017b5b17d0fa3491cd85a87e1d` |
| calibration hash | `63628f4134c27404d0846c5f9baad3bfffb10acab8d63675ac36230f04763283` |
| physical profile recalculation | false |

## 2. Calibration 结果

[本次运行] 已有 profile calibration model 的 12 个输入文件均被读取且未被排除；5 个参数阈值均为 `calibrated`。原 calibration bank 共 14 条记录，但可用于该模型的已完成 profile 文件为 12 个；未将缺失记录复制为独立证据。

| 项目 | 数量 |
| --- | ---: |
| calibration profile files | 12 |
| reliable calibration evidence | 12 |
| excluded calibration profile files | 0 |
| calibrated parameter thresholds | 5 |

## 3. 多案例 profile 收尾

[本次运行] 88 个 profile 文件逐一通过以下核验：

* 88/88 的 sample ID 能在冻结拓扑决策表中找到，且 sample ID 唯一；
* 88/88 的 compatibility hash 与冻结 pilot 一致；
* 88/88 的 calibration hash 与 profile calibration model 一致；
* 0 个 `accepted_member_count` 与 `evaluated_member_count` 不一致；
* 88/88 的 profile 为 `profile_computed=true` 且 `profile_reliable=true`。

参数域状态为：

| 状态 | 数量 |
| --- | ---: |
| `parameter_in_domain` | 7 |
| `parameter_out_suspected` | 12 |
| `parameter_domain_indeterminate` | 69 |

[模型内推断] 不可判定样本占比较高，说明当前单端口 CFR、等价类成员聚合和 profile 证据还不足以支持对多数样本作确定的参数域结论。不可判定被保留为结果，没有从分母中删除。

## 4. 139 条评价记录的合并结果

[本次运行] 新汇总保留全部 139 条拓扑确认记录；只有 88 条有 profile 证据，剩余记录的参数状态保持 `parameter_not_evaluated`。因此拓扑层和参数层没有被混为一个接受率。

拓扑集合命中率按类别为：

| 类别 | 命中/分母 | 比例 |
| --- | ---: | ---: |
| in-domain interior | 6/7 | 0.8571 |
| out-of-domain near | 54/66 | 0.8182 |
| out-of-domain medium | 14/33 | 0.4242 |
| out-of-domain far | 14/33 | 0.4242 |

参数域指标（全部 139 条评价记录，未执行 profile 的记录计为不可判定）为：

| 类别 | OOD recall | OOD false acceptance | 不可判定率 | 参数决策 coverage |
| --- | ---: | ---: | ---: | ---: |
| out-of-domain near | 12/66 = 0.1818 | 1/66 = 0.0152 | 53/66 = 0.8030 | 13/66 = 0.1970 |
| out-of-domain medium | 0/33 = 0 | 0/33 = 0 | 33/33 = 1 | 0/33 = 0 |
| out-of-domain far | 0/33 = 0 | 0/33 = 0 | 33/33 = 1 | 0/33 = 0 |

[模型内推断] medium/far 的零误接受并不等价于成功检测，因为这些样本在当前合并结果中没有形成参数确定性输出；它们主要表现为 `indeterminate`。near 样本中只有 12 个形成域外怀疑，不能据此宣称参数域检测已成熟。

## 5. 结论与后续入口

[本次运行] 早期任务的“多案例 profile 执行、校准模型生成、既有 evaluation 证据合并”已经收尾，且未覆盖 Stage 4A.1～Stage 4A.6.3 的历史结果。

[模型内推断] 本阶段不满足“可直接进入完整独立 calibration/final 结论”的条件，原因是：

1. 现有 88 条 evaluation 文件内部仍属于 pilot split；
2. 参数 profile 的确定性状态仅为 19/88，69/88 为不可判定；
3. 139 条原 pilot 评价中仍有 51 条没有 profile 证据；
4. medium/far 的低误接受率由不可判定覆盖主导，不能解读为高检测率。

因此，完整 Final 应在单独冻结新的 final seed、独立 calibration/final 身份和足够 profile coverage 后再运行。电源模式对照日志和输出仅属于运行环境比较，不作为本记录的科学 calibration/final 证据。

## 6. 产物与复现命令

[本次运行] 新增汇总产物：

* `results/data/stage4a6_3_1/profile_closure_A/stage4a6_3_1_profile_closure_A_decisions.csv`
* `results/data/stage4a6_3_1/profile_closure_A/stage4a6_3_1_profile_closure_A_profile_summary.csv`
* `results/data/stage4a6_3_1/profile_closure_A/stage4a6_3_1_profile_closure_A_metrics.csv`
* `results/data/stage4a6_3_1/profile_closure_A/stage4a6_3_1_profile_closure_A_audit.csv`
* `results/data/stage4a6_3_1/profile_closure_A/stage4a6_3_1_profile_closure_A_results.mat`
* `results/logs/stage4a6_3_1/profile_closure_A_run.log`
* `results/logs/stage4a6_3_1/stage4a6_3_1_profile_closure_A.log`

复现入口：

```bash
env LD_LIBRARY_PATH=/home/chidan/.local/share/matlab-r2024a/compat/lib \
QT_QPA_PLATFORM=xcb /home/chidan/Matlab/bin/matlab -batch \
"cd('<repo-root>'); run_stage4a6_3_1_profile_closure; exit"
```

本次只运行离线汇总，没有运行 88 个 profile 的物理重算，也没有运行完整 Final 或 B 网格。

## 7. 研究边界

[待验证] 以上结果仍属于受限径向候选库、合成参数、合成先验和模型生成的复数 CFR。它不是现场配电网拓扑恢复、真实 PLC 收发机验证、完整 OFDM PHY 验证或 Stage 4B 结果。profile 收敛也不等于参数的全局物理可辨识；`parameter_out_suspected` 不等于准确定位真实越界参数。
