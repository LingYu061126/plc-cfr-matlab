# Stage 6A Candidate Generation Technical Review

审查与实验日期：2026-09-23
仓库基线：`50267e30da9f3d42789d12c6b3fdfead85ac0c86`（Stage 5B.1）
Stage 4A freeze：`9611b284da57bd10cd64ee7e48c7ba9f3ec46a92`

## 1. 本阶段目标

Stage 4A 已能把候选拓扑送入电力线通信（power line communication, PLC）信道频率响应（channel frequency response, CFR）正向模型并输出 candidate set，Stage 5B.1 已在该集合上增加 margin、normalized confidence score、entropy 和四状态判决。但是，“候选从何而来”仍缺少一个面向部分工程先验的统一入口。

Stage 6A 的目标是：在不改动 Stage 4A 正向/评分函数和 Stage 5B.1 判决函数的前提下，把部分节点、部分线路、未知开关和线路参数范围组织为可审计的图约束，生成有效候选集合

\[
\mathcal G=\{G_1,G_2,\ldots,G_K\},
\]

并通过兼容层导出到既有 candidate interface。[implemented]

本阶段不是端到端拓扑预测，也不声称仅凭单次 CFR 物理唯一确定真实拓扑。[implemented]

## 2. 当前方法（Stage 4A）

仓库审计表明，Stage 4A 并非只有一种“完整账本直接变成候选库”的路径：

1. `generate_radial_topology_candidates.m` 用固定 TX--RX 主路径和一层分支语法生成 7 个小型候选；
2. `generate_engineering_topology_candidates.m` 已支持 allowed、required、forbidden edges、switch state、maximum degree、连通和辐射树约束；
3. Stage 4A.7.2-R.1 的正式流程由处理后的参考网络构造受控 uncertain engineering ledger，约 204 个工程图经兼容性投影后形成 87 个可评分候选。

因此 Stage 6A 不是首次实现 spanning-tree enumeration，而是补足并统一：可选节点、节点数范围、线路长度区间、最大侧支路数、约束追踪、复杂度排序，以及 `topology_id/canonical_key/network` 的兼容导出。[implemented]

Stage 4A 当前正式 benchmark 的 ledger 仍由受控参考图派生；这适合验证候选闭环，但不能等同于已经证明可直接消费独立现场 GIS/台账。[not yet verified]

## 3. 新方法

### 3.1 输入：partial prior

Stage 6A baseline 接收以下信息：

- 全部潜在节点、required nodes、optional nodes；
- allowed、required、forbidden edges；
- `closed/open/unknown` switch state；
- 节点数范围和最大节点度；
- 每条线路的名义长度及允许区间；
- 总线路长度范围和最大侧支路数；
- source/receiver 节点、线缆类型、支路负载；
- 非负工程 prior cost 和候选数量上限。

这些输入在当前实验中是受控合成 partial prior，不是现场台账。[implemented]

### 3.2 图约束

候选必须满足：节点数范围、required/forbidden/switch 边规则、连通、辐射、无环、节点度上限、单边长度区间、总长度范围和最大侧支路数。结构生成与 CFR evidence 分离；约束层不读取观测 CFR。[implemented]

### 3.3 输出与排序

有效工程图使用下式进行确定性排序：

\[
C(G)=|E(G)|+w_b N_b(G)+w_p C_{\mathrm{prior}}(G),
\]

其中 \(N_b\) 是 TX--RX 主路径之外的边数，\(C_{\mathrm{prior}}\) 是所选边的工程先验代价。本实验使用 \(w_b=w_p=1\)。该分数仅用于透明、稳定的候选排序，不是 CFR likelihood，也不是 posterior probability。[implemented]

最终由 `export_candidate_library.m` 调用既有 `adapt_engineering_candidate_to_forward_model.m`，只导出当前正向模型可表达的“单 TX--RX 主路径 + 内部节点一层叶支路”网络，并提供：

- `topology_id`；
- `canonical_key`；
- `network`。

这三个字段可直接被现有 Stage 4A profile cache/forward interface 使用。[verified by experiment]

## 4. 数学定义

设潜在节点全集为 \(V=V_r\cup V_o\)，其中 \(V_r\) 为 required nodes，\(V_o\) 为 optional nodes；允许边全集为 \(E_a\)，required/forbidden edges 分别为 \(E_r,E_f\)。先枚举活动节点集

\[
V_r\subseteq V'\subseteq V,\qquad n_{\min}\le |V'|\le n_{\max}.
\]

对于每个 \(V'\)，生成边集 \(E'\subseteq E_a(V')\)，要求

\[
E_r\subseteq E',\qquad E'\cap E_f=\varnothing,
\]

且

\[
|E'|=|V'|-1,\qquad G'=(V',E')\text{ connected and acyclic}.
\]

进一步施加

\[
\deg_{G'}(v)\le d_{\max},
\]

\[
\ell_e^{\min}\le \ell_e\le \ell_e^{\max},
\]

\[
L_{\min}\le\sum_{e\in E'}\ell_e\le L_{\max},
\]

以及

\[
N_b(G')\le B_{\max}.
\]

closed switch 被并入 required edges，open switch 被并入 forbidden edges，unknown switch 保持 optional。活动节点子集枚举完成后，现有工程 spanning-tree generator 负责边组合搜索；随后独立约束审计再次检查所有候选。[implemented]

当前 optional-node subset 使用有界穷举，并显式设置 `maximum_node_subsets`；它是小规模、可解释 baseline，不是大规模最优算法。[implemented]

## 5. Code architecture

```text
partial prior
  -> generate_candidate_topologies()
       required/optional node subsets
       existing engineering spanning-tree enumeration
  -> apply_topology_constraints()
       graph + switch + degree + length + branch audits
  -> rank_candidate_complexity()
       deterministic engineering complexity/prior ranking
  -> export_candidate_library()
       existing forward-model adapter
       topology_id + canonical_key + network
  -> Stage 4A existing forward/profile functions
  -> Stage 5B.1 existing margin/confidence/entropy/decision functions
```

| 模块 | 职责 | 是否读取 CFR |
|---|---|---:|
| `generate_candidate_topologies.m` | optional-node subset 与工程树枚举 | 否 |
| `apply_topology_constraints.m` | 显式约束审计与拒绝原因 | 否 |
| `rank_candidate_complexity.m` | 工程复杂度/先验代价排序 | 否 |
| `export_candidate_library.m` | 既有正向模型兼容导出 | 否 |
| `stage4a7_2_r1_build_profile_template_cache.m` | 既有 CFR template cache | 是 |
| `stage4a7_2_r1_profile_distance.m` | 既有 profile distance | 是 |
| `classify_stage5b1_decision_state.m` | 既有四状态判决 | 是 |

Stage 4A forward/scoring source 与 Stage 5B.1 decision source均未修改。[implemented]

## 6. Experiment design

实验入口为 `run_stage6a_candidate_generation.m`，配置为 `stage6a_candidate_generation_config.m`。实验是小型受控仿真：[implemented]

- 频率范围：2--30 MHz，共 61 个频点；
- 测量：SISO forward CFR；
- 基准库：Stage 4A.1 restricted grammar 的 7 个物理网络；
- 受控真拓扑：主路径第 2 个内部节点具有一个支路；
- 测试信噪比：\(\infty\)、30 dB、15 dB，每档 3 次，共 9 个 observation/method；
- nuisance search：主线长度 scale 为 0.98、1、1.02，其他量保持名义值；
- 每候选 20 个独立 calibration observation；Pilot/test observation 不进入 calibration；
- Stage 4A comparison 使用现有 forward、profile distance、absolute candidate-set calibration；
- Stage 5B.1 comparison 使用现有 margin、normalized confidence score、entropy 和四状态函数。

为适配不同候选库，实验分别校准每个库的 candidate-set model、evidence model 和一个 calibration-only relative-residual domain threshold。它复用 Stage 4A/Stage 5B.1 函数，但不是复用 Stage 4A freeze 的 87-candidate threshold；因此本结果是 Stage 6A 受控接口实验，不能写成 Stage 4A frozen benchmark 的直接延伸。[implemented]

比较四种候选来源：

| 方法 | 部分先验含义 |
|---|---|
| existing library | 既有 7 候选 restricted grammar |
| broad unknown switches | 三个可能支路开关均 unknown |
| informative switch prior | M2--B2 closed，M3--B3 open，M1--B1 unknown |
| stale switch prior | 真实 M2--B2 被错误标为 open，其余 unknown |

## 7. Results

结果源：`results/data/stage6a/stage6a_candidate_generation_summary.csv`、`stage6a_runtime.csv`、`stage6a_identification_summary.csv` 和 `stage6a_identification_metrics.csv`。

### 7.1 Coverage、候选规模与生成时间

这里 `coverage` 严格按任务定义为“受控真拓扑是否在候选集合中”的 0/1 指标；附加的 `reference_library_coverage` 是相对既有 7 个物理网络的覆盖比例。

| 方法 | 候选数 | coverage | 真拓扑包含 | 旧 7 库覆盖率 | generation time (s) | candidate pipeline (s) |
|---|---:|---:|---:|---:|---:|---:|
| existing library | 7 | 1 | 是 | 1.0000 | 0.055695 | 0.055695 |
| broad unknown switches | 7 | 1 | 是 | 1.0000 | 0.251640 | 0.361925 |
| informative switch prior | 2 | 1 | 是 | 0.2857 | 0.031343 | 0.042286 |
| stale switch prior | 4 | 0 | 否 | 0.5714 | 0.015762 | 0.025687 |

[verified by experiment] broad case 生成的 7 个 forward networks 与旧库 7 个 networks 完全一致，证明新接口能在该受控语法内切换替代旧库。信息性先验把候选数从 7 降为 2，同时保留真拓扑。陈旧先验说明：候选数较少并不代表候选库更好；错误 open-switch 信息会直接破坏 coverage。

这些 runtime 是同一 MATLAB 正式运行中的单次 wall-clock 记录，只用于本小实验的相对观察，不是跨硬件性能基准。[verified by experiment]

### 7.2 Identification result

| 方法 | UNIQUE_CONFIDENT | MULTIPLE_AMBIGUOUS | LOW_CONFIDENCE | REJECTED | best 为真拓扑 | 正确 confident unique |
|---|---:|---:|---:|---:|---:|---:|
| existing library | 9 | 0 | 0 | 0 | 9 | 9 |
| broad unknown switches | 8 | 0 | 0 | 1 | 9 | 8 |
| informative switch prior | 7 | 0 | 1 | 1 | 9 | 7 |
| stale switch prior | 0 | 0 | 0 | 9 | 0 | 0 |

[verified by experiment] 正确 partial prior 下，Stage 6A 候选可以通过未改动的 Stage 4A forward/profile 和 Stage 5B.1 decision interface。informative prior 的 9 个样本中，7 个为 `UNIQUE_CONFIDENT`、1 个为 `LOW_CONFIDENCE`、1 个为 `REJECTED`；没有把这两个不充分样本强制输出为 confident unique。

[verified by experiment] stale prior 排除真拓扑后，9/9 样本均被 residual/domain gate 拒绝，而不是选择错误库中某个候选作为 confident unique。这是当前受控实验的安全现象，不证明所有漏真拓扑场景都能被可靠拒绝。

[verified by experiment] 本实验未出现 `MULTIPLE_AMBIGUOUS`，因此不能用本结果宣称 Stage 6A 提高了 ambiguity detection；Stage 5B.1 的 T3/T5 非唯一证据仍来自其自身正式结果。

## 8. Improvement over Stage 4A

Stage 6A 在接口层降低了对“预先给出完整候选拓扑列表”的依赖：[implemented]

1. 允许 required/optional nodes，而不是要求固定节点全集全部存在；
2. 允许 unknown switch 和 unknown branch presence；
3. 把 node count、degree、edge length、total length、branch count 和 forbidden edges 变成显式可审计约束；
4. 自动导出到既有 forward candidate format，支持 old/new library 切换；
5. 保存约束满足项、拒绝原因、生成/导出审计和确定性 identity。

但它没有消除工程先验依赖：潜在节点和 allowed edge universe 仍需外部提供，线路参数也需给出名义值或范围。[implemented]

结论是“已形成 partial-prior candidate-generation baseline”，而不是“已解决任意真实台区的候选来源问题”。

## 9. Limitations

1. 仅验证一个 5--7 节点、一层支路的小型受控网络族，未覆盖真实台区规模和多层分支。[not yet verified]
2. optional-node subsets 与候选边搜索仍具有组合增长；当前只用上限保护，没有大规模剪枝/分解保证。[implemented]
3. 当前 forward adapter 仅支持稳定 TX--RX 单路径及内部节点一层叶支路；更一般工程树可能生成但不能进入冻结正向接口。[implemented]
4. allowed edge universe、线缆类型、负载与长度范围仍依赖工程输入；本阶段没有从 GIS、台账或量测自动恢复这些信息。[not yet verified]
5. complexity score 是工程排序，不是概率，也未由 CFR 学习。[implemented]
6. 当前 calibration/domain threshold 是本实验局部校准，不是 Stage 4A freeze 的 87-candidate threshold。[implemented]
7. 未进行现场验证、硬件验证或跨台区验证；所有结果均为模型内部受控仿真。[not yet verified]
8. stale-prior 仅测试一个错误开关案例；9/9 rejection 不能外推到全部候选遗漏或模型失配情形。[not yet verified]

## 10. Next step

建议 Stage 6B 聚焦候选生成 robustness，而不是立即引入黑盒模型：

1. 在多种树规模、optional-node 数量和 edge-universe 密度下测量 coverage、候选数与运行时间；
2. 系统注入 missing/stale switch、错误线路长度范围和漏边，评估漏真拓扑时的 false unique 风险；
3. 将当前 partial-prior schema 接入独立公共网络/GIS-like 输入，而不是从 hidden reference 派生；
4. 若当前 forward adapter 成为主要瓶颈，再单独论证多层分支正向表示升级；
5. 将 Stage 4A、Stage 5B.1 和 Stage 6A 的事实、边界及 CSV 映射整合进阶段/论文报告。

以上仅为建议，本阶段未自动开始 Stage 6B。[not yet verified]
