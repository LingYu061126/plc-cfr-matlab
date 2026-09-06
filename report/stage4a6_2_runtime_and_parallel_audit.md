# Stage 4A.6.2 运行稳定性与并行审计

## 1. 审计对象

[代码静态核对] 本阶段的主要计算热点是：候选成员的域内/扩展域连续拟合、逐参数 profile 扫描、扫描点内部的多起点优化以及嵌套诊断结构的保存。profile 关闭时，Stage 4A.6.1 的空 profile 语义会把“未计算”误并入“可靠”；Stage 4A.6.2 使用独立状态字段修正这一问题。

| 优先级 | 逻辑 | 主要原因 | 并行适合性 | 推荐粒度 | 内存风险 | 当前处理 |
|---:|---|---|---|---|---|---|
| 1 | 单参数 profile 的扫描点优化 | 每个参数值重复拟合其余 active 参数 | 适合 case/拓扑级粗粒度并行；不做嵌套并行 | 独立 case | 高 | 先串行、warm start、紧凑 shard |
| 2 | 域内/扩展域多起点优化 | 正向模型每次评价都生成网络响应 | 可在独立样本或候选成员级并行 | 外层 case | 中 | 复用既有 solver，保存状态字段 |
| 3 | profile 诊断结构保存 | 大型嵌套结构长期驻留会增加内存 | 不适合 worker 直接写共享文件 | 主进程原子保存 | 中 | shard 仅保存摘要与必要扫描点 |
| 4 | 完整频率网格响应 | 1793 点会放大每个目标函数评价 | 适合外层样本，但数据复制成本需验证 | 外层样本 | 高 | smoke 先用 A 网格 9 点子集 |
| 5 | 结果汇总与 CSV/MAT 写入 | 并发 I/O 可能超过计算收益 | 不适合 worker 共享写入 | 主进程 | 低到中 | 主进程统一保存 |

## 2. Worker 选择

[历史结果] 已核验的 Stage 4A.6.1 代表性 benchmark：

| workers | runtime | speedup | correctness | peak RAM | swap |
|---:|---:|---:|---:|---|---|
| 1 | 1.592031 s | 1.000000 | 1 | 未测得 | 未测得 |
| 4 | 13.839053 s | 0.115039 | 1 | 未测得 | 未测得 |

4 workers 没有缩短 wall-clock time，因此 Stage 4A.6.2 初始配置固定为串行 1 worker。6/8 workers 未运行，避免在已有负收益证据下无目的扩大并行池。上一阶段的本地 benchmark 日志包含前置失败调用和后续成功输出，CSV 作为结构化 benchmark 证据；不能将混合日志视为独立的干净 benchmark 记录。

## 3. Stage 4A.6.2 smoke

[本次运行] profile smoke 使用 A 快速网格前 9 个频点、2 个拓扑 case 和串行执行。源码哈希清单补全后，旧 shard 因源码 hash 不匹配未被复用，G001/G007 均按当前 hash 重新完成；入口退出状态为 0。两个 case 的实际 profile runtime 为 1.111273 s 和 0.530502 s，runtime CSV 记录 2/2 completed、0 resumed、0 failed、0 pending。

该结果只验证分批执行和 resume 机制，不提供完整 A/B 频率网格的性能结论。

## 4. 完整性与可复现性

每个 shard 保存：

```text
case_id
scientific_hash
source_tree_hash
status / exit_status
started_at / finished_at / runtime_s
profile_summary
optimizer_state
error_identifier / error_message
checksum
```

case seed 由 master seed、Stage 标识和 case 身份字段确定，不依赖 worker 调度顺序。当前 smoke manifest 保存了 case seed、网格、拓扑、输出路径和两类哈希。并行模式尚未启用，因此本阶段尚未产生新的串并行逐 case 一致性证据。

## 5. 运行门槛

[本次运行] 新增测试和完整历史回归均通过；profile-enabled 小批次可完成且可以 resume。由于目前 profile evidence 仅来自两个 smoke case，尚未满足多 seed calibration/final 冻结实验的覆盖要求，阶段结论为“部分通过”。在完成较大规模串行 calibration 前，不建议启动正式 A/B profile final，也不建议开启更高 worker 数。
