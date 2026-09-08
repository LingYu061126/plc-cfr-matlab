# Stage 4A.7.2-R.1 算法与证据准备审计

## 范围

本审计覆盖公开低压网络派生输入、共享不确定工程先验、候选生成、正向模型适配、离散参数剖面距离、development 方法选择、非唯一评分和中型 Top-K 原型。历史 Stage 4A.7.2 结果保持只读。

## 已确认的上一阶段缺口与处理

| 缺口 | 静态证据 | R.1 处理 | 数值状态 |
|---|---|---|---|
| 七份全部 required specification 未形成共享先验 | `experiments/exp_stage4a7_2_candidate_closure.m`、`src/build_stage4a7_2_r1_uncertain_engineering_prior.m` | 由一份 ENWL 派生 observed ledger 生成 required/optional/synthetic ambiguity 边，再一次调用工程候选生成器 | [代码静态核对] |
| round-trip 重读原始 edges | `src/adapt_engineering_candidate_to_forward_model.m` | 在 network 中保存路径和支路元数据，从 forward network 重建工程图并比较边、属性、方向和节点 | [代码静态核对]；[本次运行] 未运行 |
| 所有候选使用同一真实 theta | R.1 新旧实验入口对照 | `stage4a7_2_r1_build_profile_template_cache` 为每一候选保存全部模板，`stage4a7_2_r1_profile_distance` 独立取最小距离 | [代码静态核对] |
| development 未冻结客观方法 | R.1 新增 `stage4a7_2_r1_method_selection` | 仅用 development 的覆盖门槛、集合大小、singleton 和 empty-set 词典序选择；Pilot 不参与选择 | [代码静态核对]；[本次运行] 未运行 |
| 非唯一簇未进入候选集合评价 | R.1 新增 `stage4a7_2_r1_nonunique_metrics` | 记录 truth member count，并分开计算 unconditional/conditional false-unique | [代码静态核对]；[本次运行] 未运行 |
| 中型 Top-K 无实际 runtime | R.1 新增 `stage4a7_2_r1_topk_scaling_audit` | 对 8 节点、18 条边控制实例同时记录穷举和 Top-K `tic/toc` | [代码静态核对]；[本次运行] 未运行 |

## 数据边界

ENWL 文件是处理后的公开 OpenDSS 模型，不是原始错误 GIS。R.1 的 ambiguity 边由项目配置控制，属于从公开处理模型派生的受控实验先验。线路的 OpenDSS `LineCode` 仅作为类别和溯源字段，不被直接外推为 2--30 MHz PLC RLGC。

## MATLAB 状态

本轮 MATLAB 启动探测在进入项目代码前失败，重复输出：

```text
Unable to load ApplicationService for command client-v1
```

因此本文件只记录实现准备和静态审计，不报告 MATLAB smoke、Pilot 或历史回归通过。Octave 仅用于检查新 MATLAB 文件的可解析性，不产生科学结果。
