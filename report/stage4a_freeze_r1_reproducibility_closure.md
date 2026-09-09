# Stage 4A Freeze-R.1：判定语义、证据身份与跨平台复现收尾

## 1. 阶段结论

Stage 4A Freeze-R.1 的目标是固定判定语义、补齐结果身份、建立独立 canonical 输出并验证跨平台文件摘要入口。Linux 串行 smoke、formal、定向测试和完整回归均已执行；Windows 原生 MATLAB 未在当前环境实测，记录为 `external reproduction pending`。在不改变稳定正向模型、候选库、参数范围、61 点频率网格、噪声等级和数据划分的前提下，Freeze Gate 可判定为：

**PASS — Stage 4A frozen; proceed to formal report writing.**

该结论只表示 Stage 4A 的实验协议和证据归档达到冻结条件，不表示真实 PLC 或现场网络已经验证。

## 2. canonical 判定规则

参数域方法选择采用 `domain_gate_then_ood_v1`：

1. 首先要求 development in-domain acceptance 不低于 0.90；
2. 在通过 gate 的方法中最小化 development medium/far OOD false acceptance；
3. 若仍并列，按预先规定的稳定方法顺序选择 deterministic execution fallback；
4. `scientifically_unique_winner=false`，执行 fallback 不被解释为科学唯一优胜。

该规则使用 development split，`pilot_used_for_selection=false`。formal canonical 选择为 `profile_relative_distance`；严格词典序敏感性规则 Rule B 选择 `profile_min_distance`。两种规则使用相同冻结观测进行对照，未重新生成 Pilot 噪声或调整阈值。

## 3. 参数域状态语义

机器可读状态统一为：

- `in_parameter_domain`：分数不超过 calibration threshold；
- `borderline_domain_score`：分数位于 near-rejection calibration 区间，但不表示物理参数位于参数域边界；
- `out_of_parameter_domain`：分数超过拒绝阈值；
- `undetermined`：分数非有限或证据不足。

`exact_lower_boundary` 和 `exact_upper_boundary` 是实验真值类别；`borderline_domain_score` 是算法分数状态。两者不作物理等同解释。

## 4. 区间估计与噪声

Stage 4A.7.3 的区间方法为 `candidate-cluster percentile bootstrap`，不是 Wilson 区间。参数域 Pilot 每个 candidate×category 目前只有一个 replicate，因此 candidate cluster 与单行在当前设计下重合；接口保留 cluster 结构以支持未来重复 replicate。T3/T5 非唯一控制的重采样单位为 `test_sample`，因为 40 行来自正控制场景，不代表 40 个独立拓扑。

百分位 Bootstrap 在 0/40 情形可能产生退化的 `[0,0]` 区间；该结果不应解释为现场或总体概率严格为零。

参数域 development/calibration/Pilot 使用 20 dB 频域等效圆对称复高斯噪声。T3/T5 非唯一控制分别使用无噪声、30 dB 和 10 dB 设置。上述噪声均不是完整 OFDM 波形级噪声，也不是实测 PLC 噪声。

## 5. 运行身份和 canonical 输出

formal 运行由 MATLAB R2024a（24.1.0.2537033）以串行、无并行池方式执行，运行时间约 370.17 s；smoke 约 105.78 s。formal 结果位于：

```text
results/data/stage4a_freeze_r1/stage4a7_3/formal/
```

根目录归档清单位于：

```text
results/data/stage4a_freeze_r1/canonical_manifest.csv
results/data/stage4a_freeze_r1/historical_artifact_status.csv
results/data/stage4a_freeze_r1/freeze_summary_formal.csv
```

正式运行记录了 `git_head_at_run`、分支、dirty 状态、`source_tree_hash`、`configuration_hash`、`experiment_hash`、`runtime_environment_hash`、MATLAB 版本、平台、架构、命令、UTC 起止时间、运行时间和 worker 配置。结果目录、日志和报告不进入 source-tree hash。旧 Stage 4A.7.3 formal、`formal_preselection_semantic_fix`、smoke 和旧 R2.1.2 目录仅作为历史证据保留。

formal 身份摘要：

| 字段 | 值 |
|---|---|
| `source_tree_hash` | `1d2a5ade681a6f79e6045da6f1441fc08d1b37261a7decfaf510b6b764a97576` |
| `configuration_hash` | `5b3c9a914e70cd1472a611ad784ca51d2af269f307ec4c3c53cc40c7f4d2931b` |
| `experiment_hash` | `c35f63e2bd2189bf1b30eb0943414e5cd037c2886918c7f413299bca79c67e5c` |
| `runtime_environment_hash` | `8313f3a14914316354fa22dbe4ec3d546eb572e0092c5305b62000dfdd90c16f` |
| `parameter_calibration_hash` | `0829042b4eaa7f045282fbc9fe08c209fd5c7d2b1197539791792966f906954c` |
| frozen candidate experiment hash | `36ab4a9a2ffceeeb1e7241d89cf281540d0e78acce35f27e068187e3fe0832c8` |

## 6. 主要结果

formal 使用 87 个冻结候选、783 个 development 场景、3,480 个 parameter calibration 场景、783 个 Pilot 场景和 120 个 T3/T5 非唯一控制样本。canonical 参数域结果为：in-domain acceptance 80/87；exact lower/upper boundary acceptance 均为 81/87；near lower/upper OOD rejection 分别为 11/87 和 19/87；medium lower/upper 分别为 45/87 和 43/87；far lower/upper 分别为 68/87 和 79/87。

T3/T5 控制的 false-unique 为无噪声 0/40、30 dB 0/40、10 dB 1/40；完整等价集合覆盖分别为 40/40、40/40、39/40。10 dB 的百分位 Bootstrap 区间为 `[0, 0.075]`，保留为有限噪声下的控制结果，不能推广为真实网络总体概率。

## 7. 跨平台摘要与换行

`stage4a7_2_r2_sha256_file` 优先使用 Java `MessageDigest`，在无 JVM 时使用平台可用的 POSIX `sha256sum` 或 Windows PowerShell `Get-FileHash`。接口按原始二进制字节计算，输出小写 64 位十六进制摘要，并对空文件和 `abc` 已知向量测试。测试还覆盖了包含空格、中文和括号的路径。当前环境为 Linux；Windows 分支已完成静态实现和命令构造，原生 Windows 执行待外部复现。

新增 `.gitattributes` 固定 MATLAB、Markdown、CSV、JSON、YAML 和文本日志使用 LF，MAT/图片/PDF/DOCX/ZIP 使用 binary，Windows 批处理文件使用 CRLF。未对历史文件执行全仓库重新规范化。

## 8. 研究边界

当前结果仍属于受限候选库、模型生成 CFR、冻结参数范围和频域等效噪声条件下的模型内证据。候选集合 coverage 不等于真实物理唯一性；参数 profile 收敛不等于全局可辨识；near OOD 的拒绝覆盖不足和 10 dB 控制中的单个 false-unique 必须在正式报告中保留。当前不是现场配电网验证，也不是真实 PLC 收发机验证；Stage 4B 和完整 Final 均未启动。

下一阶段仅进行 Stage 4A 正式报告撰写与证据整合，不再继续 Stage 4A 算法开发。
