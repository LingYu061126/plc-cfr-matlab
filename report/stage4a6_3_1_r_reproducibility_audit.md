# Stage 4A.6.3.1-R 复现链审计

## 结论摘要

本审计把 Stage 4A.6.3.1 的历史闭环结果与本阶段 R 版独立 Pilot 的复现依赖分开。历史闭环目录中存在若干未被 Git 跟踪的 MAT、CSV、配置和源码；这些文件不能被新实验静默当作公开依赖。R 版入口已在 MATLAB R2024a 中重新生成 A 网格候选缓存、校准场景和 Pilot 场景，结果写入 `results/data/stage4a6_3_1_r/`，因此不依赖历史 Pilot MAT 才能重建核心流程。[本次运行]

路径均以仓库根目录为基准；绝对路径只用于本次审计，不进入科学配置哈希。SHA-256 由审计运行时计算，未把未跟踪的大型历史结果自动加入本阶段提交范围。[代码静态核对]

## 依赖清单

| 依赖文件或目录 | 用途 | 本地存在 | Git 跟踪 | 大小/哈希 | 能否确定性重建 | 重建入口 | 建议处理 |
|---|---|---:|---:|---|---|---|---|
| `experiments/exp_stage4a6_3_1_profile_closure.m` | 历史 profile closure 入口 | 是 | 是 | 约16 KiB；以 `sha256sum` 审计 | 是，依赖其历史输入协议 | `run_stage4a6_3_1_profile_closure` | 保留，不作为 R 版输入 |
| `report/stage4a6_3_1_profile_calibration_final_closure.md` | 历史结果说明 | 是 | 是 | Git 已跟踪 | 是，报告本身可复核 | 读取报告引用的日志/CSV | 保留为历史证据 |
| `config/stage4a6_3_1_protocol_config.m` | 上一版协议配置 | 是 | 否 | 未跟踪，约4 KiB | 代码在本地可重建，公开克隆不可直接获得 | 旧 `exp_stage4a6_3_1_protocol_pilot` | 不作为 R 版唯一依赖；R 版配置单独提交 |
| `src/confirm_stage4a6_3_1_topology.m` | 旧 Stage 4A.5.1 适配器 | 是 | 否 | 未跟踪，约4 KiB | 当前工作区可重建 | 旧 Pilot | R 版通过新 adapter 显式调用；应与相关源一起纳入后续归档 |
| `src/run_stage4a6_3_1_member_profiles.m` | 等价成员逐一 profile | 是 | 否 | 未跟踪，约4 KiB | 当前工作区可重建 | R 版 adapter | R 版源码显式记录完整成员计数 |
| `src/generate_stage4a6_3_1_independent_trials.m` | 上一版试验池生成器 | 是 | 否 | 未跟踪，约8 KiB | 当前工作区可重建 | 旧 Pilot | R 版使用新独立场景生成器，避免旧语义混用 |
| `results/data/stage4a6_3_1/stage4a6_3_1_pilot_results.mat` | 历史 Pilot 汇总 | 是 | 否 | 约25 MiB；SHA-256 见审计命令输出 | 可由旧入口和旧配置重建，但不在干净克隆中存在 | 旧 Pilot | 不直接提交；保留摘要和重建入口 |
| `results/data/stage4a6_3_1/profile_final_A/*.mat` | 历史逐案例 profile | 是 | 否 | 约108 MiB目录 | 可由 profile batch 重建，成本高 | 历史 profile batch | 不直接提交；建议 Git LFS/外部归档前先获授权 |
| `results/data/stage4a6_3_1/stage4a6_3_1_pilot_match_decisions.csv` | 历史决策表 | 是 | 否 | 约48 KiB | 可由旧入口重建 | 旧 Pilot | 作为历史本地证据，不冒充公开依赖 |
| `results/data/stage4a6_3_1/stage4a6_3_1_pilot_scoring_labels.csv` | 历史离线评分标签 | 是 | 否 | 约24 KiB | 可由旧试验池重建 | 旧 Pilot | 与决策分离保存；R 版重新生成 |
| `results/data/stage4a6_3_1_r/` | R 版新 Pilot 结果 | 运行后生成 | 本阶段新增 | 以本阶段结果清单为准 | 是 | `run_stage4a6_3_1_r_independent_pilot` | 提交紧凑 CSV、配置、日志；大型 MAT 需单独审查 |

## 关键历史文件 SHA-256

以下摘要由本地工作区审计得到，路径均相对于仓库根目录。它们用于识别历史依赖，不表示这些未跟踪文件已经成为 R 版的必要输入。[代码静态核对]

| 文件 | SHA-256 |
|---|---|
| `experiments/exp_stage4a6_3_1_profile_closure.m` | `30ed9dd3517a6d528888e32030cc23001be230f71fe705048b9adff19290aae8` |
| `config/stage4a6_3_1_protocol_config.m` | `f3b1c88168b9fcd5dc8427ff7595f4a164f575832684e40f773bb301b6d7fb44` |
| `src/confirm_stage4a6_3_1_topology.m` | `c5ec27507da81533013bd758611e51bcfe2b76b1d775650fafb7bc6748cb89dc` |
| `src/run_stage4a6_3_1_member_profiles.m` | `e0e16e1945ef1e53867ba1c56d229edc192f7bec7988cb1910609b1c0b57f817` |
| `src/generate_stage4a6_3_1_independent_trials.m` | `da46a6d6a1225297414f2ba8c7aaf625ca17cd0956cea3752e32826d0b53a190` |
| `src/stage4a6_3_1_compatibility_hash.m` | `fa696e9d57e4c67e791ff9b08d396d378abee067bf426ba21e409f7cd766a22e` |
| `tests/test_stage4a6_3_1_protocol_pilot.m` | `f06838806d1e497f3bcb5a2ba9440f7961fb7c31ffcf307fa1a929e14d815b54` |
| `results/data/stage4a6_3_1/stage4a6_3_1_pilot_results.mat` | `c4409ac4b3fb018e024986e7ee6592e9749625681ec744759405a0857492741d` |
| `results/data/stage4a6_3_1/stage4a6_3_1_profile_parameter_calibration_model.mat` | `4ff15dd696396d65d68c3819973de86798243e7c62a29041635de5ccc5c74a75` |
| `results/data/stage4a6_3_1/stage4a6_3_1_pilot_match_decisions.csv` | `d4b03f2244e833f3de62bc3053436ea4884445c66f24fc56f5c4c2391e9ef0d5` |
| `results/data/stage4a6_3_1/stage4a6_3_1_pilot_scoring_labels.csv` | `376a9e5859103418f3744f5ad3cf0ce9a5146957cd436a489b35d805128d9b0e` |
| `results/data/stage4a6_3_1/profile_final_A/` | 88 MAT 文件，目录级 SHA-256 未生成；单文件清单尚未进入 Git |

## R 版最小复现链

干净克隆后，使用仓库内的配置、候选生成函数、Stage 4A.5.1 缓存构建函数、R 版场景生成器和 MATLAB 入口即可重新生成小型 A-grid Pilot。`final_reserved` 仅生成身份清单，不生成观测、不参与校准、不进入评分。[代码静态核对]

核心身份分为：`compatibility_hash`、`source_tree_hash`、`calibration_hash`、场景的 `parameter_vector_hash`、`noiseless_cfr_hash` 与 `observation_hash`。不同工作目录不会改变科学哈希；代码或确认规则变化会改变兼容性身份。[代码静态核对]

历史未跟踪 MAT 不作为 R 版的必要依赖。若未来希望归档完整历史 profile，应使用 Git LFS 或外部对象存储，并同时提交清单与 SHA-256；本阶段未擅自启用大文件存储。[模型内推断]

## R 版实际运行证据

本次 MATLAB Pilot 使用 A 网格、1 个串行 worker、14 个 calibration 场景和 35 个 Pilot 场景，其中 26 个进入参数 profile；`final_reserved` 仅生成清单，未执行。核心文件已经在工作区生成：

- `results/data/stage4a6_3_1_r/pilot/pilot_match_decisions.csv`
- `results/data/stage4a6_3_1_r/pilot/pilot_member_evidence.csv`
- `results/data/stage4a6_3_1_r/pilot/pilot_scoring_labels.csv`
- `results/data/stage4a6_3_1_r/pilot/pilot_metrics.csv`
- `results/data/stage4a6_3_1_r/pilot/stage4a6_3_1_r_independence_audit.csv`
- `results/data/stage4a6_3_1_r/runtime_summary.csv`
- `results/data/stage4a6_3_1_r/stage4a6_3_1_r_pilot_results.mat`
- `results/logs/stage4a6_3_1_r/matlab_protocol_tests_final.log`
- `results/logs/stage4a6_3_1_r/full_regression_after_pilot.log`

这些文件当前仍是工作区新增内容，尚未提交 Git；大型 MAT 是否进入远程仓库应在提交前单独审查。[本次运行]

## 限制

R 版 Pilot 仍是受限径向语法、合成先验、无噪声模型 CFR 和 A 网格的模型内重建。它验证的是代码—配置—场景—评分链的可追溯性，不是现场数据复现，也不是完整 Final。[模型内推断]
