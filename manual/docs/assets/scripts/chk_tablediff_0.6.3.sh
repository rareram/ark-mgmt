#!/usr/bin/env bash
# ==============================================================================
# chk_tablediff_0.6.3.sh
# TableDiff Result Checker v0.6.3 (Audit & Summary View)
# Script Revision: 20260125_Audit_Summary_Focused
# Developed by: ArkData (www.iarkdata.com)
# ==============================================================================

if [ -z "${BASH_VERSION:-}" ]; then
  echo "This script must be run with bash. Example: bash $0"
  exit 1
fi

pf(){ printf -- "$@"; }

# --- Colors ---
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "${TERM:-}" != "dumb" ]; then
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

# --- Helpers ---
to_int() {
  local v="$1"
  v="$(echo "$v" | tr -cd '0-9')"
  [ -z "$v" ] && v="0"
  echo "$v"
}

mtime_epoch() {
  local f="$1"
  if stat -c %Y "$f" >/dev/null 2>&1; then stat -c %Y "$f"
  else stat -f %m "$f" 2>/dev/null || echo 0; fi
}

mtime_human() {
  local f="$1"; local e; e="$(mtime_epoch "$f")"
  if date -d "@$e" "+%Y-%m-%d %H:%M:%S" >/dev/null 2>&1; then
    date -d "@$e" "+%Y-%m-%d %H:%M:%S"
  else
    date -r "$e" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "-"
  fi
}

count_type() {
  local json="$1" type="$2"
  [ -f "$json" ] || { echo 0; return; }
  local out
  out="$(grep -Ec "\"type\"[[:space:]]*:[[:space:]]*\"${type}\"" "$json" 2>/dev/null || true)"
  to_int "$out"
}

log_extract_val() {
  local log="$1" pat="$2"
  [ -f "$log" ] || return
  grep -E "$pat" "$log" 2>/dev/null | head -n 1 | awk -F':' '{print $2}' | sed -E 's/^[[:space:]]*//'
}

get_log_duration() {
  local log="$1"
  [ -f "$log" ] || { echo "-"; return; }
  # Try to find start/end timestamps if logged (depends on run script logging format)
  # Fallback to file mtime vs ctime is hard in pure bash without helper tools
  # Just return file mtime for now as "Finished At"
  mtime_human "$log"
}

# --- Data Collection ---
collect_runs() {
  shopt -s nullglob
  local jsons=( result_*.json )
  local logs=( result_*.json.log )
  shopt -u nullglob

  BASEKEYS=()
  add_basekey() {
    local k="$1" i
    for i in "${BASEKEYS[@]}"; do [ "$i" = "$k" ] && return 0; done
    BASEKEYS+=( "$k" )
  }
  for j in "${jsons[@]}"; do add_basekey "$j"; done
  for l in "${logs[@]}"; do add_basekey "${l%.log}"; done

  if [ ${#BASEKEYS[@]} -eq 0 ]; then SORTED=(); return 0; fi

  # Sort by mtime descending
  # shellcheck disable=SC2207
  SORTED=($(for k in "${BASEKEYS[@]}"; do
    local f="$k"; [ ! -f "$f" ] && f="${k}.log"
    if [ -f "$f" ]; then pf "%s\t%s\n" "$(mtime_epoch "$f")" "$k"; else pf "0\t%s\n" "$k"; fi
  done | sort -rn | awk -F'\t' '{print $2}'))
}

# --- UI Functions ---
render_list() {
  RUN_BASE=(); RUN_JSON=(); RUN_LOG=()
  
  pf "%s============================================================%s\n" "$BLUE" "$NC"
  pf "%s   TableDiff Audit & Tracker v0.6.3                         %s\n" "$BLUE" "$NC"
  pf "%s============================================================%s\n\n" "$BLUE" "$NC"

  if [ ${#SORTED[@]} -eq 0 ]; then
    pf "%s[Info]%s No result files found.\n" "$YELLOW" "$NC"
    return 1
  fi

  pf "%s%-3s %-19s %-30s %-8s %-10s%s\n" "$BOLD" "#" "Date" "Run Key" "Status" "Rows" "$NC"
  pf "%s----------------------------------------------------------------------------%s\n" "$BLUE" "$NC"

  local idx=1
  for base in "${SORTED[@]}"; do
    local json="$base"
    local log="${base}.log"
    local when; if [ -f "$json" ]; then when="$(mtime_human "$json")"; else when="$(mtime_human "$log")"; fi
    
    local same change oa ob total status color
    if [ -f "$json" ]; then
      same="$(count_type "$json" "Same")"
      change="$(count_type "$json" "Change")"
      oa="$(count_type "$json" "OnlyInA")"
      ob="$(count_type "$json" "OnlyInB")"
      total=$((same + change + oa + ob))
      
      if [ "$change" -gt 0 ] || [ "$oa" -gt 0 ] || [ "$ob" -gt 0 ]; then
        status="DIFF"; color="$YELLOW"
      else
        status="MATCH"; color="$GREEN"
      fi
    else
      total=0
      if [ -f "$log" ] && grep -Eq "Exception|ERROR|\[Failed\]" "$log"; then
        status="FAIL"; color="$RED"
      else
        status="NO-DATA"; color="$MAGENTA"
      fi
    fi

    local run_key="${base#result_}"
    run_key="${run_key%.json}"
    
    # Truncate run key if too long
    if [ ${#run_key} -gt 29 ]; then run_key="${run_key:0:28}…"; fi

    pf "%s%-3d %-19s %-30s %-8s %-10s%s\n" "$NC" "$idx" "$when" "$run_key" "${color}${status}${NC}" "$total" "$NC"

    RUN_BASE+=( "$base" )
    idx=$((idx+1))
  done
  return 0
}

show_detail() {
  local sel="$1"
  local i=$((sel-1))
  local base="${RUN_BASE[$i]}"
  local json="$base"
  local log="${base}.log"
  LAST_VIEWED_JSON="$json" # Store for exit message

  pf "\n%s============================================================%s\n" "$BLUE" "$NC"
  pf "%s   [ DETAILED REPORT ]                                      %s\n" "$BLUE" "$NC"
  pf "%s============================================================%s\n" "$BLUE" "$NC"

  # 1. Audit Info (from Log)
  if [ -f "$log" ]; then
    local user host conf mode jver heap
    user=$(log_extract_val "$log" "User[[:space:]]*")
    host=$(log_extract_val "$log" "Host[[:space:]]*")
    conf=$(log_extract_val "$log" "Config[[:space:]]*")
    mode=$(log_extract_val "$log" "Mode[[:space:]]*")
    jver=$(log_extract_val "$log" "Java Ver[[:space:]]*")
    heap=$(log_extract_val "$log" "Heap[[:space:]]*")
    
    pf "\n%s[ AUDIT TRAIL ]%s\n" "$CYAN" "$NC"
    pf "  • Operator : %s%s%s @ %s\n" "$BOLD" "$user" "$NC" "$host"
    pf "  • Config   : %s\n" "$conf"
    pf "  • Context  : %s Mode / Java %s / Heap %s\n" "$mode" "$jver" "$heap"
    pf "  • Finished : %s\n" "$(mtime_human "$log")"
  fi

  # 2. Result Statistics (from JSON)
  if [ -f "$json" ]; then
    local same change oa ob total
    same="$(count_type "$json" "Same")"
    change="$(count_type "$json" "Change")"
    oa="$(count_type "$json" "OnlyInA")"
    ob="$(count_type "$json" "OnlyInB")"
    total=$((same + change + oa + ob))
    
    pf "\n%s[ COMPARISON SUMMARY ]%s\n" "$CYAN" "$NC"
    pf "  • Total Rows : %s%d%s\n" "$BOLD" "$total" "$NC"
    pf "  • Matched    : %s%d%s\n" "$GREEN" "$same" "$NC"
    
    if [ "$change" -gt 0 ]; then pf "  • Changed    : %s%d%s\n" "$RED" "$change" "$NC"
    else pf "  • Changed    : %d\n" "$change"; fi
    
    if [ "$oa" -gt 0 ]; then pf "  • Only In A  : %s%d%s\n" "$YELLOW" "$oa" "$NC"
    else pf "  • Only In A  : %d\n" "$oa"; fi
    
    if [ "$ob" -gt 0 ]; then pf "  • Only In B  : %s%d%s\n" "$YELLOW" "$ob" "$NC"
    else pf "  • Only In B  : %d\n" "$ob"; fi
    
    # Verdict
    if [ $((change + oa + ob)) -eq 0 ] && [ "$total" -gt 0 ]; then
      pf "\n  %s[ VERDICT: INTEGRITY CONFIRMED ]%s\n" "$GREEN" "$NC"
    elif [ "$total" -eq 0 ]; then
      pf "\n  %s[ VERDICT: NO DATA COMPARED ]%s\n" "$MAGENTA" "$NC"
    else
      pf "\n  %s[ VERDICT: DISCREPANCIES FOUND ]%s\n" "$RED" "$NC"
    fi
    
    pf "\n%s[ FILE INFO ]%s\n" "$CYAN" "$NC"
    pf "  • Result File: %s\n" "$json"
    ls -lh "$json" | awk '{print "  • File Size  : " $5}'
    
  else
    pf "\n%s[ RESULT STATUS ]%s\n" "$CYAN" "$NC"
    pf "  • %sJSON Result File Missing (Execution likely failed)%s\n" "$RED" "$NC"
  fi

  # 3. Error Analysis (if Log indicates failure)
  if [ -f "$log" ] && grep -Eq "Exception|ERROR|\[Failed\]" "$log"; then
    pf "\n%s[ ERROR ANALYSIS ]%s\n" "$RED" "$NC"
    local err_msg
    err_msg=$(grep -E "Exception|ERROR|\[Failed\]|Caused by" "$log" | head -n 3 | sed 's/^/  > /')
    pf "%s\n" "$err_msg"
    pf "\n  * Check full log for details: %s\n" "$log"
  fi
  pf "\n"
}

# --- Main Loop ---
LAST_VIEWED_JSON=""

while true; do
  collect_runs
  render_list || break

  pf "\n%sSelect run # (Enter=quit, r=refresh):%s " "$BOLD" "$NC"
  read -r sel
  [ -z "$sel" ] && break
  if [[ "$sel" =~ ^[Rr]$ ]]; then continue; fi

  sel="$(to_int "$sel")"
  if [ "$sel" -lt 1 ] || [ "$sel" -gt "${#RUN_BASE[@]}" ]; then
    pf "%s[Error]%s Invalid selection.\n" "$RED" "$NC"
    continue
  fi

  show_detail "$sel"

  pf "%sPress Enter to return list (q=quit):%s " "$BOLD" "$NC"
  read -r again
  [[ "$again" =~ ^[Qq]$ ]] && break
done

# --- Exit Message ---
if [ -n "$LAST_VIEWED_JSON" ]; then
  pf "\n%sLast viewed file:%s %s\n" "$GREEN" "$NC" "$LAST_VIEWED_JSON"
fi