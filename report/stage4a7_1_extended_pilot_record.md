# Stage 4A.7.1 独立扩展 Pilot 记录

## 1. 范围与数据协议

本扩展实验在 Stage 4A.7.1 已冻结的方法定义下增加独立样本数量，不运行连续参数 profile，不使用 Pilot 标签调整阈值，也不物化 `final_reserved`。观测仍为 A 网格（2–30 MHz，61 点）上的模型生成无噪声 SISO 复 CFR；候选库仍为 7 个受限径向合成拓扑、每图 243 个离散参数模板。[本次运行]

Calibration 使用 master seed `20261811`，每个候选拓扑 100 个独立连续域内场景，共 700 个。Pilot 使用 master seed `20261821`，包含 210 个连续域内、7 个 symmetry-preserving nominal、210 个参数 OOD 和 73 个结构 OOL 场景，共 500 个。参数 OOD 按 near、medium、far 各 70 个；无支路拓扑不生成无物理意义的支路长度或支路负载越界。[本次运行]

`final_reserved` seed 为 `20261831`，状态为 `manifest_only_not_materialized`。[本次未运行]

## 2. 独立性审计

| Split | 行数 | 唯一物理场景 | 唯一参数向量 | 唯一 CFR | 跨 split 参数重复 | 跨 split CFR 重复 |
|---|---:|---:|---:|---:|---:|---:|
| Calibration | 700 | 700 | 700 | 700 | 0 | 0 |
| Pilot | 500 | 500 | 494 | 500 | 0 | 0 |

Pilot 中 6 个重复参数哈希来自 7 个拓扑共享冻结名义参数的 symmetry-preserving 设计；拓扑网络不同，最终 500 个 CFR 哈希均唯一。联合参数 OOD 通过确定性 case-index jitter 产生独立参数向量，near/medium/far 越界区间保持不重叠。[本次运行]

## 3. Calibration

按候选类别的 empirical candidate-set calibration 每类使用 100 个非相容度分数，`alpha=0.05`，最小可达到 p-value 为

\[
\frac{1}{100+1}=0.00990099.
\]

M3、加权残差和候选集合阈值只由 calibration split 产生。Pilot truth 只在决策完成后的离线评分中使用。[代码静态核对/本次运行]

## 4. 扩展 Pilot 结果

拓扑集合准确率的分母为真值位于评分候选库的 427 个场景；结构 OOL 的 73 个场景单独计算误接受。所有区间为 Wilson 95% 区间。[本次运行]

| 方法 | topology set accuracy | accepted coverage | topology selective risk | average set size | parameter OOD FA | structure OOL FA |
|---|---:|---:|---:|---:|---:|---:|
| M0 minimum residual | 392/427 = 91.8% | 500/500 = 100% | 35/427 = 8.20% | 1.554 | 210/210 = 100% | 73/73 = 100% |
| M3 frozen | 337/427 = 78.9% | 359/500 = 71.8% | 0/337 = 0% | 1.144 | 144/210 = 68.6% | 22/73 = 30.1% |
| W-GLRT-compatible | 374/427 = 87.6% | 457/500 = 91.4% | 10/384 = 2.60% | 1.408 | 177/210 = 84.3% | 73/73 = 100% |
| C-set | 357/427 = 83.6% | 446/500 = 89.2% | 17/374 = 4.55% | 4.936 | 159/210 = 75.7% | 72/73 = 98.6% |
| C-set + I | 357/427 = 83.6% | 446/500 = 89.2% | 17/374 = 4.55% | 4.936 | 159/210 = 75.7% | 72/73 = 98.6% |

M3 的结构 OOL false acceptance 为 22/73，Wilson 95% CI 为 20.8%～41.4%；参数 OOD false acceptance 为 144/210，CI 为 62.0%～74.5%。其 0/337 的拓扑选择性风险必须与 71.8% 的接受覆盖共同报告，不能解释为无条件零错误。[本次运行]

C-set 输出 394/500 个 ambiguous candidate set，singleton 仅 51/500，说明其较高接受覆盖主要依赖较大的集合；`C_set_plus_I` 当前只增加不可区分图审计，不改变候选集合，因此汇总指标相同。[本次运行]

same-theta 真实非唯一场景仍为 4 个，五种方法的 conditional false-unique 为 0/4，Wilson 上界约 49.0%。本扩展主要增加域内和 OOL 统计量，未增加足够的非唯一场景；false-unique 仍不能形成稳定结论。[本次运行]

## 5. 运行与复现

- MATLAB：`24.1.0.2537033 (R2024a)`。
- 模式：`extended_pilot`，串行 1 worker，未启动并行池。
- MATLAB 内部总耗时：19.173 s；含 MATLAB 启动 wall-clock：28 s。
- 结果目录占用约 66 MB；峰值 RSS 因系统缺少 `/usr/bin/time` 可执行文件而未测得。
- Scientific hash：`0a7ad136906bcc694e9cdc57485e98b3b14f59e1c377a526b9098a8d631e77f1`。
- Source-tree hash：`1141cb13c2e374847868383474ff86613e2d208f6174d54251de1e327054a705`。
- Pilot 命令：`run_stage4a7_1_candidate_generation_and_confirmation('extended_pilot')`，退出状态 0。
- 完整回归：`run('tests/run_tests.m')`，退出状态 0；Stage 1.5～Stage 4A.7.1 全部通过。

| Phase | 事前预计 | 实际 | 偏差原因 |
|---|---:|---:|---|
| 配置和独立场景扩展 | 10–20 min | 约 15 min | 增加 active-parameter OOD 筛选和联合参数独立扰动 |
| 定向测试 | 1–3 min | <1 min | 仅物化清单和运行小型函数测试 |
| 700+500 Pilot | 45–90 s wall | 28 s wall | 61 点模板评分和缓存构建开销低于估计 |
| 完整历史回归 | <1 min | 13 s wall | 全部测试为小型确定性用例 |

## 6. 结论边界

扩大样本后，M3 对结构 OOL 的拒识优势仍然存在，但参数 OOD 大量被拓扑确认器接受；后者应由独立参数域诊断处理，而不能被重新解释成拓扑错误。W-GLRT-compatible 的冻结噪声尺度不是现场噪声协方差，C-set 的经验 p-value 不是后验概率，也不提供现场 coverage 保证。[模型推断]

本结果不是完整 Final，不是 B 网格比较，不是现场配电网验证，也不是真实 PLC 收发机验证。候选确认接受不证明物理唯一性；Stage 4B 未启动。[模型推断]
