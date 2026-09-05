# Stage 4A.3.1 template cache

该目录由 `run_stage4a3_1_statistical_open_set_audit('formal')` 和
`run_stage4a3_1_statistical_open_set_audit('smoke')` 生成模板缓存。

缓存 MAT 文件包含候选图—参数复合模板的无噪声复 CFR，不包含测试真值标签。由于文件体积较大，MAT 文件沿用仓库的 `results/data/*.mat` 忽略规则，不纳入 Git；缓存文件路径、模板数量、频点数量、配置哈希、构建时间和文件大小记录在对应的
`stage4a3_1_runtime_and_cache.csv` 中。需要复现时，从仓库根目录运行：

```matlab
addpath('src'); addpath('config'); addpath('experiments');
run_stage4a3_1_statistical_open_set_audit('formal');
```
