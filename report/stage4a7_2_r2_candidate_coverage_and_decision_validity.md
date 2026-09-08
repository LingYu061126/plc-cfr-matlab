# Stage 4A.7.2-R.2：候选覆盖与集合判定有效性修复

## 1. 阶段范围

本阶段审计并修正共享工程先验生成的候选空间、Top-K 截断覆盖、离散参数剖面距离、有限样本校准分辨率和候选集合方法选择。实验仍使用 A 网格（2–30 MHz、61 个频点）与当前稳定单端口复 CFR 正向模型。未运行完整 Final，未启动 Stage 4B，也未改变稳定正向模型的物理定义。

## 2. 证据边界

- `[代码静态核对]` 候选生成首先产生 131 个工程候选，再逐一通过正向模型兼容性检查。
- `[本次运行]` 53 个候选通过兼容性检查，R.2 将这 53 个候选全部纳入 profile 评分基线；不再把 Top-K 截断结果误写成完整评分库。
- `[本次运行]` 参考 ENWL 派生拓扑位于工程候选空间和正向兼容空间，按先验代价排序为第 1 名。
- `[本次运行]` 结果是模型内、受限候选库内的受控验证，不是现场 PLC 测量或真实配电网拓扑识别验证。

## 3. 数据来源、单位与溯源

实验使用本地缓存的 Electricity North West LVNS 公开模型压缩包、项目总结 PDF 和 Ofgem closedown report。原始大文件不写入 Git；结果仅保存逻辑相对路径、文件大小、SHA256、来源 URL 和解析状态。

选定子网为 `network_13 / Feeder_3`，源节点 32、接收节点 39，派生边来自 OpenDSS `Lines.txt` 的记录 32–38。原始记录明确使用 `Units=m`，因此派生 `length_m` 采用单位恒等换算；`LineCode.txt` 中的工频参数不被外推为 MHz 级 PLC RLGC。电缆编号到当前模型编号是受控建模映射，不是实测高频参数证据。

机器可读证据见 `results/data/stage4a7_2_r2/formal/external_data_manifest.csv`。该文件不包含本机绝对路径。

## 4. 候选空间与 Top-K

流程为：共享不确定工程台账 → 131 个工程可行树 → 53 个正向模型兼容候选 → 53 个全量 profile 评分基线；Top-K 仅作为覆盖审计，不用于强行插入真值。

Top-K 排序采用先验代价和规范图键的确定性顺序。实现中修正了并列代价的字典序判断，并冻结了 `1e-12` 相对数值 tie 容差。R.2 对 K=1、3、5、6、10、20、30、53 均比较了：候选键顺序、代价、tie-break、重复数和运行时间。Formal 结果中八个 K 的 `exact_first_k_match`、`ordered_key_match`、`cost_match`、`tie_break_match` 均为真，重复数均为 0。

K=53 时按需搜索运行时间约 0.091 s，完整枚举约 0.087 s；该规模下完整枚举已足够快，Top-K 不构成实际加速。该结论来自当前 131 候选实例，不能外推到更大候选空间。

## 5. Profile distance 与模板口径

每个候选独立使用 243 个冻结参数模板计算离散 profile distance：

\[
d_G(x)=\min_{\theta\in\Theta_G}D\left(x,H_G(\theta)\right).
\]

Formal 配置为：

```text
theta_grid_count = 243
templates_per_candidate = 243
candidate_count = 53
total_template_count = 12879
```

profile API 只接收观测和候选模板缓存，不接收生成样本的真实参数。缓存审计记录候选 ID、参数网格、频率网格、特征和缓存哈希。

## 6. 校准分辨率与方法选择

Smoke 使用每候选 5 个 calibration 样本，仅用于验证执行结构；其最小经验 p 值为 `1/6=0.1667`，大于 `alpha=0.05`，因此不能作为 alpha=0.05 的拒绝证据。

Formal 使用每候选 40 个 calibration 样本，共 2120 个样本，最小经验 p 值为：

\[
p_{\min}=\frac{1}{40+1}=0.0243902\le 0.05.
\]

五种方法 `absolute`、`scaled`、`ratio`、`margin` 和 `absolute_I` 在 development split 上覆盖率、集合大小、singleton 和 empty-set 指标均并列。系统输出 `scientifically_unique_winner=false`、`status=no_unique_winner`，仅为保证后续计算而采用确定性执行 fallback `absolute`。这不构成 absolute 的科学优胜结论。

## 7. Formal Pilot

Formal pilot 对 53 个评分候选各生成 2 个模型内样本，共 106 个场景。候选集合结果为：

| 指标 | 分子 | 分母 | 结果 |
|---|---:|---:|---:|
| truth-set coverage | 106 | 106 | 1.000 |
| singleton rate | 106 | 106 | 1.000 |
| empty-set rate | 0 | 106 | 0.000 |
| selective risk | 0 | 106 | 0.000 |

这些数值只说明当前候选自洽生成样本在当前模板和规则下的结果；样本由评分候选自身生成，不能解释为外部网络泛化性能。R.2 尚未加入独立结构库外或参数库外 Pilot，因此 OOD false acceptance、in-domain false alarm 和完整 false-unique 性能仍不可评价。

## 8. 非唯一与 false-unique

R.2 对 53 个兼容候选在冻结参数点上逐场景计算复 CFR，并以 `1e-10` 的复 CFR 均方根距离阈值审计 same-theta 等价。Formal 运行的 20 个场景中没有发现满足该阈值的候选对，故：

- 场景级等价审计状态为 `no_same_theta_equivalent_pair`；
- `false_unique` 的真实非唯一分母为 0；
- 不把该结果写成 false-unique=0% 的性能结论；
- 近对称边界没有可用候选对，暂不生成虚假的扰动转变边界。

这暴露出当前共享 ENWL 派生候选空间和 A 网格尚未提供可评价的真实非唯一样本。后续必须增加实际经 CFR 核验的 symmetry-preserving 场景，或明确使用受控小图进行独立的等价性实验。

## 9. 运行记录

MATLAB 版本为 `24.1.0.2537033 (R2024a)`。串行命令入口为：

```text
run_stage4a7_2_r2_candidate_coverage_validity('smoke')
run_stage4a7_2_r2_candidate_coverage_validity('formal')
```

Smoke 最终运行约 29.9 s；Formal 运行约 85.4 s。未启用 Parallel Computing Toolbox，也未进行 1/4/6 workers benchmark；本阶段重点是修复候选覆盖和统计语义，且当前规模下完整枚举与 Top-K 已接近同一数量级，强行并行会增加变量复制和复现风险。

## 10. 文件与复现

核心代码包括：

- `config/stage4a7_2_r2_candidate_coverage_config.m`
- `experiments/exp_stage4a7_2_r2_candidate_coverage_validity.m`
- `src/stage4a7_2_r2_exact_topk_audit.m`
- `src/stage4a7_2_r2_method_selection.m`
- `src/stage4a7_2_r2_scenario_equivalence.m`
- `src/stage4a7_2_r2_external_manifest.m`
- `src/stage4a7_2_r2_sha256_file.m`
- `src/stage4a7_2_r2_source_hash.m`
- `run_stage4a7_2_r2_candidate_coverage_validity.m`

结果分别位于 `results/data/stage4a7_2_r2/` 和其 `formal/` 子目录；旧 R.1 结果未覆盖。最终定向测试、烟雾实验、正式实验和完整回归日志分别为 `results/logs/stage4a7_2_r2_targeted_final.log`、`stage4a7_2_r2_smoke_after_cost_tie_fix.log`、`results/logs/stage4a7_2_r2_formal_final2.log` 和 `results/logs/stage4a7_2_r2_full_regression.log`。

## 11. 阶段判断

Stage 4A.7.2-R.2 当前判定为 **partial / blocked**，而不是完成。已完成的部分是：全兼容候选基线、参考拓扑覆盖审计、严格 Top-K 顺序核验、正式校准分辨率和方法并列语义。阻塞项是：当前共享候选空间未产生可由实际 CFR 核验的非唯一场景，且本轮未评价独立 OOD 样本，因而不能形成完整集合判定有效性结论。

当前结果只能说明：在给定候选空间、工程先验、参数模板、端口、频带、端接和模型下，候选生成及 profile 评分协议可以稳定执行并被审计。候选库覆盖真值不等于真实网络一定在库内；profile 最小距离不证明物理唯一性；无噪声 CFR 也不等于现场 PLC 测量。

Stage 4B 和完整 Final 均未启动。
