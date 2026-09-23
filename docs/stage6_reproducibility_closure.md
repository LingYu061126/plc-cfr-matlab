# Stage 6 Reproducibility Closure

## 1. Scope

本次归档闭环仅核验 Stage 6 源码身份、正式结果归档、MATLAB 复现、日志和 manifest；未改变 Stage 4A、Stage 5B.1、Stage 6A 或 Stage 6B 的科学算法、阈值、实验协议和正式数值。以下日志是 **post-commit reproduction / archive-closure verification**，不是原实验生成时的原始日志。

## 2. Source identity

| 项目 | 验证记录 |
|---|---|
| 验证基线 | `bea0aee10b216ba42813329772f05a24dbdca07c`，Stage 6A/6B 归档提交 |
| 分支与工作树 | 主分支 `main`；验证在基线提交的独立 detached 临时工作树进行，formal 开始时 Git 工作树干净 |
| MATLAB | `24.1.0.2537033 (R2024a)`，Linux，`glnxa64` |
| 并行 | 未启动并行池；parallel workers = 0；实验为串行执行。正式 runtime CSV 的 `worker_count=1` 表示串行执行槽，不代表启动了一个并行 worker |
| 随机种子 | Stage 6A：`20264001`；Stage 6B：`20266001`，均来自各阶段配置 |
| 配置 | `config/stage6a_candidate_generation_config.m`；`config/stage6b_robustness_config.m` |
| 入口 | `run_stage6a_candidate_generation.m`；`run_stage6b_robustness.m` |
| 验证日期 | 2026-09-23 UTC；单次日志和 `closure_summary.csv` 记录对应身份 |

Stage 6B identifiability 控制需要未跟踪的 `results/data/stage5b1/formal/stage5b1_results.mat`。在临时工作树上先从跟踪源码和配置执行 Stage 5B.1 formal 生成该派生 MAT，再将其用于独立的 Stage 6B 验证；没有向主工作树写入该文件。其前置日志位于 `results/logs/stage6_closure/stage5b1_prerequisite_reproduction.log`。

## 3. Verification commands

下列 MATLAB 命令均以临时工作树为当前目录运行，启动时使用独立 `MATLAB_PREFDIR`、`-nodisplay -nosplash -softwareopengl -batch`。R2024a 的图形兼容库路径与 `QT_QPA_PLATFORM=xcb` 仅用于此机器的无显示启动，不改变科学配置。路径占位符不属于实验参数。

```matlab
run_stage5b1_objective_confirmation_upgrade(pwd,'formal')
addpath('src','config','experiments','tests'); test_stage6a_candidate_generation(); test_stage6b_robustness()
addpath('src','config','experiments','tests'); run_tests()
run_stage6a_candidate_generation(pwd,'formal')
run_stage6b_robustness(pwd,'formal')
```

新增 `test_stage6_archive_integrity()` 注册在 `tests/run_tests.m`。它检查归档 CSV 的固定计数与状态，以及 source/artifact 清单中的文件大小和原始字节 SHA-256；不重新定义任何科学阈值。

## 4. Result comparison

对 `results/data/stage6a/` 与 `results/data/stage6b/` 的 11 份科学 CSV 按行、列逐字段比较：4,426 个非运行时间字段匹配，零差异超限；另有 9 个运行时间字段标为 `not_compared`。整数、状态和文本要求精确一致；其他有限浮点值使用绝对容差 `1e-12`。完整逐字段证据见 `results/data/stage6_closure/reproduction_comparison.csv`，清单中的 SHA-256 直接按原始文件字节计算。`stage6a_runtime.csv`、`stage6b_runtime.csv`、PNG 二进制、MAT 文件的时间相关元数据和 MATLAB/JIT wall-clock 波动不要求逐字节一致；正式归档文件未被复现输出覆盖。

清单中的 `source_commit=bea0aee10b216ba42813329772f05a24dbdca07c` 表示未修改的 Stage 6 基线文件；`source_commit=stage6_archive_closure` 是本次提交文件的非递归身份标记，不冒充尚无法写入自身 manifest 的最终 Git hash。最终提交身份以 Git 提交记录为准。

复现保留了关键科学结论：Stage 6A broad/informative/stale 候选数分别为 7/2/4，coverage 为 1/1/0，stale prior 的 9/9 样本被拒绝。Stage 6B 中，14/14 个实际错误先验样本被拒绝且 false unique 为 0，20% population prior error 的 coverage 为 0.8；3/7/23 候选规模下 30/30 为正确 `UNIQUE_CONFIDENT`；0% length error 下 10/10 为 `UNIQUE_CONFIDENT`，±5%、±10%、±20% 共 60/60 为 `REJECTED`；T3/T5 及 three-topology-close 控制均为 `MULTIPLE_AMBIGUOUS`。正式 Stage 6B 串行总时间仍以 canonical `stage6b_runtime.csv` 的 11.068872 s 为准，复现的 8.818 s 不替代它。

## 5. Test results

| 验证 | 状态 | Exit status | 归档日志 |
|---|---|---:|---|
| Stage 5B.1 前置派生 MAT | PASS | 0 | `results/logs/stage6_closure/stage5b1_prerequisite_reproduction.log` |
| Stage 6A/6B 定向测试 | PASS | 0 | `results/logs/stage6_closure/stage6_targeted_tests.log` |
| 完整 `tests/run_tests.m`，含归档完整性测试 | PASS | 0 | `results/logs/stage6_closure/stage6_full_regression.log` |
| Stage 6A formal | PASS | 0 | `results/logs/stage6_closure/stage6a_formal_reproduction.log` |
| Stage 6B formal | PASS | 0 | `results/logs/stage6_closure/stage6b_formal_reproduction.log` |
| 科学 CSV 对照 | PASS | 0 | `results/logs/stage6_closure/stage6_result_comparison.log` |

完整回归存在既有 `lsqnonlin` trust-region-reflective 方程数不足、回退到 Levenberg–Marquardt 的 warning；其相关测试通过。MATLAB 无显示启动偶有 `Unable to load ApplicationService for command client-v1` 提示，但本次记录的测试与实验进程以退出码 0 结束。未发现影响 Stage 6 结论的 MATLAB 错误。

## 6. Conclusion and research boundary

**PASS — Stage 6 archived and reproducible under the recorded environment.** Stage 6 Archive Closure completed；Stage 7 formal report / thesis synthesis ready。该结论仅覆盖记录的受控 MATLAB 模型内实验，不是现场低压台区或真实 PLC 收发机验证。candidate coverage 不等于观测可辨识；`UNIQUE_CONFIDENT` 不等于全局物理唯一；`REJECTED` 不自动定位错误台账。14/14 prior rejection 不能外推到任意错误先验；23 candidates 不是大规模候选库；±5% 全拒绝提示当前 calibration domain 较窄，而非通用物理容差；T3/T5 和 three-topology-close 是受控 positive controls。Stage 4B 未启动，Multi-view CFR 尚未实现且不是当前主线阻塞条件。
