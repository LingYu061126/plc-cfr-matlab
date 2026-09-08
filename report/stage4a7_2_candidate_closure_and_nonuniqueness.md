# Stage 4A.7.2：候选生成闭环、按需 Top-K 与非唯一场景强化

## 1. 阶段结论

本阶段已完成一组受控的 Stage 4A.7.2 代码扩展，并保留了旧 Stage 4A.7.2 结果目录。最新 `tier2_v3` 运行完成了 7 个工程候选的工程适配、70/140/49 个 development/calibration/Pilot 场景、100 个 same-theta 非唯一场景和 50 个近对称场景；小型 Lazy Top-K 一致性检查也在 MATLAB 中通过。[本次运行]

MATLAB 启动器采用独立偏好目录和兼容库后可以完成命令执行，但当前 ServiceHost 会在启动早期输出多次 `client-v1` 警告，启动时间约 1 分钟量级；这不影响本次命令以退出码 0 完成。[本次运行] 本阶段的受控结果没有覆盖历史 `tier2_v2`。[代码静态核对]

阶段状态：**controlled pilot completed; not a full Final**。Stage 4B 和完整 Final 均未启动。[本次运行]

## 2. 候选生成闭环

当前工程候选路径为：

```text
synthetic engineering prior
→ normalized node/edge specification
→ constrained radial tree search
→ canonical graph key and deterministic prior-cost order
→ forward-model compatibility adapter
→ scored candidate library
→ residual/nonconformity candidate confirmation
```

工程先验的语义是允许节点、可能边、required/forbidden 或 switch 状态、长度/线缆/端部属性和径向/度数约束；它不是现场 GIS 或完整可信线路台账。[代码静态核对]

`generate_engineering_topology_candidates` 通过 Union-Find 增量检查环、连通性、剩余边数、required 边和最大度数，并保留搜索统计。新增的 `normalize_engineering_candidate_spec` 将无向边端点规范化、反向重复去重、同步重排先验代价并拒绝自环、未知节点、非法代价和 required/forbidden 冲突。[代码静态核对]

当前适配器 `adapt_engineering_candidate_to_forward_model` 只接受稳定正向模型能够表示的“source→receiver 主路径＋一级叶支路”图。无法表示的工程候选必须保留并带有 reason code，不能静默删除或伪造 CFR。[代码静态核对]

历史 tier2_v2 结果中工程候选、正向兼容候选和评分候选均为 7，7 个 legacy 网络的适配 CFR 与原定义距离为 0。[历史结果] 该数字不代表最新修改后的 MATLAB 重跑已经完成。

## 3. Lazy Top-K

`generate_topk_topology_candidates` 已从“完整枚举后排序截取”改为确定性 best-first branch-and-bound。每个状态保存已选边、处理位置、累计代价、Union-Find/度数状态和数学下界；include/exclude 分支在生成下一个状态前进行环、度数和剩余边数检查。相同代价时使用状态键和 canonical key 确定性排序。[代码静态核对]

在历史受控运行的小型 4 节点 edge-universe 中，完整枚举得到 4 棵树，K=3 返回 3 个不重复候选，K=4 的 canonical key 集合与完整枚举一致。[历史结果]

该实现是本项目的受约束 Lazy Top-K 原型，不是 Eppstein 算法的复现，也不继承 Eppstein 的复杂度结论。[模型内推断]

## 4. 候选集合非相容度

当前代码保留绝对残差，并计算：

\[
A_{\mathrm{abs}}(x,G)=d_G(x),\qquad
A_{\mathrm{scaled}}(x,G)=d_G(x)/s_G,
\]

\[
A_{\mathrm{ratio}}(x,G)=d_G(x)/(d_{\mathrm{competitor}}(x,G)+\epsilon),
\quad
A_{\mathrm{margin}}(x,G)=d_G(x)-d_{\mathrm{competitor}}(x,G).
\]

同一等价组成员不作为彼此竞争者。calibration 仅估计经验分数分布和最小可达到 p-value；当前没有独立噪声协方差和现场交换性证据，因此输出只能称为 calibrated empirical candidate set，不能称为现场 distribution-free conformal guarantee 或后验概率。[代码静态核对][模型内推断]

新增 `absolute_I` 将绝对分数集合与 observation-conditioned calibrated indistinguishability graph 合并；其连通分量是校准不可区分组，不是严格物理等价类。[代码静态核对]

## 5. 非唯一与近对称场景

`build_stage4a7_2_nonunique_clusters` 生成 G004/G007 的 same-theta 对称请求，并分别记录 exact CFR 距离和受限 profile-distance；`build_stage4a7_2_near_symmetry` 对接收端阻抗相对源阻抗施加冻结的 \(0.1\%\)、\(0.5\%\)、\(1\%\)、\(2\%\)、\(5\%\) 扰动，以区分 exact same-theta、profile-equivalent 和 symmetry-breaking 场景。[代码静态核对]

历史 tier2_v2 已生成 100 个独立 same-theta 参数/CFR hash 场景，并在 \(10^{-10}\) 的 exact 距离容差下通过。[历史结果] 最新 `tier2_v3` 已由 MATLAB 重跑确认 `profile-equivalent=100`，并生成 `near-symmetry=50` 条记录。[本次运行]

## 6. 历史受控 Pilot 结果

`results/data/stage4a7_2_tier2_v2/confirmation_metrics.csv` 的历史结果为：

| 方法 | 类别 | 集合覆盖 | singleton | 空集合 |
|---|---|---:|---:|---:|
| absolute/scaled/ratio | in-domain | 21/21 | 21/21 | 0/21 |
| margin | in-domain | 20/21 | 16/21 | 1/21 |
| absolute/scaled/ratio | parameter OOD | 21/21 | 21/21 | 0/21 |
| margin | parameter OOD | 17/21 | 13/21 | 4/21 |
| absolute/scaled/ratio | structure OOL | 0/7 | 7/7 | 0/7 |
| margin | structure OOL | 0/7 | 7/7 | 0/7 |

这组数字表明，在旧受控无噪声 Pilot 中，绝对、缩放和 ratio 集合没有形成有效参数库外拒识；它不支持最终 open-set 性能结论。结构库外集合覆盖为 0 不能直接解释成分类错误，因为库外真值不在评分候选集合内，应结合 candidate coverage audit 和拒识语义报告。[历史结果]

## 7.1 最新 tier2_v3 受控运行

在修正工程候选复杂度审计所需的 `node_count/edge_count` 字段后，使用相同 Stage 4A.7.2 设计以串行 MATLAB 重新运行。结果文件位于 `results/data/stage4a7_2_tier2_v3/`，运行日志为 `results/logs/stage4a7_2_tier2_v3_retry.log`。[本次运行]

| 项目 | 数值 |
|---|---:|
| engineering candidates | 7 |
| forward-compatible candidates | 7 |
| scored candidates | 7 |
| development / calibration / Pilot | 70 / 140 / 49 |
| same-theta non-unique clusters | 100 |
| profile-equivalent clusters | 100 |
| near-symmetry rows | 50 |
| candidate-set calibration | calibrated |
| minimum attainable p-value | 0.047619 |
| experiment runtime | 2.516 s |

`absolute`、`scaled`、`ratio` 和 `absolute_I` 在当前无噪声受控数据中对库内样本均为 21/21 集合覆盖、0/21 空集合；对参数 OOD 样本均为 21/21 集合覆盖、0/21 空集合；对结构库外样本均为 7/7 空集合。`margin` 对库内为 20/21 覆盖、1/21 空集合，对参数 OOD 为 17/21 覆盖、4/21 空集合。上述结果是当前合成 Pilot 的集合行为，不是现场开放集性能结论。[本次运行]

当前运行的 scientific hash 为 `4529de112934e19ea28be655771be49c9cd29ea926db1579ae209314d662025d`，source-tree hash 为 `214831f3fdcee34805e2630b6bac9b61b00d627295297f5938c3a9ffc2156033`；final-reserved 仍为 manifest-only，未物化。[本次运行]

## 8. 证据与运行状态

| 项目 | 状态 |
|---|---|
| 历史 tier2_v2 数据 | 已存在，保留在独立目录。[历史结果] |
| 最新结构库外/近对称/Profile 修改 | 已写入工作区，并由 `tier2_v3` MATLAB 运行验证。[本次运行] |
| Octave 兼容性检查 | Lazy Top-K 小型键集合检查通过；不替代 MATLAB。[本次运行] |
| MATLAB 定向测试 | 6 项 Stage 4A.7.2 定向测试逐项通过。[本次运行] |
| MATLAB 受控 Pilot | `tier2_v3` 完成：development=70、calibration=140、Pilot=49、非唯一=100。[本次运行] |
| 并行池 | 未启动；本阶段默认串行。[本次未运行] |
| 完整 Final | 未运行。[本次未运行] |
| Stage 4B | 未启动。[本次未运行] |

相关运行日志：

- `results/logs/stage4a7_2_matlab_targeted_retry.log`：MATLAB R2024a 定向测试逐项通过；
- `results/logs/stage4a7_2_matlab_full_regression_retry.log`：完整历史回归退出码 0；
- `results/logs/stage4a7_2_tier2_v3_retry.log`：最新受控 Pilot 与摘要；
- `results/logs/stage4a7_2_matlab_startup_probe.log`：记录了先前失败探针和本次恢复后的启动证据。

## 9. 研究边界与下一步门槛

当前结果仍限于受限径向候选库、合成先验、模型生成的无噪声单端口复数 CFR 和 61 点快速网格。候选集合、same-theta 等价和 profile 等价都只在冻结的模型、端口、频带、端接、参数和数值容差下成立。确认器接受候选不等于物理拓扑全局唯一；参数拟合收敛不等于参数全局可辨识；候选数减少也不等于观测能力增加。[模型内推断]

在进入下一阶段前，仍需要补充：

1. 将本次受控 Pilot 的指标与独立观测等价、结构库覆盖和候选集合语义做完整离线审计；
2. 在需要更大样本时重新冻结 calibration/Pilot 设计，不能把本次 49 个 Pilot 直接解释为稳定总体性能；
3. 如需正式性能结论，另行运行独立 Final；本阶段没有运行完整 Final；
4. 保持当前串行执行，未来扩大任务前再基于实际 wall-clock 和内存进行并行 benchmark，不进入 Stage 4B。
