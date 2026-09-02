# PLC-CFR 项目共享交接状态

> 用途：这是网页端讨论、Codex 任务、IDE/CLI 工作之间共用的**项目事实快照**，不是聊天原文，也不记录私人信息。新任务应先阅读本文件，再按其中链接阅读对应报告和代码。

## 1. 当前基线

- 仓库：<https://github.com/LingYu061126/plc-cfr-matlab>
- 分支：`main`
- 状态快照基线：`5d34ac9 docs: freeze PLC transceiver baseline evidence`（2026-09-02）
- 当前阶段：**Stage 3B-pre 已完成并收尾；正式 Stage 3B 尚未启动。**

已完成阶段包括 Stage 1.5、2、2.1、2.2、2.3、3A、3A.1、3A.2，以及带宽配置边界和 Stage 3B-pre 理想 CFR 诊断。后两者不等于真实 NB/BB 硬件实验。

## 2. 已确认的项目结论

1. 当前拓扑感知主链路为
   `OFDM/训练符号 → PLC 网络 CFR → 信道估计 → CFR/CIR/端口特征 → 候选拓扑匹配或等价类`。
2. 现有早期 OFDM 模型与 Stage 3B-pre 结果是模型内仿真；它们不构成真实 PLC 收发机或现场拓扑识别验证。
3. 给定当前 SISO 观测配置，T3/T5 的结构观测等价仍存在。更复杂的分类器、更多频点或更高数值准确率本身不能保证唯一识别。
4. Stage 3B-pre 已被准确降级为“理想 CFR + 接收端样点等效噪声 + 名义库/参数失配”的解析外推诊断；它没有实现等总能量、等观测时间或重复平均增益。
5. G3-PLC 低频结果仍基于当前线路模型的解析外推，不能解释为真实窄带优劣或物理 NB/BB 对比。

## 3. 已冻结的标准派生主基线

推荐主基线是：

```text
Ghn_100MHz_powerline_SISO_standard_derived_reference
```

它是用于下一轮**波形级模型**的标准/资料派生参考平台，不是已采购、接线、标定或验证的硬件。

可作为下一版独立配置的标准派生字段：

| 字段 | 冻结值或规则 | 边界 |
|---|---|---|
| OFDM 网格 | `NFFT=4096`、`Fs=100 MHz`、`Δf=24.4140625 kHz` | G.hn 派生；2--30 MHz 只是本项目研究 mask |
| GI/CP | 使用 G.hn 的 GI/window 规则；100 MHz-PB 可核验参考为 `β=512`、`N_GI=1024`、`N_CP=N_GI+β` | 不得把历史 `CP=256` 写成 G.hn 实机参数 |
| PSD 框架 | 2--30 MHz 段 `−55 dBm/Hz` 上限、`+20 dBm` 合规上限、`100 ohm` 标准测量端接 | 合规参考不等于本项目实装输出、线路端接或注入电压 |
| 窄带对照 | G3-PLC CENELEC-A：`N=256`、`Fs=0.4 MHz`、36 carrier、`N_CP=30`、overlap `8` | 仅独立窄带对照；低频线路模型尚未校准 |

完整的来源、页码、证据等级和参数冻结矩阵见：[stage3b_transceiver_baseline_freeze.md](stage3b_transceiver_baseline_freeze.md)。

## 4. 仍必须作为假设或未来实测项

下列内容尚不能冻结为本项目真实硬件参数：

- 实际 active carrier、notch、导频/训练图样与固件 profile；
- 耦合器、隔离/保护网络的复传递函数与线路侧参考面；
- 源端/接收端阻抗 `Zs(f)`、`Zr(f)`、负载分布及实际 RLGC；
- 可导出的 CFR/IQ/反射端口，以及测量节点和方向；
- AGC、同步时间原点、残余 CFO/SCO；
- 现场背景噪声、脉冲噪声统计和实际 SNR；
- 窄带 CENELEC-A 下的线路、端接与耦合标定。

因此，标准参数与理想 CFR 诊断只提高模型可追溯性，**不等于真实 PLC 拓扑识别性能已被验证**。

## 5. 下一步允许开展的工作

下一项允许启动的是“Stage 3B 前的波形级基线实现准备”，而不是资源优化或硬件结论。实施时应创建与既有历史模型隔离的新配置/实验，至少包含：

1. G.hn 派生频率栅格和显式 2--30 MHz 研究 mask；
2. IFFT、可参数化 GI/window、抽象前导--header--payload 训练块；
3. 线性时域卷积、LS CFR 估计、CFO/定时/SCO 接口；
4. 有色/脉冲噪声接口，以及参数化耦合器、端接与参考面；
5. CP 覆盖与循环 CIR 非物理 ToA 的审计；
6. 对 T3/T5 等价类、false-unique 和多观测需求的持续审计。

开始写代码前，先用 `/plan` 或等价的只读计划阶段说明：拟改文件、新旧配置隔离方式、每个参数的证据来源、测试和回归方案。不得覆盖 Stage 1--3A.2 的代码、结果或历史结论。

## 6. 必读文件

| 目的 | 文件 |
|---|---|
| 当前主基线与参数证据 | [stage3b_transceiver_baseline_freeze.md](stage3b_transceiver_baseline_freeze.md) |
| Stage 3B-pre 诊断边界与结果 | [stage3b_pre_level_a.md](stage3b_pre_level_a.md) |
| 进入门槛与未冻结量 | [stage3b_entry_gate.md](stage3b_entry_gate.md) |
| 多观测物理建模 | [stage2_2_physical_multiview.md](stage2_2_physical_multiview.md) |
| 等价类与可辨识性 | [stage2_3_observability.md](stage2_3_observability.md) |
| 当前仓库使用规则 | `AGENTS.md`（若当前工作副本提供）与 [README.md](../README.md) |

## 7. 更新规则

每次完成一个可复核任务后，仅更新本文件中的：当前提交号、阶段、已验证结论、下一步允许任务和必读文件。不要粘贴聊天原文、私人内容、访问令牌、绝对本机路径或未经核验的推断。

若聊天中的结论与本文件或已提交报告冲突，以原始标准/论文、当前代码与已提交结果为准，并在下一次提交中显式更正。
