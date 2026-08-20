阶段 2.1 修改前基线快照说明

本目录不复制阶段 1.5/阶段 2 的大尺寸 MAT 和 PNG 文件；它们已经由 Git 提交和
results/SHA256SUMS_final.txt 封存。阶段 2.1 开始时的 Git 提交为：

8306506 实施 PLC CFR 阶段2 OFDM拓扑识别基线

相关封存提交：
90e2198 记录阶段1.5最终结果哈希
7e764ba 封存 PLC CFR 阶段1.5稳定正向模型

修改前 MATLAB：R2024a (24.1.0.2537033), release 2024a；使用 MATLAB 基础功能，
未依赖额外工具箱。

修改前实际测试：
- results/logs/stage2_1_prechange_run_tests.log：直接运行 tests/run_tests.m，因入口未
  加入 config/src 路径而失败；这是入口环境错误，不记为通过。
- results/logs/stage2_1_prechange_run_tests_corrected.log：在项目根目录并按 run_all 的
  路径方式运行，阶段 1.5 与阶段 2 测试全部通过。

原阶段 2 运行日志和结果文件仍由 8306506 及 results/SHA256SUMS_final.txt 保留；阶段
2.1 新结果使用 stage2_1_ 前缀，便于与修改前结果逐项比较。
