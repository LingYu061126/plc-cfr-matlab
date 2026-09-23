# Stage 7A 参数剖面搜索技术记录

日期：2026-09-23。验证基底为 `81b95a63c5ce7e4ba6985de52cd5177768f68a59`；Stage 6A/6B 正式结果源为 `bea0aee10b216ba42813329772f05a24dbdca07c`。Stage 7A 当前为未提交工作树增量，源文件原始字节身份见 `results/data/stage7a/source_inventory.csv`。本记录不是正式论文报告。

## 方法与预先固定的协议

[implemented] 新方法从 Stage 6A 合成 allowed-edge prior 推得四段 20 m 主线各自的 18–22 m 区间，统一主线 scale 的逐边交集为 `[0.90,1.10]`；对 Stage 6A partial-prior 候选还与总长度 80–110 m 相交。Stage 6B 扩展 grammar 只继承相同标称主线的逐边参数假设，不错误套用 Stage 6A 分支数/总长度限制。支路长度固定。负载 scale `[0.80,1.20]` 仅是 Stage 6B 受控扰动对应的 nuisance 假设，不是现场通用容差。coarse/fine 主线步长为 `0.05/0.025`，负载步长为 `0.20/0.10`。每个局部模型内，每候选、每参数格点只计算一次正向 CFR；评分只从缓存计算 coarse 最佳点及其相邻 fine 窗口，不接收真实生成参数。搜索域、候选库或距离尺度改变时，独立重做候选集合、domain gate 与证据层局部校准；Stage 6B 方法保持独立 baseline。完整预先协议见 [`stage7a_protocol.md`](stage7a_protocol.md)。

[implemented] 保留 calibrated candidate set、domain rejection，以及 `UNIQUE_CONFIDENT / MULTIPLE_AMBIGUOUS / LOW_CONFIDENCE / REJECTED` 的既有语义。normalized confidence score 不是 Bayesian posterior，不跨候选库解释为统一概率。校准种子为 `20267001`，测试种子为 `20267002`；formal 每候选 20 个校准样本。Stage 6B 参数/错误先验重放使用原实验种子和噪声，70 个参数样本的 baseline 状态与 CFR 距离逐样本对上归档 CSV。所有结果只写入独立 Stage 7A 目录。

## 正式对照结果

来源：`results/data/stage7a/formal/stage7a_comparison.csv`、`stage7a_summary.csv`、`stage7a_safety.csv`、`stage7a_resources.csv`。以下 U/A/L/R 分别为四状态数量；单元为样本，不将正确唯一确认与任何物理全局唯一混同。

| 对照 | Stage 6B baseline | Stage 7A | 解释 |
|---|---:|---:|---|
| 同源参数失配，正确 U / 70 | 10 | 50 | `[−10%,+10%]` 内的 −10%、−5%、0、+5%、+10% 各 10/10 正确 U；±20% 共 20/20 拒绝 |
| 独立库内、域内样本，正确 U / 10 | 5 | 10 | 真拓扑覆盖率均为 1；Stage 7A 候选集合覆盖 10/10 |
| 独立域外 `0.85/1.15`，拒绝 / 10 | 10 | 10 | 仅适用于固定合成模型与这些域外点 |
| wrong-open / wrong-closed，拒绝 / 14 | 14 | 14 | 两方法库外误接受均为 0，false unique 均为 0 |
| T3/T5 与 three-topology-close，ambiguous / 2 | 2 | 2 | 搜索距离进入冻结 Stage 5B.1 正控制判决；这两库没有宣称新局部校准可部署 |
| 候选规模 3/7/23，正确 U / 10 | 10 / 10 / 10 | 7 / 8 / 4 | 明确退化；3 候选的集合覆盖也从 10/10 降为 8/10 |

[verified by experiment] 正式比较共 272 条成对方法记录。所有普通测试中 false unique 为 0；14 个库外错误先验样本两方法均 `REJECTED`；两个受控不可辨识案例均 `MULTIPLE_AMBIGUOUS`。预设安全规则通过，但 Stage 7A 在 candidate-scale 三组均降低正确确认率，不能只报告参数改善。

[verified by experiment] 23 候选模型占用约 1.52 MB（MATLAB `whos`，不是进程峰值内存），Stage 6B 对照约 0.93 MB；Stage 7A 缓存构造约 0.448 s，对照约 0.031 s，校准约 0.600 s，对照约 0.415 s。该组单样本平均评分约 0.000787 s，对照约 0.001031 s；这些微秒级差异受 MATLAB/JIT 影响，不能单独宣称总体更快。formal 主函数计算约 3.024 s，另有 MATLAB 启动与退出开销。所有运行保持串行，无 parallel pool。

## 验证与归档

[verified by experiment] MATLAB `24.1.0.2537033 (R2024a)`：Stage 7A 定向测试、smoke、formal，以及 Stage 5B.1/6A/6B/Stage 6 archive/Stage 7A 相关回归均通过；最终日志为 `results/logs/stage7a/stage7a_regression_final.log`、`stage7a_smoke_acceptance.log` 和 `stage7a_formal_acceptance.log`，最终快照与元数据哈希一致。84 个重放 baseline 样本（参数 70、错误先验 14）的状态及距离与 Stage 6B 归档 CSV 精确匹配。Stage 6 归档完整性测试继续通过，旧阶段 canonical CSV/MAT/PNG 和冻结源码未改动。Stage 7A 测试独立运行，不注册到被冻结哈希覆盖的 `tests/run_tests.m`；本轮未在不干净工作树上运行要求 clean Git 身份的完整 `run_tests.m`。

结果目录中的 `stage7a_config_snapshot.mat` 和 `stage7a_metadata.csv` 固定搜索域、种子、校准数、候选库及来源身份。`stage7a_resources.csv` 给出不同候选规模的 wall-clock 与模型字节数。失败的早期 smoke 日志仅用于记录普通编排错误；正式结论依据最终通过的 acceptance 日志。

## 未解决问题与阶段判定

[not yet verified] 尚未解释为何宽搜索使 3/7/23 候选库的 calibrated candidate set 或证据门槛变得更保守；这可能与候选间距离尺度、局部校准分辨率及候选竞争有关，需要独立开发样本分析，不能根据正式测试反复调阈值。相同 medium 库在参数与规模对照中仍分别构造缓存以保持局部校准隔离，跨实验缓存去重尚未实现。长度仍按全主线统一 scale，未覆盖逐段长度、RLGC、频变复负载、同步误差或更大候选库。T3/T5 正控制使用冻结 Stage 5B.1 evidence model，仅说明新搜索未把这些受控不可辨识样本强制唯一，不等于已经完成这两库的新局部校准。

Stage 7A **通过预设安全检查，但未达到替代 Stage 6B baseline 或直接推广到下一轮算法主线的条件**：库内参数失配改善明显，候选规模确认率却显著退化。下一轮应首先用独立开发集诊断候选集合覆盖和校准分辨率，再决定是否提出新的、预先冻结的改进方案。本阶段不启动 Multi-view CFR 或正式论文写作。所有结论仅限受控合成模型，非现场低压台区或真实 PLC 收发机验证。
