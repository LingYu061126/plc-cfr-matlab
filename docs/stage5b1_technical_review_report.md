# Stage 5B.1 Objective Confirmation Upgrade Technical Review

审查日期：2026-09-23

审查性质：基于当前仓库代码、跟踪文档和既有实验结果的静态技术审查；本报告未修改 MATLAB 代码、未修改实验结果、未重跑实验。

证据标签：

- **[implemented]**：当前代码或配置中已实现、可定位到具体语句；
- **[verified by experiment]**：当前仓库的既有 CSV/MAT 结果或冻结 ledger 直接支持；
- **[not yet verified]**：当前代码与结果尚不能支持，或仅有设计意图而无独立验证。

## 0. 开始前项目状态核对

### 0.1 Git 状态

- **[implemented]** 审查开始时当前分支为 `main`，当前提交为 `50267e30da9f3d42789d12c6b3fdfead85ac0c86`（`feat: add Stage 5B.1 objective confirmation`）。
- **[implemented]** 审查开始时 `git status --porcelain=v1 --branch --untracked-files=all` 仅输出 `## main...origin/main`，即跟踪文件、未跟踪文件均无待处理项，本地与 `origin/main` 同步。
- **[implemented]** 本报告生成后，唯一工作区变化为未跟踪文件 `docs/stage5b1_technical_review_report.md`；本任务不提交、不推送。

### 0.2 Stage 4A freeze 与 canonical source

- **[implemented]** 指定 Stage 4A baseline 为 `9611b284da57bd10cd64ee7e48c7ba9f3ec46a92`（`stage4a: archive clean-source freeze closure`）。
- **[verified by experiment]** Stage 4A canonical formal 结果中的 `git_head_at_run` 为 `54868370cc6c426f417681146caace79de782e91`，`git_dirty_at_run=0`，`canonical_eligible=1`；来源见 [`summary.csv`](../results/data/stage4a_freeze_r1_1/stage4a7_3/formal/summary.csv)。该提交是本项目指定的 canonical source。
- **[implemented]** Git 历史关系为 `5486837 -> 9611b28 -> 50267e3`；`5486837` 是 freeze 提交的祖先，Stage 5B.1 提交是 freeze 提交的直接后继。
- **[implemented]** 从 `9611b28` 到当前提交，Stage 4A 的冻结结果目录、Stage 4A 核心算法、Rule A/Rule B 配置和既有结果未被改写。Stage 5B.1 从冻结 summary、candidate model、Rule A domain model 和 ledger 读取输入，并在其后增加 margin、normalized confidence score、entropy 与四状态判决；见 [`exp_stage5b1_objective_confirmation_upgrade.m`](../experiments/exp_stage5b1_objective_confirmation_upgrade.m#L10-L34) 和 [`classify_stage5b1_decision_state.m`](../src/classify_stage5b1_decision_state.m#L3-L20)。因此，**Stage 5B.1 是建立在冻结框架上的 add-only decision layer**。
- **[not yet verified]** 配置文件记录了 `expected_freeze_commit` 和 `expected_canonical_source_commit`，但当前实验函数没有读取或断言这两个字段；提交关系由本次 Git 审计确认，而不是由 Stage 5B.1 runner 在运行时强制验证。runner 实际强制验证的是候选数量、Rule A 方法/阈值，以及逐样本距离、候选集合、域判定和 observation hash。

### 0.3 Stage 5B.1 提交的文件范围

**[implemented]** `9611b28..50267e3` 共修改 20 个文件，其中新增 17 个、修改 3 个。

Stage 5B.1 直接相关新增文件：

1. `config/stage5b1_objective_confirmation_config.m`
2. `docs/stage5b1_project_audit.md`
3. `docs/stage5b1_objective_confirmation_upgrade.md`
4. `experiments/exp_stage5b1_objective_confirmation_upgrade.m`
5. `run_stage5b1_objective_confirmation_upgrade.m`
6. `src/calibrate_stage5b1_decision_metrics.m`
7. `src/classify_stage5b1_decision_state.m`
8. `src/compute_candidate_confidence.m`
9. `src/compute_candidate_margin.m`
10. `tests/test_stage5b1_decision_metrics.m`
11. `results/data/stage5b1/formal/stage5b1_calibration.csv`
12. `results/data/stage5b1/formal/stage5b1_decision_metrics.csv`
13. `results/data/stage5b1/formal/stage5b1_runtime.csv`

同一提交中还新增了 4 个 Stage 4A 辅助/说明文件，它们不是 Stage 5B.1 判决算法的一部分：

1. `run_stage4a6_3_1_power_mode_subset.sh`
2. `run_stage4a6_3_1_profile_calibration.m`
3. `run_stage4a6_3_1_profile_smoke.m`
4. `results/data/stage4a7_2_tier2_v2/README.md`

修改文件为 `.gitignore`、`README.md` 和 `tests/run_tests.m`。其中 `tests/run_tests.m` 只增加 Stage 5B.1 定向测试调用；`.gitignore` 排除可再生的大型详细结果。

**[implemented]** 当前 Git 跟踪的 Stage 5B.1 formal 结果只有上述 3 个紧凑 CSV。`candidate_margin.csv`、`candidate_confidence.csv`、`enhanced_decision_summary.csv` 和 `stage5b1_results.mat` 当前存在于本地，但被 `.gitignore` 排除，不属于提交 `50267e3`。本报告的汇总结论优先使用已跟踪 CSV；涉及单样本细节时明确注明本地详细文件来源。

## 1. 项目背景

**[implemented]** Stage 4A 已建立以下流水线：工程候选拓扑生成、物理正向 CFR 模板/profile、候选距离评分、候选级经验校准接受，以及 Rule A 参数域 residual gate。当前冻结空间为 87 个正向模型兼容候选，每个候选 243 个参数模板；该数字由项目审计文档和 Stage 5B.1 的候选数断言共同给出。

**[implemented]** Stage 4A 并非单纯输出 minimum-distance winner。它能够输出经验校准后的单候选、多候选或空集合，并通过 Rule A 拒绝超出冻结参数域的观测。然而，“冻结候选集合为单例”仍不能证明最优候选相对第二候选有充分分离证据，也不能证明物理拓扑唯一。

**[verified by experiment]** T3/T5 匹配端接 SISO 正控制显示了这一风险：Stage 4A 在无噪声和 30 dB 下均为 `0/40` false unique，但在 10 dB 下出现 `1/40` false unique。

**[implemented]** Stage 5B.1 的目标是在不改变 Stage 4A candidate set 和 Rule A gate 的前提下增加 evidence-aware confirmation layer，从而增强不确定场景表达能力。它不声称“解决拓扑唯一识别”，也不以增加唯一输出数量为目标。

## 2. Stage4A baseline review

### 2.1 输入、候选、距离与输出

**[implemented]** 对观测信道频率响应（channel frequency response, CFR）$H_{\mathrm{obs}}$ 和候选拓扑 $G_i$，Stage 4A 在候选 $i$ 的离散参数模板中取最小复 CFR 均方根距离：

$$
d_i=\min_{\theta\in\Theta_i}
\sqrt{\frac{1}{K}\sum_{k=1}^{K}
\left|H_{\mathrm{obs}}[k]-H(G_i,\theta)[k]\right|^2}.
$$

实现见 [`stage4a7_2_r1_profile_distance.m`](../src/stage4a7_2_r1_profile_distance.m#L11-L41)。若有多个观测 view，代码再对各 view 距离取均方根聚合。

**[implemented]** 候选接受不是单一 $d_i$ 阈值。冻结候选模型按候选级 calibration 分布计算经验 $p$ 值：

$$
p_i=\frac{1+\#\{z\in\mathcal C_i:z\ge s_i\}}
{N_i+1},
$$

并以 $p_i>\alpha$ 形成 candidate set；见 [`stage4a7_2_r1_apply_profile_candidate_set.m`](../src/stage4a7_2_r1_apply_profile_candidate_set.m#L3-L17)。随后 Rule A 对 `profile_relative_distance` 应用阈值 `0.110340450651554`，超阈值时拒绝；见 [`stage4a7_3_apply_domain_model.m`](../src/stage4a7_3_apply_domain_model.m#L3-L11) 和冻结 [`parameter_domain_calibration.csv`](../results/data/stage4a_freeze_r1_1/stage4a7_3/formal/parameter_domain_calibration.csv)。

**[implemented]** Stage 4A baseline 输出可归纳为：

```text
H_obs
  -> 对每个 G_i 计算 profile distance d_i
  -> 候选级经验校准 p_i > alpha
  -> frozen candidate set
  -> Rule A absolute/domain residual gate
  -> UNIQUE / AMBIGUOUS / REJECTED
```

### 2.2 已有优势

- **[implemented]** 物理模型驱动：候选评分来自传输线/网络正向 CFR，而非仅用黑箱标签分类。
- **[implemented]** 可拒绝：空候选集合或 Rule A 参数域 gate 失败可输出拒绝。
- **[implemented]** 支持非唯一：冻结候选集合可保留多个相容候选，而不是强制 Top-1。
- **[verified by experiment]** canonical formal 分离了 development（783）、calibration（3480）和 Pilot（783）场景，并保存了源提交、hash、环境和运行信息。

### 2.3 已有不足

- **[implemented]** baseline candidate set 没有直接报告 Top-1/Top-2 距离差异。
- **[implemented]** baseline 没有候选全集上的归一化集中度和熵表达。
- **[verified by experiment]** 冻结单例可能仍是物理等价候选中的 false unique；T3/T5 的 10 dB 样本 `r73_non_10_26` 是正控制实例。
- **[not yet verified]** 单候选不能被解释为物理唯一；当前结果只证明在给定候选库、参数网格、频带、端口与噪声模型下的相容性。

## 3. Stage5B.1 方法设计

### 3.1 Candidate margin

**[implemented]** 对稳定排序后的候选距离 $d_1\le d_2\le\cdots$，定义：

$$
\Delta=d_2-d_1.
$$

代码以“距离、原候选次序”联合稳定排序，距离相等时由候选次序打破排序并保留零 margin；见 [`compute_candidate_margin.m`](../src/compute_candidate_margin.m#L15-L23)。

**[implemented]** margin 只衡量最佳候选与次佳候选的相对分离程度。它不能替代 absolute residual、经验候选集合或 Rule A 参数域 gate；`REJECTED` 判定仍先于 margin。

### 3.2 Normalized confidence score

**[implemented]** 代码使用对最小距离平移后的指数权重：

$$
s_i=\exp[-\beta(d_i-d_1)],\qquad
p_i=\frac{s_i}{\sum_j s_j}.
$$

平移 $d_i-d_1$ 只提高数值稳定性，不改变归一化结果。实现见 [`compute_candidate_confidence.m`](../src/compute_candidate_confidence.m#L12-L23)。

**[implemented]** $p_i$ 的正确名称是 **normalized confidence score**。它是距离经温度缩放后的辅助相对权重，代码显式记录 `normalized_confidence_score_not_posterior_probability`；它不是 Bayesian posterior，也没有经过概率校准或似然模型推导。

### 3.3 Entropy

**[implemented]** 代码同时计算原始熵和按候选数归一化的熵：

$$
H=-\sum_i p_i\log p_i,
\qquad
H_{\mathrm{norm}}=\frac{H}{\log M}.
$$

当 $M>1$ 时，$H_{\mathrm{norm}}\in[0,1]$；高值表示权重分散、多个候选竞争，低值表示权重集中。判决实际使用的是 `normalized_entropy`，不是原始 $H$；见 [`compute_candidate_confidence.m`](../src/compute_candidate_confidence.m#L15-L20)。

## 4. Decision state

**[implemented]** 代码先定义：

$$
\texttt{residual\_accepted}
=\texttt{domain\_accepted}\land
(\texttt{candidate\_set\_size}>0),
$$

并分别检查：

$$
\Delta\ge\tau_\Delta,
\quad p_1\ge\tau_p,
\quad H_{\mathrm{norm}}\le\tau_H,
\quad \text{Top-1}\in\mathcal C_{\mathrm{frozen}}.
$$

全部新增证据通过时 `evidence_sufficient=true`。精确实现见 [`classify_stage5b1_decision_state.m`](../src/classify_stage5b1_decision_state.m#L6-L27)。

| 状态 | 代码触发条件 | 解释边界 |
|---|---|---|
| `REJECTED` | `~domain_accepted` 或 frozen candidate set 为空 | 优先级最高；任何 soft score 都不能撤销冻结拒绝 |
| `UNIQUE_CONFIDENT` | residual accepted；frozen set 大小为 1；margin、Top-1 score、normalized entropy 全通过；Top-1 位于 frozen set | 仅表示当前模型和候选库下证据较充分，不等于物理唯一 |
| `MULTIPLE_AMBIGUOUS` | residual accepted；frozen set 大小大于 1；新增证据不足 | 显式保留多个相容候选之间的竞争 |
| `LOW_CONFIDENCE` | residual accepted，但不满足以上三种分支 | 包括证据不足的 frozen singleton，以及多候选但 soft evidence 意外集中的混合情况 |

**[implemented]** 多候选即使 soft score 很集中也不会升级为 `UNIQUE_CONFIDENT`；按代码会落入 `LOW_CONFIDENCE`。因此 softmax 层不能覆盖 Stage 4A 的多候选语义。

## 5. Calibration strategy

### 5.1 数据来源与泄漏控制

- **[implemented]** 新证据阈值只读取 Stage 4A 已冻结的 `calD`/`cal` calibration split，共 3480 行；实验入口没有把 development 或 Pilot 距离传给校准函数，见 [`exp_stage5b1_objective_confirmation_upgrade.m`](../experiments/exp_stage5b1_objective_confirmation_upgrade.m#L18-L34)。
- **[implemented]** 参考样本要求：稳定 Top-1 等于已知 truth、冻结 Stage 4A candidate set 为单例、margin 有限且大于 0；见 [`calibrate_stage5b1_decision_metrics.m`](../src/calibrate_stage5b1_decision_metrics.m#L11-L15)。formal 中得到 834 个参考样本。
- **[implemented]** Stage 5B.1 阈值校准未使用 development split；development 仅属于既有 Stage 4A 方法/Rule A 选择流程。
- **[implemented]** Stage 5B.1 阈值校准未使用 Pilot、OOD 类别标签或 T3/T5 测试结果；输出元数据为 `pilot_used_for_calibration=0`。
- **[not yet verified]** 校准函数本身没有接收或断言 split ID，而是信任调用者传入 calibration 数组。当前官方实验调用路径避免了 Pilot leakage，但通用 API 层没有额外的 split 身份防护。

### 5.2 阈值规则与冻结值

**[implemented]** 分位数使用排序后第 `ceil(q*N)` 个样本，不做插值；温度由参考 margin 中位数映射到两候选 9:1 权重比：

$$
\beta=\frac{\log 9}{\operatorname{median}(\Delta_{\mathrm{ref}})}.
$$

**[verified by experiment]** [`stage5b1_calibration.csv`](../results/data/stage5b1/formal/stage5b1_calibration.csv) 给出的 formal 冻结值为：

| 项目 | 值 |
|---|---:|
| calibration 样本数 | 3480 |
| reference 样本数 | 834 |
| reference margin 中位数 | 0.0017791862665657 |
| $\beta$ | 1234.96039657356 |
| margin 5% 分位阈值 | 0.000494626468155172 |
| Top-1 score 5% 分位阈值 | 0.474848734540424 |
| normalized entropy 95% 分位上限 | 0.341676935875114 |
| evidence calibration hash | `2543850db72814ac88a04e798cf6cce980ccccea706a8ba3e630236cf4e478ac` |

**[not yet verified]** 这些阈值没有被验证为跨候选库、跨频带、跨线路参数域或现场通用常数；候选库、距离、频带或观测配置变化后需要重新冻结。

## 6. Experiment design

### 6.1 Pilot：in-domain 与 OOD

**[implemented]** formal 重放 87 个冻结候选，每个候选覆盖 9 类 Pilot，共 783 个样本：

- `in_domain`；
- `exact_lower_boundary`、`exact_upper_boundary`；
- `near_lower_ood`、`near_upper_ood`；
- `medium_lower_ood`、`medium_upper_ood`；
- `far_lower_ood`、`far_upper_ood`。

**[implemented]** 主线长度比例的域内边界为 `[0.95,1.05]`，near 为 `0.90/1.10`，medium 为 `0.75/1.30`，far 为 `0.60/1.60`；Pilot 观测使用 2–30 MHz、61 个频点、SISO forward、complex raw CFR 和 20 dB 频域圆对称复高斯噪声。来源见 [`stage4a7_3_domain_validation_config.m`](../config/stage4a7_3_domain_validation_config.m#L6-L28)。

### 6.2 T3/T5 非唯一正控制

**[implemented]** T3/T5 测试使用匹配端接 SISO 条件，噪声等级为无噪声、30 dB、10 dB，每档 40 个样本，共 120 个。

**[verified by experiment]** 冻结 [`nonunique_equivalence_audit.csv`](../results/data/stage4a_freeze_r1_1/stage4a7_3/formal/nonunique_equivalence_audit.csv) 报告 81 个模板上的最大 CFR 差异为 `8.47340948655004e-16`，低于 `1e-10` 数值容差。该结论仅是指定参数和观测条件下的正控制，不是 T3/T5 在所有配置下全局等价。

### 6.3 Baseline 与 comparison

- **[implemented]** baseline：冻结 Stage 4A candidate set + Rule A gate，输出 `UNIQUE/AMBIGUOUS/REJECTED`。
- **[implemented]** comparison：在完全相同的重放距离与冻结判决上增加 Stage 5B.1 evidence layer，输出四状态。
- **[implemented]** 每个 Pilot 样本都核对最小距离、relative distance、candidate set、domain decision 和 observation hash；T3/T5 样本核对 candidate set 和 observation hash。不一致即断言失败，见 [`exp_stage5b1_objective_confirmation_upgrade.m`](../experiments/exp_stage5b1_objective_confirmation_upgrade.m#L187-L198)。
- **[verified by experiment]** formal 状态为 `formal_completed`，串行、1 worker、未使用 `parfor`，总时间 `42.711753 s`；见 [`stage5b1_runtime.csv`](../results/data/stage5b1/formal/stage5b1_runtime.csv)。
- **[not yet verified]** 本实验是 MATLAB 仿真/确定性重放，不是现场 PLC 测量或硬件验证。

## 7. Results

### 7.1 Decision distribution

**[verified by experiment]** 下表为 783 个 Pilot 样本，来源是 [`stage5b1_decision_metrics.csv`](../results/data/stage5b1/formal/stage5b1_decision_metrics.csv) 的 `pilot,ALL` 行。

| method | unique | ambiguous | rejected | low confidence |
|---|---:|---:|---:|---:|
| Stage 4A baseline | 176 | 323 | 284 | 不适用 |
| Stage 5B.1 | 161 | 305 | 284 | 33 |

**[verified by experiment]** Stage 5B.1 的 ambiguity/证据不足合计为 `305+33=338`，比 baseline ambiguous 323 多 15；可信唯一减少 15。该变化表示更保守的证据表达，不能单独解释成拓扑识别率提升或下降。

**[verified by experiment]** 若把 120 个 T3/T5 样本也计入，runtime 汇总为：baseline `177 unique / 442 ambiguous / 284 rejected`；Stage 5B.1 为 `161 unique-confident / 424 multiple-ambiguous / 34 low-confidence / 284 rejected`。

### 7.2 False unique

**[verified by experiment]** false unique 结果如下：

| scenario | baseline | Stage 5B.1 |
|---|---:|---:|
| Pilot 全部类别 | 76/783 | 68/783 |
| T3/T5 全部 SNR | 1/120 | 0/120 |
| T3/T5 无噪声 | 0/40 | 0/40 |
| T3/T5 30 dB | 0/40 | 0/40 |
| T3/T5 10 dB | 1/40 | 0/40 |

**[verified by experiment]** T3/T5 的 baseline false-unique 样本是 `r73_non_10_26`：冻结 ledger 只接受 `T5`，但 truth equivalence set 是 `T3,T5`。本地详细输出显示 $d(T3)=d(T5)=0.181480139666078$、margin 为 0、Top-1 score 为 0.5、normalized entropy 为 1，增强状态为 `LOW_CONFIDENCE`。聚合后的 `1/40 -> 0/40` 已由跟踪的 metrics CSV 支持；逐样本增强记录位于本地被忽略的 `enhanced_decision_summary.csv`。

**[not yet verified]** 这一正控制只证明本层能纠正指定 T3/T5 条件下的一个 false unique；不能外推为所有物理非唯一拓扑均可被检出。

### 7.3 OOD

**[verified by experiment]** Stage 5B.1 没有改变冻结拒绝门，因此各 OOD 类别的 rejected 数完全不变：

| OOD category | baseline rejected | Stage 5B.1 rejected | baseline false unique | Stage 5B.1 false unique |
|---|---:|---:|---:|---:|
| near lower | 11 | 11 | 9 | 6 |
| near upper | 19 | 19 | 6 | 4 |
| medium lower | 45 | 45 | 18 | 18 |
| medium upper | 43 | 43 | 19 | 17 |
| far lower | 68 | 68 | 16 | 16 |
| far upper | 79 | 79 | 7 | 7 |

**[verified by experiment]** 因此，Stage 5B.1 **没有提高 OOD rejection capability**。它在 near lower、near upper 和 medium upper 中把部分 baseline 唯一输出降级，减少 false unique；但 medium lower 和 far OOD 的 false unique 没有改善。

**[not yet verified]** 更强的 OOD 检测需要新的 residual/domain 方法或独立物理观测；当前 margin/confidence/entropy 层没有实现该能力。

## 8. Code architecture

### 8.1 新增模块

- **[implemented]** `compute_candidate_margin()`：输入 $N\times M$ 候选距离与候选 ID，稳定排序并输出 Top-1、Top-2、$d_1$、$d_2$、margin。
- **[implemented]** `compute_candidate_confidence()`：输入候选距离、$\beta$ 与候选 ID，输出全候选 normalized confidence scores、Top-1 score、entropy、normalized entropy。
- **[implemented]** `calibrate_stage5b1_decision_metrics()`：从冻结 calibration split 筛选参考样本并冻结新增 evidence 阈值。
- **[implemented]** `classify_stage5b1_decision_state()`：组合 frozen candidate-set/domain gate 与新增 evidence，输出四状态及逐项通过标记。
- **[implemented]** `exp_stage5b1_objective_confirmation_upgrade()`：读取冻结输入、校准新增层、确定性重放、核对 Stage 4A、汇总并写出结果。
- **[implemented]** `run_stage5b1_objective_confirmation_upgrade()`：只负责路径注册和调用实验函数。

### 8.2 数据流

```text
Stage 4A frozen source
  |-- 87-candidate profile distances d_i
  |-- empirical candidate set
  |-- Rule A domain_accepted
  |
  +-> compute_candidate_margin(d)
  +-> compute_candidate_confidence(d, beta)
  +-> classify_stage5b1_decision_state(
        frozen set size,
        domain_accepted,
        Top-1 in frozen set,
        margin / Top-1 score / normalized entropy)
  +-> UNIQUE_CONFIDENT / MULTIPLE_AMBIGUOUS /
      LOW_CONFIDENCE / REJECTED
  +-> metrics and compact formal summaries
```

**[implemented]** `tests/test_stage5b1_decision_metrics.m` 覆盖四类定向情况：明显第一名、近似并列、全部拒绝，以及实际 T3/T5 数值等价。测试断言 T3/T5 不得输出 `UNIQUE_CONFIDENT`，但没有为每个 formal 类别逐行重算统计量。

## 9. Improvements compared with Stage4A

1. **从 best candidate 到 evidence-aware decision**
   **[implemented]** Stage 5B.1 不再只报告排序第一或冻结集合大小，还同时要求 Top-1/Top-2 分离度、候选全集权重集中度、熵和 Top-1 与冻结集合的一致性。

2. **从可能过度确定的单例到 uncertainty-aware output**
   **[implemented]** Stage 4A 本身已支持多候选和拒绝，因此并非所有场景都被 forced decision。Stage 5B.1 的新增价值更准确地说，是把“冻结 gate 接受但单例证据不足”的情况从 `UNIQUE` 降为 `LOW_CONFIDENCE`，并避免 soft score 把多候选强压成唯一。

3. **从 accuracy-oriented 汇总到 identifiability-aware evidence**
   **[implemented]** 输出新增 margin、normalized confidence score、entropy、false-unique 和 ambiguity/证据不足统计，使审查者能区分“最小距离候选”与“相对可分候选”。
   **[not yet verified]** 这些指标是可辨识性证据代理，不构成严格的全局可辨识性证明。

## 10. Limitations

1. **[implemented]** normalized confidence score 不是概率，更不是 Bayesian posterior；当前没有概率校准、先验或显式似然模型。
2. **[verified by experiment]** 决策依赖 834 个参考样本导出的经验分位阈值；改变候选库、距离、频带、端口或参数网格后不能直接复用。
3. **[implemented]** Stage 5B.1 继承 Stage 4A 参数域和 Rule A 限制，且不会增强 OOD 拒绝；formal rejected 数保持 284。
4. **[implemented]** 候选库限制仍存在：真实拓扑不在 87 个冻结候选中时，confidence 集中也不能证明答案正确。
5. **[not yet verified]** CFR 正向模型、频域复高斯噪声、理想同步和 SISO 观测尚未经过现场耦合器、AGC、脉冲噪声、时变负载和同步误差的联合验证。
6. **[verified by experiment]** T3/T5 等价只在匹配端接、指定 SISO、频带和参数条件下成立，不能外推到所有端口与端接。
7. **[implemented]** runner 记录但没有运行时断言预期 freeze/canonical commit；它通过输入文件、hash 和冻结判据一致性保护重放，但 Git 身份仍需外部审计。
8. **[implemented]** 校准函数不验证 split ID；当前官方调用没有 Pilot leakage，但其他调用者理论上可能传入错误 split。
9. **[implemented]** 逐样本 margin/confidence/decision 和轻量 MAT 当前被忽略、未纳入 Git；远端人工审查只能直接看到 3 个 compact CSV、代码和方法文档，不能仅靠远端仓库逐样本复算本报告全部细节。
10. **[not yet verified]** 当前没有证明 Stage 5B.1 提高完整拓扑识别率、边 F1 或真实系统性能；已验证的是特定 formal 集上的 false-unique 减少与不确定性表达变化。

## 11. Recommended next step

以下建议不在本任务中自动执行：

1. **[not yet verified] Robustness study**：固定当前决策层，系统评估负载时变、线路参数偏差、有色/脉冲噪声、同步误差和候选库遗漏对 margin、score、entropy 与 false unique 的影响。
2. **[not yet verified] Multi-view CFR**：增加独立测量端口、端接组合、输入导纳或反射观测，检查能否从物理上缩小 T3/T5 类等价集合；先做可辨识性与类间/类内距离分析，再决定是否改波形。
3. **[not yet verified] Threshold validation**：在独立于当前 3480 calibration 和 783 Pilot 的新场景上验证阈值稳定性，并为 confidence score 做可靠性分析，但不得把它改称 posterior probability。
4. **[not yet verified] Review packaging**：若需要远端逐样本人工审查，可单独设计小型、可追溯的 audit ledger 或压缩抽样证据；不要直接提交 16 MB confidence 长表或更大的历史数据。
5. **[not yet verified] Report writing**：把本阶段结论纳入导师材料时，应明确区分“冻结仿真重放已验证”“算法已实现”和“现场尚未验证”。

## Formula-code mapping

**[implemented]** 公式与代码对应如下。

| Method | Formula | MATLAB file | Function |
|---|---|---|---|
| Margin | $\Delta=d_2-d_1$ | `src/compute_candidate_margin.m` | `compute_candidate_margin()` |
| Shifted exponential weight | $s_i=\exp[-\beta(d_i-d_1)]$ | `src/compute_candidate_confidence.m` | `compute_candidate_confidence()` |
| Normalized confidence score | $p_i=s_i/\sum_j s_j$ | `src/compute_candidate_confidence.m` | `compute_candidate_confidence()` |
| Entropy | $H=-\sum_i p_i\log p_i$ | `src/compute_candidate_confidence.m` | `compute_candidate_confidence()` |
| Normalized entropy | $H_{\mathrm{norm}}=H/\log M$ | `src/compute_candidate_confidence.m` | `compute_candidate_confidence()` |
| Temperature calibration | $\beta=\log(9)/\operatorname{median}(\Delta_{\mathrm{ref}})$ | `src/calibrate_stage5b1_decision_metrics.m` | `calibrate_stage5b1_decision_metrics()` |
| Evidence thresholds | margin 5% quantile；Top-1 score 5% quantile；normalized entropy 95% quantile | `src/calibrate_stage5b1_decision_metrics.m` | `calibrate_stage5b1_decision_metrics()` |
| Residual acceptance | `domain_accepted && candidate_set_size > 0` | `src/classify_stage5b1_decision_state.m` | `classify_stage5b1_decision_state()` |
| Four-state decision | frozen gate + set size + margin/confidence/entropy + Top-1 membership | `src/classify_stage5b1_decision_state.m` | `classify_stage5b1_decision_state()` |
| Stage 4A profile distance | $d_i=\min_\theta\mathrm{RMS}(H_{obs}-H_i(\theta))$ | `src/stage4a7_2_r1_profile_distance.m` | `stage4a7_2_r1_profile_distance()` |
| Stage 4A candidate set | empirical $p_i>\alpha$ | `src/stage4a7_2_r1_apply_profile_candidate_set.m` | `stage4a7_2_r1_apply_profile_candidate_set()` |

## Result-source mapping

| Result | Source file | Experiment |
|---|---|---|
| Evidence calibration 样本数、阈值、hash、`pilot_used_for_calibration` | `results/data/stage5b1/formal/stage5b1_calibration.csv` | Stage 5B.1 formal calibration replay |
| Pilot decision distribution、分类别 false unique、ambiguity gain | `results/data/stage5b1/formal/stage5b1_decision_metrics.csv` | Stage 5B.1 formal Pilot replay |
| T3/T5 各 SNR baseline/enhanced false unique | `results/data/stage5b1/formal/stage5b1_decision_metrics.csv` | Stage 5B.1 formal T3/T5 replay |
| 总体计数、串行设置、runtime | `results/data/stage5b1/formal/stage5b1_runtime.csv` | Stage 5B.1 formal aggregate |
| Stage 4A candidate/development/calibration/Pilot 数量及 canonical run identity | `results/data/stage4a_freeze_r1_1/stage4a7_3/formal/summary.csv` | Stage 4A.7.3 canonical formal |
| Rule A 方法、3480 calibration 和阈值 | `results/data/stage4a_freeze_r1_1/stage4a7_3/formal/parameter_domain_calibration.csv` | Stage 4A.7.3 domain calibration |
| Stage 4A 783 个 Pilot 的 candidate set、domain decision、hash | `results/data/stage4a_freeze_r1_1/stage4a7_3/formal/paired_domain_validation.csv` | Stage 4A.7.3 Pilot |
| Stage 4A T3/T5 每样本 accepted set 与 false unique | `results/data/stage4a_freeze_r1_1/stage4a7_3/formal/nonunique_benchmark_ledger.csv` | Stage 4A.7.3 non-unique benchmark |
| T3/T5 数值等价容差与最大 CFR 差异 | `results/data/stage4a_freeze_r1_1/stage4a7_3/formal/nonunique_equivalence_audit.csv` | Stage 4A.7.3 equivalence audit |
| `r73_non_10_26` 的 margin、score、entropy 和增强状态 | 本地忽略文件 `results/data/stage5b1/formal/{candidate_margin,candidate_confidence,enhanced_decision_summary}.csv` | Stage 5B.1 formal detailed replay；未纳入 Git |

## Review conclusion

**[implemented]** Stage 5B.1 在冻结 Stage 4A candidate-set 与 Rule A residual gate 之后增加了独立、模块化、可测试的 evidence-aware decision layer，没有替换正向模型、候选库、经验候选集合或域判据。

**[verified by experiment]** 当前 formal 证据支持的核心结论是：Pilot false unique 从 76 降至 68；T3/T5 10 dB 正控制从 `1/40` 降至 `0/40`；Pilot rejected 保持 284，不确定/歧义表达从 323 增至 338。它增强了证据不足场景的表达，但没有提高 OOD rejection，也没有证明物理拓扑唯一识别。

**[not yet verified]** 在真实 PLC 硬件、复杂噪声、时变负载、候选库不完备和多端口观测下的有效性仍需后续独立验证。
