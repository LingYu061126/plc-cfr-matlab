# Stage 4A.7.1 候选生成与客观确认阶段记录

## 1. 阶段范围

本阶段建立三条候选生成路线、工程候选与正向模型兼容性的分层审计，以及基于独立 calibration 的候选确认对照。实验仅使用 A 网格（2–30 MHz，61 点）、受限径向合成候选库和模型生成的无噪声复 CFR。完整 Final、B 网格、真实 PLC PHY 与 Stage 4B 均未启动。[本次运行]

## 2. 文献约束与候选生成路线

工作区内实际读取了 6 篇原始 PDF；逐篇输入、算法、适用条件和精确位置见 `stage4a7_1_literature_method_evidence.md`。[论文明确陈述]

- 路线 A 为受约束工程边集枚举。输入包括节点、允许边、required/forbidden 边、开关状态、最大度、径向性与连通性。搜索使用确定性边排序、required-edge 预处理、Union-Find 环检测、连通性/度/剩余边剪枝和候选数硬保护，不生成允许边的完整幂集。[代码静态核对]
- 路线 B 为无额外工具箱的 Top-K 原型。它以路线 A 的 exact feasible-set oracle 为基础，按冻结软边成本与 canonical key 确定性排序，并以 canonical key 作为 no-good identity。该实现验证 Top-K 接口和无重复语义，不是完整 MILP/MIQP 求解器。[代码静态核对]
- 路线 C 是多节点测距重构 capability gate。Ahmed–Lampe 方法需要叶节点间成对 ToA/距离；当前单 TX–RX CFR 不具备该输入，因此返回 `not_applicable`，不把 IFFT 峰当作成对物理距离。[论文明确陈述/代码静态核对]

历史 7 图通过 legacy adapter 严格保留 topology ID、canonical key、顺序、网络对象和每图 243 个模板。小型 4 节点工程边集生成 4 个可行径向树；路线 B 在 `K=4` 时与路线 A 的 canonical-key 集合完全一致。[本次运行]

## 3. 两层候选空间与覆盖审计

工程层保留图结构、约束满足情况、先验成本和生成轨迹；正向模型兼容层单独标记当前稳定单主路径/一级侧支路模型能否表达该图。工程可行但无法适配的图不会被静默删除，也不会伪造 CFR，而是保留并从评分库排除。[代码静态核对]

| 审计案例 | 工程候选 | 正向模型兼容 | 评分候选 | 结论 |
|---|---:|---:|---:|---|
| legacy 真值受覆盖 | 7 | 7 | 7 | `covered` |
| stale prior 删除 G003 | 7 | 7 | 6 | `truth_excluded_from_scored_library` |
| 工程可行但当前模型不兼容 | 4 | 0 | 0 | `truth_forward_model_incompatible` |

候选空间漏真值和正向模型覆盖损失分别记录，不计为分类器错误。[本次运行]

## 4. 客观候选确认

基础复 CFR 模型相容性为

\[
d_G=\min_{\theta\in\Theta_G}D\!\left(\hat H,H(G,\theta)\right).
\]

在显式冻结的对角噪声尺度下，另计算

\[
J_G=r_G^{\mathrm H}\Sigma_N^{-1}r_G,
\qquad r_G=\hat H-H(G,\hat\theta_G).
\]

本阶段没有给出经现场验证的复高斯噪声模型，故将其命名为 `W_GLRT_compatible` 或 noise-weighted residual，而不是严格 likelihood/GLRT。协方差维数和奇异正则化均有单元测试。[代码静态核对]

竞争候选证据包括最优/次优残差、绝对 margin、相对 ratio、子带证据和冻结频率块稳定度。`C_set_plus_I` 另外构造观测条件下的 calibrated residual-indistinguishability graph；其连通分量不是严格物理等价类。[代码静态核对/模型推断]

按候选类别的经验候选集合使用

\[
p_G(x)=\frac{1+\#\{A_i(G)\ge A(x,G)\}}{n_G+1},
\qquad
\mathcal C_\alpha(x)=\{G:p_G(x)>\alpha\}.
\]

每个候选使用 20 个独立 calibration 场景，`alpha=0.05`，最小可达 p-value 为 `1/21=0.047619`。该集合只具有当前合成分布下的经验 calibration 含义；候选库漏真值、分布漂移或现场分布变化均会破坏其解释。[本次运行/模型推断]

## 5. 数据隔离与样本

Calibration 使用 seed `20261711`，共 140 个场景（7 个拓扑 × 每类 20 个连续域内参数）；Pilot 使用 seed `20261721`，共 33 个场景：14 个连续域内、7 个 symmetry-preserving nominal、9 个参数 OOD 和 3 个结构 OOL。`final_reserved` seed `20261731` 只保存身份，未物化、未运行。[本次运行]

Calibration 内 140 个 physical scenario、参数哈希和 CFR 哈希均唯一。Pilot 有 33 个 physical scenario、27 个唯一参数向量和 33 个唯一 CFR；重复参数来自跨拓扑使用相同名义参数的 symmetry-preserving 设计，不是重复观测。两个 split 的参数哈希与 CFR 哈希交集均为 0。[本次运行]

## 6. Pilot 结果

以下比率均报告分子/分母；区间详见 `pilot_metrics.csv`。拓扑集合准确率仅在真值位于评分候选库的 30 个场景上评价。参数 OOD false acceptance 表示拓扑确认器仍接受该观测，不等同于参数域诊断结果。[本次运行]

| 方法 | topology set accuracy | accepted coverage | topology selective risk | 平均集合大小 | structure OOL FA | parameter OOD FA |
|---|---:|---:|---:|---:|---:|---:|
| M0 minimum residual | 29/30 | 33/33 | 1/30 | 1.545 | 3/3 | 9/9 |
| M3 frozen | 28/30 | 29/33 | 0/28 | 1.394 | 1/3 | 7/9 |
| W-GLRT-compatible | 28/30 | 31/33 | 0/28 | 1.455 | 3/3 | 7/9 |
| C-set | 27/30 | 32/33 | 2/29 | 5.212 | 3/3 | 8/9 |
| C-set + I | 27/30 | 32/33 | 2/29 | 5.212 | 3/3 | 8/9 |

真实 same-theta 非唯一场景为 4 个。五种方法的 conditional false-unique 均为 0/4，但 Wilson 95% 上界约 0.490，样本量不足以支持稳定的零风险结论。M3 将结构 OOL 误接收从 M0 的 3/3 降为 1/3，同时牺牲部分覆盖；参数 OOD 仍有 7/9 被接受，说明拓扑确认不能替代后续参数域诊断。[本次运行]

C-set 的高接受覆盖伴随平均集合大小 5.212、31/33 ambiguous-set 输出和仅 1/33 singleton；因此不能以覆盖率单独宣称优于 M3。`C_set_plus_I` 本轮作为不可区分图审计层，没有改变经验集合本身，故汇总指标与 C-set 相同。[本次运行]

## 7. 候选复杂度与计算

`candidate_complexity_audit.csv` 逐候选保存 active parameter dimension、243 个模板、平均/最小 Pilot 残差。该审计只检查复杂度敏感性；由于本阶段没有完整统计似然与有效自由度证明，没有机械套用 AIC/BIC。[本次运行]

最终成功运行的 MATLAB 内部总耗时为 5.142 s，其中候选缓存重建约 1.4 s、calibration 评分约 1.5 s；含 MATLAB 进程启动的 wall-clock 为 12 s。根据 Stage 4A.6.3.1-R.2 已有证据，小任务并行慢于串行，本轮使用 1 worker 且未启动并行池。[本次运行]

| Phase | 事前预计 | 实际 | 偏差原因 |
|---|---:|---:|---|
| 环境与静态复核 | 5–10 min | <5 min | MATLAB 启动问题已通过沙箱外启动隔离解决 |
| 最终 calibration/Pilot | 5–15 min | 12 s wall / 5.142 s MATLAB | 缓存与 61 点向量化评分远快于保守估计 |
| 完整历史回归 | 5–20 min | 14 s wall | 测试均为小型确定性用例 |
| 结果审计与记录 | 10–20 min | 约 10 min | 包括分母、哈希、路径和负面结果复核 |

## 8. 测试与复现

- MATLAB：`24.1.0.2537033 (R2024a)`。
- Pilot：`run_stage4a7_1_candidate_generation_and_confirmation()`；退出状态 0；日志 `results/logs/stage4a7_1/stage4a7_1_calibrated_pilot_final.log`。[本次运行]
- 完整回归：`run('tests/run_tests.m')`；退出状态 0；Stage 1.5 至 Stage 4A.7.1 全部通过；日志 `results/logs/stage4a7_1/stage4a7_1_full_regression_final.log`。[本次运行]
- 最终 scientific hash：`11e7be32aeffcf55df2bd00cad81a4f7b0c0890194fd4fe2a2071893993a8acb`。
- 最终 source-tree hash：`76cd43be057d65b27321d1ec6621c23960af2ec9f96a56dfb5191b50f6ff012a`。

## 9. 阶段结论与边界

在初始受控 Pilot 之后，另以新 seed 完成了 700 条 calibration＋500 条 Pilot 的独立扩展实验；扩展结果和置信区间见 `stage4a7_1_extended_pilot_record.md`。扩展运行不覆盖本报告中的 140＋33 历史结果，也没有消费 `final_reserved`。[本次运行]

Stage 4A.7.1 的受控 Pilot 门槛已完成：legacy 7 图严格保留；路线 A、路线 B 原型和路线 C capability gate 均有测试；工程/模型/评分空间分离；noise-weighted residual、经验候选集合与不可区分图已实现；非唯一评价分母大于 0；独立 calibration 与 Pilot 已运行；完整历史回归通过。[本次运行]

总体阶段状态仍记为 `Stage 4A.7.1 partial / blocked`：指定清单中的 Erseghe、Deka、Cavraro、Gabow–Myers、Angelopoulos 和 Fisch 原始 PDF 未在工作区找到，因而不能满足“全部关键原始论文均已核对精确位置”的文献门槛。该阻塞不影响本轮代码、calibration、Pilot 和回归证据的完成状态。[待核对]

这不是稳定总体性能结论。当前候选库仍是受限径向合成库，先验不是现场 GIS，观测是模型生成的无噪声 SISO CFR。候选确认接受不证明物理唯一性，profile/残差收敛不证明参数全局可辨识，经验 p-value 不是后验概率，也不提供现场 coverage 保证。完整 Final 与 Stage 4B 均未启动。[模型推断]
