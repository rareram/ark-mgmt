

# Try to run SQL inside a Docker container if local client is unavailable.
# For Oracle, many setups ship sqlplus inside the container.
find_oracle_container() {
  if ! command -v docker >/dev/null 2>&1; then
    return 1
  fi
  # If user supplied ORACLE_DOCKER_CONTAINER env var, use it
  if [ -n "${ORACLE_DOCKER_CONTAINER:-}" ]; then
    printf "%s" "$ORACLE_DOCKER_CONTAINER"
    return 0
  fi
  # Best-effort auto-detect (single match)
  local matches
  matches="$(docker ps --format '{{.Names}} {{.Image}}' 2>/dev/null | grep -i oracle || true)"
  local cnt
  cnt="$(printf "%s\n" "$matches" | sed '/^$/d' | wc -l | tr -d ' ')"
  if [ "$cnt" = "1" ]; then
    printf "%s" "$matches" | awk '{print $1}'
    return 0
  fi
  return 1
}

oracle_query_via_docker_sqlplus() {
  local container="$1"
  local conn="$2"
  local sql="$3"

  # Execute sqlplus non-interactively inside container. We assume sqlplus is present.
  # Use -L to fail fast on login errors.
  docker exec -i "$container" bash -lc "sqlplus -L -s '$conn' <<'SQL'
set pages 0 feedback off verify off heading off echo off trimspool on linesize 32767
$sql
exit
SQL"
}

#!/usr/bin/env bash
# ==============================================================================
# TableDiff Schema Fetcher v0.6.3
# Output JSON: {"tables":[...],"columns":[...],"pkCandidates":[...]}
# Exit codes: 0=success, 1=usage/internal, 2=soft-failure(connect/tool/perm)
# ==============================================================================
set -u

pf(){ printf -- "$@"; }

usage(){
  cat <<'USAGE'
Usage:
  sch_tablediff_0.6.3.sh --dbcode <o|p|m|t> --jdbcUrl <url> --username <u> --password <p> --table <t> [--schema <s>]

dbcode:
  o=oracle, p=postgres, m=mysql, t=tibero

Notes:
  - Requires client tool:
      o/t: sqlplus
      p  : psql
      m  : mysql
  - Soft failures return 2 so caller can fallback to manual mode.
USAGE
}

DBCODE="" JDBC_URL="" USERNAME="" PASSWORD="" TABLE="" SCHEMA=""
CACHE_DIR="${HOME}/.tablediff_schema_cache"
CACHE_TTL_SEC=3600

while [ $# -gt 0 ]; do
  case "$1" in
    --dbcode) DBCODE="${2:-}"; shift 2;;
    --jdbcUrl) JDBC_URL="${2:-}"; shift 2;;
    --username) USERNAME="${2:-}"; shift 2;;
    --password) PASSWORD="${2:-}"; shift 2;;
    --table) TABLE="${2:-}"; shift 2;;
    --schema) SCHEMA="${2:-}"; shift 2;;
    --out) shift 2;;
    -h|--help) usage; exit 0;;
    *) pf "Unknown arg: %s\n" "$1"; usage; exit 1;;
  esac
done

[ -n "$DBCODE" ] && [ -n "$JDBC_URL" ] && [ -n "$USERNAME" ] && [ -n "$TABLE" ] || { usage; exit 1; }

now_epoch(){ date +%s; }

sha256(){
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
  else
    echo ""
  fi
}

json_escape(){
  # JSON string escape (minimal): backslash, quote, newline
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n//g'
}

ensure_cache(){
  mkdir -p "$CACHE_DIR" 2>/dev/null || true
  chmod 700 "$CACHE_DIR" 2>/dev/null || true
}

cache_get(){
  local key="$1"
  local jf="$CACHE_DIR/$key.json" tf="$CACHE_DIR/$key.ts"
  [ -f "$jf" ] && [ -f "$tf" ] || return 1
  local ts now age
  ts="$(cat "$tf" 2>/dev/null || echo 0)"
  now="$(now_epoch)"
  age=$((now - ts))
  [ $age -le $CACHE_TTL_SEC ] || return 1
  cat "$jf"
}

cache_put(){
  local key="$1" json="$2"
  [ -n "$key" ] || return 0
  ensure_cache
  printf '%s' "$json" >"$CACHE_DIR/$key.json" 2>/dev/null || return 0
  printf '%s' "$(now_epoch)" >"$CACHE_DIR/$key.ts" 2>/dev/null || return 0
  chmod 600 "$CACHE_DIR/$key.json" "$CACHE_DIR/$key.ts" 2>/dev/null || true
}

emit_json(){
  local cols_file="$1" pk_file="$2"
  local cols_json="" pk_json="" line first

  first=1
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [ $first -eq 1 ]; then
      cols_json="\"$(json_escape "$line")\""; first=0
    else
      cols_json="${cols_json},\"$(json_escape "$line")\""
    fi
  done <"$cols_file"

  first=1
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    if [ $first -eq 1 ]; then
      pk_json="\"$(json_escape "$line")\""; first=0
    else
      pk_json="${pk_json},\"$(json_escape "$line")\""
    fi
  done <"$pk_file"

  pf '{"tables":["%s"],"columns":[%s],"pkCandidates":[%s]}\n' "$(json_escape "$TABLE")" "$cols_json" "$pk_json"
}

HOST="" PORT="" DBNAME="" SERVICE=""

parse_jdbc(){
  case "$DBCODE" in
    p)
      if [[ "$JDBC_URL" =~ ^jdbc:postgresql://([^:/]+):?([0-9]*)/([^?]+) ]]; then
        HOST="${BASH_REMATCH[1]}"; PORT="${BASH_REMATCH[2]:-5432}"; DBNAME="${BASH_REMATCH[3]}"
      else
        return 1
      fi
      ;;
    m)
      if [[ "$JDBC_URL" =~ ^jdbc:mysql://([^:/]+):?([0-9]*)/([^?]+) ]]; then
        HOST="${BASH_REMATCH[1]}"; PORT="${BASH_REMATCH[2]:-3306}"; DBNAME="${BASH_REMATCH[3]}"
      else
        return 1
      fi
      ;;
    o|t)
      if [[ "$JDBC_URL" =~ ^jdbc:oracle:thin:@//([^:/]+):([0-9]+)/(.+)$ ]]; then
        HOST="${BASH_REMATCH[1]}"; PORT="${BASH_REMATCH[2]}"; SERVICE="${BASH_REMATCH[3]}"
      elif [[ "$JDBC_URL" =~ ^jdbc:tibero:thin:@([^:/]+):([0-9]+):(.+)$ ]]; then
        HOST="${BASH_REMATCH[1]}"; PORT="${BASH_REMATCH[2]}"; DBNAME="${BASH_REMATCH[3]}"
      else
        return 1
      fi
      ;;
    *) return 1;;
  esac
  return 0
}

parse_jdbc || exit 2

CACHE_KEY="$(sha256 "${DBCODE}|${JDBC_URL}|${USERNAME}|${SCHEMA}|${TABLE}")"
if [ -n "$CACHE_KEY" ] && cache_get "$CACHE_KEY" >/dev/null 2>&1; then
  cache_get "$CACHE_KEY"
  exit 0
fi

cols_tmp="$(mktemp "${TMPDIR:-/tmp}/tablediff_cols.XXXXXX")" || exit 2
pk_tmp="$(mktemp "${TMPDIR:-/tmp}/tablediff_pks.XXXXXX")" || exit 2
trap 'rm -f "$cols_tmp" "$pk_tmp"' EXIT

norm_file(){
  local f="$1"
  awk '{gsub(/^[ \t]+|[ \t]+$/,""); if(length($0)>0 && !seen[$0]++){print $0}}' "$f" >"$f.norm" && mv "$f.norm" "$f"
}

case "$DBCODE" in
  p)
    command -v psql >/dev/null 2>&1 || exit 2
    where_schema=""
    where_schema2=""
    [ -n "$SCHEMA" ] && where_schema="and table_schema='${SCHEMA}'"
    [ -n "$SCHEMA" ] && where_schema2="and tc.table_schema='${SCHEMA}'"

    PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$DBNAME" -Atc \
      "select column_name from information_schema.columns where table_name='${TABLE}' ${where_schema} order by ordinal_position;" \
      >"$cols_tmp" 2>/dev/null || exit 2

    PGPASSWORD="$PASSWORD" psql -h "$HOST" -p "$PORT" -U "$USERNAME" -d "$DBNAME" -Atc \
      "select kcu.column_name from information_schema.table_constraints tc join information_schema.key_column_usage kcu on tc.constraint_name=kcu.constraint_name and tc.table_schema=kcu.table_schema where tc.constraint_type='PRIMARY KEY' and tc.table_name='${TABLE}' ${where_schema2} order by kcu.ordinal_position;" \
      >"$pk_tmp" 2>/dev/null || true
    ;;
  m)
    command -v mysql >/dev/null 2>&1 || exit 2
    mysql_pass_arg=()
    [ -n "$PASSWORD" ] && mysql_pass_arg=(-p"$PASSWORD")

    mysql --protocol=tcp -h "$HOST" -P "$PORT" -u "$USERNAME" "${mysql_pass_arg[@]}" -N -B "$DBNAME" \
      -e "select column_name from information_schema.columns where table_schema='${DBNAME}' and table_name='${TABLE}' order by ordinal_position;" \
      >"$cols_tmp" 2>/dev/null || exit 2

    mysql --protocol=tcp -h "$HOST" -P "$PORT" -u "$USERNAME" "${mysql_pass_arg[@]}" -N -B "$DBNAME" \
      -e "select column_name from information_schema.key_column_usage where table_schema='${DBNAME}' and table_name='${TABLE}' and constraint_name='PRIMARY' order by ordinal_position;" \
      >"$pk_tmp" 2>/dev/null || true
    ;;
  o|t)
    if ! command -v sqlplus >/dev/null 2>&1; then
      # Fallback: try docker-contained sqlplus (common for Oracle XE in Docker)
      oc="$(find_oracle_container || true)"
      [ -n "$oc" ] || exit 2
      ORACLE_DOCKER_CONTAINER_DETECTED="$oc"
    fi
    owner="${SCHEMA:-$USERNAME}"

    if [ "$DBCODE" = "o" ]; then
      conn="${USERNAME}/${PASSWORD}@//${HOST}:${PORT}/${SERVICE}"
    else
      conn="${USERNAME}/${PASSWORD}@${HOST}:${PORT}:${DBNAME}"
    fi
    if [ -n "${ORACLE_DOCKER_CONTAINER_DETECTED:-}" ]; then
      oracle_query_via_docker_sqlplus "$ORACLE_DOCKER_CONTAINER_DETECTED" "$conn" "select column_name from all_tab_columns where owner = upper('${owner}') and table_name = upper('${TABLE}') order by column_id;" >"$cols_tmp" 2>/dev/null || exit 2
    else
      sqlplus -s "$conn" <<SQL >"$cols_tmp" 2>/dev/null || exit 2
set pages 0 feedback off verify off heading off echo off lines 32767 trimspool on
select column_name
  from all_tab_columns
 where owner = upper('${owner}')
   and table_name = upper('${TABLE}')
 order by column_id;
exit
SQL
    fi


    sqlplus -s "$conn" <<SQL >"$pk_tmp" 2>/dev/null || true
set pages 0 feedback off verify off heading off echo off lines 32767 trimspool on
select acc.column_name
  from all_constraints ac
  join all_cons_columns acc
    on ac.owner = acc.owner
   and ac.constraint_name = acc.constraint_name
 where ac.constraint_type = 'P'
   and ac.owner = upper('${owner}')
   and ac.table_name = upper('${TABLE}')
 order by acc.position;
exit
SQL
    ;;
  *) exit 1;;
esac

norm_file "$cols_tmp"
norm_file "$pk_tmp"
[ -s "$cols_tmp" ] || exit 2

json_out="$(emit_json "$cols_tmp" "$pk_tmp")"
cache_put "$CACHE_KEY" "$json_out"
printf '%s' "$json_out"
exit 0
