# Stage 3B-pre：真实 PLC 收发机主基线平台证据冻结

## 1. 当前阶段与本轮目的

当前阶段是：**Stage 3B-pre 已完成并收尾；正式 Stage 3B 尚未启动。**

已完成的 Stage 3B-pre 是“理想 CFR + 接收端 CFR 样点等效噪声 + 参数失配”的解析外推诊断，不是完整 PLC PHY、硬件或现场实验。本轮不修改 MATLAB、配置、测试、既有报告或结果，也不运行 MATLAB；唯一交付是把下一轮可用的收发机参数证据冻结为可追溯的模型边界。

这里的“主基线平台”指**标准/资料派生的波形级参考平台**，不是已采购、已接线或已标定的实验装置。标准参数、芯片公开资料和论文实测均不能自动证明本项目具有拓扑唯一识别能力；当前 SISO 的 T3/T5 观测等价结论继续有效。

## 2. 已阅读的项目边界

已完整核对 `AGENTS.md`、`README.md`、`report/stage3b_entry_gate.md`、`report/stage3b_pre_level_a.md`、`report/stage2_2_physical_multiview.md`、`report/stage2_3_observability.md`、`report/stage3a_communication_baseline.md`、`report/stage3a_1_parameter_aware_baseline.md`、`report/stage3a_2_model_validity_and_observation_protocol.md`、`report/stage3a_2_final_evidence_matrix.md`、`docs/宽窄带双频段研究设计.md`、`docs/参数来源与缺口清单.md`，以及 `src/stage3_band_configs.m`、`src/stage3a_config.m` 和对应测试。仓库上一级目录的既有证据副本 `../real_plc_transceiver_evidence (1).md` 亦已全文核对；它提供了本报告所列标准条款的交叉索引，但本报告仍以原始链接作为参数证据。

必须保留的边界如下：

- 当前 2--30 MHz、SISO、50 ohm 数学端口、RLGC、端接、噪声和 CP=256 中，只有有独立证据支持的字段才能被新波形级配置采用；历史 `64 MHz / 4096 / CP=256` 仍是 Stage 3A 项目假设，不能追溯写成 G.hn 实机参数。
- 当前 RLGC 的项目证据窗口是 2--30 MHz。G3-PLC CENELEC-A 的低频结果仍只是解析外推，不能成为物理 NB/BB 比较。
- Stage 3A 的 IFFT/CP/FFT/LS 链路不是完整 G.hn、HomePlug 或 G3-PLC PHY；循环 CIR 没有已校准物理时间原点。

## 3. 检索记录、可访问性与证据等级

检索日期：2026-09-02。实际检索式包括：

1. `site:itu.int/rec/T-REC-G.9960 G.9960 G.hn transceivers`
2. `site:itu.int/rec/T-REC-G.9964 G.9964 power line PSD`
3. `site:itu.int/rec/T-REC-G.9903 G3-PLC OFDM 256 400 kHz`
4. `G.hn power line chip datasheet G.9960 G.9964 official MaxLinear`
5. `site:microchip.com G3-PLC CENELEC-A 36 carriers 256 FFT datasheet`
6. `G.hn 4096 100 MHz 24.4140625 kHz G.9960 official PDF`

本轮直接检索并核验 8 份可访问资料：ITU-T G.9960、G.9964、G.9903（含公开 PDF/目录或摘要）、MaxLinear 88LX2720 产品页与数据表、Microchip PL360 主机 API 与 AN3400，以及原始论文 Cortés、Cañete、Díez (2023)；另全文阅读了上述项目既有证据副本，复核其 G.9963、PL360/PL485、HomePlug AV2 与原始测量论文的来源索引。证据等级统一为：`[A]` 标准或官方资料明确规定；`[B]` 原始论文实验设置；`[C]` 基于资料的受限推断；`[D]` 未找到可靠证据、不得采用。

| 编号 | 资料与访问状态 | 可支持的结论 | 位置 |
|---|---|---|---|
| S1 | [ITU-T G.9960 (06/2023) 官方页](https://www.itu.int/rec/T-REC-G.9960/en)，公开 PDF 可访问 | G.hn 系统架构和 PHY 规范的在行版本；全文具体条款仍应随目标版本核对 | 官方页、版本/下载项 |
| S2 | [ITU-T G.9960 (11/2018) 公开 PDF](https://www.itu.int/rec/dologin_pub.asp?id=T-REC-G.9960-201811-S%21%21PDF-E&lang=e&type=items) | Table 7-67 给出 `N=256...4096`、基本 `F_SC=24.4140625 kHz` 的倍数、GI 与窗参数规则 | p.103, Table 7-67；该版已 superseded，作为公开条款定位，目标 2023 版条款待复核 |
| S3 | [ITU-T G.9964 (12/2023) 官方页/PDF](https://www.itu.int/rec/T-REC-G.9964-202312-I/en) | PSD mask、功率、指定端接阻抗下的测量与接收输入阻抗属于规范范围 | TOC: clauses 5, 6.2, 6.4--6.6；数值 mask 待按目标地区/档案逐项选定 |
| S4 | [ITU-T G.9903 (08/2017) 公开 PDF](https://www.itu.int/rec/dologin_pub.asp?id=T-REC-G.9903-201708-I%21%21PDF-E&lang=e&type=items) | CENELEC-A 示例：`N=256`、`N_CAR=36`、`N_O=8`、`N_CP=30`、`F_S=0.4 MHz`、`N_PRE=9.5` | p.10, §7.3.1.1；后续修订/勘误应随目标固件复核 |
| V1 | [MaxLinear 88LX2720 官方产品页](https://www.maxlinear.com/product/connectivity/wired/g-hn/supporting-ics/88lx2720) | 电力线 Wave-2 G.hn AFE；100 MHz powerline SISO/MIMO profile；1 TX、2 RX；DW920 EVK 关联 | Overview / Documentation & Design Tools |
| V2 | [88LX2720 官方数据表](https://www.maxlinear.com/ds/88lx2720.pdf) | 集成 TX/RX 路径、增益、滤波与 line driver；产品框图与典型系统连接 | July 2020, figures 1--4；页码/电气极限待按 PDF 复核 |
| V3 | [Microchip PL360 Host Controller API](https://ww1.microchip.com/downloads/en/DeviceDoc/PL360-Host-Controller-50002738.pdf) 与 [AN3400](https://ww1.microchip.com/downloads/en/Appnotes/AN3400-PLC-and-Go-Application-Note-00003400A.pdf) | CENELEC-A 有 36 个 carrier；tone mask 可逐 carrier 屏蔽；API 可回读每 carrier SNR | API §10.2.5.15；AN3400 p.14 |
| P1 | Cortés, Cañete, Díez, “[Channel Estimation for OFDM-based Indoor Broadband Power Line Communication Systems](https://doi.org/10.23919/JCN.2022.000056),” JCN 25(2), 2023；工作区 PDF 已核对 | 171 条实测室内 CFR，1--87.15 MHz；帧前导/头部估计、notch 与非遍历性会影响 CFR 估计 | pp.151--156, Table I, Fig.3--6；不是拓扑反演或芯片资料 |

`[A]` 不代表“本实验室实际值”。公开标准全文中无法在本轮可靠定位的条款、未公开的固件 profile、实际板级原理图或厂商已下线资料，一律不作为冻结数值。

## 4. 平台参数—证据—用途表

### A. 宽带主候选：G.hn 100 MHz powerline SISO 参考平台

| 参数类别 | 参数名 | 数值或规则 | 证据等级 | 原始来源链接 | 页码/章节/表/公式 | 可否写入 MATLAB | 使用边界 |
|---|---|---|---|---|---|---|---|
| 平台 | 主参考名称 | `Ghn_100MHz_powerline_SISO_standard_derived_reference` | [C] | S1--S3、V1 | 见上表 | 是，作为配置名称 | 不是已采购 88LX2720/DW920 或任何商用 modem |
| PHY/介质 | G.hn、power-line、SISO | G.9960 规定 PHY；V1 明示 100 MHz powerline SISO profile | [A] | [G.9960](https://www.itu.int/rec/T-REC-G.9960/en)、[V1](https://www.maxlinear.com/product/connectivity/wired/g-hn/supporting-ics/88lx2720) | S1 官方页；V1 Overview | 是 | 仅冻结波形级的单视图 SISO 基线；不实现 MIMO |
| FFT/网格 | `NFFT=4096` | G.9960 公开 Table 7-67 的允许值之一；V1 关联 100 MHz profile | [A] | [S2](https://www.itu.int/rec/dologin_pub.asp?id=T-REC-G.9960-201811-S%21%21PDF-E&lang=e&type=items) | p.103, Table 7-67 | 是 | 标准派生模型参数，不是本项目设备时钟测得值 |
| 采样率/间隔 | `Fs=100 MHz`、`Δf=24.4140625 kHz` | `100 MHz / 4096`；基本间隔见 S2 | [A] | [S2](https://www.itu.int/rec/dologin_pub.asp?id=T-REC-G.9960-201811-S%21%21PDF-E&lang=e&type=items) | p.103, Table 7-67 | 是 | 必须连同实际 bin indexing/上变频规则定义；2--30 MHz 只是研究窗口 |
| 频带 | 2--30 MHz | 项目研究窗口；P1 覆盖其室内测量子带 | [C] | [P1](https://doi.org/10.23919/JCN.2022.000056) | pp.155--156 | 是，明确标为研究 mask | 不是完整 100 MHz G.hn power-line bandplan |
| active carrier/notch | 由可配置 mask 表示，初始值不得伪造 | 标准有 masking/PSD 机制；P1 说明实际 notch 重要 | [A]/[B] | [S3](https://www.itu.int/rec/T-REC-G.9964-202312-I/en)、[P1](https://doi.org/10.23919/JCN.2022.000056) | S3 clauses 5, 6.2；P1 Table I | 仅可写入“mask 接口” | 具体启用 bin、区域/EMC notch、固件 tone map 均待确认 |
| GI/CP | 100 MHz-PB 的公开表列 `β=N/8=512`、header/default-payload `N_GI=1024`；G.9960 定义 `N_CP=N_GI+β`，可变 payload GI 仍须由 profile/frame 选择 | [A] | [G.9964](https://www.itu.int/rec/dologin_pub.asp?id=T-REC-G.9964-202312-I%21%21PDF-E&lang=e&type=items)、[G.9960](https://www.itu.int/rec/dologin_pub.asp?id=T-REC-G.9960-202306-I%21%21PDF-E&lang=e&type=items) | G.9964 Table 6-4 p.10；G.9960 Table 7-68 p.106，目标版本条款已由既有证据副本交叉索引 | 是，写为规则/候选 | 不可把 Stage 3A `CP=256` 改称 G.hn 或实际设备 GI；实际帧 profile 与有效时延仍待确认 |
| 前导/训练/估计 | 通信帧含前导、header、payload；P1 的特定研究场景为 405 preamble 和 3317 header/data carriers | [B] | [P1](https://doi.org/10.23919/JCN.2022.000056) | pp.153--154, Table I | 仅可实现抽象训练块/LS 对照 | 不把论文场景图样、7 S1/2 S2 或其 carrier 集合当成普遍 G.hn/本项目固件值 |
| PSD/总功率 | 先冻结 G.9964 约束框架；100 MHz-PB power-line baseband 的 2 MHz 至 30 MHz 区间上限为 `−55 dBm/Hz`（边界/额外 shaping/notch 另按表处理），总发射功率合规上限为 `+20 dBm` | [A] | [G.9964](https://www.itu.int/rec/dologin_pub.asp?id=T-REC-G.9964-202312-I%21%21PDF-E&lang=e&type=items) | Table 6-5/Fig.6-2 pp.10--11；Table 6-12 p.17 | 是，作为上限/mask 约束 | 不冻结本实验室实际 PSD、总功率或注入电压；须按地区/端接/profile 和实测核对 |
| 标准测量端接 | power-line baseband PSD/功率测量参考为 `100 ohm` | [A] | [G.9964](https://www.itu.int/rec/dologin_pub.asp?id=T-REC-G.9964-202312-I%21%21PDF-E&lang=e&type=items) | Table 6-11 p.17 | 是，仅用于合规测量参考 | 不等于线路实际负载，也不替代项目 SISO 数学端口 |
| 接收能力 | 88LX2720 有可编程 TX/RX gain、滤波、line driver；1 TX/2 RX | [A] | [V1](https://www.maxlinear.com/product/connectivity/wired/g-hn/supporting-ics/88lx2720)、[V2](https://www.maxlinear.com/ds/88lx2720.pdf) | V1 Overview；V2 Figs.1--4 | 否，不能成为本项目数值 | 未找到可直接冻结为项目 AGC、灵敏度、动态范围、CFR/IQ 导出格式的公开证据 |
| 同步/CFO/SCO | G.9960 时钟容差可取 `±50 ppm` 作为扫描初值；CFO/触发/相位仍未知 | [A]/[D] | [G.9960](https://www.itu.int/rec/dologin_pub.asp?id=T-REC-G.9960-202306-I%21%21PDF-E&lang=e&type=items) | §7.1.6.1 p.107（既有证据副本交叉索引） | 可写误差接口及该初值，不写其他实数 | 实际时钟、触发、相位与时间零点必须实测/firmware 确认 |
| 耦合/端接/参考面 | 参数化模块 | [D] | S3、V2 | S3 有规范范围；实际板级值未获 | 仅写接口 | 50 ohm 数学端口不等于 G.9964 测量端接或板级线路参考面 |
| CFR/诊断端口 | 未找到 V1/V2 公开 API 证明可导出 raw CFR/IQ | [D] | V1/V2 | 待具体 DBB/firmware 文档 | 否 | 不得假设 DW920 或芯片自动可提供拓扑感知所需 CFR/反射数据 |
| 实测支撑 | P1 的室内实测 CFR（非 88LX2720 设备验证） | [B] | [P1](https://doi.org/10.23919/JCN.2022.000056) | pp.151, 155--156 | 仅作测量模型边界参考 | 不能转写为本项目、G.hn AFE 或拓扑识别实测结论 |

### B. 窄带对照：G3-PLC CENELEC-A 参考平台

| 参数类别 | 参数名 | 数值或规则 | 证据等级 | 原始来源链接 | 页码/章节/表/公式 | 可否写入 MATLAB | 使用边界 |
|---|---|---|---|---|---|---|---|
| PHY/频段 | G3-PLC，AC/DC，500 kHz 以下；CENELEC-A | G.9903 的规范范围 | [A] | [G.9903](https://www.itu.int/rec/t-rec-g.9903) | 官方摘要；§7.3.1.1 | 是 | 仅作为窄带对照，不替代宽带主线 |
| FFT/采样 | `N=256`、`Fs=0.4 MHz`、`Δf=1.5625 kHz` | G.9903 公开 CENELEC-A 示例 | [A] | [S4](https://www.itu.int/rec/dologin_pub.asp?id=T-REC-G.9903-201708-I%21%21PDF-E&lang=e&type=items) | p.10, §7.3.1.1 | 是 | 标准派生模型值，不是本项目硬件时钟 |
| carrier/CP/overlap | `N_CAR=36`、`N_CP=30`、`N_O=8` | G.9903 公开 CENELEC-A 示例；PL360 资料也给 36 carrier | [A] | [S4](https://www.itu.int/rec/dologin_pub.asp?id=T-REC-G.9903-201708-I%21%21PDF-E&lang=e&type=items)、[V3](https://ww1.microchip.com/downloads/en/DeviceDoc/PL360-Host-Controller-50002738.pdf) | S4 p.10；V3 §10.2.5.15 | 是 | 具体 tone map 是运行时/地区/耦合相关，不能假设全 36 tone 均有效 |
| 前导/FCH | 示例 `N_PRE=9.5`、`N_FCH=13`；标准还定义 preamble phase vector | [A] | [S4](https://www.itu.int/rec/dologin_pub.asp?id=T-REC-G.9903-201708-I%21%21PDF-E&lang=e&type=items) | p.10；后续 Amd.2 Table 7-9 | 是，作为可核验帧结构 | 不等于本项目 firmware 的抓包序列 |
| notch/tone map | 每个 carrier 有 mask；至少保留 6 个 used carriers 是 PL360 API 的约束 | [A] | [V3](https://ww1.microchip.com/downloads/en/DeviceDoc/PL360-Host-Controller-50002738.pdf) | §10.2.5.15 | 是，写 mask 机制 | 具体 mask 与耦合输出需要设备资料和测量 |
| PSD/发射功率 | G.9903 指向 G.9901 的 PSD 控制与测量 | [A] | [G.9903 AAP 摘要](https://www.itu.int/t/aap/recdetails/10325) | Summary | 仅写约束接口 | 本轮未核对 G.9901 的区域数值，不能冻结 PSD/功率 |
| 耦合器 | Microchip PLCOUP007/ISO 支持 35--91 kHz 的单通道 CENELEC-A | [A] | [Microchip coupling documentation](https://onlinedocs.microchip.com/oxy/GUID-D618401D-16E1-413A-902D-B5A0EC089340-en-US-2/GUID-E8EF51EC-4008-46E7-9800-BCA37B7F6AEF.html) | §3.4.5 | 否 | 只是可购参考板耦合器类别；传递函数与项目参考面仍必须标定 |
| CFR/SNR 数据 | PL360 API 可提供每 carrier SNR / tone map 相关数据 | [A] | [AN3400](https://ww1.microchip.com/downloads/en/Appnotes/AN3400-PLC-and-Go-Application-Note-00003400A.pdf) | p.14 | 否 | carrier SNR 不等于复数 CFR/IQ，更不等于拓扑反演测量端口 |
| RLGC/端接/噪声 | 当前项目低频没有独立校准 | [D] | 项目证据矩阵 | Stage 3B-pre 边界 | 否 | NB 继续只能做解析外推；不构成物理宽窄带对比 |

## 5. 候选横向比较与推荐

| 候选 | 可追溯 PHY 栅格 | 公开前导/训练信息 | PSD/耦合资料 | 与 2--30 MHz 拓扑 CFR 研究的关系 | 结论 |
|---|---|---|---|---|---|
| G.hn 100 MHz powerline + 88LX2720 类 AFE | 强：4096 与 24.4140625 kHz 基本网格有标准条款 | 中：标准有 PHY 框架，P1 有一套实测/估计场景；具体固件图样未冻结 | 中：G.9964 有框架，AFE 公开；板级耦合未冻结 | 直接覆盖项目 MHz 级研究窗口；2--30 MHz 仍是受限研究 mask | **推荐为主基线** |
| G3-PLC CENELEC-A + PL360 类平台 | 强：256 / 0.4 MHz / 36 / CP30 / overlap8 可核验 | 强于本轮 BB 的公开帧字段，但用途是窄带 | 中：有 tone map 和耦合板类别，实际 PSD/参考面未冻结 | 频率远低于现有 RLGC 证据窗口 | 保留为对照，不作主线 |
| 现有 Stage 3A 64 MHz/4096/CP256 | 无标准参数链；明确是项目假设 | 仅项目抽象全导频 | 无实际 PSD/耦合资料 | 与既有结果连续，但不能作为真实收发机主基线 | 保留历史，不升级 |

**推荐主基线：`Ghn_100MHz_powerline_SISO_standard_derived_reference`。** 理由是：其 4096 点和约 24.414 kHz 网格可由 G.hn PHY 追溯；100 MHz powerline SISO profile 与公开 G.hn AFE 资料相交；2--30 MHz 可作为不冒充完整 profile 的研究子窗口；P1 还提供该频段内真实室内 CFR、前导/头部估计、notch 和非遍历性证据。它能提高波形级模型的可追溯性，却不能解决 SISO T3/T5 结构等价，也不提供本项目的真实端口、噪声或耦合器。

## 6. 主基线冻结矩阵

### 6.1 可立即写入下一版 MATLAB 配置

下表所有项目都是**标准/资料派生的模型参数，不是未确认实验硬件的实际测量值**。

| 项目 | 冻结值/规则 | 证据 | 可实现用途 |
|---|---|---|---|
| 主平台与空间模式 | G.hn 100 MHz powerline 的 SISO 波形级参考 | S1/S2/V1 `[A]` | 固定模型命名、单 TX/单 RX 观测接口 |
| 基本 OFDM 网格 | `NFFT=4096`、`Fs=100 MHz`、`Δf=24.4140625 kHz` | S2 Table 7-67 `[A]` | 标准派生 bin 网格、2--30 MHz 研究 mask |
| GI 表达方式 | 依照 G.9960 GI/window 规则配置，不沿用历史 `CP=256` 的来源描述 | S2 Table 7-67 `[A]` | 参数化 GI/窗模块和 CP 覆盖审计 |
| 可核验 GI 参考 | 100 MHz-PB：`β=512`；header/default-payload `N_GI=1024`，并以 `N_CP=N_GI+β` 记录 | G.9964 Table 6-4 / G.9960 Table 7-68 `[A]` | 规则驱动的 GI/CP/窗模型；其他 payload GI 仍显式选择 |
| PSD 结构 | `−55 dBm/Hz` 的 2--30 MHz 上限段、`+20 dBm` 总功率上限、100 ohm 标准测量端接，以及显式 mask/notch 接口 | G.9964 Tables 6-5、6-11、6-12 `[A]` | 频域 mask / PSD 约束对象；不等于实装输出或线路端接 |
| G3 对照网格 | `N=256, Fs=0.4 MHz, Δf=1.5625 kHz, N_CAR=36, N_CP=30, N_O=8` | S4 `[A]` | 独立 NB 抽象链路，不与已验证 BB RLGC 混称物理比较 |
| 训练块抽象 | 前导--header--payload 分层与 LS/插值比较 | P1 `[B]` | 不同训练密度/估计器的基线接口 |

### 6.2 只能作为明确假设

| 参数 | 当前可采用的受限假设 | 影响与禁止表述 |
|---|---|---|
| 2--30 MHz active carrier | 在 G.hn grid 上的研究 mask；mask 表显式存档 | 不得称为商用 G.hn 的 active-carrier/tone map |
| 实际 notch | 使用可配置、可复现实验 mask（初始规则需单列） | 不得说符合地区 EMC 或设备固件 |
| 训练/导频图样 | 以“抽象训练符号”实现；可用 P1 场景作对照但不复刻成标准 | 不得假设真实 preamble phase、载波集合或导频密度 |
| 接收端噪声 | 继续使用明确标记的等效白/有色/脉冲噪声模型 | 不得从其推导真实发送功率、NF 或现场 SNR |
| 端接/耦合器 | 用可参数化传递函数、`Zs(f)`、`Zr(f)` 模块作灵敏度分析 | 当前 50 ohm 仅数学参考，不能称实机端口 |
| CFO/SCO/定时 | 用独立接口扫描 | 不得填真实 ppm、CFO 或时间零点 |

### 6.3 必须实测标定，当前不得冻结为真实值

| 必测项 | 为什么不能从标准/资料替代 | 推荐未来证据 |
|---|---|---|
| 耦合器、隔离/保护网络的复传递函数 | 板级器件、安装、线路和频率均改变增益/相位 | 在安全隔离实验条件下，以校准仪器定义 TX/RX 参考面 |
| 线路侧参考面及 `Zs(f), Zr(f)` | G.9964 规范测量端接不等于项目端口；负载随现场变化 | VNA/阻抗测量与可追溯端口校准 |
| 实际 RLGC、负载分布 | 当前 2--30 MHz 是项目模型窗口；NB 未校准 | 线路样段、负载状态和频段对应的独立测量 |
| 接收噪声/背景噪声/干扰 | PLC 噪声有色、脉冲、周期和位置相关 | 长时噪声记录、触发/主频相位标记和统计模型 |
| 时钟、CFO、同步时间原点、AGC | 芯片功能说明不能给出本系统残余误差 | 实机双端同步/触发和帧级日志 |
| 可获取的 CFR/IQ/反射/多节点端口 | AFE、carrier SNR 或 tone map 不保证可导出复数诊断数据 | 硬件/firmware API 资料、抓包和校准试验 |
| NB 低频模型 | G3 标准能给 PHY，不能证明现有 BB RLGC 可用于 35--91 kHz | NB 专用线路/端接/耦合测量 |

## 7. 从理想 CFR 到波形级模型的最小实现范围

在不声称硬件验证、也不进入导频/功率/子载波优化的前提下，下一次 MATLAB 修改可以实现：

1. 标准/资料派生的 G.hn 频率栅格（4096、100 MHz、24.4140625 kHz）与显式的 2--30 MHz 研究 mask；
2. IFFT、可参数化 GI/窗、抽象前导--header--payload 训练块，以及基于已知训练符号的 LS CFR 估计；
3. 线性时域卷积、CFO/定时/SCO 误差接口、有色与脉冲噪声接口；
4. 参数化的耦合器/端接模块、参考面标签和不确定性扫描；
5. 与 G3-PLC CENELEC-A 独立模型的接口对照（不得将 NB 数值称作已校准物理比较）。

上述工作仍属于“标准派生或假设驱动的波形级模型”。实施前必须保持既有 Stage 1--3A.2 结果不变，并把新的物理模型与历史 `64 MHz/CP=256` 假设隔离保存。

## 8. 仍阻止硬件级或现场级 Stage 3B 的条件

以下任一项缺失时，不能称真实收发机或现场 Stage 3B：真实测量节点与方向；耦合器/保护网络和线路侧参考面；项目 `Zs/Zr` 与负载频响；实际 G.hn DBB/firmware 的 active carrier、notch、GI 与训练序列；可导出的 CFR/IQ/反射数据；同步时间原点、残余 CFO/SCO/AGC；现场噪声统计；NB 的 RLGC/端接校准；以及能实际作用于观测统计的能量、时间和 SNR 定义。

## 9. 结论

本轮可以把 G.hn 100 MHz powerline SISO 选为**标准派生的宽带主基线**，并进入“Stage 3B 前的波形级基线实现准备”；这不是正式 Stage 3B 的资源优化，更不是硬件/现场验证。G3-PLC CENELEC-A 可作为参数可核验的窄带对照，但当前低频线路模型仍未校准。

通信标准参数、理想 CFR 诊断和波形级仿真，只提高模型可追溯性；它们不等于真实 PLC 拓扑识别性能已经得到验证。
