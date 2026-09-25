# Stage 7A.3 候选库外拓扑可检测性审计报告

- 报告日期：2026-09-26
- 验证基线：`f1e1ed13f296b5e21267bf6aceda4199c8ee86f0`
- 验证环境：MATLAB R2024a `24.1.0.2537033`，`glnxa64`；串行，未启用并行池。

## 1. 结论摘要

Stage 7A.2 的 small 库 `94/100` 错误唯一已能逐样本复现，M2 与经库内风险门处理的 M2R 均一致。审计没有发现真值泄漏、候选 ID/索引错配或历史数值复现错误。对代表性 seed `560100001`，真值拓扑确实不在 3 候选库，但最近库内拓扑的无噪声复数 CFR 在本次单端口、等端接配置下与真值达到约 `4.2×10⁻¹⁶` 的相对 RMS 差；参数剖面分别优化后仍约 `3.0×10⁻¹⁶`。这属于“所测配置下数值近似难分”，不是解析证明的拓扑等价。

新增的四频带残差 gate 使用独立 F 校准集确定阈值，且只会保留原状态或拒绝、不会更改候选集合。它在公开的历史错误唯一集上只将错误唯一从 `94/100` 降至 `92/100`，没有达到预注册的至少 50% 降幅；在新的 topology-family 留出集上也没有减少 M2R 的 false unique。因此它**不作为已验证的库外拒识改进**。当前证据支持的判断是：在这个特定镜像拓扑上，主要障碍是观测响应重叠，而不是代码映射错误；其余拓扑的库外表现依库规模、SNR 和风险状态变化，不能概括为普遍可检测或不可检测。

所有结果均来自受控 MATLAB 合成模型，不是现场低压配网或真实 PLC 收发机验证。库内覆盖不等于库外可辨识；候选集合非空不等于真值存在；`UNIQUE_CONFIDENT` 不代表全局物理唯一；拒绝也不指出哪一条工程台账有误。

## 2. 基线、身份与审计边界

- 阶段开始时本地 `HEAD`、本地 `origin/main` 跟踪引用和 branch `main` 均为 `f1e1ed13f296b5e21267bf6aceda4199c8ee86f0`，工作树干净。当时尝试读取实时 GitHub `origin/main` 遇到 DNS 故障；归档前重新 `git fetch origin main --prune` 成功，远端仍为该提交。
- 新增源码及清单记载验证基线 commit；本轮最终正式运行源码清单为 `results/data/stage7a_3/formal/stage7a3_source_inventory.csv`，按仓库相对路径、SHA-256、字节数和验证时的 `git_tracked` 字段识别。正式运行发生在本阶段归档提交之前，因此新文件在该清单中标记为未跟踪。较早运行产物保留在 `results/data/stage7a_3/` 根目录，没有覆盖；最终通过完整性检查的 formal 产物位于 `formal/`，smoke 产物位于 `smoke/`。
- Stage 4A、5B.1、6A、6B、7A、7A.1、7A.2 冻结代码、配置和历史正式数值结果均只读。Stage 6 归档完整性测试通过。
- Stage 7A.2 formal 的 metadata `runtime_s=22.78305` 是出图前计时；历史 formal logs 的 `27.356–28.747 s` 是包含出图的结束计时。它们对应相同固定种子的不同计时边界/重跑，不是科学 CSV 数值冲突。本阶段未改写历史 metadata 或日志。

静态审计重点包括：

- `src/stage7a_profile_distance.m` 从候选缓存中返回每个候选的 profile distance 和 `best_template_indices`；`cache.H{candidate}(index,:)` 可取回拟合复数 CFR。
- `src/stage7a2_score_distances.m` 输入 observation、距离向量和校准模型，不接收 truth index/signature。新 gate `src/stage7a3_band_residual.m` 与 `src/stage7a3_apply_residual_gate.m` 也不接收真值。
- 实验在生成样本和计算审计标签时保留真值，但调用评分时只传观测、profile distances、缓存及校准模型；truth 只在评分之后用于统计。未发现真值流入判决函数。
- candidate ID、candidate signature、profile-distance 行按同一缓存顺序保存。3 个库的 100 个历史库外样本均逐样本重放；离散状态、集合、候选签名和 ID 映射一致，距离容差 `1e-12`。距离差绝对值在 `1e-12` 内时按稳定候选顺序处理，并另行记录近并列标记。

## 3. Stage 7A.2 失败重放与逐样本诊断

### 3.1 代表性样本 `seed=560100001`

small 库含 3 个候选：`G001` 无支路，`G002` 一条支路接在主线节点 2，`G003` 一条支路接在主线节点 1。库外真值是一条支路接在主线节点 3。对应签名为：

|对象|signature|profile distance|排名|经验候选 p 值|进入候选集合|
|---|---|---:|---:|---:|---|
|G001|`B=none`|0.194685794|3|0.0163934|否|
|G002|`B=2,15,1,50;`|0.124632739|2|0.0163934|否|
|G003|`B=1,15,1,50;`|0.037702391|1|0.8196721|是|
|库外真值|`B=3,15,1,50;`|不属于候选库|—|—|不适用|

该样本的 Stage 7A.2 M2/M2R 输出相同：候选集合 `{G003}`，`UNIQUE_CONFIDENT`，但 `best_is_truth=false`，属于错误唯一，不是候选排序或索引错误。逐项门槛如下：

|判据|观测值|阈值/条件|结果|
|---|---:|---:|---|
|候选集合大小|1|必须为 singleton|通过|
|domain relative distance|0.137205275|0.417429626|通过|
|Top-1/Top-2 margin|0.086930348|0.047661945|通过|
|normalized top-1 confidence|0.925247635|0.787233333|通过|
|normalized entropy|0.265094525|不高于 0.595158936|通过|
|M2R 独立风险门|库内 risk certificate 已通过|库内选择性风险上界 0.0386508 ≤ 0.05|通过，但不具库外认证效力|

错误来源的判决分支是 `singleton_and_all_evidence_checks_pass`。本样本没有距离并列；Top-1/Top-2 距离差约 `8.69×10⁻²`，远大于数值 tie 容差。

新 gate 的四个归一化子带残差是 `[0.0727830, 0.1375678, 0.1756913, 0.2255578]`，`r_max=0.2255578`，低于 F 集阈值 `0.6873459`，所以新 gate 也放行。新 gate 的结果依然是 `UNIQUE_CONFIDENT`、错误候选 G003。

### 3.2 三个历史未知结构的加噪距离与状态

下表的距离分位数来自 Stage 7A.2 原始 seeds 逐样本复现，均为 100 次复数 CFR 合成噪声观测；`d1/d2` 是库内候选最小/第二小 profile distance，并非库外真值自身的候选分数。

|候选库|历史未知 branch pattern|domain 通过|`d1` Q25/中位/Q75|`d2` Q25/中位/Q75|margin 中位|空集合|非空集合|M2 错误唯一|新 gate 错误唯一|
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|
|3|`[0,0,1]`|100/100|0.04875 / 0.07396 / 0.09609|0.12938 / 0.14018 / 0.15120|0.06632|4/100|96/100|94/100|92/100|
|7|`[0,0,2]`|92/100|0.06171 / 0.07259 / 0.08488|0.07160 / 0.08192 / 0.09273|0.00883|14/100|86/100|0/100|0/100|
|23|`[0,0,3]`|76/100|0.05406 / 0.07192 / 0.08260|0.05406 / 0.07192 / 0.08260|约 `1.39×10⁻¹⁷`|13/100|87/100|0/100|0/100|

small 库的 100 个样本全部通过 domain gate；其中 4 个候选集合为空，是集合校准分支的拒绝，并非 domain gate 拒绝。其余 96 个集合非空，94 个成为错误 singleton。medium/large 的候选竞争更明显：median margin 分别只有约 `8.83×10⁻³` 和数值近并列，未产生错误唯一。该差异符合“候选竞争/响应重叠与判决门槛”的解释，不符合候选映射 bug 的表现。

## 4. 无噪声 CFR 与剖面响应重叠

固定观测为 61 个频点、2–30 MHz 的单视角 SISO 复数 CFR，源与接收端阻抗均为 50 Ω。距离是复 CFR RMS；相对差以真值 CFR 的 RMS 归一化。真值在 45 个网格参数对上枚举：主线 length scale 为 `0.90:0.025:1.10`，支路 load scale 为 `0.80:0.10:1.20`；每个候选在同一 profile cache 的 `admissible{k}` 参数子集上搜索。该计算仅作诊断，真值参数未进入候选评分接口。数值等价门限预先定为 `max(abs(H1-H2))/RMS(Htruth) ≤ 1e-12`；超过/低于它只表示本配置数值比较结果，不构成解析拓扑等价证明。

|历史未知结构|固定相同参数的最近候选|固定参数绝对 RMS|固定参数相对 RMS|双方独立 profile 后最近候选|优化后绝对 RMS|优化后相对 RMS|1e-12 内数值等价|
|---|---|---:|---:|---|---:|---:|---|
|small `[0,0,1]`|G003|`1.1541×10⁻¹⁶`|`4.1989×10⁻¹⁶`|G003|`8.2229×10⁻¹⁷`|`2.9918×10⁻¹⁶`|是|
|medium `[0,0,2]`|G006|0.0527617|0.232434|G006|0.0416649|0.183548|否|
|large `[0,0,3]`|G003|0.0442784|0.227363|G018|0.0405788|0.208366|否|

small case 的真值与 G003 物理 signature 不同，分支位置相反；但在四段等长主线、单端到端 CFR、对称 50 Ω 端接及本次参数下，两条复响应达到机器精度附近的一致。其数值结果与端点反向/镜像网络响应近似相同的机制相容；本阶段没有做 ABCD 解析不变量证明，故只称“本配置下数值近似难分”。medium 与 large 的两个未知结构仍有显著非零 profile 距离；它们没有显示与 small 相同的数值等价证据。

历史 seed 的最优拟合复 CFR 及逐频残差保存在 `stage7a3_residual_spectra.csv`；各样本四个子带相对残差和 `r_max` 在 `stage7a3_sample_diagnostics.csv`。该残差描述“最佳库内模板对观测的拟合”，不直接识别某一条物理边或断言真值 topology。

## 5. 候选库外拓扑与数据划分

采用原有的一层径向 main-path grammar：四段 20 m 主线，允许主线节点 1–3 接入 15 m 侧支路，支路负载 50 Ω；每接入点不超过 3 条、总支路不超过 5 条、总节点不超过 10。扩展 grammar 在 `max_candidates=128` 下共枚举 44 个 branch-count vectors；上限未触发。3/7/23 候选库之外分别枚举到 41/37/21 个 topology signatures。最终从每个库外集合预注册留出 8 种不同结构：

`[3,0,0]`, `[0,3,0]`, `[3,1,0]`, `[3,0,1]`, `[1,3,0]`, `[0,3,1]`, `[2,2,1]`, `[2,1,2]`。

最终评估每结构分别有 30 个独立噪声重复，分为 20 dB 和 10 dB；每种候选库共 8 个独立物理结构、240 个观测。候选库之间使用配对的 topology family 和 noise seeds。每个 signature、branch pattern、候选 ID 顺序和是否被正式留出均见 `stage7a3_library_out_inventory.csv`。未进入八结构测试的同 grammar 结构仍列在 inventory 中：small/medium/large 分别还有 33/29/13 个；它们不是因 128 候选上限被截断，而是有限正式 holdout 清单没有覆盖。此 grammar 不包含深层侧支路、环路、不同电缆/负载类别或不同测量端口；这些是 grammar 边界，不是本次“剩余结构”的隐含验证。

数据划分与 seed base 在协议和 config snapshot 中冻结：D 每候选 20 条，F 每候选 200 条，独立风险审计 R 每候选 30 条，T 库内 20 dB 每候选 100 条，T 库内 SNR shift 10 dB 每候选 100 条，T 参数域外每候选 100 条，最终库外 8 topology × 每结构 30 条/每个 SNR。Stage 7A.2 已公开的 3 个历史未知结构及其 100 条重复只用于重放/开发；没有用于阈值拟合或最终八结构成绩。D/F/R/T 使用不同 seed base；F 是唯一拟合残差阈值的数据，T 未反馈到任一校准。

T 参数域外使用主线 scale `[0.82,0.88]` 与 `[1.12,1.18]`，而 profile search domain 是 `[0.90,1.10]`；这是一项明确的合成域外压力测试，不是现场允许误差。10 dB 是同参数支持域下的 SNR shift，不声称覆盖任意噪声/负载变化。

## 6. 拒识统计量与校准边界

唯一新增判据为最坏子带归一化复数残差 `r_max`：把 61 个频点按索引切成四段，逐段计算 `RMS(H_best−Y)/max(RMS(Y),eps)` 后取最大值。F 批在各候选库单独校准，使用 order statistic `ceil((n_F+1)×0.95)`；阈值分别为 small `0.6873459`、medium `0.6939022`、large `0.7127943`。F 批内阈值接受比例分别为 `571/600=95.17%`、`1331/1400=95.07%`、`4371/4600=95.02%`。这是同条件库内分布的边际校准；不是库外、逐 topology、SNR shift、parameter shift 或任意未知网络的拒识保证。

gate 保留原 candidate set，只允许决定状态不变或转为 `REJECTED`；不缩小集合、不升为 singleton、不把 `MULTIPLE_AMBIGUOUS` 强改成唯一。baseline M2/M2R 与新 gate 并列输出。Stage 7A.2 的 M2R 风险门由库内 R 观察得到：small 风险审计选出 76 个唯一输出且 0 错误，风险上界 0.03865，故 gate 被认证；这只解释其为何继续接受未知图，不对未知拓扑有效。

## 7. Formal 结果

### 7.1 历史 94/100 案例及独立新 family 测试

所有区间均为 95% Wilson；观测级 false-unique rate 分母是该 scenario 的全部观测，选择性错误率若引用则分母是唯一输出数。最终 topology-family 统计另以 8 个不同结构为分母，避免把同一结构的 30 次噪声重复当作 30 个独立未知 topology。

|条件|方法|false unique|观测级 95% CI|拓扑 family 概况|
|---|---|---:|---:|---|
|历史 small `[0,0,1]`, 20 dB，100 次|M2|94/100|[0.8752, 0.9722]|1 个结构；错误唯一 94 次|
|同上|M2R|94/100|[0.8752, 0.9722]|库内风险门同样放行|
|同上|M2R + band gate|92/100|[0.8500, 0.9589]|gate 拒绝 5/100，仅把 2 个错误唯一降级；false unique 仅相对下降 2.1%|
|新八结构，medium，20 dB，240 次|M2/M2R/gate|0/240|[0, 0.0158]|0/8 结构出现错误唯一；M2R/gate 非空接受均 18/240|
|新八结构，medium，10 dB，240 次|M2|2/240|[0.0023, 0.0299]|错误均在 `[3,0,0]`，2/30；family error 1/8，Wilson [0.0224,0.4709]|
|同上|M2R|2/240|[0.0023, 0.0299]|risk gate 没有拦截该结构的两次错误唯一|
|同上|M2R + band gate|2/240|[0.0023, 0.0299]|错误数、结构数均未减少|
|新八结构，large，20 dB，240 次|M2|17/240|[0.0447, 0.1105]|错误均在 `[0,3,0]`，17/30；1/8 结构出现错误|
|同上|M2R|0/240|[0, 0.0158]|风险门使本组无唯一输出错误；8 个结构中仍有 192/240 非空集合被接受|
|同上|M2R + band gate|0/240|[0, 0.0158]|非空接受 187/240；比 M2R 多拒 5 个非空集合，但无可测 false-unique 降幅|
|新八结构，large，10 dB，240 次|M2|10/240|[0.0228, 0.0750]|错误均在 `[0,3,0]`，10/30；1/8 结构出现错误|
|同上|M2R|0/240|[0, 0.0158]|风险门基线无错误唯一|
|同上|M2R + band gate|0/240|[0, 0.0158]|非空接受从 105/240 降至 91/240，false unique 仍为 0|

small 新八结构测试中三种方法均为 0 个非空接受/240；medium 20 dB 为 18/240 非空接受、10 dB 为 6/240；large 20 dB 为 192/240、10 dB 为 105/240（均为 M2R baseline）。这说明库外接受率强烈依赖候选库、SNR 和 topology family；不能用 small 的 0 接受宣称具有普遍拒识能力。新 gate 在 large 两个 SNR 下确实减少了一部分非空接受，但 M2R 的 false unique 已为 0，故这只是增加拒绝，不是已证明的错误确认改进。

### 7.2 库内覆盖、唯一判断和拒绝代价

|候选数|T 库内 20 dB 真值集合覆盖|M2R 正确唯一|M2R → gate 非空接受|M2R → gate 唯一输出|gate 相对 M2R 新拒绝的已接受样本|
|---:|---:|---:|---:|---:|---:|
|3|285/300 = 95.00%（Wilson [91.92%,96.95%]）|263/300|285 → 281|263 → 262|4/285|
|7|657/700 = 93.86%（[91.83%,95.41%]）|183/700|664 → 645|183 → 179|19/664|
|23|2184/2300 = 94.96%（[93.98%,95.78%]）|0/2300|2222 → 2150|0 → 0|72/2222|

平均候选集合大小分别为 `0.9533 / 1.9686 / 7.8057`。23 候选库的 M2R 风险证书未通过，故其唯一输出被降为 `LOW_CONFIDENCE`；这不是 gate 的独立效果。新 gate 在 20 dB 库内的正确唯一数只下降 1/300、4/700、0/2300（分别约 0.33、0.57、0 个百分点），但它仍拒绝了一部分原本非空的多候选集合。

10 dB 库内 SNR shift 下，M2R 覆盖为 small `152/300=50.67%`、medium `339/700=48.43%`、large `1251/2300=54.39%`；其拒绝数分别为 `148/300`、`355/700`、`993/2300`。新 gate 又减少非空接受 `4/300`、`11/700`、`90/2300`。large 的这 90 条是原 M2R 非空输出的 6.9%，提示 20 dB F 阈值迁移至 10 dB 后带来额外拒绝；它不是经 10 dB 校准的保证。

参数域外样本在三种规模下均被基线判为 REJECTED：`300/300`、`700/700`、`2300/2300`。新 gate 也达到高残差，但 baseline 已全部拒绝，因而不能把它的 gate flag 当成新增拒识收益。

### 7.3 库内独立风险审计与正控制

Stage 7A.3 新 R 批没有用于改阈值。small/medium 的 M2/M2R false unique 均为 `0/90`、`0/210`；large M2 为 `1/690`，M2R 因未获 Stage 7A.2 risk certificate 没有唯一输出。Band gate 在 R 批分别把非空接受从 `87→86`、`204→197`、`663→633`，并未改善已接近为零的库内 false unique；这体现了拒绝成本。

T3/T5 与 three-topology-close 复用 Stage 6B 的非唯一控制。两拓扑控制最大 pairwise CFR RMS 为 `9.3402×10⁻¹⁷`，三拓扑控制为 `6.95745×10⁻⁸`；基线状态均为 `MULTIPLE_AMBIGUOUS`。残差 gate 对控制样本接受，候选集合大小不变，没有把任何控制升级为 `UNIQUE_CONFIDENT`。

### 7.4 运行时间与缓存规模

|候选数|profiled 观测数|候选距离行|profile cache `whos` 字节|cache build|每库 Stage 7A.3 elapsed|
|---:|---:|---:|---:|---:|---:|
|3|2,230|6,690|136,586|0.139386 s|5.186638 s|
|7|4,430|31,010|314,506|0.112840 s|8.458476 s|
|23|13,230|304,290|1,026,646|0.504370 s|35.989987 s|

最终 formal 总计 `59,010` 个 method-sample 输出行、`341,990` 个 candidate-distance 行，metadata 运行时间 `62.069249 s`，日志结束时间 `62.109 s`。两者的轻微差异来自计时边界。缓存字节是 MATLAB `whos` 对缓存结构变量的估计，不是进程峰值 RAM。所有运行都为串行，未开并行池。

## 8. 是否采用新拒识规则

预注册门槛要求：在每个库的最终八个新 topology 上，sample-level 与等权 family-level false unique 均相对 M2R 至少下降 50%；20 dB 库内 gate 新拒绝不超过 5%，正确唯一下降不超过 5 个百分点；候选集合不得改变，非唯一控制不得被强制成唯一。

结果不满足首要改进条件：

1. 历史 small case 错误唯一从 `94/100` 到 `92/100`，相对减少仅 `2/94=2.1%`，新 gate 仍放行代表样本。
2. 最终 medium 10 dB 的错误唯一在 M2R 与新 gate 下同为 `2/240`，全部来自同一 `[3,0,0]` 结构；large 的 M2R false unique 已为零，新 gate 不能显示相对下降。
3. large 新 holdout 中 gate 把 M2R 非空接受从 `192→187`（20 dB）、`105→91`（10 dB），但唯一错误不变为 `0`；这增加拒绝，不证明提升库外安全性。
4. 对被数值响应重叠的 small 镜像拓扑，任何仅从当前单视角 CFR 残差取得的判据缺少区分信息；把阈值降到能拒绝此响应会有误拒库内同响应的风险。有限样本实验不能给任意 topology 的分布自由保证。

因此 band residual gate 保留为可复现实验对照，不作为当前推荐的默认 Stage 7A 判据。下一轮如果要验证可证伪的改进，应先选能打破镜像对称性的额外独立信息，例如不同测量端口/接收位置、不同端接或具有物理含义的开关/节点台账先验；预先定义“新增观测能否把同一 mirror pair 的最小 profile 距离从数值误差提升到噪声尺度以上”，再用完全独立 topology family 测试 false-unique 与 in-library 拒绝代价。本报告不启动 Multi-view CFR 正式实验。

## 9. 文献全文核对及迁移边界

下列八份用户本地 PDF 均通过首页核对标题/作者；路径以仓库根目录为基准，文件本身未复制进仓库。SHA-256 用原始 PDF 字节计算。这里只引用实际核读页；其他章节不作论据。

|文献/PDF|版本、页数、SHA-256|本报告实际引用位置与可迁移范围|
|---|---|---|
|Sadinle, Lei & Wasserman, *Least Ambiguous Set-Valued Classifiers with Bounded Error Levels*；[`../1609.00451v2 (1).pdf`](../../1609.00451v2%20%281%29.pdf)|arXiv `1609.00451v2`，2018-12-22，44 页；`b790160a3feaaf9c05987840c17d983ee22ae23fa0a50fc9f5f7e9c6741d9be1`|§2/Theorem 1、§3/Theorem 6、§4.3 式(7)/Theorem 16，PDF pp.8–10、21–23；JASA 114(525), 223–234，印刷页映射未逐页复核。支持覆盖率对象与独立留出校准讨论，不推出库外覆盖。[JASA DOI](https://doi.org/10.1080/01621459.2017.1395341)|
|Romano, Sesia & Candès, *Classification with Valid and Adaptive Coverage*；[`../NeurIPS-2020-classification-with-valid-and-adaptive-coverage-Paper (1).pdf`](../../NeurIPS-2020-classification-with-valid-and-adaptive-coverage-Paper%20%281%29.pdf)|NeurIPS 2020，11 页；`8aba157b6e4a6b3ff539053014c4d9e8aee832856bf74e9c3166303ed899f25f`|式(1) PDF p.1；Algorithm 1/Theorem 1 pp.3–4；§2.5 pp.5–6。交换性下的 coverage，不适用于任意 distribution shift。[NeurIPS 原文](https://papers.neurips.cc/paper_files/paper/2020/hash/244edd7e85dc81602b7615cd705545f5-Abstract.html)|
|Bates et al., *Distribution-Free, Risk-Controlling Prediction Sets*；[`../2101.02703v3.pdf`](../../2101.02703v3.pdf)|arXiv `2101.02703v3`，2021-08，34 页；`082cb7f952b4a4f91ad184a394ebe3766e66a1ccc4c7bbb295b2f7b7994a7983`|§2、式(1)–(2)、Theorem 1，PDF pp.3–5。定理要求嵌套集合与单调损失；错误单例损失未证明满足，故本项目不借该保证。[JACM DOI](https://doi.org/10.1145/3478535)|
|Geifman & El-Yaniv, *Selective Classification for Deep Neural Networks*；[`../NIPS-2017-selective-classification-for-deep-neural-networks-Paper.pdf`](../../NIPS-2017-selective-classification-for-deep-neural-networks-Paper.pdf)|NeurIPS 2017，10 页；`167ed5f7292edd07b90c27b2711dea70947ccb024681af020f4bfc4fbbad2e40`|式(1) PDF p.2；§3 Algorithm 1/Theorem 3.2 pp.3–4。选择性风险分母是被选择输出数；其分类网络结论不直接转移为物理 CFR 保证。[NeurIPS 原文](https://proceedings.neurips.cc/paper_files/paper/2017/hash/4a8423d5e91fda00bb7e46540e2b0cf1-Abstract.html)|
|Tibshirani et al., *Conformal Prediction Under Covariate Shift*；[`../NeurIPS-2019-conformal-prediction-under-covariate-shift-Paper.pdf`](../../NeurIPS-2019-conformal-prediction-under-covariate-shift-Paper.pdf)|NeurIPS 2019，11 页；`15234a15fc04d6f3d332870c49676327bb0af4352652df3ad7f6ca61b883b905`|Lemma 1 PDF p.2；§2/Theorem 1/Corollary 1 pp.3–4。其协变量偏移条件不等于任意 SNR/线路/负载变化。[NeurIPS 原文](https://papers.neurips.cc/paper_files/paper/2019/hash/8fb21ee7a2207526da55a679f0332de2-Abstract.html)|
|Bendale & Boult, *Towards Open Set Deep Networks*；[`../Bendale_Towards_Open_Set_CVPR_2016_paper.pdf`](../../Bendale_Towards_Open_Set_CVPR_2016_paper.pdf)|CVPR 2016，10 页；`aad734677e37753117bbf302d59bee229b8333456a7e19c105db3039a01271cc`|§2–3、Algorithms 1–2、Theorem 1，PDF pp.3–6/印刷 pp.1565–1568。OpenMax 面向深度网络 activation 特征，非当前物理 CFR distance 的直接替代。[CVF 原文](https://openaccess.thecvf.com/content_cvpr_2016/html/Bendale_Towards_Open_Set_CVPR_2016_paper.html)|
|Cortés et al., *A Close Examination of the Multipath Propagation Stochastic Model for Communications Over Power Lines*；[`../A_Close_Examination_of_the_Multipath_Propagation_Stochastic_Model_for_Communications_Over_Power_Lines.pdf`](../../A_Close_Examination_of_the_Multipath_Propagation_Stochastic_Model_for_Communications_Over_Power_Lines.pdf)|IEEE TCOM 73(11), 2025, 印刷 pp.10391–10404，14 页；`b3f5e1419ca63f7fa07e60f0d4e7b8d15c95a70af78bbcb75aea3d03295b74a0`|§III 式(5)–(9)，PDF pp.3–4/印刷 pp.10393–10394；426 条实测 CFR 用于 MPM 参数拟合与 NRMSE，不等于物理图唯一反演。[DOI](https://doi.org/10.1109/TCOMM.2025.3576942)|
|Lazaropoulos, *From Vector-Level to Frequency-Wise Gaussian Mixture Modeling: A Footprint Analysis for Populating OV LV BPL Topology Class Maps*；[`../202-935-1-PB.pdf`](../../202-935-1-PB.pdf)|Trends in Renewable Energy 12(2), 2026, 印刷 pp.140–161，22 页；`f79a07723efb1fb83ef75bdbee586b992ecb4af2d55ec55d4ad99c7083ace62c`|摘要、class-map/vector-level/frequency-wise GMM，PDF pp.1–5/印刷 pp.140–145。ACA/SDCA 虚拟衰减 footprint/class map 不等于包含物理节点边关系的 topology candidate graph。[DOI](https://doi.org/10.17737/tre.2026.12.2.00202)|

## 10. 复现命令、测试与结果索引

最终 smoke 命令（从仓库根目录）：

```matlab
addpath('src','config','experiments','tests');
test_stage7a3_library_out_audit();
run_stage7a3_library_out_audit(pwd,'smoke');
test_stage7a3_result_integrity(pwd,'smoke');
```

最终 formal 命令：

```matlab
addpath('src','config','experiments','tests');
run_stage7a3_library_out_audit(pwd,'formal');
test_stage7a3_result_integrity(pwd,'formal');
```

退出状态：Stage 7A.3 targeted unit + smoke + smoke integrity **PASS**；formal + formal integrity **PASS**。冻结阶段相关回归 **PASS**：

```matlab
test_stage5b1_decision_metrics();
test_stage6a_candidate_generation();
test_stage6b_robustness();
test_stage6_archive_integrity();
test_stage7a_profile_search();
test_stage7a1_diagnostics();
test_stage7a2_set_coverage();
test_stage7a2_result_integrity(pwd);
```

全仓 `tests/run_tests.m` 本轮没有执行；报告不把已运行的定向/相关回归表述为全量回归。错误尝试与重跑均保存在独立 `results/logs/stage7a_3/`；本轮最终正式日志为 `stage7a3_formal_separated_final.log`，最终 smoke 为 `stage7a3_smoke_separated_final.log`，历史回归为 `stage7a3_historical_regression.log`。

最终通过完整性检查的 formal 结果均位于 `results/data/stage7a_3/formal/`；smoke 结果位于 `results/data/stage7a_3/smoke/`。仓库归档采用 [`stage7a3_artifact_manifest.csv`](../results/data/stage7a_3/formal/stage7a3_artifact_manifest.csv) 区分入库的紧凑结果与本地保留、可按上述 formal 命令重建的三个大型逐样本文件（`stage7a3_candidate_distances.csv`、`stage7a3_sample_diagnostics.csv`、`stage7a3_residual_spectra.csv`）；清单记录全部正式文件的原始字节 SHA-256 和大小。smoke 数据和较早运行副本也保留在本地，不纳入公开仓库。`test_stage7a3_result_integrity(pwd,'formal')` 核对完整正式输出，因此新检出的仓库需先运行 formal 入口，再运行该完整性测试。以下文件名对应 formal 目录：

|结果/身份|文件|
|---|---|
|逐样本判决、四子带残差、domain/evidence 状态|`stage7a3_sample_diagnostics.csv`|
|每个样本的候选 profile distance、rank、p 值、signature|`stage7a3_candidate_distances.csv`|
|按 scenario/method 统计及 Wilson 区间|`stage7a3_group_summary.csv`|
|8 个不同未知 topology 的 family 和 cluster 统计|`stage7a3_topology_family_summary.csv`、`stage7a3_topology_cluster_summary.csv`|
|库外 topology signature、pattern、候选规模及留出身份|`stage7a3_library_out_inventory.csv`|
|F 阈值、候选库/搜索域/evidence identity、缓存及运行成本|`stage7a3_gate_calibration.csv`、`stage7a3_model_identity.csv`|
|固定/优化 CFR 对照、正控制、逐频拟合残差|`stage7a3_response_overlap.csv`、`stage7a3_positive_controls.csv`、`stage7a3_residual_spectra.csv`|
|seed/场景与逐输入 observation hash|`stage7a3_seed_manifest.csv`|
|config、运行元数据、原始字节源码 hash|`stage7a3_config_snapshot.mat`、`stage7a3_metadata.csv`、`stage7a3_source_inventory.csv`|
|冻结的审计协议|[`docs/stage7a3_library_out_protocol.md`](stage7a3_library_out_protocol.md)|
