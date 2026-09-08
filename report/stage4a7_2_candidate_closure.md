# Stage 4A.7.2：候选生成闭环与受控 Pilot 记录

## 1. 阶段范围

本阶段在冻结的模型内 CFR 正向模型上，补齐三类候选生成和候选确认所需的可追溯接口，并运行受控的第二档 Pilot。研究对象仍是受限径向候选库、合成先验和单发送端—单接收端复数 CFR；本阶段不进入 Stage 4B，不运行完整 Final，也不修改稳定的传输线正向模型。[代码静态核对]

第二档修正版结果写入 `results/data/stage4a7_2_tier2_v2/`。早先同规模运行保留在 `results/data/stage4a7_2_tier2/`，没有被覆盖。[本次运行]

## 2. 候选生成的三条路线

### 路线 A：受约束工程候选枚举

输入为节点集合、允许边、required/forbidden 边、开关状态、径向和连通约束、最大度数及候选数上限。`normalize_engineering_candidate_spec` 先规范化无向边、去除反向重复并校验先验冲突；`generate_engineering_topology_candidates` 通过增量选边、Union-Find 环检测、边数/连通性/度约束和候选上限进行搜索。该层输出工程候选，并保留搜索审计字段，不把候选数量减少解释为观测能力增加。[代码静态核对]

### 路线 B：按需 Top-K 原型

`generate_topk_topology_candidates` 使用确定性的 best-first branch-and-bound。队列状态保存已选边、下一决策位置、先验成本和下界；required 边预加载，周期、度数、连通性和剩余边数在搜索过程中剪枝。它不先调用完整枚举器；在一个 4 节点小型 edge-universe 中，K 等于全部可行候选数时，规范键集合与完整枚举一致，且无重复输出。[本次运行]

当前 Top-K 的排序目标是配置中的工程先验成本，而不是 CFR 距离。它因此是候选生成原型，不是最终拓扑确认器。[模型内推断]

### 路线 C：多节点测距直接重构

Ahmed/Lampe 路线需要多 PLC 节点之间的成对传播时间或距离；当前项目只有单端口复数 CFR，没有成对 ToA 矩阵、绝对同步和现场测距标定。因此本阶段不伪造 RNJA 或 GLRT 的原始输入，路线 C 仍应返回 `not_applicable`。[历史结果][代码静态核对]

## 3. 工程候选层与正向模型兼容层

工程候选通过 `adapt_engineering_candidate_to_forward_model` 转换到当前稳定模型可表示的主路径和一级叶支路网络。适配器检查树性、连通性、源—接收端路径、边长、线缆类型、端部负载和支路层级；无法表示的候选应保留在工程清单中并标记不兼容，而不是静默删除或伪造 CFR。

本次 tier2_v2 中：

| 层级 | 数量 |
|---|---:|
| 工程候选 | 7 |
| 正向模型兼容候选 | 7 |
| 进入评分的候选 | 7 |

7 个 legacy 图经适配后的名义 CFR 距离均为 0，说明适配器没有改变这组历史网络对象的模型响应。[本次运行]

当前结构库外控制样本由扩展工程语法生成并经过同一适配器处理；它不通过重新命名库内图构造。[代码静态核对]

## 4. 非相容度与候选集合

本阶段保留未加权绝对残差，同时实现四类经验非相容度：

- `absolute`：候选绝对残差；
- `scaled`：按 development 中的尺度归一化；
- `ratio`：候选残差相对最优残差；
- `margin`：候选与竞争候选的残差差异。

calibration 只使用 140 个库内 calibration 行，每个候选 20 个，最小经验 p-value 为

$$
p_{\min}=\frac{1}{20+1}=0.0476190476.
$$

这里的经验候选集合是模型内、按候选类别校准的实验接口；没有独立噪声协方差，也没有现场交换性证据，因此不把它写成现场 distribution-free 保证或后验概率。[模型内推断]

## 5. 第二档 Pilot 设置

| split/category | 场景数 | 备注 |
|---|---:|---|
| development/in-domain | 70 | 7 个候选，每个 10 个独立连续参数场景 |
| calibration/in-domain | 140 | 7 个候选，每个 20 个独立连续参数场景 |
| Pilot/in-domain | 21 | 7 个候选，每个 3 个 |
| Pilot/parameter OOD | 21 | 7 个候选，每个 3 个 |
| Pilot/structure OOL | 7 | 扩展工程语法生成的结构库外控制 |
| same-theta non-unique | 100 | G004/G007 对称条件下的独立参数场景 |

三类普通 split 的参数向量哈希和无噪声 CFR 哈希均无重复：development 70/70、calibration 140/140、Pilot 49/49。[本次运行]

非唯一场景使用 G004/G007 的同一物理参数向量，并设置相同源/接收端阻抗以保持该受限 SISO 模型中的对称性；100 个场景均满足冻结的 $10^{-10}$ CFR 距离容差。该等价性只在当前模型、端口、频带、端接和容差下成立。[本次运行][模型内推断]

## 6. Pilot 结果摘要

`confirmation_metrics.csv` 报告候选集合覆盖、singleton 和空集合比例，并给出 Wilson 95% 区间。关键结果如下：

| 方法 | 类别 | 候选集合覆盖 | singleton | 空集合 |
|---|---|---:|---:|---:|
| absolute/scaled/ratio | in-domain | 21/21 | 21/21 | 0/21 |
| margin | in-domain | 20/21 | 16/21 | 1/21 |
| absolute/scaled/ratio | parameter OOD | 21/21 | 21/21 | 0/21 |
| margin | parameter OOD | 17/21 | 13/21 | 4/21 |
| absolute/scaled/ratio | structure OOL | 0/7 | 7/7 | 0/7 |
| margin | structure OOL | 0/7 | 7/7 | 0/7 |

绝对、缩放和 ratio 非相容度在这个无噪声小样本 Pilot 上几乎总是给出 singleton，且没有对参数库外形成有效拒绝；这只能说明当前校准设计和观测配置下，候选集合没有提供足够的 open-set 证据，不能写成参数库外检测已完成。[本次运行]

margin 产生了一些空集合和多候选集合，但其样本量不足以支持稳定性能结论。非唯一 100 场景已经生成，可用于下一阶段把 false-unique 的条件分母与真实场景级等价标签连接起来；本次 Pilot 主表尚未把它们冒充为普通独立分类样本。[本次运行]

## 7. Top-K 与运行记录

在小型 4 节点 edge-universe 中，完整枚举得到 4 个可行树；K=3 返回 3 个无重复候选；K=4 时 lazy Top-K 与完整枚举的 canonical key 集合一致。搜索统计记录在 `topk_audit.csv` 中。[本次运行]

修正版 tier2_v2 总运行时间为 2.370 s，其中非唯一场景约 0.176 s；串行 1 worker，未启动并行池。[本次运行]

## 8. 测试与可追溯文件

新增定向测试 `tests/test_stage4a7_2_candidate_closure.m`，覆盖 lazy Top-K 全集一致性、候选集合校准、Wilson 零分母和非唯一场景独立性。Stage 4A.7.1 两个相关回归测试也通过。[本次运行]

主要机器可读结果包括：

- `summary.csv`：阶段状态、样本规模、科学哈希；
- `topk_audit.csv`：搜索剪枝和全集一致性；
- `adapter_audit.csv`：7 个历史图的适配与 CFR round-trip；
- `confirmation_metrics.csv`：四种非相容度的 Pilot 指标与区间；
- `independence_audit.csv`：参数/CFR 哈希独立性；
- `nonunique_clusters.csv`：100 个 same-theta 对称场景；
- `scenario_manifest.csv`：场景、seed、参数和观测身份；
- `stage4a7_2_results.mat`：受控 Pilot 汇总对象；
- `runtime_summary.csv`：运行模式和时间。

## 9. 阶段判断

本阶段完成了工程候选层、实际适配器、lazy Top-K 原型、经验非相容度族、独立非唯一场景生成和受控第二档 Pilot。由于绝对/scaled/ratio 候选集合对参数 OOD 仍没有形成有效拒绝，且 Pilot 样本量仍小，不应据此冻结最终候选确认阈值或宣称 open-set 性能稳定。阶段状态为“受控 Pilot 完成、科学结论部分有效”，不是完整 Final 通过。[本次运行]

## 10. 限制与下一步

1. 当前候选先验是 `synthetic_demo_prior_not_field_data`，不是 GIS 或现场线路台账；
2. 当前观测是模型生成的无噪声单端口复数 CFR；
3. 当前 61 点网格是快速研究配置，不是完整真实 PLC OFDM PHY；
4. candidate-set 经验 p-value 受每候选 20 个 calibration 场景限制，最小可达到值为 0.047619；
5. 非唯一场景证明了当前受限模型下的观测等价风险，但不证明真实网络全局物理等价；
6. 正式扩大样本前，应先完善候选库外标签、场景级 indistinguishability 与真正的噪声协方差校准；
7. Stage 4B 和完整 Final 均未启动。[本次未运行]
