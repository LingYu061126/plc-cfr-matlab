# Stage 4A.7.2 tier2_v2 结果

这是 Stage 4A.7.2 第二档受控 Pilot 的修正版独立结果目录。原始 `stage4a7_2_tier2` 目录保留为先前运行证据，本目录不覆盖它。

本目录是历史 tier2_v2 运行基线。工作区中后续加入的 `absolute_I`、profile-equivalence、near-symmetry 和剪枝统计修正尚未回写本目录；这些修改需要 MATLAB 恢复后写入新的结果目录，不能把本目录数字解释为最新源码的重跑结果。

## 运行规模

- 网格：`A_stage4a1_quick61`，2–30 MHz、61 点；
- development：7 个工程候选 × 10 = 70；
- calibration：7 个工程候选 × 20 = 140；
- Pilot：库内 21 + 参数库外 21 + 结构库外 7 = 49；
- 同一观测配置下的 G004/G007 same-theta 非唯一簇：100；
- 执行：串行，1 worker；
- Final reserved：仅保留身份，未物化、未评分。

## 结果含义

`confirmation_metrics.csv` 中的 `coverage` 是候选集合覆盖真实候选 ID 的比例；`singleton_rate` 和 `empty_set_rate` 分别是单元素集合和空集合比例。结构库外样本没有当前库内真值候选，因此 `coverage=0` 不表示“分类器错把结构库外判成某个真值”，而表示输出集合不包含库外真值；库外拒识应结合集合状态解释。

`independence_audit.csv` 对每个 split 同时检查参数向量哈希和无噪声 CFR 哈希。`topk_audit.csv` 同时记录请求 K=3 的输出和 K=全部候选时的精确键集合一致性。

## 可复现入口

从仓库根目录运行：

```matlab
addpath('src','config','experiments');
exp_stage4a7_2_candidate_closure(pwd,'tier2_v2');
```

运行结果需要写入同名目录；如需保留既有结果，应先使用新的模式/结果目录，不要覆盖本目录。

## 边界

候选先验、线路参数和观测均为模型内合成设置；本结果不是现场配电网或真实 PLC PHY 验证，也没有启动 Stage 4B。
