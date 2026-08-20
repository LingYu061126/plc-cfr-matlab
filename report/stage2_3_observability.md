# 阶段 2.3：对称拓扑等价类、算法公平比较与最小观测配置

## 范围与方法

本阶段是自主仿真审计，不是论文现场复现。仍采用 2–30 MHz、1793 个全导频子载波的频域等效 LS 测量 `Y=XH+N`，而非完整 OFDM 收发机。候选为 T2/T3/T4/T5；T3/T5 是镜像重点对。

完整树网络由阶段 2.2 的分布参数节点导纳模型生成。`dual_receiver_complete` 与 `three_view_complete` 的内部接收机作为并联负载加入完整网络，未截断下游线路；因此其结果包含接收负载扰动，不代表无扰动现场探头。

原有等价类定义使用**单位范数归一化复数 CFR**：

$$D_{ij}=\sqrt{\frac1{N_v}\sum_v\operatorname{RMS}^2(\bar H_{i,v}-\bar H_{j,v})}.$$

距离不大于 `1e-10` 的候选连通分量被视为“归一化复数 CFR 形状/相对响应等价类”。数值 tie 是某次匹配中多个分数相等的事件，不能替代这一结构判据。此次修复新增原始绝对复数距离 $D_{raw}=\operatorname{RMS}(H_i-H_j)$；它不替换旧分类结果，供绝对标定审计使用。

`ambiguous` 是数值 tie；`physically_ambiguous_class` 是预测候选所属类非单元素；`unique_identification` 同时要求无数值 tie 且类为单元素；`false_unique` 则统计真值在物理非唯一类中、算法却没有报告数值歧义的情形。后者必须单列，不能被严格准确率掩盖。

## 本次修复

- 汇总器按 `smoke/formal` 分离 partial 文件前缀，并校验 MAT 内的 `mode` 字段；不同模式不混读。smoke 期望 7 批，formal 期望 14 批。
- 结构数组统一转为列向量；空数组写出预定义表头。
- pairwise 去重键为 `measurement_kind|sorted(topology_i,topology_j)`，正式输出应为 42 行而非 7 行。
- 发布版不带 formal MAT；因此只能验证 smoke 汇总。保留的旧 CSV 不能代替与当前代码匹配的 formal MAT 重汇总；本次 smoke 输出以 `stage2_3_smoke_fixed_*` 另存，未覆盖历史 formal 文件。

匹配器包括名义最近邻与参数网格联合匹配；公平对照固定使用相同的幅相加权特征、同一观测、噪声、候选和频点。`lambda=0.01`、0.5/0.5 权重及 243 点参数网格是预先冻结的仿真设置，不是测试集最优调参。

## 实际运行与数据

MATLAB R2024a 实际完成七种配置各 100 次独立 trial（分为两个 50 次种子区间），每个配置共 21,200 条方法评价记录。原始批次保留在 `results/data/stage2_3_partial_*`；流式汇总避免同时装载所有大型 MAT。

- 对称端点 SISO；50/75 Ω 不对称 SISO；role-fixed 与 endpoint-fixed 反向；endpoint-fixed 双向；完整网络双接收点；完整网络三视图。
- 噪声：固定接收 SNR，30/20/10/0 dB；参数条件在 20 dB 下分别改变长度、负载、端接与联合参数（含 `kG`）。
- 历史 formal 汇总保留为 `stage2_3_summary.csv`、`stage2_3_trials.csv`、`stage2_3_pairwise_distance.csv`、`stage2_3_confusion.csv`、`stage2_3_config.csv`。它们是修复前封存物，不作为本次 formal 重汇总结果。修复代码的实际 MATLAB smoke 汇总产物为 `stage2_3_smoke_fixed_*`，其中 pairwise CSV 为表头加 42 条记录。

### 修复验证状态

`results/logs/stage2_3_fixed_smoke.log` 记录了 MATLAB R2024a 对 7 个 smoke 批次的实际汇总（7420 条 trial 行、42 条 pairwise 数据）以及此前完整 1.5/2/2.1/2.2/2.3 回归通过。最后追加的“MAT 内 `mode` 一致性”保护及其测试在本次会话末尾遇到 MATLAB 启动层 `Unable to load ApplicationService for command client-v1`，未能重新启动 MATLAB；因此这一步标记为**待重跑**，不是本次声称已运行通过的测试。发布版亦没有匹配的 14 个 formal MAT，formal 修复汇总同样待原始数据包和 MATLAB 环境可用后执行。

### 旧 formal CSV 的可审计复算

不依赖缺失 MAT 而直接从保留的 `stage2_3_trials.csv`（使用能处理 `{T3,T5}` 引号字段的 CSV 解析）过滤 `siso_forward`、`noise_only`、20 dB、`amp_phase_joint_weighted` 后，名义最近邻和 nuisance-aware joint 各有 400 条记录。名义最近邻的 `false_unique=0.0000`、`ambiguous=0.5000`；joint 的 `false_unique=0.1250`、`ambiguous=0.3750`。两者的等价类准确率均为 1，而严格准确率分别为 0.7500、0.7375。故 joint 在该旧 formal trial 中确有 12.5% 的物理等价类内“伪唯一”输出风险，不能被严格准确率掩盖，更不能解释为 T3/T5 已被唯一识别。由于正式 MAT 未随发布包提供，其他 formal 结果尚未用修复后的汇总器重新生成。

## 已验证结论

1. 50/50 Ω 对称单端 SISO 下，T3/T5 属于 `{T3,T5}` 等价类；理想匹配的唯一严格率为 0.5、等价类准确率为 1。任何以浮点最小索引输出 T3 或 T5 的做法不构成唯一识别。
2. 20 dB 噪声条件下，对称 SISO 的名义幅相联合严格率为 0.75，而等价类准确率为 1、唯一严格率为 0.5，正好反映 T3/T5 的不可唯一性。
3. 在当前模型中，50/75 Ω 单向不对称端接即可打破名义 T3/T5 镜像；其 20 dB 严格率为 0.88。若端点必须保持对称，完整网络双接收点是已测试配置中最小的额外测量：20 dB 严格率为 1。
4. 三视图同样在当前理想模型的 20 dB 噪声条件下达到严格率 1；这不是现场性能结论。
5. 联合参数扰动下，双接收点的名义/联合严格率为 0.695/0.915，三视图为 0.710/0.933；当前预设网格在这些条件下优于对应名义匹配，但不据此称其为最优算法。

## 模型推断与限制

- 单纯改分类算法不能使完全相等的对称 SISO CFR 产生新信息；瓶颈首先是观测对称性而非导频稀疏。
- 不对称端接是“无额外接收节点”的最小信息改变，但其是否可部署取决于真实耦合器/端接硬件；不能泛化为所有现场端接。
- 当前没有多导体/MIMO、耦合器寄生、CP、同步/CFO、现场有色/脉冲噪声或真实负载标定。因此不建议进入 OFDM 波形优化；应优先确认可用内部节点与端接模型。

## 待验证问题

真实 PLC FFT/导频、可测内部端口、端接随收发切换的物理语义、时变复负载、RLGC 校准、现场噪声与多导体测量仍待实验或文献证据核对。
