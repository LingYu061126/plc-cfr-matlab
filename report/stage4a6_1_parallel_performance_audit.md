# Stage 4A.6.1 并行性能审计

## 1. 审计范围

本记录评估 Stage 4A.6.1 中连续参数拟合、profile likelihood 和外层案例批处理的耗时与并行适用性。审计不改变稳定传输线正向模型，也不把并行加速解释为物理可辨识性提升。

## 2. MATLAB Profiler 结果

[本次运行] 在代表性小规模优化上，观察到的主要热点如下：

| 优先级 | 文件/函数 | 耗时逻辑 | 慢的原因 | 是否适合并行 | 推荐粒度 | 重复计算 | 内存风险 | 正确性风险 |
|---:|---|---|---|---|---|---|---|---|
| 1 | `plc_multiview_response` / `plc_full_network_response` | 每次目标函数评价重建网络 CFR | 每个参数点均重新调用完整网络模型 | 适合外层案例并行 | 案例 | RLGC、ABCD 和网络响应重复 | 中 | 参数顺序与候选 ID 必须保持 |
| 2 | `optimize_stage4a6_1_parameters` | 多起点 `lsqnonlin` | 同一案例重复求解非线性目标 | 适合案例级并行 | 案例 | 起点结果不复用 | 中 | 多起点 seed/顺序必须固定 |
| 3 | `compute_stage4a6_1_profile` | 固定参数扫描并重新优化其余参数 | 每个 profile 点触发一次有界拟合 | 适合参数/案例批处理，但不做嵌套并行 | profile 批次 | 频率和网络固定项重复 | 高 | profile 顺序和阈值来源 |
| 4 | `compute_stage4a6_1_jacobian` | 有限差分响应 | 每个 active 参数额外计算两次响应 | 可随案例并行 | 案例 | 固定网络部分可缓存 | 中 | active mask 一致性 |
| 5 | `write_outputs` 与 worker 数据复制 | 大型嵌套诊断结构保存 | optimizer runs/profile 曲线包含大量中间字段 | 不宜并行写文件 | 主进程统一写 | 诊断字段重复保留 | 高 | 文件竞争和结构体字段不一致 |

审计结论是：最安全的并行粒度是“独立观测案例”，不采用 profile 内层与案例外层的嵌套 `parfor`。worker 只返回结果，CSV/MAT 由主进程统一写入。

## 3. 实现的并行接口

`src/run_stage4a6_1_member_batch.m` 提供：

```matlab
sc.parallel.use_parallel = false;   % 串行 fallback
sc.parallel.use_parallel = true;    % 外层案例并行
sc.parallel.num_workers = N;
sc.parallel.parallel_strategy = 'outer_cases';
```

没有 Parallel Computing Toolbox 或无法创建 pool 时，项目仍保留串行路径。当前实现不让 worker 并发写 CSV、MAT 或日志。

## 4. Worker benchmark

[本次运行] 固定 A 网格、小规模 final-only 案例、profile 关闭，得到：

| workers | runtime (s) | speedup | correctness | peak RAM | swap |
|---:|---:|---:|---|---|---|
| 1 | 1.592031 | 1.000 | 通过 | 未测得 | 未测得 |
| 4 | 13.839053 | 0.115 | 通过 | 未测得 | 未测得 |
| 6 | 未测得 | — | 未完成 | — | 进程异常/曾观察到 swap 风险 |
| 8 | 未测得 | — | 未完成 | — | 未测量 |

4-worker 结果虽然逐案例输出与 1-worker 一致，但在该小样本上并行池初始化和数据复制远大于计算收益。运行环境观察到约 16 GiB 内存、约 19 GiB swap；此前 6-worker 尝试导致 MATLAB 进程异常结束，因此没有继续强行运行 6/8 workers。

结果文件：`results/data/stage4a6_1_worker_benchmark.csv`；日志：`results/logs/stage4a6_1_worker_benchmark_1_4.log`。

## 5. 缓存与内存修正

阶段入口在 calibration 阈值生成后压缩嵌套 optimizer/profile 诊断结构，仅保留决策、校准和结果摘要所需字段。该操作不改变拟合值、profile 曲线或判定数学定义，但降低了长批次持续保留 `runs`、固定参数曲线和嵌套 solver 输出的风险。

由于完整 profile experiment 仍存在 MATLAB 进程级中止，本次没有将该修正描述为已经解决所有长期内存问题。后续更稳妥的方案是按案例或小批次启动独立 MATLAB 进程，生成紧凑结果后释放进程。

## 6. 串行/并行正确性

[本次运行] benchmark 对 1-worker 与 4-worker 的案例结果签名进行比较，`correctness=1`。比较对象包括结果数量和每个案例的距离摘要；更完整的 profile 字段逐项比较尚待 profile 正式批次稳定后完成。

[模型内推断] 并行结果一致只说明实现没有明显改变当前小批次的数值输出，不代表 MATLAB worker 在所有工具箱、内存和大频点网格下都安全。正式实验应先确认内存，再选 worker 数。

## 7. 当前性能结论

当前机器上的小样本测试不支持默认启用 4、6 或 8 workers。对本阶段的可靠性优先级而言，建议暂时使用串行模式或每个独立 MATLAB 进程运行一个小批次；若后续批次足够大并且缓存可安全共享，再重新 benchmark。没有证据表明并行能够改善参数域判定质量。

## 8. 未完成项目

- [本次未运行] 6/8 workers 的完整可比 benchmark；
- [本次未运行] profile-enabled A/B formal final；
- [本次未运行] profile coverage-aware 的正式 calibration/final 统计；
- [待验证] `parallel.pool.Constant` 或预计算网络项是否在 1793 点网格下减少复制；
- [待验证] 按案例独立 MATLAB 进程是否可以稳定完成全 profile 批次。
