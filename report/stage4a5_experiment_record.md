# Stage 4A.5 实验记录：多尺度残差、邻域模板证据与重采样稳定性

## 1. 研究问题与边界

本阶段研究在受限径向候选库和既有完整树正向模型下，能否利用多尺度残差、同一拓扑的邻域模板证据以及连续频率块重采样稳定性，降低库外样本被候选库吸收的概率。当前结果是模型内合成审计，不是真实低压配电网拓扑恢复、真实 PLC 收发机验证或现场统计性能。Stage 4B 未启动。

当前观测为单发送端—单接收端复数 CFR；A 网格为 Stage 4A.1 的 61 点网格，B 网格为由当前配置导出的 1793 个有效 OFDM 子载波。61 点、1793 点、4096 点 FFT 和 64 MHz 采样率均是当前仿真配置，不能解释为真实设备参数证据。

## 2. Stage 4A.4 基线

[仓库历史结果] Stage 4A.4 的冻结测试池中，M0 型绝对残差加类间隔基线在 A 网格的库内集合准确率为 `45/56=0.8036`，结构库外和参数库外误接受率均为 `8/20=0.4000`；B 网格分别为 `44/56=0.7857`、`8/20=0.4000` 和 `8/20=0.4000`。该测试池在本阶段标记为 `historical_consumed_test`，未用于本阶段的方法或超参数选择。

[仓库历史结果] Stage 4A.3.1 的约 0.55 库外误接受率来自不同样本池和实验协议，不能与上述 0.40 作严格配对增益比较。本阶段重新建立了独立 development/final replication 协议。

## 3. 数据隔离与固定协议

[代码静态核对] 配置文件为 `config/stage4a5_multiscale_confirmation_config.m`。正式配置使用 development seeds `20261201, 20261202`，final seeds `20261301` 至 `20261308`。P0、P1、P2 和两个频率网格复用同一批真值样本；先验只改变候选集合，不改变真值样本池。

[本次运行] 正式 trial bank 共 1310 个样本，分组如下：

| 分组 | 样本数 | 说明 |
|---|---:|---|
| `development_training` | 42 | 2 个 development seed，7 图，每图 2 个连续参数样本和 1 个网格样本 |
| `development_calibration` | 70 | 2 个 seed，每图 4 个连续参数样本和 1 个网格样本 |
| `development_validation` | 150 | 库内 70，结构库外 40，参数库外 40 |
| `final_replication_calibration` | 280 | 8 个 seed，每图 4 个连续参数样本和 1 个网格样本 |
| `final_replication_test` | 768 | 库内 448，结构库外 160，参数库外 160 |

每个 final seed 的库内测试样本为每图 6 个连续参数样本和 2 个网格样本；结构库外、参数库外各 20 个。库外样本和参数越界维度均保存在 trial bank 中。final test 未参与方法选择、子带数选择、邻域阶数选择或稳定性阈值选择。

## 4. M0～M3 方法

[代码静态核对] 所有方法共享一次观测生成和候选 CFR 缓存；`src/score_stage4a5_observation.m` 生成全频带、子带、拓扑前 `K` 个模板和频率块稳定性原始证据，`src/apply_stage4a5_confirmation.m` 只接收原始观测证据、校准模型和方法规格，不接收真实标签。

* **M0**：Stage 4A.4 的全频带最佳残差与类间隔规则。
* **M1**：M0 加入连续子带残差。开发阶段比较 `M=4,8` 和 `q=0.75,0.90`，使用校准样本对统计量作中心—尺度归一化。
* **M2**：M1 加入同一拓扑内部的前 `K=3,5,10` 个等尺寸模板邻域分数和邻域间隔。模板数在各拓扑间相同，不让模板较多的拓扑获得额外优势。
* **M3**：M2 加入连续频率块重采样稳定性。正式配置使用 `B=30`，4 个连续块，保留频率点比例为 0.25；重采样只重新汇总缓存残差，不重新调用正向模型。

M1～M3 的统一判定顺序为全频带残差、子带统计、邻域统计、稳定性、类间隔和等价类输出。拒识原因分别记录为 `reject_model_mismatch`、`reject_subband_mismatch`、`reject_neighborhood_mismatch`、`reject_low_stability` 和 `reject_low_margin`。P0 中的多成员观测等价类仍输出 `equivalence_class`，不得由稳定性把它强制拆成唯一拓扑。

## 5. Development 方法选择与冻结参数

[本次运行] 方法选择只读取 development validation。选择约束为库内微平均集合准确率不低于 0.80，且 false-unique 不高于 M0；在约束内优先最小化结构库外与参数库外误接受率中的最大值。

| 网格 | M1 | M2 | M3 |
|---|---|---|---|
| A，61 点 | `M=8,q=.75,K=5` | `M=8,q=.75,K=3` | `M=4,q=.75,K=3, τq=.70` |
| B，1793 点 | `M=8,q=.75,K=5` | `M=8,q=.75,K=3` | `M=4,q=.75,K=3, τq=.80` |

残差、子带和邻域统计使用校准分位数与安全系数；M0～M3 的 final 阈值由各 final seed 的 P0 校准样本冻结产生，P1/P2 复用同一网格、同一 seed 的 P0 校准模型。最终测试只用于评价。

## 6. Final replication 结果

[本次运行] P0 的 8 个 final seed 合并结果如下。比例后的方括号为按二项 Wilson 方法计算的 95% 区间；分子和分母保留在表中。

| 网格 | 方法 | 库内集合准确率 | 结构库外误接受 | 参数库外误接受 | false-unique |
|---|---|---|---|---|---|
| A | M0 | 403/448 = 0.8996 [0.8682, 0.9241] | 87/160 = 0.5438 [0.4664, 0.6190] | 74/160 = 0.4625 [0.3870, 0.5397] | 0/256 |
| A | M1 | 396/448 = 0.8839 [0.8509, 0.9104] | 52/160 = 0.3250 [0.2573, 0.4009] | 72/160 = 0.4500 [0.3750, 0.5274] | 0/256 |
| A | M2 | 396/448 = 0.8839 [0.8509, 0.9104] | 52/160 = 0.3250 [0.2573, 0.4009] | 71/160 = 0.4438 [0.3690, 0.5212] | 0/256 |
| A | M3 | 393/448 = 0.8772 [0.8436, 0.9045] | 35/160 = 0.2188 [0.1617, 0.2890] | 71/160 = 0.4438 [0.3690, 0.5212] | 0/256 |
| B | M0 | 399/448 = 0.8906 [0.8583, 0.9163] | 93/160 = 0.5813 [0.5038, 0.6549] | 73/160 = 0.4563 [0.3810, 0.5336] | 0/256 |
| B | M1 | 393/448 = 0.8772 [0.8436, 0.9045] | 63/160 = 0.3938 [0.3214, 0.4711] | 72/160 = 0.4500 [0.3750, 0.5274] | 0/256 |
| B | M2 | 393/448 = 0.8772 [0.8436, 0.9045] | 63/160 = 0.3938 [0.3214, 0.4711] | 71/160 = 0.4438 [0.3690, 0.5212] | 0/256 |
| B | M3 | 389/448 = 0.8683 [0.8338, 0.8965] | 29/160 = 0.1813 [0.1293, 0.2482] | 68/160 = 0.4250 [0.3510, 0.5025] | 0/256 |

[模型推断] 在本次冻结测试池中，M3 将 A/B 的结构库外误接受分别从 0.5438/0.5813 降至 0.2188/0.1813，同时库内集合准确率仍高于 0.80。参数库外只出现小幅下降，且区间与样本量限制使其不能被表述为强统计证据。所有方法的 false-unique 均为 0，但这不意味着观测等价性已消失；等价类仍作为合法输出保留。

## 7. 逐 seed 配对稳定性

[本次运行] 以同一 final seed 的 M0 误接受率减 M3 误接受率作为配对改善，正值表示 M3 更少误接受：

| 网格和类别 | 平均配对差 | seed 标准差 | M3 优于 M0 的 seed 数 | 持平 seed 数 |
|---|---:|---:|---:|---:|
| A，结构库外 | 0.3250 | 0.1102 | 8/8 | 0/8 |
| A，参数库外 | 0.0188 | 0.0372 | 2/8 | 6/8 |
| B，结构库外 | 0.4000 | 0.1035 | 8/8 | 0/8 |
| B，参数库外 | 0.0313 | 0.0372 | 4/8 | 4/8 |

[模型推断] 结构库外改善具有明确的跨 seed 方向一致性；参数库外主要表现为不变或轻微改善，尚不足以证明多尺度、邻域和稳定性组合能够普遍识别参数域外样本。M3 相对于 M0 的库内集合准确率下降为 A 的 0.8996→0.8772、B 的 0.8906→0.8683，但均满足 0.80 约束。

## 8. 误接受类型分析

[本次运行] M3 的参数越界样本按维度合并统计如下；A/B 除接收阻抗和源阻抗的具体数值略有差异外，困难排序一致。

| 参数越界维度 | A 误接受 | B 误接受 |
|---|---:|---:|
| 主线长度 | 0/32 = 0.000 | 0/32 = 0.000 |
| 支路长度 | 17/32 = 0.531 | 17/32 = 0.531 |
| 支路负载 | 21/24 = 0.875 | 21/24 = 0.875 |
| 源阻抗 | 20/24 = 0.833 | 18/24 = 0.750 |
| 接收阻抗 | 13/24 = 0.542 | 12/24 = 0.500 |
| 联合越界 | 0/24 = 0.000 | 0/24 = 0.000 |

[本次运行] 三类结构库外规范键中，`structure_key_02` 最难拒识：M3 在 A 为 26/56=0.464，在 B 为 24/56=0.429；`structure_key_01` 为 A 7/56=0.125、B 5/56=0.089；`structure_key_03` 为 A 2/48=0.042、B 0/48=0。M3 的 P0 决策计数为 A：`unique_topology` 232、`equivalence_class` 267、拒识 269；B：225、261、282。拒识原因不只来自总残差，还包括子带、邻域和稳定性证据。

P1/P2 只在算法冻结后审计。两者均把候选数从 7 限制为 4；P1 是部分一致合成先验，P2 是陈旧或不一致合成先验，来源标签均为 `synthetic_demo_prior_not_field_data`。P1/P2 的先验过滤改变了可行候选和等价类，不应被解释为同一观测下的无条件识别能力提升；错误硬先验仍可能导致错误接受或错误的先验条件唯一输出。

## 9. 缓存与运行成本

[代码静态核对] M0～M3 共享一次观测生成、候选 CFR 缓存和逐频点原始残差；M3 的连续块重采样只使用缓存，不重新运行传输线正向模型。

[本次运行] 正式运行耗时约 `1253.374 s`（约 20.89 分钟），MATLAB 为 `R2024a (24.1.0.2537033)`。A 网格 P0 为 7×243=1701 个复合模板，估算缓存内存约 1.66 MB；P1/P2 为 972 个模板，约 0.95 MB。B 网格 P0 估算约 48.80 MB，P1/P2 约 27.88 MB。实验优先复用了只读的 Stage 4A.4 缓存，缓存来源字段为 `stage4a4_cache_or_stage4a5_cache`；未提交 672 MB 的 `stage4a5_results.mat` 大型结果对象，路径已记录。

## 10. 结果图和机器可读结果

[本次运行] 已生成：

* `results/data/stage4a5_trial_bank.csv`
* `results/data/stage4a5_match_decisions.csv`
* `results/data/stage4a5_scoring_labels.csv`
* `results/data/stage4a5_raw_evidence.csv`
* `results/data/stage4a5_metrics.csv`
* `results/data/stage4a5_seed_metrics.csv`
* `results/data/stage4a5_method_selection.csv`
* `results/data/stage4a5_thresholds.csv`
* `results/data/stage4a5_runtime.csv`
* `results/data/stage4a5_frequency_grid_manifest.csv`
* `results/data/stage4a5_subband_manifest.csv`
* `results/data/stage4a5_configuration_manifest.csv`
* `results/data/stage4a5_baseline_summary.csv`
* `results/figures/stage4a5_set_accuracy_given_covered.png`
* `results/figures/stage4a5_accepted_rate.png`
* `results/figures/stage4a5_seed_paired_improvement.png`
* `results/figures/stage4a5_parameter_out_false_accept.png`
* `results/figures/stage4a5_mean_subband_max.png`
* `results/figures/stage4a5_mean_neighborhood_score.png`
* `results/figures/stage4a5_mean_stability.png`
* `results/figures/stage4a5_accuracy_ool_tradeoff.png`

配置清单中的科学配置哈希为 `f5355193b563ab35fde3db906a9397c0d8541c5c951f19b151f3c552bf4d2c0e`，源代码树哈希为 `d6322cdb80045c8012abd947a8636c2a096b104279592fb8b96387d0ba35d370`。科学哈希不包含绝对运行路径。

## 11. 测试与回归

[本次运行] Stage 4A.5 单元测试命令为：

```bash
matlab -batch "cd('matlab_plc_cfr_publish'); addpath('tests'); addpath('src'); addpath('config'); addpath('experiments'); diary('results/logs/stage4a5_unit_test_final.log'); disp(version); test_stage4a5_multiscale_confirmation; diary off"
```

MATLAB R2024a，退出状态 `0`；日志为 `results/logs/stage4a5_unit_test_final.log`，测试输出为 `ALL STAGE-4A.5 TESTS PASSED`。

[本次运行] 正式实验入口为 `run_stage4a5_multiscale_confirmation('formal')`，退出状态 `0`；正式日志为 `results/logs/stage4a5_run.log`，运行记录从 `2026-09-06 00:27:25` 开始，运行耗时约 1253.374 秒。

[本次运行] 全历史回归入口为 `run_tests`，MATLAB R2024a，退出状态 `0`；日志为 `results/logs/stage4a5_full_regression.log`。Stage 1.5、Stage 2、Stage 2.1、Stage 2.2、Stage 2.3、Stage 3A、Stage 3A.1、Stage 3A.2、Stage 3B-pre、waveform baseline、Stage 4A.1、4A.2、4A.3、4A.3.1、4A.4 和 Stage 4A.5 均通过。Stage 4A.4 历史文件未被修改；`tests/run_tests.m` 仅新增 Stage 4A.5 测试入口。

## 12. 结论与下一步

[本次运行] 本阶段满足以下工程性条件：匹配方法不读取真值；development 与 final replication test 分离；M0～M3 使用配对样本；P0 的 7 个拓扑均有重复校准和测试样本；结构库外有 3 个规范键；参数库外按六类维度细分；两类频率网格均完成测试。

[模型推断] M3 对结构库外误接受率的改善在 8/8 个 seed 上保持方向一致，并且库内集合准确率仍超过 0.80。这支持“局部频带失配、拓扑邻域证据和重采样稳定性能够补充全频带最小距离”的模型内判断。

[模型推断] 本阶段尚不能证明整体开放集拒识已经可靠。支路负载、源阻抗和部分支路长度越界仍容易被候选库吸收；参数库外的改善很小。1793 点网格也没有自动解决这一问题。当前单端口复数 CFR 仍可能无法提供足够的独立观测维度。

因此，Stage 4A.5 可视为“实验协议、共享证据和候选确认增强方法已完成验证”，但不建议据此宣称已经达到普适算法冻结或进入 Stage 4B 的条件。下一步优先考虑增加观测维度、改进模型覆盖和真实测量误差建模，而不是继续在同一 SISO CFR 上无边界调节阈值。正式论文总报告暂不撰写，Stage 4B 不启动。

## 13. 未完成和待验证事项

* [待验证] 真实 GIS、线路台账、开关状态、线型和现场端接尚未接入。
* [待验证] 真实 OFDM LS 信道估计误差、同步误差、噪声和时变负载尚未用于最终验证。
* [待验证] 当前多尺度判据在更多独立数据源和真实网络上的覆盖率与误接受率。
* [本次未运行] 真实硬件、多端口观测、FDR/TFDR、绝对 ToF、全节点导纳/TLS、机器学习分类器和 OFDM 资源优化。
