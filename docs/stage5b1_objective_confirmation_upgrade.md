# Stage 5B.1：候选确认客观判据升级

## 为什么需要升级

Stage 4A 已经用冻结的候选级经验校准构造候选集合，并用 Rule A 的 `profile_relative_distance` 阈值判断观测是否落在冻结参数域内。它能够输出单候选、多候选或空集合，但“候选集合为单例”仍不等于“第一名相对第二名具有充分分离证据”。T3/T5 在 10 dB 下出现的 1/40 false unique 正是该风险的数值正控制。

Stage 5B.1 不重训或替换 Stage 4A，而是在其后增加只增不改的 evidence layer：

```text
冻结 Stage 4A 候选集合 + Rule A residual gate
  -> Top-1/Top-2 margin
  -> normalized confidence score
  -> entropy
  -> 四状态决策
```

目标不是增加唯一输出数量，而是减少错误唯一，并把证据不足显式降级。

## 与 Stage 4A 的关系

下列内容保持不变：

- Rule A 方法 `profile_relative_distance` 及阈值 `0.110340450651554`；
- Rule B 敏感性分析及阈值；
- 87 个正向模型兼容候选、每候选 243 个 profile 模板；
- development、calibration、Pilot 和 T3/T5 场景；
- Stage 4A 已有 CSV/MAT、随机种子、观测模型和候选确认模型。

Stage 5B.1 对 formal Pilot 和 T3/T5 场景进行确定性重放。每个样本均核对原 Stage 4A 的 observation hash、最小距离、候选集合和域判定；不一致即报错，不产生新结论。新增结果全部写入 `results/data/stage5b1/{smoke,formal}/`。

## 新增指标

设稳定排序后的候选距离为

$$
d_1\le d_2\le\cdots\le d_M.
$$

Top-1/Top-2 margin 定义为

$$
\Delta=d_2-d_1.
$$

margin 只描述相对分离度，不能绕过 Stage 4A 的绝对 residual/candidate-set gate。

normalized confidence score 定义为

$$
s_i=\exp[-\beta(d_i-d_1)],\qquad
p_i=\frac{s_i}{\sum_j s_j}.
$$

减去 $d_1$ 只是数值稳定变换，不改变归一化结果。这里的 $p_i$ 只称 normalized confidence score，**不是后验概率**。分散程度使用

$$
H=-\sum_i p_i\log p_i,
\qquad
H_{\mathrm{norm}}=\frac{H}{\log M}.
$$

## 新证据阈值的冻结方式

Stage 5B.1 只复用 Stage 4A 已冻结的 3480 个 calibration 样本，不修改这些数据，也不使用 Pilot、OOD 标签或 T3/T5 测试结果调参。参考样本定义为：真实 calibration 拓扑是稳定 Top-1，且冻结 Stage 4A 候选集合为单例。共得到 834 个参考样本。

- margin 阈值：参考 margin 的 5% 固定次序分位数；
- softmax 温度：令参考 margin 中位数对应两候选 9:1 权重比，$\beta=\log 9/\operatorname{median}(\Delta)$；
- Top-1 confidence 阈值：参考 Top-1 score 的 5% 分位数；
- normalized entropy 阈值：参考 normalized entropy 的 95% 分位数。

formal 冻结值为：

| 指标 | 值 |
|---|---:|
| 参考 margin 中位数 | 0.0017791862665657 |
| $\beta$ | 1234.96039657356 |
| margin 阈值 | 0.000494626468155172 |
| Top-1 confidence 阈值 | 0.474848734540424 |
| normalized entropy 上限 | 0.341676935875114 |
| evidence calibration hash | `2543850db72814ac88a04e798cf6cce980ccccea706a8ba3e630236cf4e478ac` |

这些阈值描述冻结 calibration 参考分布，不是跨线路、跨频带或现场通用常数。

## 四状态判定

1. `REJECTED`：冻结候选集合为空，或 Rule A 参数域 gate 拒绝。该状态优先级最高，任何软置信指标均不能撤销拒绝。
2. `UNIQUE_CONFIDENT`：冻结候选集合为单例，最优候选属于该集合，且 margin、Top-1 confidence、normalized entropy 三项全部通过。
3. `MULTIPLE_AMBIGUOUS`：冻结候选集合含多个候选，且新增分离/集中证据不足。
4. `LOW_CONFIDENCE`：冻结 gate 接受，但证据混合或不足；典型情况是原单例候选的 margin/entropy 不支持可信唯一。

当多个冻结候选通过但软分数意外集中时，仍不会输出 `UNIQUE_CONFIDENT`，而是保守输出 `LOW_CONFIDENCE`。因此 softmax 不能把 Stage 4A 多候选集合强制压成唯一候选。

## 实验结果

MATLAB R2024a formal 串行重放 783 个 Pilot 和 120 个 T3/T5 样本，用时 42.712 s；未使用 `parfor`。

### 全部 Pilot

| 指标 | Stage 4A baseline | Stage 5B.1 enhanced | 变化 |
|---|---:|---:|---:|
| 唯一/可信唯一 | 176 | 161 | -15 |
| 多候选 ambiguous | 323 | 305 | -18 |
| low confidence | 不适用 | 33 | +33 |
| rejected | 284 | 284 | 0 |
| false unique | 76 | 68 | **-8** |
| ambiguity/证据不足检出 | 323 | 338 | **+15** |

这里 ambiguity/证据不足检出在 enhanced 中合计 `MULTIPLE_AMBIGUOUS + LOW_CONFIDENCE`。唯一输出数量下降是预期的保守结果，不应解释成识别能力退化或提升；关键结果是 false unique 下降且拒绝语义未改变。

分类别看，false unique 的减少来自 exact upper boundary（1）、near lower OOD（3）、near upper OOD（2）和 medium upper OOD（2）。medium/far OOD 仍保留大量 false unique，说明 margin/confidence 只改善证据表达，不能替代更强的 OOD 检测或新增物理观测。

### T3/T5 非唯一正控制

| SNR | baseline false unique | enhanced false unique | enhanced 状态 |
|---|---:|---:|---|
| 无噪声 | 0/40 | 0/40 | 40 个 `MULTIPLE_AMBIGUOUS` |
| 30 dB | 0/40 | 0/40 | 40 个 `MULTIPLE_AMBIGUOUS` |
| 10 dB | 1/40 | **0/40** | 39 个 `MULTIPLE_AMBIGUOUS`，1 个 `LOW_CONFIDENCE` |

原 false-unique 样本为 `r73_non_10_26`。其冻结候选集合错误地只保留 `T5`，但物理距离满足 `d(T3)=d(T5)=0.181480139666078`，因此 margin 为 0、Top-1 confidence 为 0.5、normalized entropy 为 1。Stage 5B.1 将它从 `UNIQUE` 降为 `LOW_CONFIDENCE`，没有制造新的唯一拓扑结论。

## 输出与运行

运行命令：

```matlab
run_stage5b1_objective_confirmation_upgrade(pwd,'smoke')
run_stage5b1_objective_confirmation_upgrade(pwd,'formal')
```

formal 输出包括：

- `candidate_margin.csv`：903 个样本的 Top-1/Top-2、`d1`、`d2` 和 margin；
- `candidate_confidence.csv`：长表形式保存每个样本—候选的 normalized confidence score、rank 和样本 entropy；
- `enhanced_decision_summary.csv`：逐样本 baseline/enhanced 状态与证据通过标记；
- `stage5b1_decision_metrics.csv`：按 Pilot 类别和 T3/T5 SNR 汇总的 unique、ambiguous、rejected、false unique；
- `stage5b1_calibration.csv`：新增证据阈值、来源、hash 和禁止 Pilot 调参标记；
- `stage5b1_runtime.csv`、`stage5b1_results.mat`：运行摘要与轻量结果。

## 验证状态

- MATLAB R2024a 定向测试 `test_stage5b1_decision_metrics` 通过，覆盖明显第一名、两个接近、全部差和实际 T3/T5 数值等价四种情况。
- smoke 通过：18 个 Pilot 子集、12 个 T3/T5 子集，逐样本冻结结果核对通过，用时 3.266 s（最终复跑）。
- formal 通过：783 个 Pilot、120 个 T3/T5，逐样本冻结结果核对通过，用时 42.712 s。
- MATLAB Code Analyzer 对 8 个新增/修改的 Stage 5B.1 `.m` 文件返回 0 条消息。
- `tests/run_tests.m` 完整回归从 Stage 1.5 运行到 Stage 4A.7.3 均通过；随后 `test_stage4_freeze_r1_1` 按设计因当前开发工作树存在未提交跟踪修改而报 `Canonical formal requires a clean Git worktree`。这说明冻结洁净身份保护门有效，不是公式或数值测试失败。遵照本任务“不要 commit”和“保持 Stage 4A 不变”的要求，本阶段未绕过或修改该保护门；Stage 5B.1 定向测试已在其后单独通过。

## 限制与下一步

- normalized confidence score 是距离温度缩放后的相对权重，不具备贝叶斯后验概率含义。
- 新层不能解决候选库遗漏、模型偏差、near OOD 检出不足或真实 PLC 噪声/同步/耦合器失配。
- calibration 参考集本身来自当前仿真模型；分位阈值必须随候选库、距离定义、频带或观测配置变化而重新冻结。
- 当前热点是重新计算每个 Pilot 的 87×243 profile 距离。formal 串行仅 42.712 s，暂不值得为 `parfor` 重构；若未来扩展候选或 Monte Carlo 数量，应先评估缓存内存和 worker 复制开销。
- T3/T5 结果支持“降低指定正控制的错误唯一”，不证明所有真实非唯一拓扑都能被 margin/entropy 检出。若要从根本上缩小等价类，仍需增加独立测量端口、端接组合、输入导纳或反射观测。
