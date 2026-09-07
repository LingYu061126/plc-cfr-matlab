# Stage 4A.6.3.1-R 结果目录

本目录保存 R 版 A-grid calibration/Pilot 输出。MATLAB R2024a 已完成受控 Pilot；`final_reserved` 仅生成身份清单，未执行完整 Final。

运行入口：

```matlab
run_stage4a6_3_1_r_independent_pilot
```

入口会重新生成模板缓存、calibration 场景、Pilot 场景和独立性审计；`final_reserved` 只生成未执行的身份清单。结果生成后应保留 `compatibility_hash`、`source_tree_hash`、场景参数哈希和无噪声 CFR 哈希。

本次运行摘要：

- MATLAB：R2024a (`24.1.0.2537033`)
- 网格：`A_stage4a1_quick61`
- Calibration：14 个场景
- Pilot：35 个场景，26 个进入 profile
- worker：1，串行
- `final_reserved_executed=false`
- Pilot 退出状态：0
- 完整历史回归：退出状态 0

大型 MAT 文件用于本地复核；CSV、配置、日志和重建入口共同构成可追溯复现链。当前尚未执行 Git 提交或推送。
