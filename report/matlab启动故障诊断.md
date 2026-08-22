# MATLAB R2024a 启动故障诊断记录

## 1. 结论摘要

当前 MATLAB 不能进入项目脚本执行阶段。表面错误为：

```text
Unable to load ApplicationService for command `client-v1`
```

已有崩溃转储提供了更具体的线索：MATLAB R2024a 在启动许可管理器时，于

```text
/home/chidan/Matlab/bin/glnxa64/matlab_startup_plugins/lmgrimpl/libmwlmgrimpl.so
  ... lc_init
/usr/lib/libgnutls.so.30
```

发生 segmentation violation。该故障发生在 MATLAB 读取项目文件、执行 `run_tests` 或加载新增 `.m` 文件之前，因此不是 PLC 项目代码的测试失败。

这是“初步环境兼容性判断”，不是最终根因认定。最值得优先核对的是 MATLAB R2024a 与当前 Arch/EndeavourOS 系统库（尤其 glibc/GnuTLS）以及许可管理器的兼容性。

## 2. 当前环境

```text
MATLAB:       /home/chidan/Matlab, R2024a 24.1.0.2537033
Architecture: glnxa64
OS:           EndeavourOS Linux
Kernel:       6.18.45-1-lts
glibc:        2.44+r24+g16be1518495f-1
gnutls:       3.8.13-2
openssl:      3.6.3-1
libx11:       1.8.13-1
Desktop:      niri
Session:      Wayland, DISPLAY=:0, QT_QPA_PLATFORM=wayland;xcb
OpenGL:       crash dump reports software/uninitialized
```

MATLAB 的实际入口 `/home/chidan/Matlab/bin/matlab` 是 shell launcher；原生可执行文件是 `/home/chidan/Matlab/bin/glnxa64/MATLAB`。`ldd` 未报告 `not found`，但 MATLAB 自带 `libssl-mw.so.3/libcrypto-mw.so.3`，许可管理器堆栈仍调用系统 `/usr/lib/libgnutls.so.30`。

## 3. 已尝试命令和结果

### 3.1 项目全量测试

```bash
env MATLAB_PREFDIR=/tmp/matlab-pref-stage3a \
  LD_LIBRARY_PATH=/home/chidan/.local/share/matlab-r2024a/compat/lib \
  QT_QPA_PLATFORM=xcb \
  /home/chidan/Matlab/bin/matlab -nodisplay -nosplash -softwareopengl \
  -batch "cd('matlab_plc_cfr_publish'); run_tests"
```

结果：启动阶段失败，未生成 MATLAB diary。

### 3.2 新配置测试

使用全新 `MATLAB_PREFDIR` 运行：

```bash
... /home/chidan/Matlab/bin/matlab -nodisplay -nosplash \
  -softwareopengl -batch "...; test_stage3_band_configs; ..."
```

结果：仍在 `ApplicationService/client-v1` 阶段失败。

### 3.3 更底层探针

以下组合均未进入 `disp(version)`：

- `-nodisplay -nosplash -nojvm -r "disp(version); exit"`，有/无 `LD_LIBRARY_PATH`；
- `-nodesktop -nodisplay -nosplash -batch "disp(version)"`；
- `-nouserjavapath -singleCompThread -batch "disp(version)"`。

`matlab -help` 可以输出帮助，因为它不初始化 MATLAB 运行时和许可管理器，不能证明 MATLAB 计算环境正常。

### 3.4 用户重启终端后的再次探针

用户重启当前终端后，重新执行了最小版本探针：

```bash
MATLAB_PREFDIR=/tmp/matlab-pref-stage3a \
LD_LIBRARY_PATH=/home/chidan/.local/share/matlab-r2024a/compat/lib \
QT_QPA_PLATFORM=xcb \
/home/chidan/Matlab/bin/matlab \
  -nodisplay -nosplash -softwareopengl -batch "disp(version)"
```

结果：20 秒超时，退出码 `124`，输出仍为：

```text
Unable to load ApplicationService for command `client-v1`
```

重启后的 shell 检查结果：

```text
MATLAB_PREFDIR:    empty
LD_LIBRARY_PATH:   empty（命令只在进程内显式设置）
残留 MATLAB 进程:  无
新增 crash dump:   无
```

这排除了“旧 MATLAB 进程占用”这一简单原因，但不能排除系统库、许可管理器、MATLAB 安装或运行环境兼容问题。此次探针仍未执行 `disp(version)`，也未执行任何项目 MATLAB 代码。

## 4. 崩溃转储证据

本机保留以下原始文件，未移动或删除：

```text
/home/chidan/matlab_crash_dump.113687-1
/home/chidan/matlab_crash_dump.121198-1
/home/chidan/matlab_crash_dump.143660-1
/home/chidan/matlab_crash_dump.146554-1
```

四份转储都记录：

- MATLAB 24.1.0.2537033 (R2024a)；
- GNU C Library 2.44；
- `libmwlmgrimpl.so` 的 `lc_init` 位于栈顶；
- 随后进入 `/usr/lib/libgnutls.so.30`；
- segmentation violation。

其中最新转储为 `matlab_crash_dump.146554-1`，时间为 2026-08-19 15:21:09 +0800，约 13 KB。向 MathWorks 或系统维护者提交时，应附带最新转储及本报告，而不是只提交 `client-v1` 一行。

## 5. 历史对照

项目历史日志 `results/logs/stage3a_audit_progress.md` 记录过 MATLAB R2024a 成功运行：

```text
MATLAB R2024a 24.1.0.2537033
license test = 1
run_tests exit code 0
```

同一日志还记录曾使用：

```bash
MATLAB_PREFDIR=/tmp/matlab-pref-stage3a
LD_LIBRARY_PATH=/home/chidan/.local/share/matlab-r2024a/compat/lib
QT_QPA_PLATFORM=xcb
```

但当前再次使用该目录仍失败。因此可能存在系统库、许可服务、网络/证书环境或 MATLAB 缓存状态变化；仅重用偏好目录已不能恢复运行。

## 6. 建议排查顺序

1. 将本报告和最新 `matlab_crash_dump.146554-1` 提交给 MathWorks 支持，重点询问 `R2024a + glibc 2.44 + GnuTLS 3.8.13 + libmwlmgrimpl/lc_init`。
2. 在不替换系统库、不修改 MATLAB 安装的前提下，使用 MATLAB 官方支持的 Linux 发行版/容器/虚拟机验证是否能启动同一 R2024a。
3. 核对 MATLAB 许可状态、许可证服务器/网络、系统时间和证书链；`-nojvm` 不能绕过许可管理器，所以该选项无效并不奇怪。
4. 检查近期系统更新，特别是 glibc、GnuTLS、OpenSSL、桌面会话和 Wayland/XWayland；不要直接把系统 `libgnutls.so` 替换成 MATLAB 私有库。
5. 如果 MATLAB GUI 能由用户手工启动，再在 GUI 内切换到仓库目录运行：

   ```matlab
   addpath('src'); addpath('config'); addpath('tests');
   test_stage3_band_configs
   run_tests
   ```

## 7. 项目状态

- 阶段 1.5–3A.2 的历史 MATLAB 通过日志仍保留；本轮新增测试尚未获得 MATLAB 实际通过证据。
- GNU Octave 的 `test_stage3_band_configs` 兼容性 smoke 已通过，但不能替代 MATLAB 验收。
- 本诊断过程中没有修改阶段 1.5–3A.2 结果、MAT 文件、图或物理模型。
- 用户重启终端后的最新重试仍未进入 MATLAB；完整过程已同步记录在 `results/logs/wide_narrow_literature_audit.log`。

## 8. 修复后复核（2026-08-22）

第 3 节和第 7 节记录的是修复前或受限环境下的失败状态，以下是本次修复后的最终结果。

### 8.1 已实施修复

- 更新用户级启动器 `/home/chidan/.local/bin/matlab` 和 `/home/chidan/.local/bin/matlab-simulink`，默认加入 MATLAB R2024a 兼容库目录：
  `/home/chidan/.local/share/matlab-r2024a/compat/lib`；
- 默认使用 `QT_QPA_PLATFORM=xcb`，避免当前 Wayland 会话的 Qt 平台选择干扰；如需覆盖，可设置 `MATLAB_QT_QPA_PLATFORM`；
- 没有替换系统 GnuTLS/Nettle，没有删除 MATLAB 偏好目录、项目结果或原始崩溃转储；
- 项目测试命令补足了 `src`、`config`、`experiments` 和 `tests` 路径，避免把入口路径问题误判成 MATLAB 启动故障。

### 8.2 修复后验证

使用全新 `MATLAB_PREFDIR`、兼容库和 `QT_QPA_PLATFORM=xcb` 完成了两次 MATLAB 验证：

- `results/logs/wide_narrow_literature_recheck_config.log`：`Stage3 dual-band configuration boundaries and default isolation` 通过；
- `results/logs/wide_narrow_literature_recheck_full.log`：MATLAB R2024a `24.1.0.2537033`、`MATLAB_LICENSE=1`，阶段 1.5、2、2.1、2.2、3A、3A.1、3A.2 以及新增双频段配置测试全部通过，退出码为 `0`。

实际使用的项目入口为：

```matlab
cd('matlab_plc_cfr_publish');
addpath('src'); addpath('config'); addpath('experiments'); addpath('tests');
run_tests
```

修复后的 MATLAB Web UI/命令界面也已实际启动，未产生新的崩溃转储。当前 Codex 沙箱内仍可能打印 `client-v1 / Error locking mutex: Operation not permitted`，但它没有阻止 MATLAB 执行；这是沙箱 IPC 挂载限制，不是本次测试失败。

因此，原报告中的“当前 MATLAB 不能进入项目脚本执行阶段”已不再适用于修复后的启动器。原始 `libmwlmgrimpl/lc_init → /usr/lib/libgnutls.so.30` 崩溃转储仍保留，若未来再次出现同类崩溃，仍应附带最新转储提交 MathWorks 支持。

### 8.3 本次独立最终核验（2026-08-22）

在不覆盖前两次复核日志的前提下，本轮再次使用修复后的启动器和全新临时偏好目录执行完整测试：

```bash
MATLAB_PREFDIR=/tmp/matlab-pref-plc-verify \
  /home/chidan/.local/bin/matlab -batch \
  "cd('matlab_plc_cfr_publish'); diary('results/logs/wide_narrow_literature_final_verify.log'); disp(version); disp(['MATLAB_LICENSE=' num2str(license('test','matlab'))]); addpath('src'); addpath('config'); addpath('experiments'); addpath('tests'); run_tests; diary off"
```

结果：MATLAB R2024a（`24.1.0.2537033`）、`MATLAB_LICENSE=1`；阶段 1.5、2、2.1、2.2、2.3、3A、3A.1、3A.2 以及双频段配置边界测试全部通过。完整控制台/Diary 保存在 `results/logs/wide_narrow_literature_final_verify.log`；命令返回 `0`。

运行期间仍出现数次 `Unable to load ApplicationService for command client-v1` 提示，但 MATLAB 随后完成了全部测试，未产生新的崩溃转储。该提示应继续视为当前沙箱 IPC 警告，不能单独作为本次测试失败依据；若在脱离该启动环境后仍出现，应重新收集新的崩溃转储。
