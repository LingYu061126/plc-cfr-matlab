# Stage 4A Report Freeze Gate

## 决定

**结论：PASS — Stage 4A frozen; proceed to formal report writing.**

该结论限定报告可作出的主张：Stage 4A 已提供受约束候选生成、校准候选集合、拒绝/歧义语义、参数域失配和数值非唯一控制的可追溯证据；它没有证明真实网络中的物理唯一拓扑恢复。

## Gate 审计

| 门槛 | 证据 | 状态 |
|---|---|---|
| 工程先验 → 受约束候选库 | Stage 4A.7.2-R.2.1.1 canonical v3 及其覆盖审计 | 通过（模型内） |
| 候选确认是校准集合而非单一最小距离 | Stage 4A.7.2-R.2.1.2 canonical manifest、cluster-bootstrap 再分析 | 通过 |
| deterministic 方法选择与科学唯一优胜分离 | Freeze-R.1 canonical Rule A 与 Rule B sensitivity，`scientifically_unique_winner=0` | 通过（负结论保留） |
| 近拒绝分数不冒充物理边界 | `borderline_domain_score` 与 `exact_lower/upper_boundary` 分离；Stage 4A.7.3 exact-boundary 实验 | 通过 |
| 双侧 OOD 与独立参数 calibration | Stage 4A.7.3，40 calibration/候选、lower/upper near/medium/far | 通过 |
| 非唯一样本有非零分母并数值核验 | T3/T5 matched-impedance 120-row control | 通过（仅正控制范围） |
| 不利结果保留 | near OOD 低拒绝覆盖、参数失配下 topology-set coverage 下降、10 dB 一例 false unique | 通过 |
| Freeze-R.1 全历史回归 | `results/logs/stage4a_freeze_r1/full_regression.log` | 通过，退出状态 0 |
| Stage 4B / 完整 Final | formal summary 的 `final_reserved_status=manifest_only_not_materialized`；`stage4b_started=0` | 未启动（符合边界） |

## 报告中应采用的结论

1. 候选生成应被表述为：从部署时可获得的工程先验产生受约束假设空间，再由 CFR 的校准候选集合筛选；候选库覆盖不是观测可辨识性。
2. 客观确认应被表述为：最小 profile residual 提供排序，校准集合、margin、稳定性和不可区分关系决定接受、歧义或拒绝；单例不是唯一性的单独证据。
3. 参数域模块可报告：远 OOD 的拒绝覆盖提高，而 near OOD 检出不足，因而当前协议必须保留参数域失配和不可判定/拒绝语义。
4. 非唯一性可报告：在 matched-end-impedance 的 T3/T5 数值正控制中，集合方法保留等价集合；不得外推为所有网络或所有端接条件的物理等价定理。

## 冻结后的范围

冻结后仅允许为正式报告做以下工作：复现已有命令、重新生成已冻结的表格/图、校验归档哈希、修复不改变科学定义的可复现性缺陷、整理文献与方法说明。不得重新挑选阈值、随机种子、候选库、参数范围或删改不利结果。

## 不应作出的主张

- 当前受限径向候选库不代表真实网络必被覆盖。
- 合成先验、模型生成无噪声/等效噪声 CFR 和接近 PLC 的通信参数，不是真实 PLC 现场验证。
- 低 residual、高 coverage、候选集合单例或 profile 收敛均不单独证明物理唯一性。
- 当前小规模模型内验证不能推广为完整 Final、现场配电网验证或 Stage 4B 的完成。

## 下一步

进入 Stage 4A 正式报告撰写与证据整合；Stage 4B 不启动。Windows 原生 MATLAB 尚未在当前环境实测，记录为 external reproduction pending，不阻止科学协议冻结。
