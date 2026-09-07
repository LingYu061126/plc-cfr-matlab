# Stage 4A.6.3.1-R.2 宿主 MATLAB 并行复核记录

## 范围

本记录补充 R.2 原有并行启动失败记录。原有 `parallel_benchmark.csv` 和相关日志保持不变；本次使用已恢复的宿主 Xwayland 与 MATLAB R2024a，在独立输出目录中重新运行相同的 14 个 calibration 和 35 个 Pilot 场景。

## 执行设置

- MATLAB：R2024a `24.1.0.2537033`
- 网格：`A_stage4a1_quick61`
- 候选拓扑：7
- calibration：14 个场景
- Pilot：35 个场景
- `final_reserved`：仅生成 manifest，未执行
- 并行粒度：外层独立场景物化和场景等价性审计；不使用嵌套并行
- 输出目录：`results/data/stage4a6_3_1_r2/host_serial_w01_20260908/`、`host_parallel_w04_20260907/`、`host_parallel_w06_20260907/`、`host_parallel_w08_20260907/`

## 运行结果

| workers | runtime (s) | 相对 1 worker | 结果一致性 | 状态 |
|---:|---:|---:|---|---|
| 1 | 59.730270 | 1.000000 | 串行基准 | 完成 |
| 4 | 72.374594 | 0.825293 | CSV 精确一致 | 完成 |
| 6 | 73.935406 | 0.807871 | CSV 精确一致 | 完成 |
| 8 | 78.254347 | 0.763284 | CSV 精确一致 | 完成 |

相对 1 worker 的数值小于 1，表示本任务在当前实现和场景规模下没有获得加速；4、6、8 workers 均增加了 wall-clock time。8 workers 运行期间观察到约 1.7 GiB 可用内存和约 5.0 GiB 已用 swap 的采样状态，峰值 RSS 未可靠测得，因此不作精确内存结论。

## 一致性

1、4、6、8 workers 的以下文件 SHA256 完全一致：

- `pilot/pilot_match_decisions.csv`
- `pilot/pilot_member_evidence.csv`
- `pilot/pilot_scoring_labels.csv`

四组运行的 `compatibility_hash`、`source_tree_hash`、拓扑 calibration hash 和参数 calibration hash 一致。逐文件比较未发现决策、成员参数状态、seed 或 CFR hash 差异。

## 结论

本次验证证明 MATLAB `Processes` 并行池和外层并行接口可用，但当前 49 场景 R.2 任务不适合通过增加 worker 缩短运行时间。推荐默认保留串行作为基准；若未来扩大独立重计算场景数，再以 4 workers 作为低风险候选重新 benchmark。8 workers 不推荐作为默认配置，原因是观察到明显内存压力且没有加速。

本记录不构成完整 Final，也不改变当前模型 CFR、受限候选库、合成先验和单端口观测的研究边界。
