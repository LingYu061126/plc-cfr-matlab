# Stage 4A Report Freeze Gate

## 最终决定

**PASS — Stage 4A frozen; proceed to formal report writing.**

Freeze-R.1.1 在提交 `54868370cc6c426f417681146caace79de782e91` 的干净 detached worktree 中重新生成 canonical formal。该决定冻结 Stage 4A 的实验协议和证据归档，不表示真实 PLC 收发机、现场配电网或物理唯一拓扑已经验证。

## Gate 审计

| 门槛 | 证据 | 状态 |
|---|---|---|
| 工程先验到受约束候选库 | Stage 4A.7.2-R.2.1.1 canonical v3 与覆盖审计 | 通过（模型内） |
| 候选确认使用校准集合而非单一最小距离 | `results/data/stage4a_freeze_r1_1/r2_1_2/` | 通过 |
| Rule A 选择规则与代码、配置、报告一致 | formal `selection_rule_sensitivity.csv` 与独立重算 | 通过 |
| Rule B 标签和阈值与实际 `dmin` 一致 | formal sensitivity 9 类独立重算 | 通过，敏感性结果 |
| 科学唯一优胜与执行 fallback 分离 | `scientifically_unique_winner=false` | 通过（负结论保留） |
| 参数分数临界状态不冒充物理边界 | `borderline_domain_score` 与 exact boundary 分离 | 通过 |
| 双侧 OOD 与独立 parameter calibration | Stage 4A.7.3 formal，40 calibration/候选 | 通过 |
| 非唯一样本有非零分母并数值核验 | T3/T5 matched-end-impedance 120-row control | 通过（正控制范围） |
| formal 使用干净源码 | `freeze_summary_formal.csv`，`git_dirty_at_run=false` | 通过 |
| source inventory 可由 Git 重建 | 411 行，缺失/未跟踪/hash mismatch 均 0 | 通过 |
| canonical artifact 可核验 | 根 `canonical_manifest.csv`，44 个 artifact 全部存在且 hash 匹配 | 通过 |
| 定向测试、smoke、formal、完整回归 | `results/logs/stage4a_freeze_r1_1/` | 通过，退出状态 0 |
| final_reserved / Stage 4B | `manifest_only_not_materialized`、`stage4b_started=false` | 未启动（符合边界） |

## Canonical 位置和身份

```text
results/data/stage4a_freeze_r1_1/
results/data/stage4a_freeze_r1_1/stage4a7_3/formal/
results/data/stage4a_freeze_r1_1/canonical_manifest.csv
results/logs/stage4a_freeze_r1_1/formal_final.log
results/logs/stage4a_freeze_r1_1/full_regression_final.log
```

formal 的源码身份为：

```text
git_head_at_run      = 54868370cc6c426f417681146caace79de782e91
git_dirty_at_run     = false
source_tree_hash     = 5d45c12526dc205642d9cf9cb3e8be34605f529179904872fda52e75396dc353
configuration_hash   = 5b3c9a914e70cd1472a611ad784ca51d2af269f307ec4c3c53cc40c7f4d2931b
experiment_hash      = c2d0af7d0e3c27645cb195528b00ed9cf9844838d9e6eb543da1588eb888cc96
```

旧 Freeze-R.1 目录、旧 Stage 4A.7.3 formal、`formal_preselection_semantic_fix`、smoke 和历史 R2.1.1 输入均保留为历史证据；新的 canonical 目录不覆盖它们。

## 应写入正式报告的结论

1. 候选生成是从部署可获得的工程先验形成受约束假设空间，再由 CFR 的校准集合筛选；候选覆盖不是观测可辨识性。
2. Rule A 的 canonical 方法为 `profile_relative_distance`，Rule B 为敏感性对照 `profile_min_distance`；二者不构成科学唯一优胜声明。
3. formal 参数域结果为：in-domain acceptance `80/87`；exact lower/upper `81/87`、`81/87`；near lower/upper rejection `11/87`、`19/87`；medium lower/upper `45/87`、`43/87`；far lower/upper `68/87`、`79/87`。
4. T3/T5 正控制 false-unique 为无噪声 `0/40`、30 dB `0/40`、10 dB `1/40`；10 dB 结果必须保留。
5. near OOD 检出不足、模型内非唯一性和等效噪声边界是限制，不是可通过删改结果消除的缺陷。

## 不应作出的主张

- 受限候选库不代表真实网络必被覆盖。
- 模型生成 CFR 和频域等效噪声不是真实 PLC 现场测量。
- 低 residual、集合单例、候选 coverage 或 profile 收敛均不单独证明物理唯一性。
- 当前结果不是现场配电网验证，不是真实 PLC 收发机验证，也不是完整 Final。

## 复现状态和下一步

Linux MATLAB R2024a 的定向测试、smoke、formal 和完整回归已完成。Windows SHA256 分支、Git 路径和换行规则已实现，但 Windows 原生 MATLAB 尚未运行，状态为 `external reproduction pending`。下一步只进行 Stage 4A 正式报告撰写与证据整合；Stage 4B 不启动。
