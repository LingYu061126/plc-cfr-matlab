# Stage 7A.1 参数校准与候选剖面判定诊断协议

2026-09-24 冻结诊断设计。验证基线为 `38fcced7eac5aa310b7604afebd1807619a05169`；Stage 7A 算法提交为 `64c2ec2258b14d4eb02d15b88cdbb6672e992548`。核对时 `main` 与 `origin/main` 均指向验证基线，工作树干净。本协议在新增诊断代码和运行新测试前写定。已有 Stage 7A 正式结果用于提出诊断问题，不用于调本协议中的阈值、搜索域或样本选择。

## 1. 只读静态审计

来源：`config/stage7a_profile_search_config.m`、`src/stage7a_{build_profile_cache,profile_distance,calibrate_candidate_library,score_observation}.m`、`experiments/exp_stage7a_profile_search.m`、`src/classify_stage5b1_decision_state.m`、`src/stage4a7_2_r1_apply_profile_candidate_set.m` 及 `results/data/stage7a/formal/stage7a_comparison.csv`。

- [代码直接确认] 规模对照按同一 20 dB 观测种子在 3/7/23 候选库上逐样本配对；长度尺度由 `[0.98,1.02]` 生成，负载尺度为 1。Stage 7A 校准为 35 dB，主线允许范围来自 `[0.90,1.10]`，负载尺度 `[0.80,1.20]`，正式样本每候选 20 个。这两个分布差异同时存在，当前结果无法分离其作用。
- [正式 CSV 直接确认] 30/30 最佳候选都是真值、false unique 为 0。small 10 例中 7 例正确 `UNIQUE_CONFIDENT`、2 例 `REJECTED`、1 例 `LOW_CONFIDENCE`；medium 为 8/10 正确唯一与 2/10 低置信度；large 为 4/10 正确唯一与 6/10 低置信度。每组仅 10 例，不能推断总体识别率。
- [正式 CSV 直接确认] `scale_small_r01` 的相对残差 `0.4120049714` 低于 domain 阈值 `0.4217704212`，但集合大小为 0；`scale_small_r07` 的残差 `0.4231805201` 略高于同一阈值，同时集合大小为 0。两例最佳候选仍是真值。状态 `REJECTED` 不能解释为候选选错。
- [代码直接确认] candidate set 的经验值为 `p_j=(1+#\{z_{jr}\ge d_j\})/(n_j+1)`，保留条件是 `p_j>alpha`。`n_j=20, alpha=0.05` 时测试行最低可达 `1/21<0.05`；校准行计算自身 p 值时至少计入自身，使其真值类 p 值至少为 `2/21>0.05`。当前代码随后在同一批距离上计算 `set_size`，用于筛选 Stage 5B.1 evidence 参考行。这种复用缺少独立评估；它对最终阈值的方向和幅度仍待实验验证。
- [代码直接确认] `candidate_set_size>1` 且其他 evidence 条件全通过时，现有冻结分类器落入 `LOW_CONFIDENCE`；只有多候选且 evidence 不充分时才是 `MULTIPLE_AMBIGUOUS`。本阶段记录该语义和分支，不改冻结定义。
- [代码直接确认] `stage7a_score_observation` 当前未检查传入 `search` 与校准模型/缓存是否一致；需要加身份拒绝。`safety.pass` 仅检查 false unique、库外误接受与两种非唯一正控制，不包含候选集合覆盖率或整体优越性。
- [待实验验证] 35/20 dB 噪声差、nuisance 分布差、20 条/候选的经验 p 值分辨率、同批校准复用、粗到细局部搜索及库增大后的候选竞争，各自可能改变集合与状态。以下独立对照拆分这些因素。

## 2. 固定数据划分和条件

候选库固定为 Stage 6B 的 3/7/23 grammar；Stage 6B 与 Stage 7A 共用每个测试观测。新的 20 dB 测试集每库 100 条、真值在库内、主线尺度均匀取 `[0.98,1.02]`、负载尺度固定为 1；三个库使用相同的 100 个独立测试种子。Stage 7A 已归档的每库 10 条另作逐样本重放审计，不参与新模型的任何校准。新测试种子基数为 `402671100`，候选集合校准为 `202671100`，evidence 校准为 `302671100`；条件偏移为百万量级，库偏移为十万量级，候选偏移为千量级，三组种子空间互不相交，并分别记录种子集身份哈希。Stage 6B baseline 使用原局部校准协议，另记录其来源身份。所有运行串行。

每个新 Stage 7A 诊断模型从同一候选 CFR 缓存计算两批互不重叠的合成观测：A 批只校准 candidate set 和 domain gate；B 批只用已固定的 A 模型计算 `set_size`，再校准四状态 evidence。最终测试 C 批与 A、B 均不相交。A/B 每候选样本数相等；`n=20` 如不满足预设 evidence 最低参考数，记录为不可校准，不放宽阈值或重复使用 C 批。

正式诊断条件预先固定如下。`n` 指 A 和 B 各自每候选样本数；测试 C 在各条件中相同。

| 条件 | A/B SNR | A/B 主线尺度 | A/B 负载尺度 | n |
|---|---:|---|---|---:|
| matched20_n20 | 20 dB | `[0.98,1.02]` uniform | 1 | 20 |
| matched20_n100 | 20 dB | `[0.98,1.02]` uniform | 1 | 100 |
| matched20_n200 | 20 dB | `[0.98,1.02]` uniform | 1 | 200 |
| snr35_n100 | 35 dB | `[0.98,1.02]` uniform | 1 | 100 |
| nuisance_broad20_n100 | 20 dB | `[0.90,1.10]` uniform | `[0.80,1.20]` uniform | 100 |
| combined_broad35_n20 | 35 dB | `[0.90,1.10]` uniform | `[0.80,1.20]` uniform | 20 |
| combined_broad35_n100 | 35 dB | `[0.90,1.10]` uniform | `[0.80,1.20]` uniform | 100 |

再以 Stage 7A 原同批复用的 35 dB、宽参数、20 条/候选模型作为归档方式参照。另固定原模型的 candidate-set/domain 校准，仅用全新的 B 批重新估计 evidence 阈值（`originalset_split_evidence_n20`），以审计同批复用；B 批可能带来有限样本波动，不能把单次差异写成已确认的因果效应。SNR-only 比较为 `matched20_n100` 与 `snr35_n100`；nuisance-only 比较为 `matched20_n100` 与 `nuisance_broad20_n100`；样本量比较为三个 `matched20`；原分布下拆分比较为 `combined_broad35_n20` 与原同批模型。不得依据 C 批结果修改上述条件。

## 3. 逐样本记录与判因规则

对归档 30 条和新 C 批逐条记录候选 ID、物理签名、排序、所有候选 profile distance 与 p 值、真值排名与集合纳入、集合大小、domain 相对残差与门槛、Top-1/Top-2 margin、normalized confidence score、entropy、各 evidence gate、最终四状态和 `decision_reason`。候选级长表与样本级宽表同时保留。`normalized confidence score` 不作为 Bayesian posterior 或跨库概率。

补充诊断：已知 `scale_small_r01` 与 `scale_small_r07` 可在所有预先固定的校准模型上再评分，单独标记为 `archived_counterfactual`；这是已知失败案例的探索性拆解，不计入新 C 批的预注册覆盖率或 Wilson 区间，也不反馈校准。

主失败码按判决优先序固定：真值库外、Top-1 非真值、真值 profile 距离明显高于同库观测噪声或 exhaustive 最小值、真值不在候选集合、domain gate 不通过、单候选 evidence gate 不通过、多候选竞争/状态语义。并列原因另列布尔字段；特别标明空集、domain 与 evidence 可以同时发生。不得把拒绝、歧义、低置信度统计为选错。

每组报告正确唯一、false unique、真值集合覆盖、domain 拒绝、候选集合大小与四状态计数，以 `k/n` 和 95% Wilson 区间列出二项指标；现有 `n=10` 与新独立 `n=100` 分开报告。报告模型字节数（MATLAB `whos`）、缓存建立、A/B 校准、测试评分与 exhaustive 审计 wall-clock；不把模型字节数称为进程峰值内存。

## 4. 穷举 fine-grid 与接口审计

对相同缓存、相同观测，另外扫描每个候选所有 admissible fine 模板，只读计算全局最小 CFR RMS。比较每候选距离、每样本最大距离差、Top-1 排名、候选集合、domain gate、四状态和判决原因；记录 coarse pivot 与全局最优模板位置及是否在原局部窗口内。两种距离按相同已固定模型判断，不重新校准，也不直接替换原搜索。若发生状态变化，列出每条样本；若不存在，也只对已审计样本/缓存下结论。

在 `stage7a_score_observation` 入口校验 search 域、缓存候选顺序/签名与校准模型身份，增加对混用 search、缓存和模型的定向测试。分类器的多候选分支另设状态语义测试，不修改 Stage 5B.1 源码。Stage 6 `tests/run_tests.m` 的归档字节哈希保持不变。

## 5. 运行与停止条件

先估时：Stage 7A 归档 23 候选、20 条/候选的一次校准约 0.60 s；正式最重的 `n=200` 分拆 A/B 对该库约 20 倍样本工作量，加七条件与 100 条测试，预计整个 MATLAB 计算为数分钟量级。smoke 先用每候选 4 条 A/B 和每库 2 条测试检查接口与输出；若 evidence 参考数不足，smoke 单独使用 Stage 6 既有的最低参考数 2 并记录，不由正式测试调整。正式运行前固定上述协议；若实际资源明显超出可接受范围，记录耗时与中止原因，不缩小正式样本以制造完成结论。

运行定向测试、smoke、正式诊断和相关 Stage 5B.1/6A/6B/Stage 6 archive 回归；日志存入 `results/logs/stage7a_1/`，表与配置身份写入 `results/data/stage7a_1/`。若发现候选库、真值或原 Stage 7A 逐样本重放身份不一致，停止结论并记录差异。安全门槛仍要求 false unique 不增加、库外误接受不增加、受控非唯一案例不强制唯一；是否提出下一轮算法修改还须看独立 C 批集合覆盖、正确唯一、拒绝/低置信度、Wilson 区间和资源代价。本阶段只诊断，不以受控合成模型结果外推现场台区或真实 PLC 收发机。
