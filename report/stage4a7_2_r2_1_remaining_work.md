# Stage 4A.7.2-R.2.1：剩余工作与交付边界

## 1. 当前状态

当前阶段状态为：

```text
Stage 4A.7.2-R.2.1 partial / blocked
```

已完成静态修正、定向测试、完整历史回归、formal 批次、35 场景独立 Pilot，以及 87 个评分候选的同参数候选对审计。当前证据仍属于受限候选库、模型生成复数 CFR 和小规模受控验证，不能解释为真实 PLC 配电网识别性能。

## 2. 已完成且已归档的内容

| 类别 | 当前证据 |
|---|---|
| SHA-256 | 空文件、`abc` 和派生 ENWL CSV 的已知摘要向量通过 MATLAB 校验 |
| 科学身份 | source tree、数据来源、候选库、配置、模板 cache 和 experiment identity 已分层记录 |
| 候选接口 | deployment 输入与 offline benchmark 构造接口分离，不向部署候选器传入 truth |
| 候选排序 | 数值代价、tie tolerance、canonical key 的稳定三向比较器已统一 |
| 参数采样 | 独立 35 场景使用稳定 case seed、off-grid 参数和频域等效噪声 |
| formal | 87 个兼容候选，261 development、3480 calibration、174 Pilot 场景完成 |
| 独立 Pilot | 35 个场景完成，参数、无噪声 CFR 和观测 hash 均唯一 |
| 等价审计 | 3741 个候选对完成 same-theta 审计；每个候选的最近竞争者完成有限 cross-theta profile 审计 |
| 回归 | `run_tests` 退出状态为 0，Stage 1–Stage 4A.7.2-R.2.1 测试通过 |

## 3. 尚未完成的科学与工程工作

### 3.1 参数域判定尚未形成完整闭环

当前独立 Pilot 主要评价候选集合，不包含完整的逐成员参数 profile、成员可靠性门控、参数域 M1/M2/M3 聚合、参数 selective risk 和端到端风险。因此 near/medium/far 的结果不能作为参数库外检测性能结论。

进入下一阶段前应补齐：

- accepted member 的逐成员 profile evidence；
- 不可靠成员的硬性 indeterminate 门控；
- parameter calibration 与 topology calibration 的双身份核验；
- 参数域无条件和选择性指标；
- 结构 OOD、参数 OOD 和拓扑拒绝的分层分母。

### 3.2 真实非唯一场景尚未建立

当前 87 个 scored 候选的 3741 个 same-theta 候选对在数值阈值 (10^{-10}) 下没有等价对，因而没有可靠的真实非唯一场景。`false_unique` 的可评价分母仍为零，不能用唯一拓扑结果替代该指标。

后续需要在冻结观测配置和正向模型下建立可复核的 symmetry-preserving 控制场景，逐候选计算 CFR 后形成 truth equivalence set；不得由候选 ID 或预设标签直接赋值。

### 3.3 Cross-theta 等价性尚未覆盖全部候选对

本阶段对所有候选对完成了 same-theta 距离，但 cross-theta/profile 距离只对每个候选的 same-theta 最近竞争者计算，以控制内存和运行时间。该结果不能称为所有候选对的完整 profile 等价性审计。

### 3.4 开放集与台账损坏评价仍不完整

已有 nominal、missing-edge、false-edge、confidence-inversion、incorrect-required-edge、missing-switch-state 和 mixed-corruption 的候选覆盖审计接口，但当前结果没有形成完整的结构 OOD、先验排除、模型不兼容和参数 OOD 统一评分矩阵。候选库未覆盖真值时应单独记为 coverage failure，不能混入分类器错误。

### 3.5 运行环境问题尚未根治

MATLAB R2024a 在当前机器上仍会出现 MathWorks interprocess mutex/ApplicationService 警告。通过隔离 `HOME`、`MATLAB_PREFDIR`、offscreen、兼容库、`-nojvm` 和 `-singleCompThread` 可以完成数值运行，但这属于可复现 workaround，不是桌面启动根因的系统级修复。

### 3.6 并行与完整 Final 尚未进行

本阶段使用串行 1 worker，没有重新进行并行 benchmark。完整 Final、更多 seed、完整参数域验证和 Stage 4B 均未启动。

## 4. 结果解释边界

- 候选集合 coverage 不等于拓扑唯一恢复率。
- 低 singleton rate 反映当前候选库和校准分辨率仍保守，不能通过缩小集合或删除困难样本改善。
- 无真实非唯一标签时，false-unique 必须保持不可评价。
- 当前 20 dB 噪声为频域等效复高斯噪声，不是现场噪声或完整 PLC OFDM 收发链。
- ENWL 派生数据提供的是公开网络结构和受控先验来源，不是原始错误台账，也不提供 MHz 级 RLGC 标定。
- 当前结论不构成现场配电网验证，Stage 4B 未启动。

## 5. 下一阶段入口条件

下一阶段应先完成真实非唯一控制、逐成员参数 profile、全候选 cross-theta 审计和结构/参数 OOD 分层，再决定是否扩大样本或运行正式 Final。任何扩大实验前都应重新冻结 configuration hash、calibration identity、样本 seed 和统计分母。
