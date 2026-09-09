# Stage 4A.7.2-R.2.1.1：静态缺陷修复与独立验证协议重建

## 阶段判断

**Stage 4A.7.2-R.2.1.1：partial / blocked。**

本阶段完成了静态缺陷修复、新前缀 formal 重跑、候选对等价审计和 1044 场景 paired validation；但没有把参数 profile 成员级域判定、真实非唯一场景和 false-unique 统计闭环补齐。因此本阶段结果可以作为协议修复证据，不能作为完整参数域有效性结论。

## 研究范围与身份

[代码静态核对] 本阶段没有修改稳定传输线正向模型的物理定义，没有运行 `final_reserved`，没有启动 Stage 4B。formal 和 paired 结果分别写入：

```text
results/data/stage4a7_2_r2_1_1/formal/
results/data/stage4a7_2_r2_1_1/paired/
results/data/stage4a7_2_r2_1_1/equivalence/
```

[本次运行] MATLAB 为 R2024a `24.1.0.2537033`，所有计算采用串行单进程、1 worker。MATLAB 启动仍打印历史 MathWorks interprocess mutex 警告，但各次计算均有正常 MATLAB 退出状态和完成摘要；这属于启动环境 workaround 下的日志现象，不是本阶段新算法证据。

## 修复内容

### SHA256

[本次运行] `stage4a7_2_r2_sha256_file` 统一使用 `/usr/bin/sha256sum`，避免 no-JVM 路径调用 Java `MessageDigest`。测试核对：

| 输入 | 期望摘要 | 结果 |
|---|---|---|
| 空文件 | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` | 通过 |
| ASCII `abc` | `ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad` | 通过 |
| 派生 ENWL CSV | `b1796a9a0cf7ae94f66b58a9e12de2ff21debd371f68e2fe2085e7b42a057f20` | MATLAB 与系统摘要一致 |

### 台账错误隔离

[代码静态核对] `incorrect_required_edge` 不再修改第一条 reference edge，而是从受控 ambiguity edge 构造错误 required 记录，并在 audit 中保存 `incorrect_required_edge_is_reference=false`。部署候选生成器仍只接收 observed ledger，不接收 reference graph。

### 等价审计连接

[代码静态核对] `stage4a7_2_r2_1_full_equivalence_audit` 现在使用规范化的 `pair_key`：

1. `same_theta_equivalence_pairs.csv`：全部无序候选 pair；
2. `cross_theta_nearest_pair_audit.csv`：每个唯一最近 pair 一行；
3. `candidate_nearest_competitor_projection.csv`：每个候选一行，通过 `nearest_pair_key` 连接。

候选级 projection 不再通过“候选是 pair 任一端点”进行广播回写。

### 方法并列语义

[代码静态核对] 方法选择现在分开记录：

* `deterministic_development_winner`：development 词典序规则的结果；
* `statistically_distinguishable_winner`：固定 seed 的 paired bootstrap 区间是否支持差异；
* `scientifically_unique_winner`：两者同时满足。

formal 中 margin 相对 ratio 的 coverage 差异为 `0.0038314`，95% bootstrap CI 为 `[0, 0.0114943]`；平均集合大小差异为 `-0.0689655`，CI 为 `[-0.149426, 0.015326]`；因此不能称为科学唯一优胜。执行时仍选用 margin 作为 deterministic fallback，并明确 `scientifically_unique_winner=0`。

### paired 独立设计

[代码静态核对] paired 设计固定 candidate×replicate 的 nuisance theta 和归一化复噪声实现，仅改变 `main_length_scale` 六个类别值。paired 设计具有独立的 `experiment_hash`，不再复用 formal experiment identity。

## 本次运行

### Smoke

| 项目 | 数值 |
|---|---:|
| 工程候选 | 204 |
| 兼容/评分候选 | 87 |
| development | 174 |
| calibration | 870 |
| pilot | 87 |
| wall-clock | 245.993 s |
| 状态 | `smoke_completed` |

[本次运行] smoke 五种方法均输出全候选集合，平均集合大小为 87，bootstrap 不支持唯一科学优胜。这表明 smoke 只验证协议和身份链，不提供可压缩候选集的性能证据。

### Formal

| 项目 | 数值 |
|---|---:|
| 工程候选 | 204 |
| 兼容/评分候选 | 87 |
| development | 261 |
| calibration | 3480（每候选40） |
| pilot | 174 |
| wall-clock | 427.287 s |
| selected method | margin（deterministic fallback） |
| scientifically unique winner | false |
| final_reserved | 未物化 |

formal `experiment_hash` 为 `f3ded2ebab251035aa5853fa60951f5cb86da2c4de60ac73c55ef5d2fbbcedd0`，本次 source-tree hash 为 `62e69e4f1f42429ef07b292e005f942c9ec874e2a30ca638c2ff8eff7120fc84`。

### 最终源码身份复核

[本次运行] 在 paired hash 接口最后修正后，重新运行了独立的 `final_source/` formal、equivalence 和 paired。此前 `formal/`、`equivalence/` 与 `paired/` 保留为本阶段中间证据，不覆盖、不删除；最终解释应以 `final_source/` 为准：

| 输出 | 数值 |
|---|---:|
| final-source formal wall-clock | 440.732 s |
| final-source formal source-tree hash | `cdc5275e6191b2ef37c312a4e65236f13c24cf4df255521a301e02a97304d4d3` |
| final-source formal experiment hash | `54e2139394ed86ed852eba9edd72bbc603d5b9a1b23ebbe035079e8135b586ad` |
| final-source equivalence pair count | 3741 |
| final-source unique nearest cross-theta pair count | 62 |
| final-source paired row count | 1044 |
| final-source paired wall-clock | 77.271 s |
| final-source paired experiment hash | `de05941146c716efe7ff064e27b897c3591f4cdac901f8e8a1c750632ec275b5` |

这一步用于消除“结果由旧 source-tree hash 生成”的身份歧义；它没有改变样本设计或阈值，也不是新的科学样本。

### 全候选等价审计

[本次运行] 87 候选共产生 3741 个无序 pair；同 theta 数值等价 pair 数为 0（阈值 `1e-10`）。每个候选都有最近同 theta competitor，唯一最近 pair 数为 62。cross-theta profile 只对这 62 个唯一最近 pair 计算，作用域明确为 `nearest_same_theta_pairs_only`，不宣称覆盖全部 3741 个 pair。

### Paired validation

[本次运行] 1044 = 87 候选 × 6 类别 × 2 replicate，耗时 76.222 s。每个类别 174 行，六类均 balanced；1044 个 parameter hash、无噪声 CFR hash、带噪 observation hash 均唯一。

主要 topology-set 结果如下；这些指标不是参数域判定：

| 类别 | truth-set coverage | topology acceptance | topology selective risk | singleton rate | empty rate | mean set size |
|---|---:|---:|---:|---:|---:|---:|
| in_domain | 169/174 = 0.9713 | 173/174 = 0.9943 | 4/173 = 0.0231 | 40/174 = 0.2299 | 1/174 = 0.0057 | 4.4885 |
| boundary_lower | 161/174 = 0.9253 | 173/174 = 0.9943 | 12/173 = 0.0694 | 40/174 = 0.2299 | 1/174 = 0.0057 | 4.6552 |
| boundary_upper | 166/174 = 0.9540 | 173/174 = 0.9943 | 7/173 = 0.0405 | 54/174 = 0.3103 | 1/174 = 0.0057 | 4.2241 |
| parameter OOD near | 132/174 = 0.7586 | 172/174 = 0.9885 | 40/172 = 0.2326 | 66/174 = 0.3793 | 2/174 = 0.0115 | 3.7989 |
| parameter OOD medium | 19/174 = 0.1092 | 169/174 = 0.9713 | 150/169 = 0.8876 | 108/174 = 0.6207 | 5/174 = 0.0287 | 2.0000 |
| parameter OOD far | 4/174 = 0.0230 | 153/174 = 0.8793 | 149/153 = 0.9739 | 137/174 = 0.7874 | 21/174 = 0.1207 | 0.9943 |

这里的 OOD 类别只表示 paired 设计中的参数越界场景；由于本阶段尚未完成成员级 parameter-domain decision，不能把这些数字改写成 parameter OOD recall 或 false acceptance。

## 未完成事项与阻塞

以下项目仍未完成，因而阶段保持 `partial / blocked`：

1. **成员级参数 profile/domain 闭环**：尚未为全部 accepted member 生成可靠性门控、参数域状态和类级 parameter selective risk；paired 输出仅用于 topology-set/profile-distance 观察。
2. **真实非唯一场景**：当前 87 候选同 theta 审计没有发现 `1e-10` 数值等价 pair，因而 false-unique 仍为 `not_evaluable`，不能以最近 competitor 替代真实等价类。
3. **跨 theta 全 pair profile**：本阶段仍只对每个候选的唯一最近同 theta pair 做 cross-theta profile，不是全部候选对的完整 profile 矩阵。
4. **并行 benchmark**：本阶段保持串行；未启动 Parallel Computing Toolbox，也未作 4/6/8 worker benchmark。历史 R2 benchmark 已表明小任务并行更慢且有内存压力。
5. **MATLAB 启动根因**：目前使用 `HOME`、`MATLAB_PREFDIR`、offscreen、no-JVM 和 single-thread workaround；未修改 MATLAB 安装或系统 IPC 配置，故根因仍待环境层处理。
6. **完整 Final**：未运行；`final_reserved` 仅保留身份，不生成数据。

## 测试

[本次运行] 测试命令为：

```bash
matlab -nodisplay -nosplash -nojvm -singleCompThread -batch "addpath('src'); addpath('config'); addpath('experiments'); addpath('tests'); run_tests"
```

MATLAB R2024a 完整历史回归退出状态为 0；日志为 `results/logs/stage4a7_2_r2_1_1/full_regression.log`。新增定向测试 `test_stage4a7_2_r2_1_1_static_integrity` 退出状态为 0；其内容覆盖 SHA 向量、incorrect required edge 隔离、部署接口和 bootstrap 字段。

## 结论

协议层修复和独立 paired 运行已经形成可追溯证据，但本阶段不能标记为完整通过。当前结论仅为：在受限候选库、合成工程先验、模型生成复 CFR 和频域等效噪声下，R2.1.1 的哈希、错误台账、等价 pair 连接、方法并列语义和 paired 独立性协议得到验证；参数域可信判定和真实非唯一 false-unique 仍需后续阶段完成。

研究边界仍然是：候选库不是完整真实网络空间，工程先验不是现场台账，CFR 估计和 profile 收敛不等于物理拓扑或参数的全局唯一可辨识，结果不是现场配电网验证，也不是真实 PLC 收发机验证。
