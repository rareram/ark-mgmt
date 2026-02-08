#!/usr/bin/env bash

# ==============================================================================
# TableDiff Config Generator v0.6.3
# Script Revision: 20260125_ApplyTo_ChangeTemplate_Added_PrintfSafe
# Developed by: ArkData (www.iarkdata.com)
# Target: Debian / RHEL / macOS (bash 3.2+)
# ==============================================================================

PROFILE_FILE="$HOME/.tablediff_profile"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCH_SCRIPT_DEFAULT="$SCRIPT_DIR/sch_tablediff_0.6.3.sh"

STEPS=("Source DB" "Target DB" "Table Info" "Naming" "Complete")

# --- Guard: must be bash ---
if [ -z "${BASH_VERSION:-}" ]; then
  echo "This script must be run with bash. Example: bash $0"
  exit 1
fi

# --- printf safe wrappers ---
# pf: formatted printf (always stops option parsing)
pf() { printf -- "$@"; }
# ps: print string (supports \n via %b)
ps() { printf -- "%b" "$1"; }

# --- Colors (robust; auto-disable if not TTY or TERM=dumb) ---
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && [ "${TERM:-}" != "dumb" ]; then
  BLUE="$(tput setaf 4 2>/dev/null || true)"
  GREEN="$(tput setaf 2 2>/dev/null || true)"
  YELLOW="$(tput setaf 3 2>/dev/null || true)"
  RED="$(tput setaf 1 2>/dev/null || true)"
  BOLD="$(tput bold 2>/dev/null || true)"
  NC="$(tput sgr0 2>/dev/null || true)"
else
  BLUE=""; GREEN=""; YELLOW=""; RED=""; BOLD=""; NC=""
fi

# --- Helpers ---
print_progress() {
  local current_idx=$1
  pf '\nProgress: '
  local i
  for i in "${!STEPS[@]}"; do
    if [ "$i" -eq "$current_idx" ]; then
      pf '%s%s[ %s ]%s ' "$GREEN" "$BOLD" "${STEPS[$i]}" "$NC"
    else
      pf '%s ' "${STEPS[$i]}"
    fi
    # IMPORTANT: '-> ' starts with '-', must use printf -- (pf does that)
    [ "$i" -lt $((${#STEPS[@]} - 1)) ] && pf '-> '
  done
  pf '\n------------------------------------------------------------\n'
}

get_date() { date +%Y%m%d; }
sanitize_ip() { echo "$1" | tr -d '.'; }

escape_hocon() {
  local input="$1"
  input="${input//\\/\\\\}"
  input="${input//\"/\\\"}"
  echo "$input"
}


# Build multiline SQL block for TableDiff (SELECT ... FROM ... ORDER BY ...)
# Args: dbcode, tableName, colArrayName, sortKeyArrayName
build_sql_block() {
  local dbcode="$1"
  local tname="$2"
  local col_array_name="$3"
  local key_array_name="$4"

  # indirect arrays
  local -a cols=()
  local -a keys=()
  eval "cols=("\${${col_array_name}[@]}")"
  eval "keys=("\${${key_array_name}[@]}")"

  local select_list=""
  local c
  for c in "${cols[@]}"; do
    if [ -n "$select_list" ]; then
      select_list+=",
    "
    fi
    select_list+="$c"
  done

  local order_list=""
  local k
  for k in "${keys[@]}"; do
    # Determine ASC/DESC and NULLS FIRST/LAST based on adv.md overrides
    local sv="ASC"
    local nv="NULLS FIRST"
    local got_sort got_null
    got_sort="$(adv_get_sort "$k")"
    got_null="$(adv_get_null "$k")"

    if printf "%s" "$got_sort" | grep -qi 'ascending: *false'; then
      sv="DESC"
    fi
    if printf "%s" "$got_null" | grep -qi 'nullAsSmallest: *false'; then
      nv="NULLS LAST"
    fi

    if [ -n "$order_list" ]; then
      order_list+=",
    "
    fi

    # DB-specific NULLS handling (MySQL commonly lacks NULLS FIRST/LAST compatibility)
    case "$dbcode" in
      m|mysql)
        order_list+="$k $sv"
        ;;
      *)
        order_list+="$k $sv $nv"
        ;;
    esac
  done

  # If no columns were provided, leave empty to avoid generating invalid SQL.
  if [ -z "$select_list" ]; then
    printf ""
    return 0
  fi

  printf "  SELECT\n    %b\n  FROM %s" "$select_list" "$tname"
  if [ -n "$order_list" ]; then
    printf "\n  ORDER BY\n    %b" "$order_list"
  fi
}

set_var() {
  local __name="$1"
  local __value="$2"
  printf -v "$__name" '%s' "$__value"
}

get_db_type_info() {
  local type_num=$1
  case $type_num in
    1) RET_CODE="o"; RET_DRIVER="oracle.jdbc.OracleDriver";        RET_URL_TEMPLATE="jdbc:oracle:thin:@//HOST:PORT/SERVICE" ;;
    2) RET_CODE="p"; RET_DRIVER="org.postgresql.Driver";           RET_URL_TEMPLATE="jdbc:postgresql://HOST:PORT/DBNAME" ;;
    3) RET_CODE="m"; RET_DRIVER="com.mysql.cj.jdbc.Driver";        RET_URL_TEMPLATE="jdbc:mysql://HOST:PORT/DBNAME" ;;
    4) RET_CODE="t"; RET_DRIVER="com.tmax.tibero.jdbc.TbDriver";   RET_URL_TEMPLATE="jdbc:tibero:thin:@HOST:PORT:DBNAME" ;;
    *) RET_CODE="x"; RET_DRIVER="unknown";                         RET_URL_TEMPLATE="unknown" ;;
  esac
}

prompt_db_info() {
  local side=$1
  local def_type="" def_ip="" def_port="" def_db="" def_user="" def_pass=""

  if [ "$side" = "Source" ] && [ -n "${LAST_SRC_TYPE:-}" ]; then
    def_type=$LAST_SRC_TYPE; def_ip=$LAST_SRC_IP; def_port=$LAST_SRC_PORT
    def_db=$LAST_SRC_DB; def_user=$LAST_SRC_USER; def_pass=$LAST_SRC_PASS
  elif [ "$side" = "Target" ] && [ -n "${LAST_TGT_TYPE:-}" ]; then
    def_type=$LAST_TGT_TYPE; def_ip=$LAST_TGT_IP; def_port=$LAST_TGT_PORT
    def_db=$LAST_TGT_DB; def_user=$LAST_TGT_USER; def_pass=$LAST_TGT_PASS
  fi

  while true; do
    pf '%s=== Configure %s Database ===%s\n' "$BLUE" "$side" "$NC"
    [ -n "$def_ip" ] && pf '%s* Defaults loaded from profile *%s\n' "$YELLOW" "$NC"

    pf 'Select Database Type:\n'
    pf '  1) Oracle   2) PostgreSQL   3) MySQL   4) Tibero\n'

    pf 'Enter number [%s]: ' "${def_type:-1}"
    read -r db_type_sel
    db_type_sel=${db_type_sel:-${def_type:-1}}
    get_db_type_info "$db_type_sel"

    pf 'Host IP         [%s]: ' "$def_ip"
    read -r db_host; db_host=${db_host:-$def_ip}

    pf 'Port            [%s]: ' "$def_port"
    read -r db_port; db_port=${db_port:-$def_port}

    pf 'Service/DB Name [%s]: ' "$def_db"
    read -r db_service; db_service=${db_service:-$def_db}

    pf 'Username        [%s]: ' "$def_user"
    read -r db_user; db_user=${db_user:-$def_user}

    if [ -n "$def_pass" ]; then
      pf 'Password        [*****]: '
      read -r -s db_pass; pf '\n'
      db_pass=${db_pass:-$def_pass}
    else
      pf 'Password        : '
      read -r -s db_pass; pf '\n'
    fi

    local jdbc_url
    jdbc_url="${RET_URL_TEMPLATE/HOST/$db_host}"
    jdbc_url="${jdbc_url/PORT/$db_port}"
    if [[ "$jdbc_url" == *"oracle"* ]]; then
      jdbc_url="${jdbc_url/SERVICE/$db_service}"
    else
      jdbc_url="${jdbc_url/DBNAME/$db_service}"
    fi

    pf "\n%s[Check Info]%s\n" "$YELLOW" "$NC"
    pf "  URL  : %s\n" "$jdbc_url"
    pf "  User : %s\n" "$db_user"

    pf 'Is this correct? (Y/n): '
    read -r confirm
    if [[ "${confirm:-Y}" =~ ^[Yy]$ ]]; then
      INFO_CODE="$RET_CODE"; INFO_IP="$db_host"; INFO_DRIVER="$RET_DRIVER"; INFO_URL="$jdbc_url"; INFO_USER="$db_user"; INFO_PASS="$db_pass"

      set_var "${side}_TYPE_SEL" "$db_type_sel"
      set_var "${side}_IP"       "$db_host"
      set_var "${side}_PORT"     "$db_port"
      set_var "${side}_DB"       "$db_service"
      set_var "${side}_USER"     "$db_user"
      set_var "${side}_PASS"     "$db_pass"
      break
    else
      pf "%sRetrying...%s\n\n" "$RED" "$NC"
    fi
  done
}

verify_config() {
  local file="$1"
  local err_cnt=0
  pf "\n%s=== Verifying Configuration Integrity... ===%s\n" "$BLUE" "$NC"

  local o_brace c_brace quotes
  o_brace=$(tr -cd '{' < "$file" | wc -c | tr -d ' ')
  c_brace=$(tr -cd '}' < "$file" | wc -c | tr -d ' ')
  if [ "$o_brace" -ne "$c_brace" ]; then
    pf '%s[Fail] Mismatched { } pairs (Open=%s, Close=%s).%s\n' "$RED" "$o_brace" "$c_brace" "$NC"
    err_cnt=$((err_cnt+1))
  else
    pf '%s[Pass] Braces Balanced.%s\n' "$GREEN" "$NC"
  fi

  quotes=$(tr -cd '"' < "$file" | wc -c | tr -d ' ')
  if [ $((quotes % 2)) -ne 0 ]; then
    pf '%s[Fail] Mismatched Double Quotes (Count=%s).%s\n' "$RED" "$quotes" "$NC"
    err_cnt=$((err_cnt+1))
  else
    pf '%s[Pass] Quotes Balanced.%s\n' "$GREEN" "$NC"
  fi

  local missing_assign=0 key
  for key in "driver" "jdbcUrl" "username" "password"; do
    if grep -q "$key" "$file" && ! (grep "$key" "$file" | grep -q "="); then
      pf '%s[Fail] Key "%s" missing "=" assignment.%s\n' "$RED" "$key" "$NC"
      missing_assign=1
      err_cnt=$((err_cnt+1))
    fi
  done
  [ $missing_assign -eq 0 ] && pf '%s[Pass] Assignments Valid.%s\n' "$GREEN" "$NC"

  for key in "tableA" "tableB" "compare" "sortKey" "compCols"; do
    if ! grep -q "$key" "$file"; then
      pf '%s[Fail] Missing mandatory key: %s%s\n' "$RED" "$key" "$NC"
      err_cnt=$((err_cnt+1))
    fi
  done

  pf '------------------------------------------------------------\n'
  if [ $err_cnt -eq 0 ]; then
    pf '%s%s[OK] Config structure is valid.%s\n' "$GREEN" "$BOLD" "$NC"
  else
    pf '%s%s[Error] %d syntax issues detected!%s\n' "$RED" "$BOLD" "$err_cnt" "$NC"
  fi
}

get_next_sequence() {
  local date_str=$1
  local max_seq=0
  shopt -s nullglob
  local file seq_part seq_num
  for file in "${date_str}_"*.conf; do
    seq_part=$(echo "$file" | cut -d'_' -f2)
    if [[ "$seq_part" =~ ^[0-9]+$ ]]; then
      seq_num=$((10#$seq_part))
      [ $seq_num -gt $max_seq ] && max_seq=$seq_num
    fi
  done
  shopt -u nullglob
  pf "%02d" $((max_seq + 1))
}

# ---- Advanced Options store (portable; no associative arrays) ----
ADV_COLS=()
ADV_TOL=()
ADV_SORT=()
ADV_NULL=()

adv_find_idx() {
  local col="$1" i
  for i in "${!ADV_COLS[@]}"; do
    [ "${ADV_COLS[$i]}" = "$col" ] && { echo "$i"; return 0; }
  done
  echo "-1"
}

adv_set() {
  local col="$1" tol="$2" sort="$3" nll="$4"
  local idx
  idx="$(adv_find_idx "$col")"
  if [ "$idx" -ge 0 ]; then
    [ -n "$tol" ]  && ADV_TOL[$idx]="$tol"
    [ -n "$sort" ] && ADV_SORT[$idx]="$sort"
    [ -n "$nll" ]  && ADV_NULL[$idx]="$nll"
  else
    ADV_COLS+=("$col")
    ADV_TOL+=("${tol:-}")
    ADV_SORT+=("${sort:-}")
    ADV_NULL+=("${nll:-}")
  fi
}

adv_get_tol()  { local idx; idx="$(adv_find_idx "$1")"; [ "$idx" -ge 0 ] && echo "${ADV_TOL[$idx]}"; }
adv_get_sort() { local idx; idx="$(adv_find_idx "$1")"; [ "$idx" -ge 0 ] && echo "${ADV_SORT[$idx]}"; }
adv_get_null() { local idx; idx="$(adv_find_idx "$1")"; [ "$idx" -ge 0 ] && echo "${ADV_NULL[$idx]}"; }

# --- Main ---
pf '%s============================================================%s\n' "$BLUE" "$NC"
pf '%s   TableDiff Config Generator [Target: v0.6.3]              %s\n' "$BLUE" "$NC"
pf '%s   Developed by ArkData - www.iarkdata.com                  %s\n' "$BLUE" "$NC"
pf '%s============================================================%s\n' "$BLUE" "$NC"
pf '%s   Copyright (C) 2026 ArkData. All rights reserved.         %s\n\n' "$YELLOW" "$NC"

if [ -f "$PROFILE_FILE" ]; then
  pf '%sFound saved DB profile.%s\n' "$YELLOW" "$NC"
  pf 'Load saved DB settings? (Y/n): '
  read -r load_yn
  if [ "${load_yn:-Y}" = "Y" ] || [ "${load_yn:-Y}" = "y" ]; then
    # shellcheck disable=SC1090
    source "$PROFILE_FILE"
  fi
fi

# --- Schema auto-fetch (delegated) ---
schema_autofill() {
  # args: jdbcUrl user pass table dbcode
  local jdbc_url="$1" db_user="$2" db_pass="$3" table="$4" dbcode="$5"
  local sch_script="${SCH_SCRIPT_DEFAULT}"

  # allow override via env
  [ -n "${SCH_TABLEDIFF_SCRIPT:-}" ] && sch_script="${SCH_TABLEDIFF_SCRIPT}"

  # soft-fail rules: missing script, not executable, jq missing => return 2
  [ -f "$sch_script" ] || return 2
  [ -x "$sch_script" ] || return 2
  command -v jq >/dev/null 2>&1 || return 2

  local out json_tmp
  json_tmp="$(mktemp "${TMPDIR:-/tmp}/tablediff_schema.XXXXXX.json")" || return 2
  # do NOT echo secrets; pass via args (same as gen does already)
  "$sch_script" --dbcode "$dbcode" --jdbcUrl "$jdbc_url" --username "$db_user" --password "$db_pass" --table "$table" --out json >"$json_tmp" 2>/dev/null
  local rc=$?
  if [ $rc -ne 0 ]; then
    rm -f "$json_tmp"
    return $rc
  fi

  # parse
  mapfile -t __cols < <(jq -r '.columns[]? // empty' "$json_tmp" 2>/dev/null)
  mapfile -t __pks  < <(jq -r '.pkCandidates[]? // empty' "$json_tmp" 2>/dev/null)
  rm -f "$json_tmp"

  [ ${#__cols[@]} -gt 0 ] || return 2

  # export via global arrays
  COL_ARRAY=("${__cols[@]}")
  SORT_KEY_ARRAY=("${__pks[@]}")
  return 0
}

print_progress 0; prompt_db_info "Source"
SOURCE_CODE="$INFO_CODE"; SOURCE_IP="$INFO_IP"; SOURCE_DRIVER="$INFO_DRIVER"; SOURCE_URL="$INFO_URL"; SOURCE_USER="$INFO_USER"; SOURCE_PASS="$INFO_PASS"

print_progress 1; prompt_db_info "Target"
TARGET_CODE="$INFO_CODE"; TARGET_IP="$INFO_IP"; TARGET_DRIVER="$INFO_DRIVER"; TARGET_URL="$INFO_URL"; TARGET_USER="$INFO_USER"; TARGET_PASS="$INFO_PASS"

if [ ! -f "$PROFILE_FILE" ] || [ "${load_yn:-Y}" != "Y" ]; then
  pf '\n%sDo you want to save these DB settings for next time? (y/N)%s\n' "$YELLOW" "$NC"
  pf '>> '
  read -r save_yn
  if [[ "$save_yn" =~ ^[Yy]$ ]]; then
    {
      echo "LAST_SRC_TYPE=$(printf %q "$Source_TYPE_SEL")"
      echo "LAST_SRC_IP=$(printf %q "$Source_IP")"
      echo "LAST_SRC_PORT=$(printf %q "$Source_PORT")"
      echo "LAST_SRC_DB=$(printf %q "$Source_DB")"
      echo "LAST_SRC_USER=$(printf %q "$Source_USER")"
      echo "LAST_SRC_PASS=$(printf %q "$Source_PASS")"
      echo "LAST_TGT_TYPE=$(printf %q "$Target_TYPE_SEL")"
      echo "LAST_TGT_IP=$(printf %q "$Target_IP")"
      echo "LAST_TGT_PORT=$(printf %q "$Target_PORT")"
      echo "LAST_TGT_DB=$(printf %q "$Target_DB")"
      echo "LAST_TGT_USER=$(printf %q "$Target_USER")"
      echo "LAST_TGT_PASS=$(printf %q "$Target_PASS")"
    } > "$PROFILE_FILE"
    chmod 600 "$PROFILE_FILE"
    pf 'Profile saved.\n'
  fi
fi

print_progress 2
while true; do
  pf '%s=== Configure Table & Columns ===%s\n' "$BLUE" "$NC"

  pf 'Source Table Name : '
  read -r SRC_TABLE_NAME
  [ -z "$SRC_TABLE_NAME" ] && { pf 'Empty not allowed.\n'; continue; }

  pf 'Target Table Name [%s] : ' "$SRC_TABLE_NAME"
  read -r TGT_TABLE_NAME
  TGT_TABLE_NAME=${TGT_TABLE_NAME:-$SRC_TABLE_NAME}

  
# --- Optional: schema auto fetch (recommended) ---
pf '
Schema auto-fetch columns/PKs now? (Y/n): '
read -r use_schema
if [[ "${use_schema:-Y}" =~ ^[Yy]$ ]]; then
  if schema_autofill "$SOURCE_URL" "$SOURCE_USER" "$SOURCE_PASS" "$SRC_TABLE_NAME" "$SOURCE_CODE"; then
    pf '%s[OK]%s Retrieved %d column(s) from schema.
' "$GREEN" "$NC" "${#COL_ARRAY[@]}"
    if [ ${#SORT_KEY_ARRAY[@]} -gt 0 ]; then
      pf '%s[OK]%s PK candidate(s): %s
' "$GREEN" "$NC" "${SORT_KEY_ARRAY[*]}"
    else
      pf '%s[Info]%s No PK candidates found. You can enter PKs manually.
' "$YELLOW" "$NC"
    fi

    # Confirm or fall back to manual
    pf 'Use retrieved columns/PKs? (Y/n): '
    read -r use_retrieved
    if [[ "${use_retrieved:-Y}" =~ ^[Yy]$ ]]; then
      # If PKs are empty, ask now (manual) so later steps stay unchanged
      if [ ${#SORT_KEY_ARRAY[@]} -eq 0 ]; then
        pf 'PKs (Common)      : '
        read -r SORT_KEYS_INPUT
        IFS=',' read -r -a SORT_KEY_ARRAY <<< "$SORT_KEYS_INPUT"
        for i in "${!SORT_KEY_ARRAY[@]}"; do
          SORT_KEY_ARRAY[$i]=$(echo "${SORT_KEY_ARRAY[$i]}" | sed 's/^ *//;s/ *$//')
        done
      fi

      pf "
%s[Check Info]%s
" "$YELLOW" "$NC"
      pf "  Src: %s / Tgt: %s
" "$SRC_TABLE_NAME" "$TGT_TABLE_NAME"
      pf "  Cols(%d): %s
" "${#COL_ARRAY[@]}" "${COL_ARRAY[*]}"
      pf "  PKs : %s
" "${SORT_KEY_ARRAY[*]}"

      pf 'Is this correct? (Y/n): '
      read -r confirm
      [[ "${confirm:-Y}" =~ ^[Yy]$ ]] && break || pf '%sRetrying...%s

' "$RED" "$NC"
      continue
    fi
  fi
  pf '%s[Info]%s Schema auto-fetch unavailable/failed. Switching to manual input.
' "$YELLOW" "$NC"
fi

  pf 'Columns (Common)  : '
  read -r COLUMNS_INPUT
  [ -z "$COLUMNS_INPUT" ] && { pf 'Empty not allowed.\n'; continue; }

  IFS=',' read -r -a COL_ARRAY <<< "$COLUMNS_INPUT"
  for i in "${!COL_ARRAY[@]}"; do
    COL_ARRAY[$i]=$(echo "${COL_ARRAY[$i]}" | sed 's/^ *//;s/ *$//')
  done

  pf 'PKs (Common)      : '
  read -r SORT_KEYS_INPUT
  IFS=',' read -r -a SORT_KEY_ARRAY <<< "$SORT_KEYS_INPUT"
  for i in "${!SORT_KEY_ARRAY[@]}"; do
    SORT_KEY_ARRAY[$i]=$(echo "${SORT_KEY_ARRAY[$i]}" | sed 's/^ *//;s/ *$//')
  done

  pf "\n%s[Check Info]%s\n" "$YELLOW" "$NC"
  pf "  Src: %s / Tgt: %s\n" "$SRC_TABLE_NAME" "$TGT_TABLE_NAME"
  pf "  Cols: %s\n" "${COL_ARRAY[*]}"
  pf "  PKs : %s\n" "${SORT_KEY_ARRAY[*]}"

  pf 'Is this correct? (Y/n): '
  read -r confirm
  [[ "${confirm:-Y}" =~ ^[Yy]$ ]] && break || pf '%sRetrying...%s\n\n' "$RED" "$NC"
done

pf "\n%s=== Advanced Column Options ===%s\n" "$BLUE" "$NC"
pf 'Configure Advanced Options? (y/N): '
read -r adv_confirm
if [[ "$adv_confirm" =~ ^[Yy]$ ]]; then
  while true; do
    pf "\n%sAvailable Columns:%s %s\n" "$YELLOW" "$NC" "${COL_ARRAY[*]}"
    pf 'Enter Column Name (enter "q" to finish): '
    read -r target_col
    [ "$target_col" = "q" ] && break

    found=0
    for c in "${COL_ARRAY[@]}"; do [ "$c" = "$target_col" ] && found=1; done
    [ $found -eq 0 ] && { pf "%sNot found.%s\n" "$RED" "$NC"; continue; }

    pf '1) Tolerance(Delta) 2) Tolerance(Milli) 3) Sort(Asc/Desc) 4) Nulls(Smallest?)\nSelect: '
    read -r opt_sel
    case $opt_sel in
      1) pf 'Delta: '; read -r val; adv_set "$target_col" "tolerance: { delta: $val }" "" "" ;;
      2) pf 'Milli: '; read -r val; adv_set "$target_col" "tolerance: { milli: $val }" "" "" ;;
      3) pf 'Ascending? (true/false): '; read -r val; adv_set "$target_col" "" "ascending: $val" "" ;;
      4) pf 'Null as Smallest? (true/false): '; read -r val; adv_set "$target_col" "" "" "nullAsSmallest: $val" ;;
      *) pf "%sInvalid selection.%s\n" "$RED" "$NC" ;;
    esac
    pf '%sOption saved for %s%s\n' "$GREEN" "$target_col" "$NC"
  done
fi

print_progress 3
pf '%s=== Filename Configuration ===%s\n' "$BLUE" "$NC"
DATE_STR=$(get_date)
NEXT_SEQ=$(get_next_sequence "$DATE_STR")

pf "Choose Naming (Next Seq: %s)\n" "$NEXT_SEQ"
pf '  1) IP Based (Default)   2) Alias Based   3) Table Name   4) Custom\nSelect [1]: '
read -r name_opt
name_opt=${name_opt:-1}

case $name_opt in
  2)
    pf 'Source Tag: '; read -r SRC_TAG
    pf 'Target Tag: '; read -r TGT_TAG
    FILENAME="${DATE_STR}_${NEXT_SEQ}_${SRC_TAG:-SRC}-${TGT_TAG:-TGT}.conf"
    ;;
  3) FILENAME="${DATE_STR}_${NEXT_SEQ}_${SRC_TABLE_NAME}.conf" ;;
  4)
    while true; do
      pf 'Filename: '; read -r CUSTOM_NAME
      [ -z "$CUSTOM_NAME" ] && continue
      [[ "$CUSTOM_NAME" != *.conf ]] && CUSTOM_NAME="${CUSTOM_NAME}.conf"
      if [ -f "$CUSTOM_NAME" ]; then
        pf 'Overwrite? (y/n): '; read -r ow
        [[ "$ow" =~ ^[Yy]$ ]] && { FILENAME="$CUSTOM_NAME"; break; }
      else
        FILENAME="$CUSTOM_NAME"; break
      fi
    done
    ;;
  *)
    SANITIZED_SRC_IP=$(sanitize_ip "$SOURCE_IP")
    SANITIZED_TGT_IP=$(sanitize_ip "$TARGET_IP")
    FILENAME="${DATE_STR}_${NEXT_SEQ}_${SOURCE_CODE}${SANITIZED_SRC_IP}s-${TARGET_CODE}${SANITIZED_TGT_IP}t.conf"
    ;;
esac

print_progress 4
pf "%s=== Generating Config File... ===%s\n" "$BLUE" "$NC"

GEN_SQL_SRC="$(build_sql_block "$SOURCE_CODE" "$SRC_TABLE_NAME" COL_ARRAY SORT_KEY_ARRAY)"
GEN_SQL_TGT="$(build_sql_block "$TARGET_CODE" "$TGT_TABLE_NAME" COL_ARRAY SORT_KEY_ARRAY)"

# compare.sortKey / compare.compCols
SORT_KEY_CONF=""
for key in "${SORT_KEY_ARRAY[@]}"; do
  idx=1
  for col in "${COL_ARRAY[@]}"; do
    if [ "$key" = "$col" ]; then
      [ -n "$SORT_KEY_CONF" ] && SORT_KEY_CONF+=$',\n    '
      sv="ascending: true"; nv="nullAsSmallest: true"; tv=""
      got_sort="$(adv_get_sort "$col")"
      got_null="$(adv_get_null "$col")"
      got_tol="$(adv_get_tol "$col")"
      [ -n "$got_sort" ] && sv="$got_sort"
      [ -n "$got_null" ] && nv="$got_null"
      [ -n "$got_tol" ]  && tv=", $got_tol"
      SORT_KEY_CONF+="{ colA: $idx, colB: $idx, $sv, $nv$tv }"
      break
    fi
    idx=$((idx+1))
  done
done

COMP_COLS_CONF=""
idx=1
for col in "${COL_ARRAY[@]}"; do
  is_key=0
  for key in "${SORT_KEY_ARRAY[@]}"; do [ "$col" = "$key" ] && { is_key=1; break; }; done
  if [ $is_key -eq 0 ]; then
    [ -n "$COMP_COLS_CONF" ] && COMP_COLS_CONF+=$',\n    '
    tv=""
    got_tol="$(adv_get_tol "$col")"
    [ -n "$got_tol" ] && tv=", $got_tol"
    COMP_COLS_CONF+="{ colA: $idx, colB: $idx$tv }"
  fi
  idx=$((idx+1))
done

# ---- ApplyTo(Change) mapping templates ----
CHANGE_COLS_CONF=""
CHANGE_WHERE_CONF=""

# PK -> rowA.keys.N
kidx=1
for key in "${SORT_KEY_ARRAY[@]}"; do
  [ -n "$CHANGE_COLS_CONF" ] && CHANGE_COLS_CONF+=$'\n    '
  CHANGE_COLS_CONF+="${key} = \"rowA.keys.${kidx}\""
  kidx=$((kidx+1))
done

# non-PK -> rowA.cols.M (M counts only non-PK columns)
cidx=1
for col in "${COL_ARRAY[@]}"; do
  is_key=0
  for key in "${SORT_KEY_ARRAY[@]}"; do [ "$col" = "$key" ] && { is_key=1; break; }; done
  if [ $is_key -eq 0 ]; then
    [ -n "$CHANGE_COLS_CONF" ] && CHANGE_COLS_CONF+=$'\n    '
    CHANGE_COLS_CONF+="${col} = \"rowA.cols.${cidx}\""
    cidx=$((cidx+1))
  fi
done

# where: PK -> rowB.keys.N
kidx=1
for key in "${SORT_KEY_ARRAY[@]}"; do
  [ -n "$CHANGE_WHERE_CONF" ] && CHANGE_WHERE_CONF+=$'\n    '
  CHANGE_WHERE_CONF+="${key} = \"rowB.keys.${kidx}\""
  kidx=$((kidx+1))
done

# ---- Write file ----
{
  pf 'tableA = {\n'
  pf '  driver = "%s", jdbcUrl = "%s", username = "%s", password = "%s"\n' \
    "$SOURCE_DRIVER" "$SOURCE_URL" "$(escape_hocon "$SOURCE_USER")" "$(escape_hocon "$SOURCE_PASS")"
  pf '  sql = """\n%s\n  """\n' "$GEN_SQL_SRC"
  pf '}\n\n'

  pf 'tableB = {\n'
  pf '  driver = "%s", jdbcUrl = "%s", username = "%s", password = "%s"\n' \
    "$TARGET_DRIVER" "$TARGET_URL" "$(escape_hocon "$TARGET_USER")" "$(escape_hocon "$TARGET_PASS")"
  pf '  sql = """\n%s\n  """\n' "$GEN_SQL_TGT"
  pf '}\n\n'

  pf 'compare = {\n'
  pf '  sortKey = [\n    %b\n  ]\n' "$SORT_KEY_CONF"
  pf '  compCols = [\n    %b\n  ]\n' "$COMP_COLS_CONF"
  pf '}\n'

  pf '\n\n'
  pf '### [ ApplyTo / Change Template ] #########################################\n'
  pf '### Default: SAFE mock mode enabled.\n'
  pf '### Real apply: edit this block on-site (uncomment use.db/action as needed).\n'
  pf '### ApplyTo run:\n'
  pf '###   java -jar TableDiff_0.6.3.jar -c %s -i json -f result_xxx.json\n' "$FILENAME"
  pf '############################################################################\n\n'

  pf 'Change = {\n'
  pf '  # ------------------------------------------------------------------------\n'
  pf '  # 1) Target DB selection (pick ONE)\n'
  pf '  # ------------------------------------------------------------------------\n'
  pf '  use.db = "mock"          # [DEFAULT][SAFE] print SQL only, no DB changes\n'
  pf '  # use.db = "tableB"      # [REAL] apply changes to tableB\n'
  pf '  # use.db = "tableA"      # [REAL] apply changes to tableA\n\n'

  pf '  # ------------------------------------------------------------------------\n'
  pf '  # 2) Target table & batch\n'
  pf '  # ------------------------------------------------------------------------\n'
  pf '  table = "%s"\n' "$TGT_TABLE_NAME"
  pf '  batch = 100\n\n'

  pf '  # ------------------------------------------------------------------------\n'
  pf '  # 3) action (pick ONE)\n'
  pf '  #   insert => OnlyInA : A has row, B missing -> insert into B\n'
  pf '  #   delete => OnlyInB : B has row, A missing -> delete from B\n'
  pf '  #   update => Change  : same key, different values -> update B\n'
  pf '  # ------------------------------------------------------------------------\n'
  pf '  action = "update"        # [DEFAULT]\n'
  pf '  # action = "insert"\n'
  pf '  # action = "delete"\n\n'

  pf '  # ------------------------------------------------------------------------\n'
  pf '  # 4) Mapping (JSON -> DB)\n'
  pf '  # ------------------------------------------------------------------------\n'
  pf '  cols = {\n'
  pf '    %s\n' "$CHANGE_COLS_CONF"
  pf '  }\n\n'

  pf '  where = {\n'
  pf '    %s\n' "$CHANGE_WHERE_CONF"
  pf '  }\n'
  pf '}\n\n'

  pf '### [ Operator Notes ]\n'
  pf '### - Recommended flow:\n'
  pf '###   1) Keep use.db="mock" and run ApplyTo to review SQL\n'
  pf '###   2) Switch to use.db="tableB" (or tableA) only when confirmed\n'
  pf '###   3) For full sync you may run 3 times, changing action each time:\n'
  pf '###      - insert (OnlyInA) / delete (OnlyInB) / update (Change)\n'
  pf '############################################################################\n'
} > "$FILENAME"

verify_config "$FILENAME"
pf "\n%s[Success]%s Generated: %s%s%s\nPowered by ArkData\n" "$GREEN" "$NC" "$BOLD" "$FILENAME" "$NC"
 
