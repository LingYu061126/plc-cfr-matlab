# Stage 4A.6.2：Profile 分批执行稳定化与逐参数可信判定

## 1. 阶段范围

[代码静态核对] 本阶段在 Stage 4A.6.1 之上建立独立的 profile 执行和状态接口，目标是区分连续参数优化、单参数 profile 可靠性和参数域判断。历史 Stage 4A.5.1、Stage 4A.6 与 Stage 4A.6.1 的代码及结果未被本阶段覆盖。

当前观测仍是受限径向网络完整树正向模型产生的单发送端—单接收端复数 CFR。当前结果属于模型内验证，不是现场拓扑恢复、真实 PLC 收发机验证或参数真实可辨识性证明。

## 2. 状态定义

Stage 4A.6.2 的 profile 结果区分以下状态：

- `profile_computed`：是否实际执行了扫描；关闭 profile 时为 `false`。
- `profile_scan_finite`：扫描距离是否全部为有限值。
- `profile_scan_converged`：扫描点内部优化是否满足求解器收敛条件。
- `profile_multistart_consistent`：多起点结果是否一致。
- `profile_nonflat`：扫描曲线是否具有超过冻结平坦性门槛的变化。
- `profile_valid_point_count`、`profile_total_point_count` 和 `profile_valid_fraction`：扫描点完整性。
- `profile_reliable`：上述条件和最低有效比例共同满足时才为 `true`。

逐参数状态为：

```text
inactive
not_computed
optimizer_failed
scan_unreliable
unidentifiable_flat
indeterminate
in_domain
out_suspected
```

无支路拓扑的支路长度和负载参数标记为 `inactive`，不进入参数域统计分母。平坦 profile 只说明当前 CFR 对该参数缺乏足够的局部区分信息，不能解释为参数在域内或优化器失败。

## 3. 连续参数与 profile 执行

[代码静态核对] 新接口复用既有 `optimize_stage4a6_1_parameters` 的有界复数 CFR 实数残差优化，不改变历史候选排序的数学定义。Stage 4A.6.2 包装层补充了：

1. 每个扫描点的固定参数值、距离、exit flag、迭代次数、函数评价次数、边界命中、运行时间和失败标识；
2. 库内域和扩展域的边界点；
3. 相邻 profile 点的 warm start 与固定基准起点；
4. active parameter mask；
5. profile 关闭时的明确 `not_computed` 语义。

本阶段保留旧的 5% 相对灵敏度规则作为诊断基线，同时单独保存 profile 平坦性、有效点比例、Jacobian rank 和局部灵敏度，避免用单一布尔量代替这些概念。[模型内推断]

## 4. 分批、断点续跑与完整性

[代码静态核对] 新增 case shard 接口，每个 shard 保存 case ID、科学配置哈希、源码树哈希、状态、profile 摘要、错误标识和 checksum。保存流程先写临时 MAT 文件，校验后再转为正式文件。汇总器拒绝重复 case、缺失 shard 和哈希不匹配 shard。

当前默认执行方式为串行、小批次、`resume=true`、`overwrite_completed=false`、`retry_failed=false`。已完成且哈希匹配的 shard 不重复计算；不完整或身份不匹配的文件不会被静默计入完成结果。

## 5. 本次运行

[本次运行] MATLAB 版本为 `24.1.0.2537033 (R2024a)`。

### 5.1 针对性测试

运行入口：

```text
addpath('src','config','tests');
test_stage4a6_2_profile_semantics;
test_stage4a6_2_calibration_counts;
test_stage4a6_2_flat_profile;
test_stage4a6_2_member_aggregation;
test_stage4a6_2_resume;
```

结果：5 项全部通过，退出状态 0。日志：`results/logs/stage4a6_2/targeted_unit_tests_final2.log`。

覆盖内容包括 profile 关闭、校准总数与排除数、平坦/扫描不可靠、等价成员聚合以及 shard 哈希校验。

### 5.2 Profile smoke

运行入口：

```text
run_stage4a6_2_profile_stabilization('smoke')
```

配置为 A 快速网格的前 9 个频点、串行 1 worker、G001 与 G007 两个代表性拓扑、每拓扑一个独立 case、profile 初始 3 点且不进行细化。求解器为 `lsqnonlin`，smoke 优化预算为 2 个起点、60 次迭代、180 次函数评价。

[本次运行] 两个 case 均完成了 profile 计算，且没有 MATLAB 进程级中止：

| case | 拓扑 | active 参数数 | profile computed | profile reliable | 优化器状态 | 运行时间 |
|---|---|---:|---:|---:|---:|---:|
| `stage4a6_2_smoke_G001` | G001 | 3 | 1 | 1 | converged/consistent | 1.111273 s |
| `stage4a6_2_smoke_G007` | G007 | 5 | 1 | 1 | converged/consistent | 0.530502 s |

当前源码哈希下的重跑重新计算了两个 case；runtime CSV 中记录 2/2 completed、0 resumed、0 failed、0 pending。此前哈希不匹配的 shard 未被复用。由于本 smoke 未建立足够的独立 calibration evidence，逐参数最终状态仍为 `indeterminate` 或 `inactive`，不能据此报告参数域检测率。

结果文件：

```text
results/data/stage4a6_2/stage4a6_2_smoke_case_manifest.csv
results/data/stage4a6_2/stage4a6_2_smoke_profile_summary.csv
results/data/stage4a6_2/stage4a6_2_smoke_runtime.csv
results/data/stage4a6_2/shards/*.mat
results/logs/stage4a6_2/profile_smoke_clean.log
```

当前 smoke 的 scientific hash 为 `7d2177966e6e529810459af29be60cb13cbfad20db02a299fe2eb434fcfba811`，source-tree hash 为 `5b3e2695646d4f5ced479b930ddc69eb956f274e492f25fe1e46e0ae00bc0cfa`。

### 5.3 完整回归

运行入口：

```text
addpath('src','config','experiments','tests');
run_tests
```

[本次运行] Stage 1.5、Stage 2、Stage 2.1、Stage 2.2、Stage 2.3、Stage 3A、Stage 3B-pre、Stage 3B waveform baseline、Stage 4A.1～Stage 4A.6.1 以及新增 5 项 Stage 4A.6.2 测试全部通过，退出状态 0。日志：`results/logs/stage4a6_2/full_regression_final.log`。

## 6. 并行策略

[历史结果] Stage 4A.6.1 已有 1/4 worker benchmark：1 worker 为 1.592031 s，4 workers 为 13.839053 s，speedup 为 0.115039，数值正确性标记为 1；峰值 RAM 和 swap 未测得。该结果显示该代表性任务在 4 workers 下没有加速。

[本次运行] Stage 4A.6.2 默认保持串行，没有启动并行池，也没有在 profile smoke 尚未稳定前测试 6/8 workers。并行化不会增加观测维度或物理可辨识性。

## 7. 阶段门槛判断

本阶段判定为：

```text
B. Stage 4A.6.2 部分通过：软件和执行稳定性改善，但 profile coverage
   和参数域 calibration/final 证据仍不足，需要继续完善后再冻结正式验证。
```

直接依据是：

1. 新增语义、计数、聚合、哈希和 resume 测试通过；
2. profile-enabled 双拓扑 smoke 可完成并可从 shard resume；
3. 完整历史回归通过；
4. 目前只有小规模 smoke，没有完成新的多拓扑、多 seed calibration/final profile 实验；
5. 因此尚无可报告的 Stage 4A.6.2 参数域 OOD recall、漏报警率或正式 profile coverage。

## 8. 研究边界

当前结果只证明软件状态语义、分批执行和小规模 profile 运行可以稳定完成。profile 优化收敛不等于物理参数真实可辨识；局部 Jacobian 或多起点一致也不构成全局唯一性证明。SISO 对称拓扑仍可能只能输出观测等价类。Stage 4B 未启动，真实 GIS、现场测量、真实 PLC PHY、FDR/TFDR 和硬件验证均未接入。

## 9. 后续工作

下一步应在新的、未用于方法选择的 calibration/test seed 上扩大 case manifest，首先验证 A 网格的 profile coverage 和逐参数状态分布，再决定是否运行 B 网格。若 calibration 可靠 evidence 仍不足，应输出 `insufficient_calibration` 或 `indeterminate`，不应通过删除困难样本放宽门槛。
