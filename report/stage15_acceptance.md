# 阶段 1.5 验收说明：修正、验证并封存 PLC CFR 正向模型

## 1. 修改前基线

项目根目录的 `.git` 是空目录，无法执行有效的 `git status` 或读取提交历史；未发现可比较的 Git 基线。论文原件未修改、移动或重命名。修改前结果与哈希保存在：

```text
results/baseline_pre_stage15/existing_results/
results/baseline_pre_stage15/matlab_run_all_results/
results/baseline_pre_stage15/logs/
```

本机 MATLAB 信息：MATLAB R2024a `24.1.0.2537033`，项目依赖扫描结果为仅 `MATLAB|24.1`，没有额外工具箱依赖。修改前 `tests/run_tests.m` 和 `run_all.m` 均实际运行通过。

修改前长线直接 ABCD 审计为：

| 主线 | `kG=1` 最大误差 | `kG=5` 最大误差 |
|---:|---:|---:|
| 300 m | `6.36e-14` | `7.85e-6` |
| 500 m | `2.91e-12` | `64.63` |
| 800 m | `4.69e-10` | `1.55e12` |
| 1200 m | `5.33e-7` | `1.55e26` |

因此原代码仅检查 `finite_H/finite_ABCD` 的验收是不充分的。

## 2. 修改文件

- `src/cable_rlgc.m`：频率改为严格正值。
- `src/branch_input_impedance.m`：支持标量/逐频率复负载、开路、短路和零长度。
- `src/abcd_to_transfer.m`：增加参考端接参数，修正 `H_port` 的适用条件。
- `src/cascade_network.m`：保留原 ABCD 参考路径并加入行列式审计和超阈值警告。
- `src/terminated_line_response.m`：稳定线路输入阻抗和电压比。
- `src/cascade_network_stable.m`：长线路后向阻抗/电压比递推。
- `src/parallel_rlc_load.m`：Cañete 频率选择性并联 RLC 负载。
- `config/default_config.m`：端口参考阻抗、ABCD 阈值和参考测量门限。
- `tests/run_tests.m`：新增阶段 1.5 全部测试。
- `experiments/exp02_single_branch.m`：增加相位子图。
- `experiments/exp05_long_line_literature_case.m`：稳定正式结果、旧 ABCD 审计和诊断图。
- `experiments/exp06_frequency_selective_load.m`：新增频选负载实验。
- `run_all.m`：执行新实验并设置图形字体。
- `README.md`、`report/core_derivation.md`、`report/experiment_results.md`：同步公式、边界和结果。

## 3. 稳定方法与原理

直接 ABCD 中 `cosh(gamma*d)` 和 `sinh(gamma*d)` 随线路损耗指数增长，`AD` 与 `BC` 都可能很大，理论上的 1 通过大数相减得到，导致行列式残差失真。稳定方法从接收端向源端递推：

$$
Z_{in}=Z_c\frac{Z_L+Z_c\tanh(\gamma d)}{Z_c+Z_L\tanh(\gamma d)},
$$

$$
\frac{V_{out}}{V_{in}}=
\frac{2Z_L e^{-\gamma d}}
{(Z_L+Z_c)+(Z_L-Z_c)e^{-2\gamma d}}.
$$

节点处把下游阻抗和支路输入阻抗转换为导纳相加，最后施加源端分压。该方法不构造总 ABCD，因此不用大数相减验证稳定性。

## 4. MATLAB 实际验收

实际命令为：

```matlab
addpath('matlab_plc_cfr')
run_all
```

MATLAB R2024a 输出 `ALL STAGE-1.5 TESTS PASSED`，并成功生成全部实验结果。测试覆盖：

- 正频率和非法频率输入；
- RLGC、名义阻抗、均匀线路互易性、拆分等价、无支路基线；
- 标量实/复负载、等值频率向量负载、开路、短路、零长度；
- 并联 RLC 复负载；
- `Zs=50` 时 `H_port=2H_V`、`Zs=75` 时比例改为 2.5；
- 稳定/ABCD 短线复数 CFR 交叉验证；
- 稳定长线匹配极限、分段不变性、被动输入阻抗实部；
- 8 个长线场景的 `AD-BC` 最大值、中位数、最差频率和稳定 CFR。

## 5. 结果保留和排除

正式长线图全部采用稳定递推。旧 ABCD 的 `kG=5`、300–1200 m 场景均超过 `1e-6` 行列式阈值，排除其作为正式内部矩阵结果；`kG=1` 场景满足该数值筛查，但仍保留稳定递推作为统一正式路径。旧 ABCD CFR 与稳定 CFR 在当前测试拓扑中最大相对差约 `1.3e-15`，因此本次不能据此声称旧 CFR 数值已明显偏离；只能确认旧总矩阵的互易性诊断已失效。

物理上，300–1200 m 全部超出 Cañete 的典型校准线段范围。`kG=5` 的 500/800/1200 m 稳定曲线分别有约 39.9%、65.6%、80.0% 低于 `-120 dB` 参考门限。由于没有实际测量链动态范围，不能将该门限升级为硬件可测性结论。

## 6. 当前边界和下一步

当前模型仍是单导体/差模、固定拓扑、确定性端接的正向软件模型；没有真实硬件、噪声、时变负载、三相 MIMO 或 OFDM。下一阶段接 OFDM 前最需要固定的是：离散子载波频率网格、导频位置和功率、CFR 估计归一化，以及稳定正向模型输出与测量动态范围之间的可比性。
