# Stage 4A.7.2-R.2.1.1 结果目录

本目录保存本阶段独立 smoke、formal、paired 和 equivalence 输出。旧的 `stage4a7_2_r2_1` 目录未被覆盖。

* `formal/`：87 个兼容评分候选、261 development、3480 calibration、174 pilot 的新 formal 运行。
* `paired/`：87 候选 × 6 类别 × 2 replicate 的 1044 条配对场景。
* `equivalence/`：3741 个无序 same-theta pair、62 个唯一最近 pair 的 cross-theta 审计及 candidate projection。
* `final_source/`：第一次最终源码身份确认后的 formal、equivalence 和 paired 输出，保留为历史证据。
* `final_source_v2/`：加入配对按候选指标和 transition bootstrap 输出后的最新最终源码身份结果；formal 实际路径为 `final_source_v2/formal/formal/`，paired 与 equivalence 分别位于同级目录。
* `final_source_v3/`：在 v2 基础上补充 `corruption_manifest.csv`、正式局部等价诊断范围字段及完整 pair/projection 硬断言后的最新源码身份结果；formal、paired 与 equivalence 分别位于同级目录。
* `smoke/`：协议 smoke 运行。

`final_source_v2/paired/` 额外包含：

* `paired_metrics_by_category.csv`；
* `paired_metrics_by_candidate.csv`；
* `paired_transition_metrics.csv`，包括 `in_domain` 到各边界/OOD 类别的配对差值和固定 seed bootstrap 区间。

最新 v2 身份为：`source_tree_hash=d4b8f2f2b470b5e72f89aabe8590f6d768851a7348d3ab7a481d62b0ce48b289`，formal `experiment_hash=3b9ed00d84a04030715fa8f9f9faaec8d752fd24d920e803e11545fd433dbd71`，paired `experiment_hash=e2e85a4953ce8601322d85d9190def7c5f511f7a823cf7fa81be5594f51fce97`。

最新 v3 身份为：`source_tree_hash=b9e51a09f4cc1cf8d560ee58ae23b966c32aecff139d1d48f5d306777bd58f3b`，formal `experiment_hash=36ab4a9a2ffceeeb1e7241d89cf281540d0e78acce35f27e068187e3fe0832c8`，paired `experiment_hash=4eac2d3feeab6fa87ca3f53bda52b299a42dcf9f654e09bfbdb91c0adfd6611e`。

v3 formal 运行包含 204 个工程候选、87 个正向兼容/评分候选、261 个 development、3480 个 calibration 和 174 个 Pilot 场景；配对验证为 87×6×2=1044 条记录。v3 的 `formal/corruption_manifest.csv` 显式记录各类受控台账扰动，`formal/nearest_competitor_audit.csv` 显式标注 `first_9_templates_diagnostic_only`，完整 3741-pair 审计仍以 `equivalence/` 下的独立表为准。

这些结果属于模型内验证。`final_reserved` 未物化，完整 Final 和 Stage 4B 未启动。Stage 4A.7.2-R.2.1.1 的实验设计与等价性审计已完成；后续参数域科学问题列于 [剩余工作](../../../report/stage4a7_2_r2_1_1_remaining_work.md)。
