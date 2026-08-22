# P10 Performance Analysis of OFDM Systems for Broadband Power Line Communications Under Impulsive Noise and Multipath Effects

## 1. 基本信息

- 作者：Ma、So、Gunawan
- 年份：2005
- 来源：IEEE Transactions on Power Delivery, 20(2)
- 文件路径：`Performance_analysis_of_OFDM_systems_for_broadband_power_line_communications_under_impulsive_noise_and_multipath_effects.pdf`
- 标签：`#PLC收发与OFDM` `#噪声建模与抗噪`
- 阅读状态：重点读

## 2. 一句话定位

论文分析 BB-PLC OFDM 在多径和脉冲噪声下的 ISI/ICI、保护间隔和 BER，不研究未知配电网树拓扑。

## 3. 输入、输出与方法

- 输入：OFDM 符号、多径 `h(t)=Σ a_i δ(t-τ_i)`、AWGN 背景和脉冲噪声。
- 输出：BER、保护间隔/载波数条件下的通信性能。
- 噪声：脉冲到达过程采用 Poisson 到达和白高斯幅度的分析模型；论文同时讨论 PLC 中有色背景、窄带和周期脉冲噪声类别。
- 流程：建立多径/噪声模型→加入/改变 GI→分析 DFT 后子载波干扰→比较 BER。

## 4. 关键证据

- 位置：多径模型 Eq. (18) 及 OFDM/GI 分析章节；具体页码需按原 PDF 复核。
- 明确陈述：当最大路径延迟超过 GI/CP 时，线性卷积产生符号间干扰；足够 GI 可降低 ISI/ICI，但过长会损失有效功率。
- 明确陈述：载波数、符号持续时间和保护间隔存在通信性能权衡。
- 根据论文推断：CP 审计必须区分“循环等效数值正确”与“物理线性卷积的最大时延被 CP 覆盖”。

## 5. 实验与局限

- 论文使用 32/64/128 子载波、4 路多径和实际测得的脉冲噪声场景进行 BER 分析；参数数字仅限原文表格，不迁移为本项目标准。
- 主要结果是通信 BER/误码地板，不是 CFR 类间/类内距离、拓扑识别率或路径定位误差。
- 通信最优 CP 不一定是拓扑感知最优 CP：感知还要保留反射路径、CIR 时延分辨率和可解释的同步基准。

## 6. 对当前项目的复用

- 可复用：线性卷积、CP、脉冲噪声和多径对 OFDM 的物理边界。
- 不可直接复用：BER 最优载波数/GI 作为拓扑感知波形结论。
- 当前缺口：项目的 `sampled CFR` 没有物理时间原点，因此线性/循环差异不能直接解读为现场 CP 设计失败。

## 7. 证据等级

- 论文明确陈述：脉冲噪声/多径/保护间隔对通信性能的关系。
- 根据论文推断：拓扑感知应独立报告 CIR/路径特征保真度。
- 待验证理解：真实 PLC 的脉冲到达、带宽、CP 和同步协议。
