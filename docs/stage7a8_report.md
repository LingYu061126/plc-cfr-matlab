# Stage 7A.8：联合 CFR／输入阻抗全候选池计算审计

## 研究范围与基线

本阶段只研究受控合成模型中名义 H50＋Zin50、37 张物理候选图的计算成本与判定等价性。科学基线是 `31082ad056dac7dbc8a8f74f9c8453cc39a258f5` 的 Stage 7A.7 C37。A 为该提交的原评分函数；B 为仅计算训练／留出所需频点的新评分函数。候选池、E/A/F/T 种子、连续搜索网格与边界、经验候选集合及四状态判定均保持原定义。两法使用完全同一批观测、模板、视图尺度和校准模型；测试真图与生成参数没有进入评分接口。Stage 7A.7 和更早科学代码及正式结果未修改。完整预注册细节见 [协议](stage7a8_protocol.md)。

## 修改前性能定位与方法

MATLAB Profiler 对名义联合视图的一个 G002 样本记录了 37 候选、1,773 次连续目标函数评估。Profiler 插桩下评分为 4.018 s；其中 `stage7a5_profile` 嵌套总时间 3.916 s、`stage7a4_forward_state` 3.317 s、网络图解析 0.924 s、图编辑邻居仅 0.018 s。这些嵌套时间不能相加，也不能和非插桩正式计时直接比较。证据见 `results/logs/stage7a_8/baseline_profiler.log`。

B 对粗网格模板复用不变；连续拟合的正向模型仅在原定训练索引求解；对最佳图的质量门仅在原定留出索引求解。电路方程未更改，亦没有减少候选数或放宽阈值。B 仍逐一计算 37 图，不以 Top-K 截断结果冒充全池确认。

## 提前停止的安全边界

本阶段未实现 C 类提前停止。粗网格最小距离是对应图连续优化最小距离的**上界**，局部 `fminbnd` 同样不提供全参数域下界；因此目前无法证明未评分图不可能进入候选集合，也无法基于已评分 Top-K 安全地输出 `UNIQUE_CONFIDENT`。旧 C5/C12 的低置信截断语义保留为 Stage 7A.7 历史对照，但不是本阶段的效率捷径。若以后要提前排除，需建立对每个未访问拓扑及允许参数域均有效的拟合距离下界，并把下界计算成本纳入总耗时。

## 归档与复现身份

环境为 MATLAB R2024a (`24.1.0.2537033`)、Linux `glnxa64`、串行、0 worker。Stage 5B.1 完整回归依赖的忽略 MAT 文件已在提交 `31082ad` 的独立干净检出中，由 `run_stage5b1_objective_confirmation_upgrade(pwd,'formal')` 从已跟踪 Stage 4A 输入重新生成，退出码 0、耗时 134.842 s。该隔离检出仅有 `stage5b1_runtime.csv` 因 wall-clock 重跑而变化；其他科学 CSV 未变化。再将生成的 MAT 作为忽略夹具放入第二份干净检出，`run_tests()` 退出码 0；第二份检出 `git status --short` 为空。生成 MAT SHA-256 为 `f2775c13cb1a7d555a07f158e16f57d5f97f85befa22f235dd49fd5c37ce2881`，原主工作区被忽略 MAT 的原始字节哈希不同；本阶段只声称所需夹具**可从跟踪输入重生并使完整测试通过**，不声称不同日期 MAT 文件逐字节一致。日志分别见 `fixture_generation.log` 与 `clean_full_regression.log`。历史回归出现既有 `lsqnonlin` 方程数少于变量数时切换 Levenberg–Marquardt 的警告，无测试失败。

新代码的定向等价测试、smoke 及结果完整性测试单独运行，不纳入历史 `run_tests.m`，以免改变旧回归身份。Smoke 中 11 个配对观测全部等价；A/B 使用的因小校准集产生的候选集合与正式 60＋60 校准不同，不能以 smoke 的确认率代替正式结论。首次完整性测试因 MATLAB 将签名中的分号误判成 CSV 分隔符而失败；显式指定逗号后通过，原始 CSV 与科学计算未改动。失败日志与重测日志均保留。

## 正式配对结果

正式结果、资源开销及各图族判定见 `results/data/stage7a_8/formal/` 下的 `samples.csv`、`candidate_audit.csv`、`paired_comparison.csv`、`summary.csv`、`calibration.csv` 与 `metadata.csv`。`config_snapshot.mat` 保存实际配置、候选分组、视图尺度和校准模型；`results/data/stage7a_8/source_manifest.csv` 记录新增代码的原始字节 SHA-256，8 个文件逐一核验通过。日志见 `results/logs/stage7a_8/formal_paired.log` 与 `source_manifest_check.log`。本轮 66 个观测、每个 37 图、两法共 4,884 条逐候选记录。A 的 66 个逐样本科学输出与 Stage 7A.7 归档一致；视图尺度、候选库、搜索域、校准模型与条件身份哈希也一致。E/A/F 分别为 24/60/60 个观测，校准集合阈值为 0、留出质量阈值为 1.23424617438815，与归档 C37 数值一致。

逐样本 `paired_comparison.csv` 的 66 行 `equivalent` 全为真；候选 ID、完整排序、候选集合、最佳图、判定原因与四状态精确相同，距离、最佳拟合参数及留出质量统计量的最大绝对差均为 **0**（记录精度下），优化目标评估数也相同。这是对本批观测和 MATLAB R2024a 实现的实测等价，不是对所有参数输入的形式化证明。

| 真图组别 | 张数×重复 | A 与 B 共同的结果 | 真值入集 | A 评分 s | B 评分 s |
|---|---:|---|---:|---:|---:|
| 初始库内 | 3×6 | 正确唯一 18/18；错误唯一 0/18 | 18/18 | 50.298 | 49.045 |
| 旧库外、现库内 | 2×6 | 正确唯一 12/12；错误唯一 0/12 | 12/12 | 37.302 | 34.748 |
| 新连接点、现库内 | 2×6 | 正确唯一 12/12；错误唯一 0/12 | 12/12 | 29.661 | 25.867 |
| 37 图语法外 | 2×6 | 拒绝 12/12；错误唯一 0/12 | 0/12 | 32.162 | 28.632 |
| 参数搜索域外 | 2×6 | 拒绝 12/12；错误唯一 0/12 | 0/12 | 33.381 | 29.251 |

这里的 66 次噪声观测来自 11 张真图，不应被描述为 66 个独立拓扑。语法外真图不在 37 图池内；参数域外的结构虽在库内，但真值参数越界。后两组即使 CSV 中集合非空，也因留出质量门不通过而 `REJECTED`，因此不能把“集合非空”当作系统接受。各组都没有歧义或低置信输出；这只是本次名义条件结果，不表示四状态中其他分支已失效。

A/B 的 66 次测试评分累计分别为 **182.804 s** 和 **167.543 s**，B 节省 **15.261 s（8.35%）**，总评分时间比为 **1.091×**；66 次中 B 有 59 次更快，7 次更慢。实验总 wall-clock 为 **691.799 s**，其中一次性候选模板建造 3.945 s／1,665 次正向调用、E/A/F/T 观测生成 0.703 s、原版 A/F 校准 331.880 s、A/B 配对 T 评分 350.637 s。本轮只优化 T 评分路径，**没有实测 B 用于校准时的端到端加速**，也不能把 8.35% 直接当作总流程加速。模板逻辑缓存为 3,257,776 B，MATLAB 进程峰值 RSS 为 1,645,864 kB；未使用并行池。相比旧 Stage 7A.7 跨日日志，本轮 A/B 是同进程交替测量，更适合估计这一局部改动的收益，但仍可能受 JIT 与系统负载影响。

综上，B 在本批数据上**守住科学输出等价并带来温和的评分耗时下降**，但并未改变库外识别能力，也没有证据支持安全的 Top-K 提前唯一。下一轮若继续追求算力收益，应优先研究正向模型中不随连续参数变化的图结构解析与线路参数复用，并先以逐频复数 H/Z、完整排序及判定等价测试守门；不得通过减少候选池或放宽质量门制造“提速”。

## 实际运行与测试

- 旧版定向基线：`test_stage7a7_candidate_space; test_stage7a7_search_and_identity; test_stage7a7_result_integrity`，退出码 0，日志 `baseline_targeted.log`。
- 新版三组配对定向测试：`test_stage7a8_equivalence(pwd)`，退出码 0，日志 `targeted_tests.log`；最终代码再次执行该测试，见 `final_targeted_and_integrity.log`。
- Smoke：`run_stage7a8_study(pwd,'smoke')`，11/11 配对等价，退出码 0；`test_stage7a8_result_integrity(pwd,'smoke')` 重测通过。原完整性读取失败及修复证据分别见 `smoke_integrity.log` 和 `smoke_integrity_retry.log`。
- 干净检出历史回归：`run_tests()`，退出码 0，见 `clean_full_regression.log`；它不包含新增 Stage 7A.8 测试。
- 正式配对：`run_stage7a8_study(pwd,'formal')`，66/66 配对等价，退出码 0，见 `formal_paired.log`。
- 最终定向与结果完整性：`test_stage7a8_equivalence(pwd); test_stage7a8_result_integrity(pwd,'smoke'); test_stage7a8_result_integrity(pwd,'formal'); test_stage7a7_result_integrity(pwd)`，退出码 0，见 `final_targeted_and_integrity.log`；源码 SHA-256 核验退出码 0，见 `source_manifest_check.log`。

## 解释边界

这是同一受控合成电力线模型、指定频带与端接、有限 37 图候选池下的计算优化验证；不是实网/真实 PLC 收发机验证。数值等价不能证明物理拓扑全球唯一，37 图不代表大规模候选库。单个进程的峰值 RSS 是 MATLAB 进程级观测，不能归因给某一个样本或函数。计时受 MATLAB JIT、操作系统负载与硬件影响，报告以本轮同进程交替配对 wall-clock 为主。
