# Stage 4A.6.2.1：Profile 执行协议与参数判据语义收尾

## 1. 阶段范围

[代码静态核对] 本阶段只收束 Stage 4A.6.2 的 profile 状态、参数域判定、shard 身份、断点续跑和 smoke 执行协议。候选拓扑、传输线正向模型、观测配置和历史阶段结果保持不变。Stage 4A.6.3、Stage 4B、真实 PLC 收发机和现场验证均未启动。

[代码静态核对] 本阶段新结果使用 `stage4a6_2_1` 前缀；Stage 4A.5.1、Stage 4A.6 和 Stage 4A.6.2 的历史 CSV、MAT、日志和报告未被覆盖。

## 2. 状态与判据定义

### 2.1 Profile 状态

每个 active 参数分别记录：

```text
profile_computed
profile_scan_finite
profile_scan_converged
profile_multistart_evaluated
profile_multistart_consistent
profile_valid_point_count
profile_total_point_count
profile_valid_fraction
relative_dynamic_range
absolute_dynamic_range
profile_reliable
profile_status
```

单起点扫描的 `profile_multistart_evaluated=false`，其一致性字段为 `not_applicable`，不再把未执行的多起点检验写成 `true`。

有效扫描点定义为：残差有限、优化器收敛，并且在执行多起点时满足多起点一致性要求。有效比例低于 `minimum_valid_fraction` 时状态为 `scan_unreliable`；若边界点或最小值附近关键点缺失，则状态为 `scan_unreliable_critical_points_missing`。当前短阶段采用 `fixed_grid_with_midpoints`，不宣称已实现自适应多轮细化。

平坦度由两个独立量共同决定：

$$
R_{\mathrm{rel}}=\frac{d_{\max}-d_{\min}}{\max(|d_{\min}|,\varepsilon)},\qquad
R_{\mathrm{abs}}=d_{\max}-d_{\min}.
$$

只有相对动态范围和绝对动态范围同时不超过各自阈值时，profile 才标记为 `unidentifiable_flat`；平坦 profile 不得进入 `in_domain`。

### 2.2 参数域判定

逐参数判定首先检查模型和该参数阈值是否均为 `calibrated`，且所需阈值为有限值。未满足时输出 `indeterminate_insufficient_calibration`，候选级输出 `parameter_domain_indeterminate`。

在阈值有效时：

* `A6_2_M1_boundary`：边界证据判定，作为边界诊断方法保留；
* `A6_2_M2_profile`：profile 可靠、扩展域最优点越界，且绝对或相对改善达到校准阈值时输出 `out_suspected`；
* `A6_2_M3_joint_diagnostic`：profile 可靠、扩展域最优点越界、绝对和相对改善均达标、局部灵敏度达标，并且存在边界或向域外下降证据时才输出 `out_suspected`。

扩展域越界但证据不完整或成员结论冲突时输出 `indeterminate_conflicting_evidence`。M3 因而是比 M2 更保守的联合诊断，不把单一残差下降直接解释为参数域外事实。

## 3. Shard、校验与 Resume

[代码静态核对] 每个 shard 强制保存并校验以下身份字段：

```text
case_id
scientific_hash
source_tree_hash
parameter_name
status
exit_status
checksum
attempt_count
```

完成 shard 必须具有零退出状态；失败 shard 必须具有非零退出状态、错误标识和错误消息。失败 shard 仍通过原子保存留下诊断记录，但不会计入 completed 或 calibration evidence。重试时增加 `attempt_count/retry_count`，并保留简短的 `attempt_history`。

manifest 保存仓库相对路径，例如：

```text
results/data/stage4a6_2_1/shards/stage4a6_2_1_smoke_G001.mat
```

运行时才由 `root_dir` 解析为绝对路径。临时文件不在 manifest 中，不会被聚合器当作完成结果。

## 4. 本次运行

运行环境为 MATLAB R2024a（24.1.0.2537033），并行关闭，worker 数为 1。科学配置哈希为：

```text
1da5e8159204a07c9ce5cd7693cea07838b35713bfa1896ce870b35f20691785
```

本次源码树哈希为：

```text
fd0c32cd728828c9ec9fcf15ef79f73d4cc3cea8628befc445aa982ed6dc8941
```

### 4.1 针对性测试

[本次运行] 命令：

```text
matlab -batch "addpath('src','config','experiments','tests'); test_stage4a6_2_1_protocol_closure"
```

退出状态为 0。测试覆盖未校准阈值、M2/M3 区分、相对/绝对平坦度、单起点语义、checksum、身份字段、失败 shard、retry、相对路径和端到端 resume。

日志：`results/logs/stage4a6_2_1/targeted_tests_final.log`。

### 4.2 两次 Smoke

配置为 A 快速网格前 9 个频点、G001 与 G007、profile 固定网格、串行 1 worker。

| 运行 | case 数 | attempted | completed | resumed | failed | hash mismatch | runtime |
|---|---:|---:|---:|---:|---:|---:|---:|
| 第一次（最终源码哈希） | 2 | 2 | 2 | 0 | 0 | 2 | 2.3043 s |
| 第二次 | 2 | 0 | 0 | 2 | 0 | 0 | 0.1704 s |

[本次运行] 第一次运行发现此前新阶段 shard 的源码哈希与当前源码不一致，因此重新计算；第二次运行在相同哈希下跳过两个完成 shard。两次聚合均为 `aggregate_completed=2`、`aggregate_failed=0`、`pending=0`。

日志：

```text
results/logs/stage4a6_2_1/smoke_first_hash_complete.log
results/logs/stage4a6_2_1/smoke_resume_hash_complete.log
```

结果：

```text
results/data/stage4a6_2_1/stage4a6_2_1_smoke_case_manifest.csv
results/data/stage4a6_2_1/stage4a6_2_1_smoke_profile_summary.csv
results/data/stage4a6_2_1/stage4a6_2_1_smoke_runtime.csv
results/data/stage4a6_2_1/stage4a6_2_1_smoke_results.mat
```

### 4.3 完整历史回归

[本次运行] 命令：

```text
matlab -batch "addpath('src','config','experiments','tests'); run_tests"
```

退出状态为 0。Stage 1.5、Stage 2、Stage 2.1、Stage 2.2、Stage 2.3、Stage 3A、Stage 3B-pre、Stage 3B waveform baseline、Stage 4A.1～Stage 4A.6.2.1 测试均通过。

日志：`results/logs/stage4a6_2_1/full_regression_hash_complete.log`。

## 5. 时间记录

| Phase | 预计时间 | 实际时间 | 偏差 | 主要原因 |
|---|---:|---:|---:|---|
| 仓库核对与静态审计 | 5～10 min | <1 min | 较小 | 本地结构明确；远端 fetch 受 DNS 限制 |
| 代码修改与新测试 | 15～30 min | 约 20 min | 在区间内 | 复用既有优化和 shard 接口 |
| 针对性测试 | 1～3 min | 约 32 s（首次）/15 s（最终） | 较小 | MATLAB 启动和两次轻量优化 |
| 第一次 smoke | 1～3 min | 约 2.30 s | 较小 | 9 频点、2 case、串行 |
| 第二次 resume smoke | <1 min | 约 0.17 s | 较小 | 只做哈希校验和聚合 |
| 完整历史回归 | 5～15 min | 约 16.5 s | 较小 | 当前测试集为确定性快速回归 |

本阶段未运行 4/6/8 workers benchmark、A/B 全候选正式 profile calibration/final 或现场实验。

## 6. 验收结论

[本次运行] Stage 4A.6.2.1 **通过**，可进入 Stage 4A.6.3 的 A 网格多拓扑、多 seed 参数域验证。通过依据是：未校准阈值不会产生库内/库外参数结论；M2 与 M3 逻辑不同且有测试；有效扫描点、平坦度和单起点语义已显式化；失败 shard、checksum、retry 和端到端 resume 均通过；smoke 与回归退出状态为 0。

[模型内推断] 该结论只说明执行协议和判据语义满足当前软件验收条件，不说明连续参数已经全局可辨识，也不说明参数域外怀疑能够准确定位真实越界参数。

## 7. 后续入口与边界

Stage 4A.6.3 如启动，应在新的 development/calibration/final 数据划分上进行多拓扑、多 seed 的参数域验证，并继续报告不可判定比例。当前单端口复数 CFR、仿真频率网格和传输线参数仍属于模型内设定；SISO 对称拓扑仍可能只能输出观测等价类。Stage 4B 未启动。
