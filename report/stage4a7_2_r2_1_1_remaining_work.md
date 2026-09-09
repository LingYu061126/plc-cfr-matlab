# Stage 4A.7.2-R.2.1.1 剩余工作清单

R2.1.1 状态：**completed（实验设计与等价性审计闭环）**。以下是进入后续参数域科学验证前仍需完成的工作，不构成对本阶段验收结果的否定。

已完成：

- SHA256 已知向量与派生 CSV 双路径核验；
- 错误 required edge 不再读取 reference edge；
- formal 输出使用独立的 `stage4a7_2_r2_1_1` 目录；
- candidate-pair 等价审计改为 pair-key 连接；
- development 方法并列增加 paired bootstrap 语义；
- 87 候选 fresh formal 与 1044 场景 paired validation；
- 最新源码身份下重新生成 formal、paired 和 equivalence，并补充按候选指标与 transition bootstrap 表；
- 在再次冻结源码身份后生成 `final_source_v3/`，补充 `corruption_manifest.csv`、formal 局部等价诊断范围字段，以及 pair/projection 端点、模板索引和完整 pair-count 硬断言；v3 formal、paired、equivalence 和完整回归均退出状态为 0；
- 完整历史回归通过。

仍未完成：

1. 完成 accepted equivalence member 的逐成员参数 profile、可靠性门控、参数域状态和 parameter selective risk；
2. 生成实际同观测等价的非唯一场景，并计算可评价的 false-unique 分母；
3. 对全部 candidate pair 做 cross-theta profile，或正式冻结“nearest pair only”作为诊断而非全局等价结论；
4. 在有足够独立任务后再评估并行池；本阶段不以 CPU 利用率替代科学正确性；
5. 处理 MATLAB interprocess mutex 的环境根因，而非继续依赖启动 workaround；
6. 完整 Final 和 Stage 4B 均未启动。

上述事项不得通过删除失败样本、放宽阈值、使用 truth 修正候选或把最近竞争者当成等价类来“完成”。
