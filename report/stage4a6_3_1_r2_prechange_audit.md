# Stage 4A.6.3.1-R.2 修改前静态审计

| 问题 | 当前是否存在 | 代码证据 | 影响 | 修正方案 | 对应测试 | 是否影响历史 R.1 数值解释 |
|---|---|---|---|---|---|---|
| 配置清单在 calibration 前写出，双 calibration hash 为空 | 是 | `experiments/exp_stage4a6_3_1_r1_metric_calibration_closure.m` 中初始 `write_rows` | 机器可读身份不完整 | 校准完成后确定性写回，并与阈值、决策、成员证据核对 | 配置双 hash 非空与一致性测试 | 不改写 R.1 历史结果；R.1 身份缺口被记录 |
| false-unique 只有一个分母 | 是 | `src/stage4a6_3_1_r1_evaluate_metrics.m` | 无法区分全体可评价样本和真实非唯一子集 | 同时输出 unconditional/conditional 分母与区间 | 指标分母测试 | 改变指标语义，旧 R.1 false-unique 不作直接性能比较 |
| 真实等价性来自名义 cache class | 是 | `src/stage4a6_3_1_r1_build_truth_equivalence_labels.m` 使用 `current_equivalence_audit.core.class_index` | boundary/OOD 场景可能继承错误等价类 | 为每个场景计算 same-theta 与 composite 等价性 | 场景级等价性测试 | R.1 结果保留为名义等价审计 |
| calibration scoring 固定使用 Pilot seed | 是 | R.1 实验中的 `score_opts` 直接引用 `sc.seeds.pilot` | calibration/Pilot 内部随机身份混淆 | `score_opts` 显式接收 split/master seed | seed 隔离与顺序不变测试 | 不改变 R.1 文件 |
| source-tree hash 未覆盖 R.2 主实验、等价性和并行依赖 | 是 | `src/stage4a6_3_1_r_source_tree_hash.m` 的固定列表止于 R/R.1 | 科学实现变化可能不改变源码身份 | 扩展依赖清单并排除运行时字段 | hash 覆盖测试 | R.1 hash 作为历史身份保留 |
| 没有可关闭任务级并行入口 | 是 | R.1 配置固定 `use_parallel=false`，实验为串行循环 | 无法实测 worker 正确性和加速 | R.2 增加外层 batch 并行与串行 fallback | 串并行一致性测试 | 不改变 R.1 数值 |
| 配置/结果没有串并行一致性清单 | 是 | R.1 无 `parallel_correctness_audit.csv` | 无法审计 worker 数变化影响 | 比较 seed、hash、决策、状态和浮点量 | correctness audit 测试 | 不改变 R.1 数值 |
| 配置清单缺少并行版本、场景等价定义版本 | 是 | R.1 `configuration_manifest.csv` 字段有限 | 运行协议不可完整追溯 | R.2 增加版本和等价性字段 | manifest 字段测试 | 不改变 R.1 数值 |

本表是修改前代码静态核对，不把历史 R.1 文件重新解释为 R.2 结果。[代码静态核对]
