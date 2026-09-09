# Stage 4A.7.2-R.2.1.1 静态问题确认表

## 范围

本表记录在新一轮独立验证前对 Stage 4A.7.2-R.2.1 代码和结果的静态核对。旧结果目录保持只读；本阶段输出使用 `stage4a7_2_r2_1_1` 前缀。

| 问题 | 是否确认存在 | 证据文件与逻辑 | 影响 | 修正方案 | 对应测试 |
|---|---|---|---|---|---|
| SHA256 在 `-nojvm` 运行时不稳定 | 是 | `src/stage4a7_2_r2_sha256_file.m` 原先先调用 Java `MessageDigest`；历史 `formal_nojvm.log` 显示 Java 不可用 | 外部资料身份无法稳定核验 | 统一使用 `/usr/bin/sha256sum`，增加空文件、`abc` 和派生 CSV 已知向量测试 | `test_stage4a7_2_r2_1_1_static_integrity` |
| `incorrect_required_edge` 会把真实边标为 required | 是 | `src/stage4a7_2_r2_1_build_benchmark_ledger.m` 原逻辑直接修改 `ledger(1)` | 台账错误审计被真值边污染 | 只从受控 ambiguity edge 生成和选择错误 required 边，并记录是否误触及 reference edge | 同上 |
| 等价审计的 pair 结果被端点广播覆盖 | 是 | `src/stage4a7_2_r2_1_full_equivalence_audit.m` 原逻辑按候选端点回写最近 pair | 候选级投影中的距离和模板索引可能不属于该候选的最近 pair | 引入唯一 `pair_key`，分离 pair 表、cross-pair 表和 candidate projection，并硬校验连接 | `test_stage4a7_2_r2_1_1_static_integrity` 与本次 equivalence audit |
| cross-theta 作用域表述不够精确 | 是 | 历史 summary 混合 pair/候选行，容易被理解为全部候选对已做 profile | 读者可能高估 profile 等价覆盖 | 新表显式写 `nearest_same_theta_pairs_only`，并记录唯一 pair 数 | equivalence audit summary |
| 方法选择只有确定性词典序，没有统计并列检验 | 是 | `src/stage4a7_2_r2_calibrated_method_selection.m` 原逻辑只比较 development 汇总 | 小样本差异可能被误称为科学唯一优胜 | 增加固定 seed 的 paired bootstrap CI，分开 deterministic、statistical 和 scientific uniqueness | `test_stage4a7_2_r2_1_1_static_integrity` |
| R2.1 formal 与新阶段输出身份未隔离 | 是 | 原入口固定写入 `results/data/stage4a7_2_r2_1/<mode>` | 新修复可能覆盖旧证据 | 新入口传入独立 output root，并重新构建 formal cache/model | smoke/formal 输出审计 |
| paired 场景缺少同 nuisance/同噪声对照 | 是 | R2.1 场景按类别单独生成 theta | 类别间差异混入 nuisance 和噪声变化 | 新增 candidate×replicate 配对，固定 nuisance 与归一化噪声，仅改变目标参数 | paired balance/independence audit |
| 参数成员级域判定闭环 | 部分未完成 | 历史 R2.1 仍主要输出 topology-set/profile-distance 结果，没有新的成员级 parameter-domain decision 表 | 不能把本轮 topology-set 指标解释为参数域风险 | 明确列为未完成项，不伪造参数域结论 | 阶段报告 remaining work |
| 真实非唯一场景 | 未解决 | 87 候选全对 same-theta audit 在 `1e-10` 数值阈值下未发现等价对 | false-unique 仍不可评价 | 保留 `not_evaluable`，不把最近竞争候选冒充真实等价类 | 阶段报告 remaining work |

## 解释边界

以上修正只改变摘要身份、错误路径、等价审计连接和执行设计，不改变稳定传输线正向模型的物理定义。新的 paired 结果仍是模型生成的复 CFR 加频域等效复高斯噪声，不是现场 PLC 测量。
