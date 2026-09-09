# Windows 复现说明：Stage 4A Freeze-R.1.1

本文档给出 Windows MATLAB 的 clean-source 复现入口。当前 Linux 工作环境未执行 Windows 原生 MATLAB，因此 Windows 状态应记录为 `windows_native_tested=false`、`windows_reproduction_status=external_reproduction_pending`。

## 1. 获取干净源码

建议使用独立 worktree，并关闭 Git 自动换行转换：

```powershell
$Repo = "D:\Research\plc-cfr-matlab"
$Repro = "D:\Research\plc-cfr-reproduce-$(Get-Date -Format yyyyMMdd-HHmmss)"

Set-Location $Repo
git status --short
git config core.autocrlf false
git fetch origin --prune
git pull --ff-only origin main
git worktree add --detach $Repro origin/main
Set-Location $Repro
git rev-parse HEAD
git status --short
```

`git status --short` 在正式运行前应为空。推荐 MATLAB R2024a：

```powershell
matlab -batch "disp(version); disp(computer('arch'));"
```

## 2. 定向测试、smoke、formal 与回归

以下命令均从仓库根目录执行。输出写入新的 `stage4a_freeze_r1_1` 目录，不覆盖历史 Freeze-R.1 结果。

```powershell
New-Item -ItemType Directory -Force results\logs\stage4a_freeze_r1_1 | Out-Null

matlab -batch "diary('results/logs/stage4a_freeze_r1_1/targeted_tests_final.log'); addpath('src'); addpath('config'); addpath('experiments'); addpath('tests'); test_stage4_freeze_r1_1; diary off"

matlab -batch "diary('results/logs/stage4a_freeze_r1_1/smoke_final.log'); run_stage4_freeze_r1_1(pwd,'smoke'); diary off"

matlab -batch "diary('results/logs/stage4a_freeze_r1_1/formal_final.log'); run_stage4_freeze_r1_1(pwd,'formal'); diary off"

matlab -batch "diary('results/logs/stage4a_freeze_r1_1/full_regression_final.log'); addpath('src'); addpath('config'); addpath('experiments'); addpath('tests'); run_tests; diary off"
```

正式 `formal` 必须在 clean worktree 中执行；dirty worktree 会以 `stage4a_freeze_r1:DirtyCanonicalSource` 失败。流程使用串行配置，不启动并行池；`final_reserved` 仅保存身份，不物化样本。

## 3. 结果核验

```powershell
Get-ChildItem results\data\stage4a_freeze_r1_1 -Recurse
Get-Content results\data\stage4a_freeze_r1_1\canonical_manifest.csv
Get-Content results\data\stage4a_freeze_r1_1\freeze_summary_formal.csv
```

应核验：

- `results/data/stage4a_freeze_r1_1/stage4a7_3/formal/` 为 canonical formal；
- `source_identity_manifest.csv` 中每个文件均存在、由 Git 跟踪且 SHA256 匹配；
- 根 `canonical_manifest.csv` 中每个 artifact 均存在且 SHA256 匹配；
- `git_dirty_at_run=false`、`canonical_eligible=true`；
- Rule A 的 `selected_method=profile_relative_distance`；
- Rule B sensitivity 的 `selected_method=profile_min_distance`；
- `final_reserved_status=manifest_only_not_materialized`；
- `stage4b_started=false`。

允许因平台不同而变化的字段包括 MATLAB 补丁版本、平台、CPU 架构、运行时间和 runtime environment hash。科学源码、配置、实验和结果身份应以机器可读 manifest 为准。

## 4. 规模和边界

Stage 4A.7.3 formal 预期包含 87 个冻结候选、783 个 development 场景、3480 个 calibration 场景、783 个 Pilot 场景和 120 个 T3/T5 控制样本。实际值以 formal `summary.csv` 为准。

当前结果仍是受限候选库、模型生成 CFR 和频域等效噪声下的模型内验证，不构成真实 PLC 收发机或现场配电网验证。Windows 原生运行完成前不得写成 Windows 已实测通过。
