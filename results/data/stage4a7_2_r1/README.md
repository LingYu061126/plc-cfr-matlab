# Stage 4A.7.2-R.1 result directory

本目录为 Stage 4A.7.2-R.1 的独立结果目录，不覆盖
`results/data/stage4a7_2_tier2_v3/`。本轮已完成公开数据派生输入、共享不确定先验生成器、正向模型适配器、离散 profile-distance、Top-K 审计和非唯一指标接口，并完成 MATLAB R2024a 受控 Pilot。

Pilot 结果位于 `pilot/`，包含 12 个 development、12 个 calibration 和 6 个 Pilot 场景，另含 100 个非唯一场景及 50 个近对称控制场景。Pilot 使用串行 1 worker，未运行 `final_reserved`，未进入 Stage 4B。科学哈希和源代码哈希写入各 CSV 的末列及 `runtime_summary.csv`。

当前结果的适用性和已发现不足见：
`report/stage4a7_2_r1_limitations_and_open_issues.md`。其中重点记录评分 Top-K 未覆盖公开 reference truth、经验 p-value 分辨率不足、方法选择并列、非唯一审计仍使用 legacy G004/G007 控制集，以及 Pilot 集合过宽等问题。

从仓库根目录可运行 smoke 入口：

```matlab
addpath('src','config','experiments','tests');
summary = exp_stage4a7_2_r1_data_driven_closure(pwd, 'smoke');
```

受控 Pilot 入口为：

```matlab
summary = exp_stage4a7_2_r1_data_driven_closure(pwd, 'pilot');
```

定向测试日志为 `results/logs/stage4a7_2_r1_targeted_final.log`，完整历史回归日志为 `results/logs/stage4a7_2_r1_full_regression_final.log`，Pilot 日志为 `results/logs/stage4a7_2_r1_pilot.log`。外部原始文件仍位于仓库外部材料目录，原始压缩包/PDF 未纳入结果目录。
