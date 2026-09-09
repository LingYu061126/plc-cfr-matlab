# Stage 4A Freeze-R.1.1：干净源码与 canonical 归档完整性

## 1. 阶段结论

Freeze-R.1.1 只修复判定字段语义、源码身份、冻结输入路径和归档完整性，不改变候选库、阈值、随机种子、参数范围、频率网格、噪声设置或稳定正向模型。canonical formal 在提交
`54868370cc6c426f417681146caace79de782e91` 的 detached clean worktree 中运行，运行时工作树为空，`git_dirty_at_run=false`，`canonical_eligible=true`。

**PASS — Stage 4A frozen; proceed to formal report writing.**

Windows 原生 MATLAB 未在当前环境执行，保留为 `external_reproduction_pending`；这不阻止科学协议冻结。

## 2. 修复后的身份和字段语义

源码清单由 `git ls-files` 生成，只纳入 Git 跟踪的科学 MATLAB 文件，不扫描未跟踪 `.m` 文件。canonical formal 的 source inventory 包含 411 个文件；每一行均存在、由 Git 跟踪且 SHA256 匹配。source manifest 缺失、未跟踪和摘要不匹配计数均为 0。

运行身份与科学结果字段分离：

- 结果行的 `selected_method` 保留该行实际对应的方法；
- canonical 执行方法记录为 `canonical_execution_method`；
- 方法级 `domain_calibration_hash` 与 canonical 执行方法的校准身份同时保留，后者写入 `canonical_domain_calibration_hash`；
- 冲突的同名身份字段不再静默覆盖，而是显式报错。

detached worktree 的空分支名记录为 `(detached)`；HEAD、dirty 状态和 Git 命令失败均作为硬身份错误处理。formal dirty worktree 会抛出 `stage4a_freeze_r1:DirtyCanonicalSource`，smoke 可运行但 `canonical_eligible=false`。

冻结源根目录统一为 `final_source_v3`；R2.1.2 统计归档使用其根目录，Stage 4A.7.3 使用其 `formal/` 子目录，避免形成重复的 `formal/formal` 路径。

## 3. canonical 判定规则

Rule A 是 canonical execution rule：

1. development in-domain acceptance 必须不低于 0.90；
2. 在通过门槛的方法中，最小化 development medium/far OOD false acceptance；
3. 如仍并列，使用稳定预声明顺序作为 deterministic execution fallback；
4. `scientifically_unique_winner=false`，执行 fallback 不表示科学上存在唯一优胜方法。

Rule A 选择 `profile_relative_distance`，阈值为 `0.110340450651554`。Rule B 是敏感性审计，仅按严格词典序最大化 development 域内接受率，再最小化 OOD 误接受；Rule B 选择 `profile_min_distance`，阈值为 `0.0564853173821596`。两种规则使用同一批冻结 Pilot 观测，未使用 Pilot 重新选择或调参。

对 9 个 Pilot 类别逐行独立重算：Rule A 使用 `drelative <= 0.110340450651554`，Rule B 使用 `dmin <= 0.0564853173821596`，两种规则的 18 个 accepted count 均与结果表一致。

## 4. formal 运行和主要结果

运行环境为 MATLAB R2024a `24.1.0.2537033`，Linux `GLNXA64/glnxa64`，串行 1 worker，未启用并行池。canonical 输出位于：

```text
results/data/stage4a_freeze_r1_1/
results/data/stage4a_freeze_r1_1/stage4a7_3/formal/
```

formal 结果为：

| 项目 | 数值 |
|---|---:|
| 冻结候选 | 87 |
| development | 783 |
| parameter calibration | 3480 |
| Pilot | 783 |
| T3/T5 非唯一控制 | 120 |
| Stage 4A.7.3 formal runtime | 259.010 s |
| Freeze wrapper wall-clock | 276.487 s |

canonical 参数域结果保持为：域内接受 `80/87`；exact lower/upper boundary 接受均为 `81/87`；near lower/upper rejection 分别为 `11/87`、`19/87`；medium lower/upper rejection 分别为 `45/87`、`43/87`；far lower/upper rejection 分别为 `68/87`、`79/87`。

T3/T5 数值非唯一正控制的 false-unique 为：无噪声 `0/40`、30 dB `0/40`、10 dB `1/40`；完整等价集合覆盖为 `40/40`、`40/40`、`39/40`。Bootstrap 区间来自 candidate-cluster percentile Bootstrap；非唯一控制的重采样单位为 `test_sample`。10 dB 的 `[0, 0.075]` 退化/近退化区间不解释为真实总体概率严格为零。

参数域使用 20 dB 频域等效圆对称复高斯噪声；T3/T5 控制使用无噪声、30 dB 和 10 dB。它们均不是完整 OFDM 波形级噪声，也不是实测 PLC 噪声。

## 5. 身份摘要

| 字段 | canonical formal 值 |
|---|---|
| `git_head_at_run` | `54868370cc6c426f417681146caace79de782e91` |
| `git_dirty_at_run` | `false` |
| `source_tree_hash` | `5d45c12526dc205642d9cf9cb3e8be34605f529179904872fda52e75396dc353` |
| `configuration_hash` | `5b3c9a914e70cd1472a611ad784ca51d2af269f307ec4c3c53cc40c7f4d2931b` |
| `experiment_hash` | `c2d0af7d0e3c27645cb195528b00ed9cf9844838d9e6eb543da1588eb888cc96` |
| `runtime_environment_hash` | `8313f3a14914316354fa22dbe4ec3d546eb572e0092c5305b62000dfdd90c16f` |
| `domain_calibration_hash` | `0829042b4eaa7f045282fbc9fe08c209fd5c7d2b1197539791792966f906954c` |
| `frozen topology experiment hash` | `36ab4a9a2ffceeeb1e7241d89cf281540d0e78acce35f27e068187e3fe0832c8` |

根 `canonical_manifest.csv` 排除自身以避免哈希循环，包含 44 个被核验 artifact：canonical 23 个、sensitivity 2 个、history/smoke 19 个。每个 artifact 的存在性、大小和 SHA256 均已独立重算通过。

## 6. 测试和日志

定向测试、smoke、formal 和完整回归均在最终源码基线的干净 worktree 中完成。完整 `tests/run_tests.m` 退出状态为 0；既有优化器的欠定方程 warning 被保留，但没有测试失败。

最终日志为：

```text
results/logs/stage4a_freeze_r1_1/targeted_tests_final.log
results/logs/stage4a_freeze_r1_1/smoke_final.log
results/logs/stage4a_freeze_r1_1/formal_final.log
results/logs/stage4a_freeze_r1_1/full_regression_final.log
```

启动、路径和字段冲突的失败尝试分别保存在 `failed_attempt_*.log` 中，不被 PASS 日志覆盖，也不作为正式结果。

## 7. Windows 复现状态

SHA256 接口按原始二进制字节计算，优先使用 Java `MessageDigest`，无 JVM 时使用平台可用的系统 fallback；空文件、`abc`、二进制及含空格、中文、括号路径的定向测试已在 Linux 通过。`.gitattributes` 固定源代码、CSV、Markdown 和文本日志为 LF，MAT/PNG/PDF/DOCX/ZIP 为 binary。

当前环境没有 Windows 原生 MATLAB，因此 `windows_native_tested=false`，状态为 `external_reproduction_pending`。Windows 入口和结果核验命令见 `docs/windows_stage4a_freeze_r1_1_reproduction.md`；不得将 Linux 结果表述为 Windows 实测通过。

## 8. 研究边界与冻结后的范围

当前证据仍属于受限候选库、模型生成 CFR、冻结参数范围和频域等效噪声条件下的模型内验证。候选集合接受不等于真实物理唯一性；参数 profile 收敛不等于参数全局可辨识；near OOD 检出不足和 10 dB 非唯一控制中的一个 false-unique 必须在正式报告中保留。当前不是现场配电网验证，也不是真实 PLC 收发机验证；`final_reserved` 未物化，Stage 4B 未启动。

Stage 4A 之后只进行正式报告撰写、证据整合、已冻结表格/图的复现和归档核验，不再继续 Stage 4A 算法开发。
