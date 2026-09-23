# Stage 6A 开工前项目审查

审查日期：2026-09-23

## 1. 仓库与冻结状态

- 当前仓库：`matlab_plc_cfr_publish/`。
- 当前分支：`main`，跟踪 `origin/main`。
- 当前提交：`50267e30da9f3d42789d12c6b3fdfead85ac0c86`（Stage 5B.1）。
- 直接父提交：`9611b284da57bd10cd64ee7e48c7ba9f3ec46a92`（Stage 4A freeze）。
- 开工时唯一未跟踪文件为 `docs/stage5b1_technical_review_report.md`，它是上一阶段按“不提交”要求生成的报告；不得覆盖。
- Stage 6A 只能新增候选生成框架、实验、测试、结果和文档，不修改 Stage 4A freeze 或 Stage 5B.1 decision layer。

## 2. 当前候选生成流程

当前仓库同时存在三层候选来源：

1. `topology_candidates.m`：早期 6 个手工小拓扑，用于基础 CFR/OFDM 实验。
2. `generate_radial_topology_candidates.m`：受限语法生成器，固定 TX--RX 主路径，只枚举一层侧支路数量/位置；Stage 4A.1 得到 7 个候选。
3. `generate_engineering_topology_candidates.m`：工程边宇宙约束枚举器。Stage 4A.7.2-R.1 的受控流程先由 `build_stage4a7_2_r1_uncertain_engineering_prior.m` 从处理后的公共网络和合成不确定边构造 shared ledger，再生成约 204 个工程候选；经 `adapt_engineering_candidate_to_forward_model.m` 投影后，冻结评分库为 87 个候选。

实际流程为：

```text
受控参考图/公共处理模型
  -> uncertain engineering ledger
  -> node_ids + allowed/required/forbidden edges + prior cost
  -> constrained spanning-tree enumeration
  -> canonical graph identity
  -> stable single-path/first-level-branch compatibility adapter
  -> forward-compatible candidate objects
  -> Stage 4A CFR profile/scoring/candidate set
  -> Stage 5B.1 evidence-aware decision
```

因此，当前代码并非只会接收“完整拓扑列表”：枚举器本身已经使用部分边先验。但 formal benchmark 的 ledger 仍由隐藏参考图派生，尚未形成一个可由外部 partial prior 直接调用、带完整约束审计和统一导出的阶段接口。

## 3. 当前输入信息

`normalize_engineering_candidate_spec.m` 和现有实验实际使用的输入包括：

- `node_ids`：固定且全部必须进入连通树的节点集合；
- `allowed_edges`：允许边宇宙及名义长度、线缆类型、终端负载；
- `required_edges` / `forbidden_edges`；
- `switch_state`：`closed/required`、`open/forbidden`、`unknown/optional`；
- `maximum_degree`；
- `radial_only`、`require_connected`；
- `maximum_candidate_count`；
- `edge_prior_cost`、`prior_source` 和配置 hash；
- `source_node_id`、`receiver_node_id`，供 forward-model adapter 恢复主路径。

## 4. 已有工程约束

当前已实现：

1. 节点 ID 唯一、边端点合法、禁止自环；
2. required/forbidden 冲突检查；
3. required edge 必须属于 allowed edge universe；
4. 连通性与 spanning-tree 边数；
5. union-find 增量无环检查；
6. 最大节点度；
7. 重复无向边归一化与冲突属性拒绝；
8. 最大候选数保护；
9. deterministic canonical graph key；
10. 基于非负工程 prior cost 的 deterministic Top-K；
11. forward-model compatibility gate：只接受可表示为 TX--RX 单主路径加内部节点一层叶支路的树；
12. forward adapter 对正长度、线缆类型、支路负载和 round-trip graph identity 做检查。

## 5. 当前不足

1. `node_ids` 是固定全集，缺少 required/optional node 与节点数范围；未知节点是否存在不能直接枚举。
2. ledger 虽保存 `length_lower_m/length_upper_m`，但工程枚举规范只保留名义 `length_m`，没有把长度区间作为候选约束元数据贯穿到导出。
3. 没有显式 `maximum_branch_count`；现有通用枚举器只能通过节点/度/边宇宙间接限制。
4. 工程候选输出与 `build_composite_topology_library` 所需的 `topology_id/canonical_key/network` 接口之间仍需实验内手工补字段。
5. 工程可行图和 forward-compatible 图是两层集合；复杂树可被生成但不能进入当前单主路径/一层支路正向模型。
6. 当前 formal uncertain ledger 由 hidden reference graph 构造，适合受控 benchmark，但尚未证明能够直接消费独立 GIS/台账/开关 partial prior。
7. 当前没有独立 Stage 6A 结果表同时报告 candidate count、coverage、generation runtime 和 downstream four-state decision。
8. 当前没有统一接口允许 old candidate library 与 partial-prior generated library 在同一小型实验中切换比较。

## 6. Stage 6A 修改目标

Stage 6A 不重写现有 spanning-tree 枚举器，而是在其上新增可解释的 orchestration layer：

```text
partial prior
  -> generate_candidate_topologies
  -> apply_topology_constraints
  -> rank_candidate_complexity
  -> export_candidate_library
  -> existing Stage 4A forward/profile interface
  -> existing Stage 5B.1 decision functions
```

新增层应：

- 支持 required/optional nodes 与节点数范围；
- 复用 required/forbidden/switch/degree/connected/radial constraints；
- 显式检查线路名义长度是否处于声明区间；
- 显式限制 source--receiver 主路径之外的最大侧支路数；
- 保留 engineering prior cost 与确定性排序；
- 只通过独立 export/adapter 生成现有 forward-model candidate format；
- 保持旧库与新库可切换，不修改 Stage 4A 和 Stage 5B.1 文件；
- 用受控小规模实验报告 coverage、候选数、生成时间和下游四状态结果，不把仿真写成现场验证。

## 7. 审查结论

Stage 6A 的合理贡献不是首次引入约束图枚举，而是把现有分散能力升级为一个显式 partial-prior candidate-generation framework：补足可选节点、节点数范围、长度区间、最大分支、复杂度排序和兼容导出，并建立与旧库及下游判决层的可复现实验接口。
