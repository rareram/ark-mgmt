#!/usr/bin/env bash

# ==============================================================================
# TableDiff Runner v0.6.3
# Script Revision: 20260126_1600
# Developed by: ArkData (www.iarkdata.com)
#
# NORMAL UX:
#   (1) Mode Toggle (Compare / Apply)
#   (2) Config Select (*.conf)
#   (3) Compare -> Summary (always)
#   (4) Apply   -> Show Apply Plan from conf -> Select result_*.json -> Confirm -> Apply -> Summary (always)
#
# DEV MODE (-dev):
#   - Separate Xms/Xmx override (asymmetric allowed)
#   - Optional: discard compare json to /dev/null (benchmark runtime)
#   - High-res time: seconds.millis (e.g., 5.123s)
#   - On quit: print last action summary
# ==============================================================================

TARGET_JAR="TableDiff_0.6.3.jar"
DEV_MODE=false
CONF_ARG=""

# DEV-only toggles
DEV_DISCARD_COMPARE_OUTPUT=false

# Last action summary (printed on Quit)
LAST_ACTION=""
LAST_EXIT_CODE=""
LAST_DURATION_S=""
LAST_CONFIG=""
LAST_DATAFILE=""
LAST_OUTPUT=""
LAST_LOG=""

# --- 0. Environment & Colors (robust; no literal \033 leakage) ---
if [ -t 1 ] && [ "${TERM:-}" != "dumb" ] && command -v tput >/dev/null 2>&1; then
  GREEN="$(tput setaf 2 2>/dev/null || true)"
  YELLOW="$(tput setaf 3 2>/dev/null || true)"
  RED="$(tput setaf 1 2>/dev/null || true)"
  BLUE="$(tput setaf 4 2>/dev/null || true)"
  CYAN="$(tput setaf 6 2>/dev/null || true)"
  MAGENTA="$(tput setaf 5 2>/dev/null || true)"
  BOLD="$(tput bold 2>/dev/null || true)"
  NC="$(tput sgr0 2>/dev/null || true)"
else
  GREEN=""; YELLOW=""; RED=""; BLUE=""; CYAN=""; MAGENTA=""; BOLD=""; NC=""
fi

p() { printf -- "%b" "$1"; }
pf(){ printf -- "$@"; }

# --- 0.1 Argument Parsing ---
for arg in "$@"; do
  if [ "$arg" = "-dev" ]; then
    DEV_MODE=true
  else
    CONF_ARG="$arg"
  fi
done

# --- Hi-res time helpers (ms) ---
now_ms() {
  # Prefer python3 for portability (Linux/macOS)
  if command -v python3 >/dev/null 2>&1; then
    python3 - <<'PY'
import time
print(time.time_ns() // 1_000_000)
PY
  elif command -v python >/dev/null 2>&1; then
    python - <<'PY'
import time
print(int(time.time() * 1000))
PY
  elif command -v gdate >/dev/null 2>&1; then
    gdate +%s%3N
  else
    echo $(( $(date +%s) * 1000 ))
  fi
}

fmt_ms_to_s() {
  local ms="$1"
  awk -v ms="$ms" 'BEGIN{ printf "%.3f", (ms/1000.0) }'
}

# --- 1. Preconditions ---
if [ ! -w . ]; then
  pf '%s[Error]%s Writable directory required.\n' "$RED" "$NC"
  exit 1
fi

if [ ! -f "$TARGET_JAR" ]; then
  pf '%s[Error]%s %s not found.\n' "$RED" "$NC" "$TARGET_JAR"
  exit 1
fi

if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
  _java="$JAVA_HOME/bin/java"
else
  _java="java"
fi

if ! command -v "$_java" >/dev/null 2>&1; then
  pf '%s[Error]%s Java executable not found. Check JAVA_HOME or PATH.\n' "$RED" "$NC"
  exit 1
fi

FULL_JAVA_VER=$("$_java" -version 2>&1 | awk -F '"' '/version/ {print $2}')
JAVA_MAJOR=$(echo "$FULL_JAVA_VER" | cut -d'.' -f1)
[[ "$FULL_JAVA_VER" == 1.* ]] && JAVA_MAJOR=$(echo "$FULL_JAVA_VER" | cut -d'.' -f2)

get_total_mem_mb() {
  if [[ "${OSTYPE:-}" == "linux-gnu"* ]] && [ -r /proc/meminfo ]; then
    grep MemTotal /proc/meminfo | awk '{print int($2/1024)}'
  elif [[ "${OSTYPE:-}" == "darwin"* ]]; then
    sysctl -n hw.memsize | awk '{print int($1/1024/1024)}'
  else
    echo "4096"
  fi
}

TOTAL_MEM_MB=$(get_total_mem_mb)

# Auto-tuning heap: 60% of total, min 1024, max 8192
HEAP_SIZE=$((TOTAL_MEM_MB * 60 / 100))
[ "$HEAP_SIZE" -lt 1024 ] && HEAP_SIZE=1024
[ "$HEAP_SIZE" -gt 8192 ] && HEAP_SIZE=8192

# Default symmetric heap in NORMAL (DEV can override separately)
JVM_OPTS="-Xms${HEAP_SIZE}m -Xmx${HEAP_SIZE}m -XX:+UseG1GC"

USER_ID=$(whoami)
USER_UID=$(id -u)
HOST_NAME=$(hostname)
OS_INFO=$(uname -sr)
CURRENT_DIR=$(pwd)

# --- 2. Helper Functions ---
verify_config() {
  local file="$1"
  local err_cnt=0

  if [ ! -r "$file" ]; then
    pf '%s  [Fail] Cannot read config file: %s%s\n' "$RED" "$file" "$NC"
    return 1
  fi

  local o_brace c_brace quotes
  o_brace=$(tr -cd '{' < "$file" | wc -c | tr -d ' ')
  c_brace=$(tr -cd '}' < "$file" | wc -c | tr -d ' ')
  if [ "$o_brace" -ne "$c_brace" ]; then
    pf '%s  [Fail] Mismatched { } pairs (Open=%s, Close=%s).%s\n' "$RED" "$o_brace" "$c_brace" "$NC"
    err_cnt=$((err_cnt+1))
  fi

  quotes=$(tr -cd '"' < "$file" | wc -c | tr -d ' ')
  if [ $((quotes % 2)) -ne 0 ]; then
    pf '%s  [Fail] Mismatched Quotes (").%s\n' "$RED" "$NC"
    err_cnt=$((err_cnt+1))
  fi

  local key
  for key in "driver" "jdbcUrl" "username" "password"; do
    if grep -q "$key" "$file" && ! (grep "$key" "$file" | grep -q "="); then
      pf '%s  [Fail] Key "%s" missing "=" assignment.%s\n' "$RED" "$key" "$NC"
      err_cnt=$((err_cnt+1))
    fi
  done

  for key in "tableA" "tableB" "compare" "sortKey" "compCols"; do
    if ! grep -q "$key" "$file"; then
      pf '%s  [Fail] Missing key: %s%s\n' "$RED" "$key" "$NC"
      err_cnt=$((err_cnt+1))
    fi
  done

  return "$err_cnt"
}

print_runtime_info() {
  printf "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}\n"
  printf "${CYAN}│                   SYSTEM & USER AUDIT                    │${NC}\n"
  printf "${CYAN}├──────────────────────────────────────────────────────────┤${NC}\n"
  printf "${CYAN}│${NC}  User      : ${YELLOW}%s${NC} (UID: %s)\n" "$USER_ID" "$USER_UID"
  printf "${CYAN}│${NC}  Host      : ${YELLOW}%s${NC} (%s)\n" "$HOST_NAME" "$OS_INFO"
  printf "${CYAN}│${NC}  Directory : %s\n" "$CURRENT_DIR"
  printf "${CYAN}├──────────────────────────────────────────────────────────┤${NC}\n"
  printf "${CYAN}│${NC}  Java Cmd  : %s\n" "$_java"
  printf "${CYAN}│${NC}  Java Ver  : %s (Major: %s)\n" "${FULL_JAVA_VER:-unknown}" "${JAVA_MAJOR:-unknown}"
  printf "${CYAN}│${NC}  JVM Heap  : ${MAGENTA}%sMB${NC} (System: %sMB)\n" "$HEAP_SIZE" "$TOTAL_MEM_MB"
  printf "${CYAN}│${NC}  JVM Opts  : %s\n" "$JVM_OPTS"
  printf "${CYAN}│${NC}  Target JAR: %s\n" "$TARGET_JAR"
  printf "${CYAN}└──────────────────────────────────────────────────────────┘${NC}\n\n"
}

pause_enter() {
  pf "\nPress Enter to continue..."
  read -r _
}

print_last_summary() {
  pf "\n%s================ LAST ACTION SUMMARY ================%s\n" "$CYAN" "$NC"
  pf "Action   : %s\n" "${LAST_ACTION:-N/A}"
  pf "ExitCode : %s\n" "${LAST_EXIT_CODE:-N/A}"
  pf "Duration : %ss\n" "${LAST_DURATION_S:-N/A}"
  pf "Config   : %s\n" "${LAST_CONFIG:-N/A}"
  [ -n "${LAST_DATAFILE:-}" ] && pf "DataFile : %s\n" "$LAST_DATAFILE"
  pf "Output   : %s\n" "${LAST_OUTPUT:-N/A}"
  pf "Log      : %s\n" "${LAST_LOG:-N/A}"
  pf "%s======================================================%s\n" "$CYAN" "$NC"
}

# --- Simple HOCON-ish getters (best-effort; avoids heavy parsing) ---
get_kv_value() {
  local file="$1" key="$2"
  awk -v k="$key" '
    BEGIN{IGNORECASE=0}
    $0 ~ "^[[:space:]]*" k "[[:space:]]*=" {
      line=$0
      sub("^[[:space:]]*" k "[[:space:]]*=[[:space:]]*", "", line)
      gsub(/[[:space:]]*(#|\/\/).*$/, "", line)
      gsub(/^[[:space:]]*"/, "", line)
      gsub(/"[[:space:]]*$/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "$file" 2>/dev/null
}

extract_block() {
  local file="$1" name="$2"
  awk -v n="$name" '
    function count_char(s, c,   i, r){
      r=0
      for(i=1;i<=length(s);i++) if(substr(s,i,1)==c) r++
      return r
    }
    BEGIN{in=0; depth=0}
    {
      if(!in && $0 ~ "^[[:space:]]*" n "[[:space:]]*=[[:space:]]*\\{"){
        in=1
        depth += count_char($0, "{") - count_char($0, "}")
        next
      }
      if(in){
        print $0
        depth += count_char($0, "{") - count_char($0, "}")
        if(depth<=0){ exit }
      }
    }
  ' "$file" 2>/dev/null
}

block_get_field() {
  local key="$1"
  awk -v k="$key" '
    $0 ~ "^[[:space:]]*" k "[[:space:]]*=" {
      line=$0
      sub("^[[:space:]]*" k "[[:space:]]*=[[:space:]]*", "", line)
      gsub(/[[:space:]]*(#|\/\/).*$/, "", line)
      gsub(/^[[:space:]]*"/, "", line)
      gsub(/"[[:space:]]*$/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      print line
      exit
    }
  '
}

count_map_entries_in_section() {
  local section="$1"
  awk -v s="$section" '
    function count_char(x,c,   i,r){r=0;for(i=1;i<=length(x);i++) if(substr(x,i,1)==c) r++; return r}
    BEGIN{in=0; depth=0; cnt=0}
    {
      if(!in && $0 ~ "^[[:space:]]*" s "[[:space:]]*=[[:space:]]*\\{"){
        in=1
        depth += count_char($0,"{") - count_char($0,"}")
        next
      }
      if(in){
        if($0 ~ "^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*=") cnt++
        depth += count_char($0,"{") - count_char($0,"}")
        if(depth<=0){ print cnt; exit }
      }
    }
    END{ if(!in) print 0 }
  '
}

risk_label() {
  local use_db="$1" action_any="$2"
  if [ "$use_db" = "mock" ]; then
    printf "DRY-RUN (SAFE)"
    return
  fi
  if echo "$action_any" | grep -qi "delete"; then
    printf "HIGH RISK"
  elif echo "$action_any" | grep -qi "update"; then
    printf "MEDIUM RISK"
  elif echo "$action_any" | grep -qi "insert"; then
    printf "MEDIUM/LOW RISK"
  else
    printf "UNKNOWN"
  fi
}

# --- 3. Banner ---
printf '%s============================================================%s\n' "$BLUE" "$NC"
printf '%s   TableDiff Runner v0.6.3                                  %s\n' "$BLUE" "$NC"
printf '%s   Developed by ArkData - www.iarkdata.com                  %s\n' "$BLUE" "$NC"
printf '%s============================================================%s\n' "$BLUE" "$NC"
if [ "$DEV_MODE" = true ]; then
  p "${YELLOW}   [ DEVELOPER MODE ACTIVE ]                                ${NC}\n"
fi
printf '%s   Copyright (C) 2026 ArkData. All rights reserved.         %s\n\n' "$YELLOW" "$NC"

print_runtime_info

# --- 4. Dev Mode Overrides ---
PROFILER_OPT=""
if [ "$DEV_MODE" = true ]; then
  pf "\n%s┌──────────────────────────────────────────────────────────┐%s\n" "$YELLOW" "$NC"
  pf "%s│                DEVELOPER OPTION OVERRIDE                 │%s\n" "$YELLOW" "$NC"
  pf "%s├──────────────────────────────────────────────────────────┤%s\n" "$YELLOW" "$NC"

  # 4.1 Memory Override (split Xms/Xmx)
  pf "%s│%s Current JVM: %s\n" "$YELLOW" "$NC" "$JVM_OPTS"
  pf "  >> Enter Xms (e.g., 256m, 512m, 1g) [Enter to keep auto]: "
  read -r INPUT_XMS
  pf "  >> Enter Xmx (e.g., 1g, 2g, 4g) [Enter to keep auto]: "
  read -r INPUT_XMX

  if [ -n "$INPUT_XMS" ] || [ -n "$INPUT_XMX" ]; then
    [ -z "$INPUT_XMS" ] && INPUT_XMS="${HEAP_SIZE}m"
    [ -z "$INPUT_XMX" ] && INPUT_XMX="${HEAP_SIZE}m"
    JVM_OPTS="-Xms${INPUT_XMS} -Xmx${INPUT_XMX} -XX:+UseG1GC"
    pf "     %s[Updated]%s JVM heap set to Xms=%s Xmx=%s\n" "$GREEN" "$NC" "$INPUT_XMS" "$INPUT_XMX"
  else
    pf "     [Info] Keeping auto heap: %sm\n" "$HEAP_SIZE"
  fi

  # 4.2 Java Override
  pf "%s│%s Current Java: %s\n" "$YELLOW" "$NC" "$_java"
  pf "  >> Enter full path to Java executable (Press Enter to keep): "
  read -r INPUT_JAVA
  if [ -n "$INPUT_JAVA" ]; then
    if [ -x "$INPUT_JAVA" ]; then
      _java="$INPUT_JAVA"
      FULL_JAVA_VER=$("$_java" -version 2>&1 | awk -F '"' '/version/ {print $2}')
      pf "     %s[Updated]%s Using Java: %s (%s)\n" "$GREEN" "$NC" "$_java" "$FULL_JAVA_VER"
    else
      pf "     %s[Error]%s Invalid path, keeping original.\n" "$RED" "$NC"
    fi
  fi

  # 4.3 Profiling
  pf "%s│%s Profiling Options:\n" "$YELLOW" "$NC"
  pf "     1) None (Default)\n"
  pf "     2) JFR (Java Flight Recorder)\n"
  pf "     3) Pyroscope (Grafana)\n"
  pf "  >> Select Profiler (1-3): "
  read -r PROF_CHOICE

  case $PROF_CHOICE in
    2)
      JFR_FILE="recording_$(date +%Y%m%d_%H%M%S).jfr"
      PROFILER_OPT="-XX:StartFlightRecording=disk=true,dumponexit=true,filename=$JFR_FILE"
      pf "     %s[Enabled]%s JFR -> %s\n" "$GREEN" "$NC" "$JFR_FILE"
      ;;
    3)
      DEFAULT_PYRO="./pyroscope.jar"
      pf "     >> Enter path to pyroscope.jar [Default: %s]: " "$DEFAULT_PYRO"
      read -r INPUT_PYRO
      [ -z "$INPUT_PYRO" ] && INPUT_PYRO="$DEFAULT_PYRO"

      if [ -f "$INPUT_PYRO" ]; then
        APP_NAME="TableDiff-Runner"
        PROFILER_OPT="-javaagent:$INPUT_PYRO -Dpyroscope.application.name=$APP_NAME -Dpyroscope.server.address=http://localhost:4040"
        pf "     %s[Enabled]%s Pyroscope Agent loaded.\n" "$GREEN" "$NC"
      else
        pf "     %s[Error]%s %s not found. Profiling disabled.\n" "$RED" "$NC" "$INPUT_PYRO"
      fi
      ;;
    *)
      pf "     [Info] No profiling enabled.\n"
      ;;
  esac

  # 4.4 DEV: discard compare output (/dev/null) for benchmark
  pf "%s│%s Compare output discard?\n" "$YELLOW" "$NC"
  pf "     1) Keep result json file (normal)\n"
  pf "     2) Discard to /dev/null (runtime benchmark)\n"
  pf "  >> Select (1-2): "
  read -r DISCARD_CHOICE
  case "$DISCARD_CHOICE" in
    2)
      DEV_DISCARD_COMPARE_OUTPUT=true
      pf "     %s[Enabled]%s Compare JSON -> /dev/null\n" "$GREEN" "$NC"
      ;;
    *)
      DEV_DISCARD_COMPARE_OUTPUT=false
      pf "     [Info] Compare JSON will be saved to result_*.json\n"
      ;;
  esac

  pf "%s└──────────────────────────────────────────────────────────┘%s\n" "$YELLOW" "$NC"
fi

# --- 5. Common: list/select config ---
select_config() {
  SELECTED_CONFIG=""

  if [ -n "$CONF_ARG" ] && [ -f "$CONF_ARG" ]; then
    SELECTED_CONFIG="$CONF_ARG"
    pf '%s--- Auto-selected Config: %s ---%s\n' "$BLUE" "$SELECTED_CONFIG" "$NC"
    return 0
  fi

  pf '%s--- Select Configuration File ---%s\n' "$BLUE" "$NC"

  shopt -s nullglob
  configs=(*.conf)
  shopt -u nullglob

  if [ ${#configs[@]} -eq 0 ]; then
    pf '%s[Error]%s No .conf files found.\n' "$RED" "$NC"
    exit 1
  fi

  configs+=("Quit")
  config_count=${#configs[@]}
  PS3="Select config (1-$config_count): "

  COLUMNS=1
  select conf_file in "${configs[@]}"; do
    if [ "$conf_file" = "Quit" ]; then
      print_last_summary
      pf "Exiting.\n"
      exit 0
    elif [ -n "$conf_file" ]; then
      SELECTED_CONFIG="$conf_file"
      break
    else
      pf '%sInvalid selection.%s\n' "$RED" "$NC"
    fi
  done
}

# --- 6. Common: list/select result JSON runs ---
list_runs() {
  shopt -s nullglob
  runs=(result_*.json)
  shopt -u nullglob

  if [ ${#runs[@]} -eq 0 ]; then
    pf '%s[Info]%s No result_*.json found.\n' "$YELLOW" "$NC"
    return 1
  fi

  pf "\n%s--- Existing Result Runs --- %s\n" "$BLUE" "$NC"
  local i=1
  for f in "${runs[@]}"; do
    local c_same c_change c_a c_b total
    c_same=$(grep -Ec '"type"[[:space:]]*:[[:space:]]*"Same"'    "$f" 2>/dev/null || true)
    c_change=$(grep -Ec '"type"[[:space:]]*:[[:space:]]*"Change"' "$f" 2>/dev/null || true)
    c_a=$(grep -Ec '"type"[[:space:]]*:[[:space:]]*"OnlyInA"'    "$f" 2>/dev/null || true)
    c_b=$(grep -Ec '"type"[[:space:]]*:[[:space:]]*"OnlyInB"'    "$f" 2>/dev/null || true)
    total=$((c_same + c_change + c_a + c_b))
    pf "  %2d) %-45s  Total:%d  Same:%d  Change:%d  OnlyInA:%d  OnlyInB:%d\n" \
      "$i" "$f" "$total" "$c_same" "$c_change" "$c_a" "$c_b"
    i=$((i+1))
  done
  return 0
}

select_run() {
  list_runs || return 1

  shopt -s nullglob
  runs=(result_*.json)
  shopt -u nullglob

  pf "\nSelect run number (or 0 to cancel): "
  read -r n
  if ! [[ "$n" =~ ^[0-9]+$ ]]; then
    pf '%s[Error]%s Invalid input.\n' "$RED" "$NC"
    return 1
  fi
  if [ "$n" -eq 0 ]; then
    return 2
  fi
  if [ "$n" -lt 1 ] || [ "$n" -gt ${#runs[@]} ]; then
    pf '%s[Error]%s Out of range.\n' "$RED" "$NC"
    return 1
  fi
  SELECTED_RUN="${runs[$((n-1))]}"
  return 0
}

# --- 7. Compare execution + Summary (always) ---
run_compare() {
  local conf_file="$1"
  local ts conf_name out_file log_file
  ts=$(date +%Y%m%d_%H%M%S)
  conf_name="${conf_file%.*}"
  conf_name=${conf_name// /_}
  out_file="result_${conf_name}_${ts}.json"
  log_file="${out_file}.log"

  pf "\n%s--- Launching TableDiff (COMPARE / -o json) --- %s\n" "$BLUE" "$NC"
  pf "Config : %s%s%s\n" "$YELLOW" "$conf_file" "$NC"
  if [ "$DEV_MODE" = true ] && [ "$DEV_DISCARD_COMPARE_OUTPUT" = true ]; then
    pf "Output : %s%s%s\n" "$YELLOW" "(discarded:/dev/null)" "$NC"
  else
    pf "Output : %s%s%s\n" "$YELLOW" "$out_file" "$NC"
  fi
  pf "Log    : %s%s%s\n" "$BLUE" "$log_file" "$NC"
  if [ "$DEV_MODE" = true ]; then
    pf "Opts   : %s%s %s%s\n" "$MAGENTA" "$JVM_OPTS" "$PROFILER_OPT" "$NC"
  fi

  {
    pf "============================================================\n"
    pf " [AUDIT] TableDiff Compare Report (v0.6.3)\n"
    pf "============================================================\n"
    pf " * Timestamp : %s\n" "$(date)"
    pf " * User      : %s (uid=%s)\n" "$USER_ID" "$USER_UID"
    pf " * Host      : %s\n" "$HOST_NAME"
    pf " * OS        : %s\n" "$OS_INFO"
    pf " * Workdir   : %s\n" "$CURRENT_DIR"
    pf " * Mode      : %s\n" "$([ "$DEV_MODE" = true ] && echo "DEVELOPER" || echo "NORMAL")"
    pf " * Config    : %s\n" "$conf_file"
    pf " * Java Cmd  : %s\n" "$_java"
    pf " * Java Ver  : %s\n" "${FULL_JAVA_VER:-unknown}"
    pf " * JVM Opts  : %s\n" "$JVM_OPTS"
    [ -n "$PROFILER_OPT" ] && pf " * Profiler  : ENABLED (%s)\n" "$PROFILER_OPT"
    pf "============================================================\n\n"
    pf "Command:\n"
    if [ "$DEV_MODE" = true ] && [ "$DEV_DISCARD_COMPARE_OUTPUT" = true ]; then
      pf "  %s %s %s -jar %s -c %s -o json > /dev/null\n\n" "$_java" "$JVM_OPTS" "$PROFILER_OPT" "$TARGET_JAR" "$conf_file"
    else
      pf "  %s %s %s -jar %s -c %s -o json > %s\n\n" "$_java" "$JVM_OPTS" "$PROFILER_OPT" "$TARGET_JAR" "$conf_file" "$out_file"
    fi
  } > "$log_file"

  local start_ms end_ms dur_ms dur_s exit_code
  start_ms=$(now_ms)

  if [ "$DEV_MODE" = true ] && [ "$DEV_DISCARD_COMPARE_OUTPUT" = true ]; then
    "$_java" $JVM_OPTS $PROFILER_OPT -jar "$TARGET_JAR" -c "$conf_file" -o json > /dev/null 2>> "$log_file"
  else
    "$_java" $JVM_OPTS $PROFILER_OPT -jar "$TARGET_JAR" -c "$conf_file" -o json > "$out_file" 2>> "$log_file"
  fi

  exit_code=$?
  end_ms=$(now_ms)
  dur_ms=$((end_ms - start_ms))
  dur_s=$(fmt_ms_to_s "$dur_ms")

  # Summary (always)
  pf "\n%s--- Compare Summary --- %s\n" "$CYAN" "$NC"
  if [ "$DEV_MODE" = true ] && [ "$DEV_DISCARD_COMPARE_OUTPUT" = true ]; then
    pf "Run Key  : %s\n" "(discarded:/dev/null)"
  else
    pf "Run Key  : %s\n" "$out_file"
  fi
  pf "Duration : %ss\n" "$dur_s"
  pf "ExitCode : %d\n" "$exit_code"
  pf "Log      : %s\n" "$log_file"

  if [ $exit_code -eq 0 ]; then
    if [ "$DEV_MODE" = true ] && [ "$DEV_DISCARD_COMPARE_OUTPUT" = true ]; then
      pf "%s[Info]%s Output discarded; record summary skipped.\n" "$YELLOW" "$NC"
    elif [ -s "$out_file" ]; then
      local CNT_SAME CNT_CHANGE CNT_ONLY_A CNT_ONLY_B CNT_TOTAL
      CNT_SAME=$(grep -Ec '"type"[[:space:]]*:[[:space:]]*"Same"' "$out_file" || true)
      CNT_CHANGE=$(grep -Ec '"type"[[:space:]]*:[[:space:]]*"Change"' "$out_file" || true)
      CNT_ONLY_A=$(grep -Ec '"type"[[:space:]]*:[[:space:]]*"OnlyInA"' "$out_file" || true)
      CNT_ONLY_B=$(grep -Ec '"type"[[:space:]]*:[[:space:]]*"OnlyInB"' "$out_file" || true)
      CNT_TOTAL=$((CNT_SAME + CNT_CHANGE + CNT_ONLY_A + CNT_ONLY_B))

      pf "\n%s┌────────────── RESULT SUMMARY ──────────────┐%s\n" "$CYAN" "$NC"
      pf "%s│%s Total Records   : %d\n" "$CYAN" "$NC" "$CNT_TOTAL"
      pf "%s├────────────────────────────────────────────┤%s\n" "$CYAN" "$NC"
      pf "%s│%s Same            : %s%d%s\n" "$CYAN" "$NC" "$GREEN" "$CNT_SAME" "$NC"
      pf "%s│%s Changed         : %s%d%s\n" "$CYAN" "$NC" "$RED" "$CNT_CHANGE" "$NC"
      pf "%s│%s Only In A       : %s%d%s\n" "$CYAN" "$NC" "$YELLOW" "$CNT_ONLY_A" "$NC"
      pf "%s│%s Only In B       : %s%d%s\n" "$CYAN" "$NC" "$YELLOW" "$CNT_ONLY_B" "$NC"
      pf "%s└────────────────────────────────────────────┘%s\n" "$CYAN" "$NC"
    else
      pf "%s[Warning]%s Compare succeeded but output is empty.\n" "$YELLOW" "$NC"
    fi
  else
    pf "%s[Failed]%s Compare failed. Check log.\n" "$RED" "$NC"
    tail -n 30 "$log_file"
  fi

  # Update last action info
  LAST_ACTION="COMPARE"
  LAST_EXIT_CODE="$exit_code"
  LAST_DURATION_S="$dur_s"
  LAST_CONFIG="$conf_file"
  LAST_DATAFILE=""
  if [ "$DEV_MODE" = true ] && [ "$DEV_DISCARD_COMPARE_OUTPUT" = true ]; then
    LAST_OUTPUT="(discarded:/dev/null)"
  else
    LAST_OUTPUT="$out_file"
  fi
  LAST_LOG="$log_file"

  return "$exit_code"
}

# --- 8. Apply Plan preview + Apply execution + Summary (always) ---
APPLY_USE_DB=""
APPLY_RISK=""

print_apply_plan() {
  local conf_file="$1"

  local use_db
  use_db=$(get_kv_value "$conf_file" "use.db")
  [ -z "$use_db" ] && use_db="(not found)"

  local change_block onlya_block onlyb_block
  change_block="$(extract_block "$conf_file" "Change")"
  onlya_block="$(extract_block "$conf_file" "OnlyInA")"
  onlyb_block="$(extract_block "$conf_file" "OnlyInB")"

  local change_action change_table change_batch change_cols_n change_where_n
  if [ -n "$change_block" ]; then
    change_action=$(printf "%s\n" "$change_block" | block_get_field "action")
    change_table=$(printf "%s\n" "$change_block" | block_get_field "table")
    change_batch=$(printf "%s\n" "$change_block" | block_get_field "batch")
    change_cols_n=$(printf "%s\n" "$change_block" | count_map_entries_in_section "cols")
    change_where_n=$(printf "%s\n" "$change_block" | count_map_entries_in_section "where")
  fi

  local onlya_action onlya_table onlya_batch onlya_cols_n onlya_where_n
  if [ -n "$onlya_block" ]; then
    onlya_action=$(printf "%s\n" "$onlya_block" | block_get_field "action")
    onlya_table=$(printf "%s\n" "$onlya_block" | block_get_field "table")
    onlya_batch=$(printf "%s\n" "$onlya_block" | block_get_field "batch")
    onlya_cols_n=$(printf "%s\n" "$onlya_block" | count_map_entries_in_section "cols")
    onlya_where_n=$(printf "%s\n" "$onlya_block" | count_map_entries_in_section "where")
  fi

  local onlyb_action onlyb_table onlyb_batch onlyb_cols_n onlyb_where_n
  if [ -n "$onlyb_block" ]; then
    onlyb_action=$(printf "%s\n" "$onlyb_block" | block_get_field "action")
    onlyb_table=$(printf "%s\n" "$onlyb_block" | block_get_field "table")
    onlyb_batch=$(printf "%s\n" "$onlyb_block" | block_get_field "batch")
    onlyb_cols_n=$(printf "%s\n" "$onlyb_block" | count_map_entries_in_section "cols")
    onlyb_where_n=$(printf "%s\n" "$onlyb_block" | count_map_entries_in_section "where")
  fi

  local action_any risk
  action_any="$(printf "%s %s %s" "$change_action" "$onlya_action" "$onlyb_action")"
  risk="$(risk_label "$use_db" "$action_any")"

  pf "\n%s┌──────────────────── APPLY PLAN (from conf) ────────────────────┐%s\n" "$CYAN" "$NC"
  pf "%s│%s Config   : %s%s%s\n" "$CYAN" "$NC" "$YELLOW" "$conf_file" "$NC"
  pf "%s│%s use.db   : %s%s%s\n" "$CYAN" "$NC" "$YELLOW" "$use_db" "$NC"
  pf "%s│%s Risk     : %s%s%s\n" "$CYAN" "$NC" "$MAGENTA" "$risk" "$NC"
  pf "%s├───────────────────────────────────────────────────────────────┤%s\n" "$CYAN" "$NC"

  if [ -n "$change_block" ]; then
    pf "%s│%s Change   : action=%s table=%s batch=%s cols=%s where=%s\n" \
      "$CYAN" "$NC" "${change_action:-?}" "${change_table:-?}" "${change_batch:-?}" "${change_cols_n:-0}" "${change_where_n:-0}"
  else
    pf "%s│%s Change   : (not defined)\n" "$CYAN" "$NC"
  fi

  if [ -n "$onlya_block" ]; then
    pf "%s│%s OnlyInA  : action=%s table=%s batch=%s cols=%s where=%s\n" \
      "$CYAN" "$NC" "${onlya_action:-?}" "${onlya_table:-?}" "${onlya_batch:-?}" "${onlya_cols_n:-0}" "${onlya_where_n:-0}"
  else
    pf "%s│%s OnlyInA  : (not defined)\n" "$CYAN" "$NC"
  fi

  if [ -n "$onlyb_block" ]; then
    pf "%s│%s OnlyInB  : action=%s table=%s batch=%s cols=%s where=%s\n" \
      "$CYAN" "$NC" "${onlyb_action:-?}" "${onlyb_table:-?}" "${onlyb_batch:-?}" "${onlyb_cols_n:-0}" "${onlyb_where_n:-0}"
  else
    pf "%s│%s OnlyInB  : (not defined)\n" "$CYAN" "$NC"
  fi

  pf "%s├───────────────────────────────────────────────────────────────┤%s\n" "$CYAN" "$NC"
  pf "%s│%s Command  : %s -jar %s -c %s -i json -f <result.json>\n" "$CYAN" "$NC" "$_java" "$TARGET_JAR" "$conf_file"
  pf "%s└───────────────────────────────────────────────────────────────┘%s\n" "$CYAN" "$NC"

  APPLY_USE_DB="$use_db"
  APPLY_RISK="$risk"
}

run_apply() {
  local conf_file="$1"
  local data_file="$2"

  local ts log_file
  ts=$(date +%Y%m%d_%H%M%S)
  log_file="apply_${ts}_$(basename "$data_file").log"

  pf "\n%s--- Launching TableDiff (APPLY / -i json -f) --- %s\n" "$BLUE" "$NC"
  pf "Config : %s%s%s\n" "$YELLOW" "$conf_file" "$NC"
  pf "Data   : %s%s%s\n" "$YELLOW" "$data_file" "$NC"
  pf "Log    : %s%s%s\n" "$BLUE" "$log_file" "$NC"
  if [ "$DEV_MODE" = true ]; then
    pf "Opts   : %s%s %s%s\n" "$MAGENTA" "$JVM_OPTS" "$PROFILER_OPT" "$NC"
  fi

  {
    pf "============================================================\n"
    pf " [AUDIT] TableDiff Apply Report (v0.6.3)\n"
    pf "============================================================\n"
    pf " * Timestamp : %s\n" "$(date)"
    pf " * User      : %s (uid=%s)\n" "$USER_ID" "$USER_UID"
    pf " * Host      : %s\n" "$HOST_NAME"
    pf " * OS        : %s\n" "$OS_INFO"
    pf " * Workdir   : %s\n" "$CURRENT_DIR"
    pf " * Mode      : %s\n" "$([ "$DEV_MODE" = true ] && echo "DEVELOPER" || echo "NORMAL")"
    pf " * Config    : %s\n" "$conf_file"
    pf " * DataFile  : %s\n" "$data_file"
    pf " * use.db    : %s\n" "${APPLY_USE_DB:-unknown}"
    pf " * Risk      : %s\n" "${APPLY_RISK:-unknown}"
    pf " * Java Cmd  : %s\n" "$_java"
    pf " * Java Ver  : %s\n" "${FULL_JAVA_VER:-unknown}"
    pf " * JVM Opts  : %s\n" "$JVM_OPTS"
    [ -n "$PROFILER_OPT" ] && pf " * Profiler  : ENABLED (%s)\n" "$PROFILER_OPT"
    pf "============================================================\n\n"
    pf "Command:\n"
    pf "  %s %s %s -jar %s -c %s -i json -f %s\n\n" "$_java" "$JVM_OPTS" "$PROFILER_OPT" "$TARGET_JAR" "$conf_file" "$data_file"
  } > "$log_file"

  local start_ms end_ms dur_ms dur_s exit_code
  start_ms=$(now_ms)
  "$_java" $JVM_OPTS $PROFILER_OPT -jar "$TARGET_JAR" -c "$conf_file" -i json -f "$data_file" >> "$log_file" 2>&1
  exit_code=$?
  end_ms=$(now_ms)

  dur_ms=$((end_ms - start_ms))
  dur_s=$(fmt_ms_to_s "$dur_ms")

  # Summary (always)
  pf "\n%s--- Apply Summary --- %s\n" "$CYAN" "$NC"
  pf "Duration : %ss\n" "$dur_s"
  pf "ExitCode : %d\n" "$exit_code"
  pf "use.db   : %s\n" "${APPLY_USE_DB:-unknown}"
  pf "Risk     : %s\n" "${APPLY_RISK:-unknown}"
  pf "Log      : %s\n" "$log_file"

  local c_up c_in c_del
  c_up=$(grep -Eci '\bupdate\b' "$log_file" 2>/dev/null || true)
  c_in=$(grep -Eci '\binsert\b' "$log_file" 2>/dev/null || true)
  c_del=$(grep -Eci '\bdelete\b' "$log_file" 2>/dev/null || true)
  pf "\n%s┌────────── APPLY LOG KEYWORD COUNTS (best-effort) ──────────┐%s\n" "$CYAN" "$NC"
  pf "%s│%s UPDATE : %d\n" "$CYAN" "$NC" "$c_up"
  pf "%s│%s INSERT : %d\n" "$CYAN" "$NC" "$c_in"
  pf "%s│%s DELETE : %d\n" "$CYAN" "$NC" "$c_del"
  pf "%s└────────────────────────────────────────────────────────────┘%s\n" "$CYAN" "$NC"

  if [ "${APPLY_USE_DB:-}" = "mock" ]; then
    pf "%s[Note]%s use.db=mock -> no real DB changes (DRY-RUN).\n" "$YELLOW" "$NC"
  fi

  if [ $exit_code -ne 0 ]; then
    pf "%s[Failed]%s Apply failed. Last 50 lines:\n" "$RED" "$NC"
    tail -n 50 "$log_file"
  else
    pf "%s[Success]%s Apply completed.\n" "$GREEN" "$NC"
  fi

  # Update last action info
  LAST_ACTION="APPLY"
  LAST_EXIT_CODE="$exit_code"
  LAST_DURATION_S="$dur_s"
  LAST_CONFIG="$conf_file"
  LAST_DATAFILE="$data_file"
  LAST_OUTPUT="(n/a)"
  LAST_LOG="$log_file"

  return "$exit_code"
}

# --- 9. Mode toggle menu (before conf select) ---
select_mode() {
  pf "\n%s--- Select Mode --- %s\n" "$BLUE" "$NC"
  pf "  1) Compare   (generate result_*.json)\n"
  pf "  2) Apply     (use conf apply plan + select result_*.json)\n"
  pf "  3) List Runs (result_*.json)\n"
  pf "  4) Quit\n"
  pf "Select (1-4): "
  read -r MODE_CHOICE
  case "$MODE_CHOICE" in
    1) MODE="COMPARE" ;;
    2) MODE="APPLY" ;;
    3) MODE="LIST" ;;
    4) MODE="QUIT" ;;
    *) MODE="INVALID" ;;
  esac
}

# --- 10. Main loop ---
while true; do
  select_mode

  case "$MODE" in
    QUIT)
      print_last_summary
      pf "Bye.\n"
      exit 0
      ;;
    LIST)
      list_runs || true
      pause_enter
      continue
      ;;
    INVALID)
      pf '%s[Error]%s Invalid selection.\n' "$RED" "$NC"
      continue
      ;;
  esac

  # Mode is COMPARE or APPLY: select config first
  select_config
  conf_file="$SELECTED_CONFIG"

  pf "\n%s--- Verifying Config Integrity --- %s\n" "$BLUE" "$NC"
  verify_config "$conf_file"
  VERIFY_RES=$?

  if [ $VERIFY_RES -ne 0 ]; then
    pf '%s[Warning]%s Verification failed with %d errors.\n' "$RED" "$NC" "$VERIFY_RES"
    pf 'Proceed anyway? (y/N) '
    read -r REPLY
    if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
      pf "Aborted.\n"
      continue
    fi
  else
    pf '%s[OK]%s Configuration structure is valid.\n' "$GREEN" "$NC"
  fi

  if [ "$MODE" = "COMPARE" ]; then
    run_compare "$conf_file"
    pause_enter
    continue
  fi

  # APPLY mode:
  print_apply_plan "$conf_file"

  pf "\nProceed to select result json for APPLY? (y/N) "
  read -r ok
  if [[ ! "$ok" =~ ^[Yy]$ ]]; then
    pf "Cancelled.\n"
    continue
  fi

  if ! select_run; then
    pause_enter
    continue
  fi
  data_file="$SELECTED_RUN"

  pf "\n%s--- Selected Data File Summary --- %s\n" "$CYAN" "$NC"
  pf "DataFile : %s\n" "$data_file"
  pf "Size     : %s bytes\n" "$(wc -c < "$data_file" 2>/dev/null || echo 0)"
  pf "Lines    : %s\n" "$(wc -l < "$data_file" 2>/dev/null || echo 0)"
  pf "Types    : Change=%s, OnlyInA=%s, OnlyInB=%s\n" \
    "$(grep -Ec '"type"[[:space:]]*:[[:space:]]*"Change"' "$data_file" 2>/dev/null || true)" \
    "$(grep -Ec '"type"[[:space:]]*:[[:space:]]*"OnlyInA"' "$data_file" 2>/dev/null || true)" \
    "$(grep -Ec '"type"[[:space:]]*:[[:space:]]*"OnlyInB"' "$data_file" 2>/dev/null || true)"

  pf "\n%s--- FINAL CONFIRMATION --- %s\n" "$RED" "$NC"
  pf "Mode     : APPLY\n"
  pf "Config   : %s\n" "$conf_file"
  pf "DataFile : %s\n" "$data_file"
  pf "use.db   : %s\n" "${APPLY_USE_DB:-unknown}"
  pf "Risk     : %s\n" "${APPLY_RISK:-unknown}"
  pf "\nType %sAPPLY%s to proceed (or anything else to cancel): " "$BOLD" "$NC"
  read -r token
  if [ "$token" != "APPLY" ]; then
    pf "Cancelled.\n"
    pause_enter
    continue
  fi

  run_apply "$conf_file" "$data_file"
  pause_enter
done

