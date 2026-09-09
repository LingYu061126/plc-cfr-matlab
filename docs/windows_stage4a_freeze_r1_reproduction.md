# Windows 复现说明：Stage 4A Freeze-R.1

本文档给出 Windows 主机上的独立复现入口。Windows 原生 MATLAB 未在本次 Linux 执行环境中实测，因此下述流程是已实现的兼容入口，原生 Windows 执行仍需单独核验。

## 1. 工作区准备

建议使用独立 worktree，避免影响开发目录：

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
```

要求 MATLAB R2024a（24.1）或项目已验证的兼容版本。检查：

```powershell
matlab -batch "disp(version); disp(computer('arch'));"
```

## 2. MATLAB 入口

在仓库根目录执行，路径可使用 Windows 盘符格式：

```powershell
New-Item -ItemType Directory -Force results\logs\stage4a_freeze_r1 | Out-Null
matlab -batch "diary('results/logs/stage4a_freeze_r1/targeted_tests_windows.log'); addpath('src'); addpath('config'); addpath('experiments'); addpath('tests'); test_stage4_freeze_r1; test_stage4a7_2_r2_1_2_statistics; diary off"
matlab -batch "diary('results/logs/stage4a_freeze_r1/smoke_windows.log'); run_stage4_freeze_r1(pwd,'smoke'); diary off"
matlab -batch "diary('results/logs/stage4a_freeze_r1/formal_windows.log'); run_stage4_freeze_r1(pwd,'formal'); diary off"
matlab -batch "diary('results/logs/stage4a_freeze_r1/full_regression_windows.log'); addpath('src'); addpath('config'); addpath('experiments'); addpath('tests'); run_tests; diary off"
```

正式运行使用串行配置，不启动并行池。`final_reserved` 只保留 manifest 身份，不生成样本。

## 3. 结果核验

检查以下目录和文件：

```powershell
Get-ChildItem results\data\stage4a_freeze_r1 -Recurse
Get-Content results\data\stage4a_freeze_r1\canonical_manifest.csv
Get-Content results\data\stage4a_freeze_r1\freeze_summary_formal.csv
```

formal 输出应位于：

```text
results/data/stage4a_freeze_r1/stage4a7_3/formal/
```

canonical manifest 中的每个 `relative_path` 应存在，且以同一二进制读取方式重新计算的 SHA256 应与 `sha256` 字段一致。Smoke 只作为复现检查，不作为正式性能结果；Rule B 只作为 sensitivity 审计。

科学身份应保持一致：`source_tree_hash`、`configuration_hash`、候选和参数 calibration hash 以及 experiment hash。允许不同的环境字段包括 MATLAB 版本补丁号、平台、CPU 架构、运行时间和绝对路径；Windows 的 `runtime_environment_hash` 可以不同。

## 4. 预期规模和边界

Stage 4A.7.3 formal 预期包含 87 个冻结候选、783 个 development 场景、3,480 个参数 calibration 场景、783 个 Pilot 场景和 120 个 T3/T5 非唯一控制样本。具体计数以机器可读 summary 为准。

Windows 实机未在本阶段执行；应将其结果标记为 `external reproduction pending`，不能写成 Windows 已通过。跨平台 SHA256 实现按原始二进制字节工作，支持带空格、中文和括号的路径；系统工具不可用时会返回明确错误，不会返回空摘要。
