#!/usr/bin/env bash
# Run a fixed, paired subset of Stage 4A.6.3.1 profile cases under one
# power profile while recording turbostat and (in performance mode) a
# conservative temperature/throttling watchdog.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:?usage: $0 balanced|performance}"
if [[ "$MODE" != "balanced" && "$MODE" != "performance" ]]; then
    echo "unsupported mode: $MODE" >&2
    exit 2
fi

MATLAB_BIN="${MATLAB_BIN:-/home/chidan/Matlab/bin/matlab}"
MATLAB_ENV=(env LD_LIBRARY_PATH=/home/chidan/.local/share/matlab-r2024a/compat/lib QT_QPA_PLATFORM=xcb)
FREQ_LIMIT="${FREQ_LIMIT:-9}"
OPT_BUDGET_1="${OPT_BUDGET_1:-10}"
OPT_BUDGET_2="${OPT_BUDGET_2:-30}"
CASE_TIMEOUT_S="${CASE_TIMEOUT_S:-240}"
CASE_SET="${CASE_SET:-subset14}"

RUN_ID="$(date +%Y%m%d_%H%M%S)"
OUT_DIR="$ROOT/results/data/stage4a6_3_1/profile_rerun_${MODE}_${CASE_SET}_${RUN_ID}"
LOG_DIR="$ROOT/results/logs/stage4a6_3_1/profile_rerun_${MODE}_${CASE_SET}_${RUN_ID}"
mkdir -p "$OUT_DIR" "$LOG_DIR"

MODEL_FILE="$ROOT/results/data/stage4a6_3_1/stage4a6_3_1_profile_parameter_calibration_model.mat"
if [[ ! -f "$MODEL_FILE" ]]; then
    echo "missing calibration model: $MODEL_FILE" >&2
    exit 3
fi

# The default list is a fixed paired 14-case subset.  CASE_SET=all88
# deterministically derives the complete accepted profile bank from the
# existing profile_final_A filenames, mapping final_pilot_* to pilot_*.
if [[ "$CASE_SET" == "all88" ]]; then
    CASES=()
    while IFS= read -r file; do
        sample="${file#stage4a6_3_1_final_}"
        sample="${sample%.mat}"
        CASES+=("$sample")
    done < <(find "$ROOT/results/data/stage4a6_3_1/profile_final_A" -maxdepth 1 -type f \
        -name 'stage4a6_3_1_final_pilot_*.mat' -printf '%f\n' | sort)
    if [[ "${#CASES[@]}" -ne 88 ]]; then
        echo "ALL88_CASE_DISCOVERY_FAILED count=${#CASES[@]}" >&2
        exit 4
    fi
else
    # This list is frozen before either power-mode run.  It contains one
    # representative accepted case for each of the seven candidate IDs and
    # seven additional accepted boundary/equivalence cases.
    CASES=(
      pilot_G001_main_length_scale_near_upper_02
      pilot_G002_in_01
      pilot_G003_in_01
      pilot_G004_in_01
      pilot_G005_in_01
      pilot_G006_in_01
      pilot_G007_in_01
      pilot_G002_main_length_scale_near_upper_02
      pilot_G005_main_length_scale_near_lower_01
      pilot_G004_main_length_scale_near_lower_01
      pilot_G007_main_length_scale_near_upper_02
      pilot_G002_source_impedance_ohm_near_lower_01
      pilot_G004_source_impedance_ohm_near_upper_02
      pilot_G005_receiver_impedance_ohm_medium_lower_03
    )
fi

TURBO_LOG="${EXTERNAL_TURBO_LOG:-$LOG_DIR/turbostat_${MODE}.log}"
WATCHDOG_LOG="$LOG_DIR/temperature_watchdog_${MODE}.csv"
BATCH_LOG="$LOG_DIR/batch_${MODE}.log"
SUMMARY_CSV="$LOG_DIR/case_summary_${MODE}.csv"
MANIFEST="$LOG_DIR/case_manifest.csv"
RUN_META="$LOG_DIR/run_metadata.txt"

exec > >(tee -a "$BATCH_LOG") 2>&1

echo "STAGE4A6_3_1_POWER_MODE_RUN_BEGIN=$(date --iso-8601=seconds)"
echo "MODE=$MODE"
echo "RUN_ID=$RUN_ID"
echo "ROOT=$ROOT"
echo "FREQ_LIMIT=$FREQ_LIMIT"
echo "OPT_BUDGET=[$OPT_BUDGET_1 $OPT_BUDGET_2]"
echo "CASE_TIMEOUT_S=$CASE_TIMEOUT_S"
echo "CASE_SET=$CASE_SET"
echo "CASE_COUNT=${#CASES[@]}"
echo "OUTPUT_DIR=$OUT_DIR"
echo "LOG_DIR=$LOG_DIR"
echo "MATLAB_BIN=$MATLAB_BIN"

printf 'case_index,sample_id,mode,output_dir,matlab_log\n' > "$MANIFEST"
for i in "${!CASES[@]}"; do
    sample="${CASES[$i]}"
    printf '%d,%s,%s,%s,%s\n' "$((i+1))" "$sample" "$MODE" \
        "${OUT_DIR#$ROOT/}" "${LOG_DIR#$ROOT/}/${sample}.matlab.log" >> "$MANIFEST"
done
printf 'case_index,sample_id,exit_status,runtime_s,output_file\n' > "$SUMMARY_CSV"

POWER_SET_RC=0
timeout 20s pkexec /usr/bin/powerprofilesctl set "$MODE" || POWER_SET_RC=$?
if [[ "$POWER_SET_RC" -ne 0 ]]; then
    echo "POWER_PROFILE_SET_FAILED=$POWER_SET_RC" >&2
    exit 10
fi
CURRENT_MODE="$(timeout 20s /usr/bin/powerprofilesctl get 2>/dev/null || true)"
if [[ -z "$CURRENT_MODE" ]]; then
    CURRENT_MODE="$(timeout 20s pkexec /usr/bin/powerprofilesctl get 2>/dev/null || true)"
fi
echo "POWER_PROFILE_CURRENT=$CURRENT_MODE"
if [[ "$CURRENT_MODE" != "$MODE" ]]; then
    echo "POWER_PROFILE_VERIFY_FAILED expected=$MODE actual=$CURRENT_MODE" >&2
    exit 11
fi

EXTERNAL_MONITOR=0
if [[ -n "${EXTERNAL_TURBO_LOG:-}" ]]; then
    EXTERNAL_MONITOR=1
    echo "TURBOSTAT_EXTERNAL_LOG=$TURBO_LOG"
else
    before_turbostats="$(pgrep -x turbostat 2>/dev/null || true)"
    if [[ -n "$before_turbostats" ]]; then
        echo "TURBOSTAT_ALREADY_RUNNING=$before_turbostats" >&2
        exit 12
    fi
fi

TURBO_LAUNCHER_PID=""
TURBO_PID=""
MATLAB_PID=""
ABORT_REASON=""
cleanup_monitor() {
    set +e
    if [[ -n "$MATLAB_PID" ]] && kill -0 "$MATLAB_PID" 2>/dev/null; then
        kill -TERM "$MATLAB_PID" 2>/dev/null || true
    fi
    if [[ -n "$TURBO_PID" ]]; then
        timeout 12s pkexec /bin/kill -TERM "$TURBO_PID" >/dev/null 2>&1 || true
        sleep 1
        if ps -p "$TURBO_PID" >/dev/null 2>&1; then
            timeout 12s pkexec /bin/kill -KILL "$TURBO_PID" >/dev/null 2>&1 || true
        fi
    fi
    if [[ -n "$TURBO_LAUNCHER_PID" ]]; then
        kill -TERM "$TURBO_LAUNCHER_PID" 2>/dev/null || true
    fi
    timeout 20s /usr/bin/powerprofilesctl set balanced >/dev/null 2>&1 || \
        timeout 20s pkexec /usr/bin/powerprofilesctl set balanced >/dev/null 2>&1 || true
}
trap cleanup_monitor EXIT INT TERM

if [[ "$EXTERNAL_MONITOR" -eq 0 ]]; then
    setsid stdbuf -oL pkexec /usr/bin/turbostat --interval 1 > "$TURBO_LOG" 2>&1 &
    TURBO_LAUNCHER_PID=$!
    for _ in $(seq 1 20); do
        TURBO_PID="$(pgrep -n -x turbostat 2>/dev/null || true)"
        if [[ -n "$TURBO_PID" ]]; then
            break
        fi
        sleep 1
    done
    if [[ -z "$TURBO_PID" ]]; then
        echo "TURBOSTAT_START_FAILED=1" >&2
        exit 20
    fi
else
    TURBO_PID=""
fi
echo "TURBOSTAT_PID=${TURBO_PID:-external-session}"

pkg_temp() {
    sensors 2>/dev/null | awk '/Package id 0:/{gsub(/[+°C]/,"",$4); print $4; exit}'
}
throttle_count() {
    local total=0 value
    while IFS= read -r f; do
        value="$(cat "$f" 2>/dev/null || echo 0)"
        [[ "$value" =~ ^[0-9]+$ ]] && total=$((total + value))
    done < <(find /sys/devices/system/cpu -type f \( -name core_throttle_count -o -name package_throttle_count \) 2>/dev/null | sort)
    echo "$total"
}

if [[ "$MODE" == "performance" ]]; then
    printf 'timestamp,case_index,sample_id,package_temp_c,thermal_throttle_count,high_temp_consecutive\n' > "$WATCHDOG_LOG"
fi
INITIAL_THROTTLE="$(throttle_count)"
echo "INITIAL_THERMAL_THROTTLE_COUNT=$INITIAL_THROTTLE"
date --iso-8601=seconds > "$RUN_META"
{
    echo "mode=$MODE"
    echo "run_id=$RUN_ID"
    echo "sample_count=${#CASES[@]}"
    echo "turbostat_log=${TURBO_LOG#$ROOT/}"
    echo "watchdog_log=${WATCHDOG_LOG#$ROOT/}"
    echo "source_matlab=$MATLAB_BIN"
    echo "initial_throttle_count=$INITIAL_THROTTLE"
} >> "$RUN_META"

batch_start="$(date +%s)"
for i in "${!CASES[@]}"; do
    case_index=$((i+1))
    sample="${CASES[$i]}"
    case_log="$LOG_DIR/${sample}.matlab.log"
    suffix="power_${MODE}_${sample}"
    echo "CASE_BEGIN index=$case_index sample=$sample"
    case_start="$(date +%s)"
    high_count=0
    timeout -k 8s "$CASE_TIMEOUT_S" "${MATLAB_ENV[@]}" "$MATLAB_BIN" -batch \
        "addpath('$ROOT'); run_stage4a6_3_1_profile_smoke('$ROOT',$FREQ_LIMIT,[$OPT_BUDGET_1 $OPT_BUDGET_2],'$sample','$suffix','pilot','$MODEL_FILE','$OUT_DIR');" \
        > "$case_log" 2>&1 &
    MATLAB_PID=$!
    case_abort=0
    while kill -0 "$MATLAB_PID" 2>/dev/null; do
        if [[ "$MODE" == "performance" ]]; then
            temp="$(pkg_temp)"
            throttle="$(throttle_count)"
            [[ "$temp" =~ ^[0-9]+([.][0-9]+)?$ ]] || temp="NaN"
            [[ "$throttle" =~ ^[0-9]+$ ]] || throttle="$INITIAL_THROTTLE"
            if awk -v t="$temp" 'BEGIN{exit !(t >= 90)}'; then high_count=$((high_count+1)); else high_count=0; fi
            printf '%s,%d,%s,%s,%s,%d\n' "$(date --iso-8601=seconds)" "$case_index" "$sample" "$temp" "$throttle" "$high_count" >> "$WATCHDOG_LOG"
            if awk -v t="$temp" 'BEGIN{exit !(t >= 95)}'; then ABORT_REASON="package_temperature_ge_95C"; case_abort=1; fi
            if [[ "$high_count" -ge 3 ]]; then ABORT_REASON="package_temperature_ge_90C_three_samples"; case_abort=1; fi
            if [[ "$throttle" =~ ^[0-9]+$ ]] && [[ "$throttle" -gt "$INITIAL_THROTTLE" ]]; then ABORT_REASON="thermal_throttle_counter_increased"; case_abort=1; fi
            if [[ "$case_abort" -eq 1 ]]; then
                echo "THERMAL_ABORT reason=$ABORT_REASON temp=$temp throttle=$throttle"
                kill -TERM "$MATLAB_PID" 2>/dev/null || true
                for child in $(pgrep -P "$MATLAB_PID" 2>/dev/null || true); do kill -TERM "$child" 2>/dev/null || true; done
                break
            fi
        fi
        sleep 1
    done
    wait "$MATLAB_PID" 2>/dev/null
    rc=$?
    if [[ "$case_abort" -eq 1 ]]; then
        rc=75
        echo "CASE_ABORTED_BY_WATCHDOG index=$case_index sample=$sample reason=$ABORT_REASON"
        printf '%d,%s,%d,%.3f,%s\n' "$case_index" "$sample" "$rc" "$(($(date +%s)-case_start))" "${OUT_DIR#$ROOT/}/stage4a6_3_1_${suffix}.mat" >> "$SUMMARY_CSV"
        break
    fi
    runtime_s=$(( $(date +%s) - case_start ))
    printf '%d,%s,%d,%d,%s\n' "$case_index" "$sample" "$rc" "$runtime_s" "${OUT_DIR#$ROOT/}/stage4a6_3_1_${suffix}.mat" >> "$SUMMARY_CSV"
    echo "CASE_END index=$case_index sample=$sample exit_status=$rc runtime_s=$runtime_s"
    MATLAB_PID=""
    [[ "$rc" -eq 0 ]] || echo "CASE_FAILED index=$case_index sample=$sample"
done

batch_runtime=$(( $(date +%s) - batch_start ))
echo "BATCH_RUNTIME_S=$batch_runtime"
echo "BATCH_ABORT_REASON=$ABORT_REASON"
echo "TURBOSTAT_BYTES=$(wc -c < "$TURBO_LOG" 2>/dev/null || echo 0)"
echo "STAGE4A6_3_1_POWER_MODE_RUN_END=$(date --iso-8601=seconds)"
if [[ -n "$ABORT_REASON" ]]; then exit 75; fi
exit 0
