# Stage 6B 开工前项目审查

审查日期：2026-09-23

## 1. 当前研究流程

当前可运行链路为：

```text
受控 partial prior
  -> Stage 6A candidate generation
  -> engineering constraints / ranking / forward-compatible export
  -> Stage 4A existing CFR template and profile distance
  -> calibrated candidate set and residual/domain gate
  -> Stage 5B.1 margin / normalized confidence / entropy
  -> UNIQUE_CONFIDENT / MULTIPLE_AMBIGUOUS / LOW_CONFIDENCE / REJECTED
```

Git 审查结果：

- 当前分支：`main`，跟踪 `origin/main`；
- 当前 HEAD：`50267e30da9f3d42789d12c6b3fdfead85ac0c86`（Stage 5B.1）；
- Stage 4A freeze：`9611b284da57bd10cd64ee7e48c7ba9f3ec46a92`；
- Stage 6A 当前没有独立 commit，其代码、结果和报告位于未提交 working tree；
- `tests/run_tests.m` 已因 Stage 6A 注册测试而修改，其余 Stage 6A 文件均未跟踪；
- 本阶段必须保留这些修改，不得通过 reset/checkout 覆盖。

## 2. Stage 6A 新增能力

Stage 6A 在现有 engineering spanning-tree generator 上新增统一 partial-prior orchestration：

1. required/optional nodes 与节点数范围；
2. allowed/required/forbidden edges；
3. closed/open/unknown switch state；
4. connected、radial、acyclic、maximum degree；
5. 单边长度区间、总长度范围和 maximum branch count；
6. 可解释 complexity/prior ranking；
7. `topology_id/canonical_key/network` 兼容导出；
8. 与旧 7 候选库及 Stage 4A/Stage 5B.1 下游接口的受控比较。

Stage 6A 正式结果显示：broad prior 复现旧 7 个网络；informative prior 将候选缩为 2 个且保留真拓扑；一个 stale-open prior 排除真拓扑后，受控测试 9/9 被拒绝。该单一案例不足以建立一般 robustness 结论。

## 3. 当前主要风险

1. **错误先验风险**：wrong-open 可删除真实边，wrong-closed 可迫使错误边和节点进入候选；目前只验证一个 stale-open 案例。
2. **候选规模风险**：candidate count 增大将同时影响生成、CFR template cache、profile scoring 和 normalized entropy；当前只有 2/4/7 个候选对比。
3. **参数域风险**：Stage 6A calibration 只覆盖主线 scale `[0.98,1,1.02]`，尚未系统测试 ±5%、±10%、±20% 长度误差和负载扰动。
4. **漏真拓扑风险**：候选库不含 truth 时，residual gate 不保证对所有样本拒绝；错误候选仍可能在有限噪声下获得单例接受。
5. **天然不可辨识风险**：T3/T5 已证明指定匹配端接 SISO 条件下两拓扑可等价，但尚无三候选近似/等价 positive control。
6. **校准可迁移性风险**：Stage 5B.1 formal threshold 属于冻结 87-candidate benchmark；候选库变化时不能直接解释为通用常数。
7. **forward representation 风险**：当前 adapter 仅支持 TX--RX 单主路径及内部节点一层叶支路。
8. **证据范围风险**：现有结果均为模型内部受控仿真，不是现场或硬件验证。

## 4. 本阶段实验目标

Stage 6B 不修改候选生成或判决公式，只对输入和受控 truth/observation 施加扰动：

1. **Prior sensitivity**：在 0%、5%、10%、20% 标称 error-rate 条件下，分别构造 deterministic wrong-open 和 wrong-closed 扰动，记录 coverage、candidate count、状态分布和 false unique。
2. **Candidate scale**：构造 small/medium/large 候选库，分别记录 candidate generation、template scoring runtime 和四状态分布。
3. **Parameter uncertainty**：保持 truth topology 不变，对主线长度施加 0、±5%、±10%、±20%，并叠加可复现负载扰动，记录 residual distance、margin、confidence、entropy 和状态。
4. **Identifiability**：重用 T3/T5 两候选等价正控制，并构造三候选近似 CFR 正控制，输出 pairwise distance matrix 摘要、candidate gap、margin、entropy 和四状态。

所有 calibration 与 test observation 必须分离。Stage 6B 可针对其受控候选库建立独立 calibration-only model，但不得覆盖或称为 Stage 4A/Stage 5B.1 frozen threshold。

## 5. 预计修改文件

新增：

- `config/stage6b_robustness_config.m`
- `src/stage6b_build_candidate_library.m`
- `src/stage6b_calibrate_candidate_library.m`
- `src/stage6b_evaluate_observation.m`
- `src/stage6b_network_signature.m`
- `experiments/exp_stage6b_prior_sensitivity.m`
- `experiments/exp_stage6b_candidate_scale.m`
- `experiments/exp_stage6b_parameter_uncertainty.m`
- `experiments/exp_stage6b_identifiability.m`
- `experiments/exp_stage6b_robustness.m`
- `run_stage6b_robustness.m`
- `tests/test_stage6b_robustness.m`
- `results/data/stage6b/*`
- `results/figures/stage6b/*`
- `docs/stage6b_technical_review_report.md`

修改：

- `tests/run_tests.m`：只注册 Stage 6B 定向测试；
- `docs/PROJECT_STATE.md`：记录 Stage 6B 结果与限制。

明确不修改：

- Stage 4A frozen thresholds、canonical results 和核心 forward/profile source；
- Stage 5B.1 margin/confidence/entropy/decision formulas 与 formal results；
- Stage 6A candidate-generation logic。
