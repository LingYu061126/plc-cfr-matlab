# Stage 4A.7.1 修改前算法审计

| 审计项 | 修改前状态 | 证据文件/函数 | 本阶段处理 |
|---|---|---|---|
| 候选生成 | 旧入口 `generate_radial_topology_candidates` 只实现受限主线+一级支路 grammar；`generate_prior_constrained_candidates` 在旧候选上过滤 | `src/generate_radial_topology_candidates.m`、`src/generate_prior_constrained_candidates.m` | 保留旧入口；新增通用工程边集树枚举器，分离工程层和模型兼容层 |
| 是否枚举全部幂集 | 旧 grammar 使用 branch-count product，不是通用边集搜索 | `generate_radial_topology_candidates.m` | 新路线 A 使用 required/cycle/connectivity/degree/remaining-edge 剪枝，不生成完整边子集 |
| legacy 7 图 | Stage 4A.1/4A.2 测试冻结 7 图 ID、顺序、canonical key 和 T3/T5 等价 | `tests/test_stage4a1.m`、`tests/test_stage4a2_prior_constrained_library.m` | 新增 legacy adapter，只加元数据，不改旧候选结构 |
| 工程候选与正向模型兼容性 | 历史代码直接围绕可运行 network 构造候选，缺少独立 coverage-loss 层 | `src/generate_prior_constrained_candidates.m` | 新增 `check_forward_model_compatibility` 和 coverage audit |
| 观测确认 | Stage 4A.5.1 已有 residual/margin/subband/neighborhood/stability 确认器 | `src/match_candidate_library_calibrated.m`、`src/apply_candidate_confirmation.m` | 不删除旧确认器；新增 weighted residual、candidate set 和 calibrated indistinguishability 接口 |
| GLRT 语义 | 当前代码没有完整噪声似然定义 | `src/match_candidate_library_calibrated.m` | 新接口明确标记 `weighted_residual_only`；不冒称严格 GLRT |
| 多节点 tomography | 当前主流程是单端口复 CFR | Stage 4A.6.3.1-R.2 结果与当前观测配置 | 新增 capability gate；没有 pairwise matrix 则 `not_applicable` |
| 候选集合校准 | 历史确认使用独立阈值模型，但没有通用经验 p-value 候选集接口 | `src/calibrate_candidate_confirmation.m` | 新增 class-conditional empirical candidate set；校准不足返回 `insufficient_calibration` |
| 复杂度 | 旧模板库有固定数量，但没有统一的参数维数/模板数量审计接口 | `src/match_candidate_library_calibrated.m` | fast scorer 增加参数维数、模板数和 complexity audit 字段 |

## 当前科学解释

旧的 7 图不是“由现实 GIS 自动生成的全候选空间”，而是受限径向合成 grammar 的模型内候选库。新增路线 A 允许在明确的 `node_ids` 与 `allowed_edges` 上进行工程候选枚举；路线 B 暂实现确定性 exact-oracle Top-K prototype，不依赖 MILP 工具箱；路线 C 只验证 pairwise distance matrix 是否存在。

