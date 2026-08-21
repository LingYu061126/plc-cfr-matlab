# Stage 3A 审计进度

## 检查点 1：修改前阅读、状态与基线

- 已阅读：父目录 `Codes/AGENTS.md`（发布仓库根目录没有同名文件）、阶段任务书、README、PUBLISHING、阶段 1.5–2.3 报告、入口脚本和测试入口。
- 修改前 Git：`1319f26 audit(stage2.3): finalize smoke and formal delivery notes`，工作树干净。
- 命令：

  ```bash
  env LD_LIBRARY_PATH=/home/chidan/.local/share/matlab-r2024a/compat/lib QT_QPA_PLATFORM=xcb /home/chidan/Matlab/bin/matlab -batch "diary('results/logs/stage3a_prechange_tests.log');disp(version);disp(['MATLAB_LICENSE=' num2str(license('test','matlab'))]);addpath('src');addpath('config');addpath('experiments');addpath('tests');run_tests;diary off"
  ```

- 结果：MATLAB R2024a `24.1.0.2537033`，MATLAB 基础许可可用，无额外工具箱；阶段 1.5、2、2.1、2.2、2.3 全部通过。

## 检查点 2：模型修订和阶段 3A 单元测试

- 新增统一 `H(f;G,theta)`/观测 `O` 说明，明确普通 OFDM-CFR 与 FDR/TFDR、输入导纳 proxy 的边界。
- 新增 Stage3A IFFT/CP/FFT/LS、稀疏导频插值、噪声/定时/采样时钟/相位/参数扰动模块；不改变旧物理公式和候选拓扑。
- 命令：`test_stage3a`；日志：`results/logs/stage3a_unit_tests_final.log`。
- 结果：全部 8 项 Stage3A 测试通过。测试后增加了端接阻抗和耦合器扰动实际影响断言，需再执行一次全量回归。

## 检查点 3：smoke/formal 运行

- smoke 初次运行成功；之后代码增加端接/耦合器案例，最终已重新刷新 smoke。
- formal 首次启动遇到 MATLAB `settings/errors_warnings` 插件错误；没有产生结果文件，未作为通过。
- formal 使用 `MATLAB_PREFDIR=/tmp/matlab-pref-stage3a` 重试成功；最后一次命令为：

  ```bash
  env MATLAB_PREFDIR=/tmp/matlab-pref-stage3a LD_LIBRARY_PATH=/home/chidan/.local/share/matlab-r2024a/compat/lib QT_QPA_PLATFORM=xcb /home/chidan/Matlab/bin/matlab -nodisplay -nosplash -softwareopengl -batch "diary('results/logs/stage3a_formal_final.log');result=run_stage3a('formal');disp(result);diary off"
  ```

- 最后一次 formal 结果：退出码 0；1088 条 trial 指标、272 条 raw 记录、136 条 summary 记录、593 条 confusion 聚合记录；`stage3a_formal_raw.mat` 本机约 185 MB，按发布策略不纳入轻量仓库。

- 最终 smoke 命令：`run_stage3a('smoke')`；退出码 0；544 条 trial 指标、136 条 raw 记录、136 条 summary 记录、544 条 confusion 聚合记录。

## 检查点 4：formal CSV 指标核对

- 20 dB 白噪声、幅相联合特征：
  - `siso_forward`：strict `0.875`，strict unique `0.500`，equivalence class `1.000`，ambiguity `0.500`，CFR NMSE `0.004179`；
  - `dual_receiver_complete`：strict/unique/class 均 `1.000`，ambiguity `0`，CFR NMSE `0.004161`；
  - `three_view_complete`：strict/unique/class 均 `1.000`，ambiguity `0`，CFR NMSE `0.004087`；
  - `bidirectional_endpoint_fixed`：strict `0.625`，unique `0.500`，class `1.000`，ambiguity `0.500`，CFR NMSE `0.004144`。
- 参数/误差压力案例的 SISO strict/class：长度 `0.500/0.750`，RLGC `0.625/0.875`，定时 `0.125/0.500`；定时场景 CFR NMSE `2.138290`。这些是当前仿真假设下的 formal 基线，不是现场统计结论。
- 当前 SISO T3/T5 的等价类结论保持不变；多视图严格率为 1 仅代表当前完整网络和接收负载模型。

## 检查点 5：最终回归、数据结构和交付状态

1. 最终命令：`run_tests`；MATLAB R2024a，退出码 0；阶段 1.5、2、2.1、2.2、2.3、3A 全部通过。
2. 最终命令：`run_stage3a('smoke')`；退出码 0，生成 544/136/136/544 条记录（trial/raw/summary/confusion）。
3. 最终 formal：退出码 0，生成 1088/272/136/593 条记录；没有从头运行更大 Monte Carlo，formal 的每个场景/拓扑为 2 个 trial。
4. CSV 结构、图、日志和文档已更新；raw MAT 仅本机保留并因约 185 MB 被发布策略排除。
5. 未进入 Stage3B；未删除或覆盖阶段 1.5–2.3 历史结果。
