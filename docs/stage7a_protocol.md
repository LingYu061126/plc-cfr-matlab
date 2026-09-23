# Stage 7A Parameter-Profile Search Protocol

本阶段是受控 MATLAB 模型内的算法增量，不是现场或真实 PLC 收发机验证。Stage 6A/6B 正式 CSV/MAT/PNG 与 Stage 4A/5B.1 冻结定义只读。baseline 为归档 Stage 6B；新方法使用独立函数、局部校准和 `results/data/stage7a/` 输出。

## 搜索域与冻结决策

Stage 6A 合成 allowed-edge prior 中，四段主线均为 20 m，逐段允许 18–22 m。因此仅针对“全主线统一 scale”模型，逐边交集为 `[0.90,1.10]`。对真正由 Stage 6A partial prior 生成的候选，还须与总长度 80–110 m 相交；例如无支路候选的下界为 1，两支路候选的上界为 1。Stage 6B 的 3/7/23 扩展 grammar 不继承 Stage 6A 的总长度或最大分支数限制，只把相同标称 20 m 主线的逐边区间作为本受控对照的参数假设。支路 15 m 允许 12–18 m，但本增量不搜索支路长度。负载 scale `[0.80,1.20]` 是沿用 Stage 6B 已声明扰动的合成 nuisance 范围，不是工程台账界限或通用物理容差。频带、正向模型、端接和 Stage 5B.1 四状态公式不变。

预先固定：主线 coarse 步长 `0.05`，fine 步长 `0.025`；负载 coarse 步长 `0.20`，fine 步长 `0.10`。每候选先在 coarse 网格取最小 CFR RMS 距离，再只在该 coarse 点的相邻 fine 窗口取最小值。所有模板只构造一次并在校准/测试间只读复用；评分接口不接收实验真值参数。Stage 7A 的每个候选库、搜索域和距离尺度均单独重新校准，旧 Stage 6B 校准模型不复用。

校准使用独立固定种子和每候选 20 个合成样本（smoke 为 4），仅用于候选集合、domain gate 和证据指标的局部校准。正式测试种子与校准种子分离；正式测试结果不反馈搜索域或阈值。normalized confidence score 不是 Bayesian posterior，不跨候选库当作统一概率比较。

## 对照与指标

1. 重放 Stage 6B 参数失配的同一 truth、种子、噪声、七个长度误差和 ±20% 负载扰动，对齐归档 baseline 样本。
2. 另取 truth 在库内、主线参数在 `[0.90,1.10]` 内的独立样本。
3. 重放 Stage 6B 实际施加 wrong-open / wrong-closed 的 14 个库外样本。
4. 另取主线 scale 为 `0.85` 或 `1.15` 的域外样本。
5. 复核 T3/T5 镜像等价及 three-topology-close 两个受控非唯一正控制。
6. 在 3/7/23 候选库上比较 cache 构造、单样本评分 wall-clock 与模型内存字节数。

逐样本和分组必须报告：真值候选覆盖率、正确 `UNIQUE_CONFIDENT` 比例、false-unique 比例、库外误接受率、域外拒绝率、非唯一样本 `MULTIPLE_AMBIGUOUS` 比例、候选集合覆盖与大小、四状态分布及 wall-clock time。内存用 MATLAB `whos` 的模型字节数表示，不冒充进程峰值内存。`REJECTED` 不会自动定位错误先验。

安全性优先：若库外误接受率或 false-unique 比例高于同样本 Stage 6B baseline，或任一非唯一正控制被强制判为 `UNIQUE_CONFIDENT`，本阶段判为安全检查未通过，即便库内确认率提高也不进入下一轮。该判据在正式测试前固定；不依据正式结果反复调参。参数域外允许拒绝，`UNIQUE_CONFIDENT` 不表示全局物理唯一。
