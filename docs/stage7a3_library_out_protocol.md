# Stage 7A.3 候选库外拓扑可检测性审计协议

协议冻结日期：2026-09-25。源码验证基线为 `f1e1ed13f296b5e21267bf6aceda4199c8ee86f0`。开始时 `main`、本地 `origin/main` 跟踪引用和 HEAD 一致，工作树干净；本次无法解析 GitHub 主机名，未能重新读取实时远端。该网络限制不影响本地归档结果读取。Stage 4A、5B.1、6A、6B、7A、7A.1、7A.2 的代码、配置和正式结果均只读。

本协议先于 Stage 7A.3 新实验代码及其测试冻结。Stage 7A.2 已公开的库外观测只用于失败重放与开发诊断，不用于 Stage 7A.3 的最终拒识效果估计。不得依据 Stage 7A.3 最终测试修改本协议、频段、参数域、阈值或拓扑清单。

## 1. 初始静态审计发现

- Stage 7A.2 的 `library_out_truth` 将允许支路位置扩至主线节点 1–3、每节点最多 3 条支路、总支路最多 5 条、最多 10 个节点，然后只取按确定顺序枚举的第一个未入库网络。扩展 grammar 的物理 signature 已由 MATLAB 重建核验：3 候选库外真值为单支路接于主线节点 3；7 候选为两条支路均接于节点 3；23 候选为三条支路均接于节点 3。每种结构被重复 100 次，故这些记录是 3 个未知结构而非 300 个独立未知拓扑。
- Stage 7A.2 将候选 ID、缓存顺序与网络 signature 同序写入距离表；评分按该缓存顺序处理距离。静态代码未见把真值索引传入 `stage7a2_score_distances` 的路径。最终仍须用逐样本重建验证映射和数值。
- Stage 7A.2 的 `stage7a2_score_distances` 以 `min(d)/RMS(y)` 计算相对 domain distance；该风险门的阈值来自库内 A 批。它没有、也不能因此认证任意候选库外拓扑。
- `stage7a_profile_distance` 返回各候选最佳 fine-template 索引；完整复数 CFR 存在 `cache.H{candidate}(template_index,:)`，可直接取回最佳拟合频谱，不需改写原搜索函数。
- 固定目标是解释特定模型观测下的错误唯一，不把候选选错与 `REJECTED`、`LOW_CONFIDENCE` 或 `MULTIPLE_AMBIGUOUS` 混作同一失败。

## 2. 文献核对与迁移边界

以下 PDF 均在仓库根目录上一层的项目资料目录中按首页核对标题/作者；本表记录相对仓库根目录的真实文件路径、PDF 版本和 SHA-256。原文链接指向出版方、会议原文或 DOI。页码同时标 PDF 页和可读取的印刷页；页码未在本次阅读范围核对的章节不作为证据。

| 文献 | 本地全文、版本与 SHA-256 | 本阶段实际核对位置及可迁移结论 |
|---|---|---|
| Sadinle, Lei & Wasserman, “Least Ambiguous Set-Valued Classifiers with Bounded Error Levels” | [`../1609.00451v2 (1).pdf`](../../1609.00451v2%20%281%29.pdf)；arXiv `1609.00451v2`（2018-12-22），44 页；`b790160a3feaaf9c05987840c17d983ee22ae23fa0a50fc9f5f7e9c6741d9be1`；[JASA DOI](https://doi.org/10.1080/01621459.2017.1395341) | §2 / Theorem 1、§3 / Theorem 6、§4.3 式 (7) 与 Theorem 16（PDF pp. 8–10、21–23；期刊版 JASA 114(525), pp. 223–234，印刷页码对应关系未逐页核验）。支持区分总体覆盖、逐类覆盖及独立留出校准；不证明库外覆盖。 |
| Romano, Sesia & Candès, “Classification with Valid and Adaptive Coverage” | [`../NeurIPS-2020-classification-with-valid-and-adaptive-coverage-Paper (1).pdf`](../../NeurIPS-2020-classification-with-valid-and-adaptive-coverage-Paper%20%281%29.pdf)；NeurIPS 2020 会议稿，11 页；`8aba157b6e4a6b3ff539053014c4d9e8aee832856bf74e9c3166303ed899f25f`；[NeurIPS 原文](https://papers.neurips.cc/paper_files/paper/2020/hash/244edd7e85dc81602b7615cd705545f5-Abstract.html) | PDF p. 1 式 (1)；§2 Algorithm 1、Theorem 1（PDF pp. 3–4）；逐类扩展 §2.5（PDF pp. 5–6）。支持交换性下的边际/逐类集合覆盖条件；不把条件分布变化纳入原保证。 |
| Bates et al., “Distribution-Free, Risk-Controlling Prediction Sets” | [`../2101.02703v3.pdf`](../../2101.02703v3.pdf)；arXiv `2101.02703v3`（2021-08），34 页；`082cb7f952b4a4f91ad184a394ebe3766e66a1ccc4c7bbb295b2f7b7994a7983`；[JACM DOI](https://doi.org/10.1145/3478535) | §2、式 (1)–(2)、Theorem 1（PDF pp. 3–5）。其风险控制定理要求嵌套集合族和随集合扩张单调不增的有界损失；错误单例损失 `1{|C|=1,Y∉C}` 不满足该单调条件，本项目不套用该定理。 |
| Geifman & El-Yaniv, “Selective Classification for Deep Neural Networks” | [`../NIPS-2017-selective-classification-for-deep-neural-networks-Paper.pdf`](../../NIPS-2017-selective-classification-for-deep-neural-networks-Paper.pdf)；NeurIPS 2017，10 页；`167ed5f7292edd07b90c27b2711dea70947ccb024681af020f4bfc4fbbad2e40`；[NeurIPS 原文](https://proceedings.neurips.cc/paper_files/paper/2017/hash/4a8423d5e91fda00bb7e46540e2b0cf1-Abstract.html) | PDF p. 2 式 (1) 的 selective risk / coverage 定义；§3 Algorithm 1、Theorem 3.2（PDF pp. 3–4）。错误率分母应为选择性输出数；其分类网络保证不直接转移为物理 CFR 拒识保证。 |
| Tibshirani et al., “Conformal Prediction Under Covariate Shift” | [`../NeurIPS-2019-conformal-prediction-under-covariate-shift-Paper.pdf`](../../NeurIPS-2019-conformal-prediction-under-covariate-shift-Paper.pdf)；NeurIPS 2019，11 页；`15234a15fc04d6f3d332870c49676327bb0af4352652df3ad7f6ca61b883b905`；[NeurIPS 原文](https://papers.neurips.cc/paper_files/paper/2019/hash/8fb21ee7a2207526da55a679f0332de2-Abstract.html) | Lemma 1（PDF p. 2）；§2、Theorem 1 / Corollary 1（PDF pp. 3–4）。协变量偏移结论要求条件分布保持不变并有适用的密度比；不能把任意 SNR 或线路变化称作该保证。 |
| Bendale & Boult, “Towards Open Set Deep Networks” | [`../Bendale_Towards_Open_Set_CVPR_2016_paper.pdf`](../../Bendale_Towards_Open_Set_CVPR_2016_paper.pdf)；CVPR 2016，10 页，印刷 pp. 1563–1572；`aad734677e37753117bbf302d59bee229b8333456a7e19c105db3039a01271cc`；[CVF 原文](https://openaccess.thecvf.com/content_cvpr_2016/html/Bendale_Towards_Open_Set_CVPR_2016_paper.html) | §2–3、Algorithms 1–2、Theorem 1（PDF pp. 3–6；印刷 pp. 1565–1568）。OpenMax 针对深度网络 activation 特征的未知类拒识；不是现有物理 CFR 距离的直接替代品。 |
| Cortés et al., “A Close Examination of the Multipath Propagation Stochastic Model for Communications Over Power Lines” | [`../A_Close_Examination_of_the_Multipath_Propagation_Stochastic_Model_for_Communications_Over_Power_Lines.pdf`](../../A_Close_Examination_of_the_Multipath_Propagation_Stochastic_Model_for_Communications_Over_Power_Lines.pdf)；IEEE Transactions on Communications 73(11), 2025, pp. 10391–10404；14 页；`b3f5e1419ca63f7fa07e60f0d4e7b8d15c95a70af78bbcb75aea3d03295b74a0`；DOI [10.1109/TCOMM.2025.3576942](https://doi.org/10.1109/TCOMM.2025.3576942) | §III、式 (5)–(9)（PDF pp. 3–4；印刷 pp. 10393–10394）说明 426 条实测室内 SISO CFR 上的多径模型拟合与 NRMSE；拟合残差描述所选参数模型对 CFR 的近似程度，不等于物理图的唯一反演。 |
| Lazaropoulos, “From Vector-Level to Frequency-Wise Gaussian Mixture Modeling: A Footprint Analysis for Populating OV LV BPL Topology Class Maps” | [`../202-935-1-PB.pdf`](../../202-935-1-PB.pdf)；Trends in Renewable Energy 12(2), 2026, pp. 140–161；22 页；`f79a07723efb1fb83ef75bdbee586b992ecb4af2d55ec55d4ad99c7083ace62c`；DOI [10.17737/tre.2026.12.2.00202](https://doi.org/10.17737/tre.2026.12.2.00202) | 摘要及 class-map / vector-level / frequency-wise GMM（PDF pp. 1–5；印刷 pp. 140–145）。ACA/SDCA class maps 描述虚拟衰减样本 footprint 与类别图；不等于含物理节点及支路连接的候选拓扑库。 |

本次核对以表列具体章节和页码为限；未核对的附录或章节不作为本报告证据。上述文献用于界定统计对象、模型拟合和迁移边界，不为本项目实验结果背书。

## 3. Stage 7A.2 失败重放

用当前冻结 Stage 7A.2 配置和原始种子重建候选网络、校准身份、每条观测和距离向量。对 `scale_small` 的历史案例 `seed=560100001`，必须逐字段比较 canonical CSV 与重建的真值 signature、候选 ID 顺序、全部 profile distance、最佳候选、集合、domain 判决和四状态。3/7/23 库分别重放其既有 100 个库外样本，并与 canonical 逐行比较。签名、ID、集合及离散状态须完全一致；距离绝对误差容差为 `1e-12`。排序遇到绝对距离差 `≤1e-12` 时标记数值并列，同时保留原确定性的候选索引次序，不以字符串舍入制造或消除并列。

审计真值 signature、拓扑对象、candidate ID 与 profile-distance 行的映射。输出真值及全部库内候选签名和距离；错误唯一的事实须由独立重建支持，不以摘要表中的计数代替。

## 4. CFR 响应重叠实验

- 观测配置固定为 Stage 7A/6B 的 SISO 正向 CFR：61 个频点，2–30 MHz；使用配置中的源/接收端阻抗及接收端接法。频点、端接和归一化不变。
- 每个 Stage 7A.2 库外真值及其最近候选，先在历史样本生成时相同的主线/负载参数下比较无噪声复数 CFR；再在 Stage 7A profile 搜索网格 `main scale=0.90:0.025:1.10`、`branch-load scale=0.80:0.10:1.20` 上比较各自优化后的 profile。另计算双方各自允许参数网格之间的最小复 CFR RMS 距离。网格、真值参数只用于诊断，不传入候选评分 API。
- 同时按原复数 RMS 定义与每条 CFR 的 RMS 能量归一化报告差异；附 61 点频率残差，检查是否呈全带一致偏移或局部频带结构。噪声条件按复高斯 AWGN 的 20 dB 基线和独立 10 dB 压力样本分别汇总。
- 只有满足 `max(abs(Ha-Hb))/max(RMS(Ha),RMS(Hb),eps) ≤ 1e-12` 才称为“在数值容差内近似相同”；不据此声称解析严格等价。高于该容差只报告测得距离，不推断现场可分。

## 5. 候选库外拓扑与数据划分

沿用 Stage 6B 一层径向 grammar：四段 20 m 主线、三个可选支路接入点、每条支路 15 m、50 Ω 支路负载。扩展枚举上限保持每接入点最多 3 条支路、总支路最多 5 条、总节点最多 10。用 branch-count vector `[n1,n2,n3]` 和 `stage6b_network_signature` 固定身份，不对已存在的候选库结果重排或重命名。

Stage 7A.2 历史的三种库外 signature（`[0,0,1]`、`[0,0,2]`、`[0,0,3]`）仅用于失败重放/开发。全新的最终留出库外结构统一使用以下八种 pattern，均不属于任一 3/7/23 候选库，也不与历史 signature 重合：

`[3,0,0]`, `[0,3,0]`, `[3,1,0]`, `[3,0,1]`, `[1,3,0]`, `[0,3,1]`, `[2,2,1]`, `[2,1,2]`。

这八种结构覆盖不同支路接入位置、每点支路数量以及总支路数量；逐个保存 signature 和网络对象摘要。它们代表该有限 grammar 的受控子集，不覆盖深层支路、非径向环路、不同电缆/负载类别或任意复杂拓扑。代码必须枚举并统计 grammar 中未纳入这八种的其他库外结构，报告其数量和未覆盖原因。

各 Stage 7A.3 split 使用不同 seed 空间及不同完整参数/噪声场景：

| split | 用途 | 生成条件/样本数 |
|---|---|---|
| D development | 检查预先指定残差统计量的行为；允许重看 Stage 7A.2 三种已公开未知结构 | 新库内开发样本每类 20；历史未知样本仅标为开发数据 |
| F fit-quality calibration | 唯一用于候选库内拟合质量阈值的样本 | 每候选 200 条；20 dB；主线 scale `[0.98,1.02]` 均匀；负载 1 |
| R independent risk audit | 对固定的 M2/M2R/新 gate 规则作独立选择性错误审计，不调阈值 | 每候选 30 条；条件同 F；独立生成 |
| T in-library final | 最终库内覆盖、集合大小、正确唯一和误拒评估 | 每候选 100 条；20 dB、窄参数域 |
| T library-out final | 最终未见物理 topology pattern；结构数与重复数分开报告 | 八个 topology × 每结构 30 条，20 dB |
| T library-out SNR shift | 同八个最终结构下的 SNR 压力结果，单独汇总 | 八个 topology × 每结构 30 条，10 dB；使用新噪声 seeds |
| T parameter-out | 库内拓扑但长度超出 profile 搜索域 | 每候选 100 条；主线 scale 在 `[0.82,0.88]` / `[1.12,1.18]` 间均衡取样；20 dB |

T 测试不参与阈值拟合或方法选择。历史 Stage 7A.2 校准 A/B/R 只用于重建旧 M2/M2R baseline；Stage 7A.3 的新 D/F/R/T seed 和场景互不复用。配置中固定全部 seed base、候选顺序、签名、搜索域和 MATLAB 版本；新增结果只写入 Stage 7A.3 独立目录。

比例同时报告观测级 `k/n`、95% Wilson 区间及 topology-cluster 级 `k/8`。对 30 次同一拓扑噪声重复，不把 30 当成 30 个未知拓扑；另报告八个结构的等权平均错误率、每结构最小/最大/中位数和有错误结构数量。不同候选库对同一结构的结果是配对比较，不合并为独立拓扑数。

## 6. 预注册拟合质量统计量与决策

只审计一个增量统计量：选出当前 profile RMS 最小的候选及其缓存最佳 CFR 后，将 61 个频点按索引连续分为四个近等长频带；逐带计算

`r_b = RMS(H_best - Y over band b) / max(RMS(Y over band b), eps)`，`r_max = max_b r_b`。

`r_max` 是可解释的最坏子带归一化复数残差，不是概率。不得根据最终 T 选择频带数、统计量、分母、搜索网格或阈值。M2 与 M2R 保持原候选集合、profile 距离、domain 和 evidence 不变。候选方法 `M2R+band-residual-gate` 只在 `r_max` 高于 F 批的一侧 split-conformal 95% 分位数时将输出状态变为 `REJECTED`；保留原候选集合，并记录“非空集合但被拒识”，不将多候选缩成单例，不增加新的 `UNIQUE_CONFIDENT`。若没有独立数据支持区分度，或安全条件未满足，该 gate 仅保留为审计对照，不作为推荐方法。

选择/保留判据在最终测试前固定：

1. F 批独立于 D/R/T，阈值使用 order statistic `ceil((n_F+1)×0.95)`，越界时置 `Inf`。其至多支持同条件 in-library 的边际校准解释，不是逐拓扑、库外或域外保证。
2. 在最终 8 个未见 topology 上，新 gate 必须同时使观测级 false-unique 比例与八结构等权 false-unique 比例相对 M2R 至少下降 50%；每种库分别判断，不跨库合并分母。
3. 新 gate 在 T in-library 的错误拒识比例不得超过 5%，正确 `UNIQUE_CONFIDENT` 比例相对 M2R 的下降不得超过 5 个百分点；同时报告逐样本配对差异及 Wilson 区间。候选集合本身不应改变。
4. 参数域外和 10 dB 变化必须单独报告拒绝、非空集合和 false unique，不将其混入库外结果。T3/T5 与 three-topology-close 必须保持非唯一；新 gate 不得把其中任何一个变成单例/唯一。
5. 若库外错误输出与 in-library 覆盖明显重叠，或上述任一安全条件失败，不再增加第二个拒识统计量或反复改阈值；结论为当前单视角配置未支持安全的拒识改进。

主要指标：真值库内候选集合覆盖、平均/中位集合大小、正确唯一率、库内拒识率、库外非空集合率、库外通过 gate 的非空集合率、错误唯一率、结构级错误比例、10 dB/参数域外 rejection、两个非唯一正控制状态、校准和评分 wall-clock、MATLAB 模型变量字节数。每个 rate 明确分子、分母和区间。错误唯一的选择性错误率分母为唯一输出数；拒识率分母为该场景总测试数。

## 7. 实施、测试和资源策略

新增代码保持 `stage7a3` 独立命名及独立入口；真值只用于生成/审计标签，不传给 scoring 或拒识函数。记录候选库及排序、物理 signature、搜索域 hash、阈值样本身份、所有 split seeds、源 commit、MATLAB/platform、并行状态、运行时和缓存模型变量大小。先做静态检查、定向单元测试、smoke 与 wall-clock benchmark，再运行冻结的 formal 对照和 Stage 7A.3 结果完整性测试，最后执行相关 Stage 5B.1/6A/6B/归档回归。保持串行 fallback；Stage 7A.2 正式 log 约 27.5 s，当前无理由默认开并行池。

Stage 7A.2 `stage7a2_metadata.csv` 中 `runtime_s=22.78305` 是入口在出图前写下的计时；`stage7a2_formal_final.log` 的 `27.483 s` 是出图完成后打印的总 elapsed。另两次运行 log 为 `28.747 s` 和 `27.356 s`，对应固定 seed 重跑的 wall-clock 波动。正式结果数值哈希保持不变；历史数据与日志原件不改。本阶段溯源表须明确区分 CSV 记录的 pre-figure runtime 与 log 记录的 post-figure total，不覆盖旧字段。

本阶段所有结论仅限指定 MATLAB 合成模型、grammar、CFR 观测配置、频带、端接和抽样分布。candidate coverage 不等于可辨识性；拒绝不定位台账错误；已知库内校准不会自动认证未知拓扑；不宣称对任意未知 topology 有分布自由拒识保证。Stage 4B 未启动，Multi-view CFR 不在本阶段范围。
