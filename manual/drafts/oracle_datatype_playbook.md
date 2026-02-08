# Oracle Data Type Support & Fetch Test Playbook

This document is a hands-on guide for engineers to verify `TableDiff`'s support for various Oracle data types. It covers creating a test table with diverse column types, fetching its schema, and configuring the tool for comparison.

## 1. Setup Overview

- **Target Host**: `192.168.0.78` (or `localhost` if running on the host machine)
- **Port**: `1521`
- **Service Name (SID)**: `XEPDB1`
- **Username**: `cdctest`
- **Password**: `cdctest`
- **Test Table**: `DIVERSE_COLS_100` (Contains ~70 columns of various types)

---

## 2. Table Creation

We use the following SQL script (`setup_diverse_columns.sql`) to create a table with approximately 70 columns covering most standard Oracle data types (NUMBER, VARCHAR2, DATE, TIMESTAMP, CLOB, BLOB, RAW, INTERVAL, etc.) and populate it with 100 rows of random data.

```sql
-- setup_diverse_columns.sql
DECLARE
    v_table_name VARCHAR2(30) := 'DIVERSE_COLS_100';
    v_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_exists FROM user_tables WHERE table_name = v_table_name;
    IF v_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE ' || v_table_name;
    END IF;
END;
/

CREATE TABLE DIVERSE_COLS_100 (
    pk_id           NUMBER PRIMARY KEY,
    -- Person Info
    username        VARCHAR2(50),
    full_name       NVARCHAR2(100),
    email_addr      VARCHAR2(100),
    phone_num       VARCHAR2(20),
    zip_code        CHAR(10),
    city_name       VARCHAR2(50),
    state_code      CHAR(2),
    country_iso     CHAR(3),
    -- Large Text/Binary
    bio_text        CLOB,
    profile_pic     BLOB,
    -- Financial
    account_bal     NUMBER(12,2),
    credit_limit    NUMBER(12,2),
    loyalty_pts     INTEGER,
    -- Dates & Times
    signup_date     DATE,
    last_login      TIMESTAMP,
    next_review     TIMESTAMP WITH TIME ZONE,
    session_dur     INTERVAL DAY TO SECOND,
    contract_pd     INTERVAL YEAR TO MONTH,
    -- Flags/Codes
    is_verified     CHAR(1),
    gender_code     CHAR(1),
    marital_stat    VARCHAR2(10),
    pref_color      VARCHAR2(20),
    -- Biometrics/Metrics (Floats)
    height_cm       NUMBER(5,1),
    weight_kg       NUMBER(5,1),
    body_temp       BINARY_FLOAT,
    bmi_index       BINARY_DOUBLE,
    iq_score        NUMBER(3),
    fav_number      NUMBER,
    -- Misc Types
    lucky_char      NCHAR(1),
    secret_code     RAW(16),
    ipv4_addr       VARCHAR2(15),
    mac_addr        VARCHAR2(17),
    -- Geo
    latitude        NUMBER(8,6),
    longitude       NUMBER(9,6),
    altitude_m      FLOAT,
    pressure_hpa    FLOAT,
    humidity_pct    NUMBER(3),
    -- Weather/Env
    wind_speed      NUMBER(5,2),
    wind_dir        VARCHAR2(3),
    -- Employment
    job_title       VARCHAR2(50),
    dept_name       VARCHAR2(50),
    manager_id      NUMBER,
    hire_date       DATE,
    hourly_rate     NUMBER(6,2),
    bonus_amt       NUMBER(8,2),
    comm_pct        NUMBER(2,2),
    stock_opts      INTEGER,
    rating_perf     NUMBER(1),
    comments_perf   CLOB,
    -- Files/Media
    file_data       BLOB,
    thumb_img       RAW(200),
    -- Configs (Text as JSON/XML)
    xml_config      CLOB,
    json_props      CLOB,
    tag_list        VARCHAR2(200),
    -- Inventory/Product
    category_id     NUMBER(4),
    prod_sku        VARCHAR2(20),
    ean_code        VARCHAR2(13),
    upc_code        VARCHAR2(12),
    qty_stock       INTEGER,
    min_stock       INTEGER,
    max_stock       INTEGER,
    reorder_pt      INTEGER,
    cost_price      NUMBER(10,4),
    sell_price      NUMBER(10,4),
    discount_rt     NUMBER(3,1),
    tax_group       CHAR(1),
    promo_start     DATE,
    promo_end       DATE,
    is_deleted      CHAR(1)
);
-- (Insert logic omitted for brevity, see actual file for PL/SQL block)
```

**To execute this setup:**
```bash
# If running from the host machine with Docker available:

docker exec -i orcl_21c_src sqlplus -L -s cdctest/cdctest@//localhost:1521/XEPDB1 < setup_diverse_columns.sql
```

---

## 3. Schema Fetching Test

Use the `sch_tablediff_0.6.3.sh` script to verify that the tool can correctly identify all columns and the primary key.

### Command
```bash
# Export the container name if running locally via Docker
export ORACLE_DOCKER_CONTAINER=orcl_21c_src

./sch_tablediff_0.6.3.sh \
  --dbcode o \
  --jdbcUrl jdbc:oracle:thin:@//192.168.0.78:1521/XEPDB1 \
  --username cdctest \
  --password cdctest \
  --table DIVERSE_COLS_100
```

*Note: If testing from a different machine, ensure `192.168.0.78` is reachable and the JDBC URL is updated accordingly.*

### Expected Output
The output should be a JSON object listing the table name, all ~70 columns in order, and the primary key (`PK_ID`).

```json
{"tables":["DIVERSE_COLS_100"],"columns":["PK_ID","USERNAME","FULL_NAME", ... "IS_DELETED"],"pkCandidates":["PK_ID"]}
```

---

## 4. Configuration for `gen_` Script

To generate a full comparison configuration using the `gen_` script, use the following connection details. This setup assumes you are fetching the schema from the source DB (`o` for Oracle) to build the `tablediff.conf`.

**Connection Parameters:**
- **DB Code**: `o`
- **JDBC URL**: `jdbc:oracle:thin:@//192.168.0.78:1521/XEPDB1`
- **Username**: `cdctest`
- **Password**: `cdctest`
- **Table**: `DIVERSE_COLS_100`

### Example `gen_` Command
```bash
./gen_tablediffconf_0.6.3.sh \
  --src-dbcode o \
  --src-url "jdbc:oracle:thin:@//192.168.0.78:1521/XEPDB1" \
  --src-user cdctest \
  --src-pass cdctest \
  --src-table DIVERSE_COLS_100 \
  --dst-dbcode o \
  --dst-url "jdbc:oracle:thin:@//192.168.0.78:1522/XEPDB1" \
  --dst-user cdctest \
  --dst-pass cdctest \
  --dst-table DIVERSE_COLS_100 \
  --out diverse_cols_test.conf
```
