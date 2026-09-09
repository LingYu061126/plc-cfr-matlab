# Stage 4A.7.2-R.2.1.2：统计判定与结果归档收尾

## 范围与结论

本阶段对 Stage 4A.7.2-R.2.1.1 的 `final_source_v3` 结果作只读、可追溯的统计再分析与归档。本阶段没有重新选择候选库、修改前向传输线模型、生成新 Final，或启动 Stage 4B。

**阶段状态：completed。** 完成在于统计判定语义和归档身份的收尾；这不表示某一候选确认方法已被证明为科学上的唯一优胜方法。

## 统计判定

候选集合方法继续按冻结流程执行：每个方法仅用 calibration split 建模，在独立 development split 上比较。候选集合覆盖、集合大小、单例正确率、空集率和选择性风险均保留为原始指标。每个 development row 属于一个候选拓扑，因此置信区间以 **candidate ID cluster** 而不是 row 为重采样单位。

[代码静态核对] `stage4a7_2_r2_1_2_cluster_bootstrap.m` 对候选 ID 重采样；`stage4a7_2_r2_calibrated_method_selection.m` 对所有通过 coverage gate 的竞争方法逐对比较，并要求所选方法相对**每一个**合格竞争方法都有预先定义的方向性证据，才可称为统计可区分。

方向性证据要求覆盖差的多重比较调整 bootstrap CI 下界至少为 0.005，且选择性风险不恶化。缺失比较、CI 重叠、并列或只胜出一个竞争者均不能产生科学唯一优胜者。程序仍可为可复现的下游执行保留 deterministic fallback，但该字段与 `scientifically_unique_winner` 分离。

[本次运行] 261 条 development 记录、87 个候选 cluster 的重分析选择 `margin` 作为 deterministic execution fallback；`statistically_distinguishable_winner=0`，`scientifically_unique_winner=0`。因此报告不得把 `margin` 写成经统计证明的唯一最优方法。

| 对比 | 指标 | 旧 row-bootstrap 95% CI | candidate-cluster 95% CI |
|---|---|---:|---:|
| margin − ratio | coverage | [0, 0.01149] | [0, 0.01916] |
| margin − ratio | mean set size | [−0.14943, 0.01533] | [−0.18774, 0.04215] |
| margin − ratio | selective risk | [−0.01158, 0] | [−0.01923, 0] |

上表仅比较同一 development 输入上的两种不确定性汇总单位；它不是新的性能实验。候选 cluster CI 没有支持 coverage 或集合大小上的严格方向性优胜。

## 参数类别的历史语义

[代码静态核对] 历史 paired 数据中的 0.951 和 1.049 被冻结重命名为 `near_lower_boundary_in_domain` 和 `near_upper_boundary_in_domain`，均在严格域 [0.95, 1.05] 内。历史的 1.10、1.30、1.60 记录为单侧 upper OOD；它们不能用来声称双侧 OOD 性能。

相应机器可读表为 `results/data/stage4a7_2_r2_1_2/category_semantics.csv`。

## 归档与可复现身份

本阶段确认的 canonical 来源是：

```text
results/data/stage4a7_2_r2_1_1/final_source_v3/
```

`canonical_manifest.csv` 对 formal、paired 和 equivalence 目录逐文件记录相对路径、大小、SHA256、来源 source-tree hash 和 experiment hash。`source_result_status.csv` 明确把 R2、R2.1 和 v2 目录标记为只读历史，而把 `final_source_v3` 标记为 canonical reanalysis source。历史目录未重写。

[本次运行] 归档重分析入口 `run_stage4a7_2_r2_1_2_statistics_archive` 耗时 5.072 s；canonical paired 输入为 1,044 rows。来源 experiment hash 为 `36ab4a9a2ffceeeb1e7241d89cf281540d0e78acce35f27e068187e3fe0832c8`。

## 测试

[本次运行] `test_stage4a7_2_r2_1_2_statistics` 通过，覆盖 candidate-cluster 重采样元数据、阈值状态和“只胜出一名竞争者/缺失比较不能成为科学唯一优胜者”的失败路径。完整 `tests/run_tests.m` 也通过。

## 限制

- 该重分析不改变历史候选库或历史物理观测；只修正统计解释。
- candidate cluster 是本实验的独立设计单位，不构成现场配电网总体的抽样框。
- 候选集合覆盖与单例输出均不等于物理拓扑唯一可辨识。
- Stage 4B 和完整 Final 均未启动。
