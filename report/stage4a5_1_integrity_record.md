# Stage 4A.5.1 数据身份、缓存和结果完整性记录

## 1. 实验范围

[代码静态核对] 本记录针对 Stage 4A.5 的结构库外身份、覆盖标签、频率块重采样、候选缓存身份和图表语义进行独立修正。Stage 4A.5 原始代码、结果和日志保留不变；本记录对应的文件均使用 `stage4a5_1_` 前缀。

[模型边界] 结果来自受限径向候选语法、7 个合成候选图、每图 243 个参数模板、单发送端—单接收端复数 CFR 和完整树正向模型。P1/P2 合成先验、当前频率网格和端接配置均不是现场资料或真实 PLC 硬件证据。

## 2. 数据身份修正

[本次运行] 结构库外样本按 `canonical_key` 排序并映射到独立命名空间 `OOG001`、`OOG002`、`OOG003`。正式试验池中结构库外键数量为 3，拓扑 ID 与 P0 的 `G001`～`G007` 交集为 0，规范键交集为 0。

[本次运行] 覆盖标签拆分为：

```text
truth_graph_in_current_prior
truth_parameter_in_domain
truth_covered = 两者逻辑与
coverage_status
```

正式标签中结构库外样本全部为 `structure_out_of_library`、`truth_covered=false`；参数库外样本的图仍属于 P0 候选集，但 `truth_parameter_in_domain=false`，状态为 `parameter_out_of_domain`。身份判断不再依赖局部 `topology_id`。

## 3. 冻结重采样和缓存

[代码静态核对] 频率块掩码只由 `grid_id`、replicate 序号、bootstrap 序号和冻结基础种子生成，不读取 `sample_id`、类别、真实拓扑或参数。相同网格和 replicate 的样本共享同一组掩码。

[本次运行] 正式配置使用 30 次连续频率块重采样、4 个块、块比例 0.25。A/B 两网格均生成了 `stage4a5_1_resampling_manifest.csv` 对应的冻结设计。

[代码静态核对] 新缓存校验包括完整频率数组、候选 ID 和规范键、完整参数网格、模板数量、观测类型、源/接收端阻抗、距离特征与权重、缓存 schema、科学配置哈希和正向模型源码哈希。缺字段或任一内容变化都会拒绝旧缓存。

[本次运行] 正式缓存包含每网格 7 个候选图、243 个参数模板、1701 个复合模板。A 缓存约 17 MB，B 缓存约 52 MB；均通过 Stage 4A.5.1 身份校验。

## 4. 门槛结果

| 网格 | M3 库内集合准确率 | M0 结构库外误接收 | M3 结构库外误接收 | 8 个 seed 中 M3 改善数 |
|---|---:|---:|---:|---:|
| A：61 点 | 0.8795 | 0.5387 | 0.2103 | 8/8 |
| B：1793 点 | 0.8795 | 0.5764 | 0.1796 | 8/8 |

[本次运行] M3 相对 M0 的结构库外误接收下降在两个网格的全部 8 个独立 final seed 上保持。库内集合准确率均超过 0.80；ID、规范键、覆盖标签、缓存身份和图表语义测试均通过。

[本次运行] 参数库外误接收仍约为 A=0.4635、B=0.4566。该数值在本阶段不应直接解释为拓扑错误，因为参数库外样本的真实图仍在候选库内；它表示尚未建立独立的参数域外报警机制。

## 5. 图表与结果文件

[本次运行] 正式图表分别按 A/B 网格生成，包括 P0 M0～M3 库内集合准确率、结构库外误接收、M0 与 M3 的逐 seed FAR 差值、M3 参数维度漏报警图和准确率—库外误接收权衡图。`seed_paired_improvement` 的纵轴定义为 `FAR(M0)-FAR(M3)`；权衡图横轴为库内 micro set accuracy，纵轴为库外 false accept rate。

主要结果文件：

- [stage4a5_1_gate_summary.csv](../results/data/stage4a5_1_gate_summary.csv)
- [stage4a5_1_metrics.csv](../results/data/stage4a5_1_metrics.csv)
- [stage4a5_1_scoring_labels.csv](../results/data/stage4a5_1_scoring_labels.csv)
- [stage4a5_1_resampling_manifest.csv](../results/data/stage4a5_1_resampling_manifest.csv)
- [stage4a5_1_cache_manifest.csv](../results/data/stage4a5_1_cache_manifest.csv)
- [stage4a5_1_run.log](../results/logs/stage4a5_1_run.log)

## 6. 验证记录

[本次运行] MATLAB 版本为 R2024a `24.1.0.2537033`。smoke 入口为 `run_stage4a5_1_integrity_audit('smoke')`，退出码 0；正式入口为 `run_stage4a5_1_integrity_audit('formal')`，退出码 0，实验耗时约 1110.3 s。完整回归入口为 `run_tests`，退出码 0。

[本次运行] Stage 4A.5.1 专项测试覆盖 OOL ID/规范键、标签语义、共同掩码可复现、缓存频率数组失配拒用；完整回归同时覆盖 Stage 1.5、Stage 2、Stage 2.1、Stage 2.2、Stage 2.3、Stage 3A、Stage 3B-pre、Stage 3B waveform baseline、Stage 4A.1～4A.5。

## 7. 门槛结论

[本次运行] Stage 4A.5.1 门槛通过，可以进入 Stage 4A.6。该结论仅说明数据身份、覆盖标签、缓存验证、重采样设计和结果语义满足本轮审计要求，不说明参数域外样本已经能够被可靠拒识，也不说明拓扑反演已完成现场验证。
