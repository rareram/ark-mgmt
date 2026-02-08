SET DEFINE OFF;
SET SERVEROUTPUT ON;

DECLARE
    v_table_name VARCHAR2(30) := 'DIVERSE_COLS_100';
    v_exists NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_exists FROM user_tables WHERE table_name = v_table_name;
    IF v_exists > 0 THEN
        EXECUTE IMMEDIATE 'DROP TABLE ' || v_table_name;
        DBMS_OUTPUT.PUT_LINE('Table ' || v_table_name || ' dropped.');
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

DECLARE
    v_blob BLOB;
    v_clob CLOB;
    v_raw  RAW(200);
    v_raw_chunk RAW(100);
BEGIN
    FOR i IN 1..100 LOOP
        -- Prepare dummy BLOB
        DBMS_LOB.CREATETEMPORARY(v_blob, TRUE);
        v_raw_chunk := UTL_RAW.CAST_TO_RAW('BLOBDATA' || i);
        DBMS_LOB.WRITEAPPEND(v_blob, UTL_RAW.LENGTH(v_raw_chunk), v_raw_chunk);
        
        -- Prepare dummy CLOB
        v_clob := 'This is a CLOB text for row ' || i || '. ' || DBMS_RANDOM.STRING('A', 50);

        -- Prepare dummy RAW
        v_raw := UTL_RAW.CAST_TO_RAW('RAW' || i);

        INSERT INTO DIVERSE_COLS_100 VALUES (
            i,                                                  -- pk_id
            'user_' || i,                                       -- username
            'Full Name ' || i,                                  -- full_name
            'user' || i || '@example.com',                      -- email_addr
            '555-01' || LPAD(i, 2, '0'),                        -- phone_num
            LPAD(TRUNC(DBMS_RANDOM.VALUE(10000,99999)), 5, '0'), -- zip_code
            'City_' || i,                                       -- city_name
            'NY',                                               -- state_code
            'USA',                                              -- country_iso
            v_clob,                                             -- bio_text
            v_blob,                                             -- profile_pic
            ROUND(DBMS_RANDOM.VALUE(0, 10000), 2),              -- account_bal
            ROUND(DBMS_RANDOM.VALUE(1000, 50000), 0),           -- credit_limit
            TRUNC(DBMS_RANDOM.VALUE(0, 5000)),                  -- loyalty_pts
            SYSDATE - DBMS_RANDOM.VALUE(0, 1000),               -- signup_date
            SYSTIMESTAMP - DBMS_RANDOM.VALUE(0, 10),            -- last_login
            SYSTIMESTAMP + DBMS_RANDOM.VALUE(0, 30),            -- next_review
            NUMTODSINTERVAL(DBMS_RANDOM.VALUE(0, 86400), 'SECOND'), -- session_dur
            NUMTOYMINTERVAL(TRUNC(DBMS_RANDOM.VALUE(1, 5)), 'YEAR'), -- contract_pd
            CASE WHEN DBMS_RANDOM.VALUE > 0.5 THEN 'Y' ELSE 'N' END, -- is_verified
            CASE WHEN DBMS_RANDOM.VALUE > 0.5 THEN 'M' ELSE 'F' END, -- gender_code
            'Single',                                           -- marital_stat
            'Blue',                                             -- pref_color
            ROUND(DBMS_RANDOM.VALUE(150, 200), 1),              -- height_cm
            ROUND(DBMS_RANDOM.VALUE(50, 120), 1),               -- weight_kg
            36.5 + DBMS_RANDOM.VALUE(0, 2),                     -- body_temp
            18.5 + DBMS_RANDOM.VALUE(0, 15),                    -- bmi_index
            TRUNC(DBMS_RANDOM.VALUE(80, 150)),                  -- iq_score
            TRUNC(DBMS_RANDOM.VALUE(0, 100)),                   -- fav_number
            '7',                                                -- lucky_char
            HEXTORAW('FF00' || LPAD(TO_CHAR(i,'FMXX'),2,'0')),  -- secret_code
            '192.168.1.' || i,                                  -- ipv4_addr
            '00:1A:2B:3C:4D:' || LPAD(TO_CHAR(i,'FMXX'),2,'0'), -- mac_addr
            37.0 + DBMS_RANDOM.VALUE(-10, 10),                  -- latitude
            -122.0 + DBMS_RANDOM.VALUE(-10, 10),                -- longitude
            DBMS_RANDOM.VALUE(0, 5000),                         -- altitude_m
            1013.25 + DBMS_RANDOM.VALUE(-50, 50),               -- pressure_hpa
            TRUNC(DBMS_RANDOM.VALUE(0, 100)),                   -- humidity_pct
            ROUND(DBMS_RANDOM.VALUE(0, 100), 2),                -- wind_speed
            'NW',                                               -- wind_dir
            'Developer',                                        -- job_title
            'IT',                                               -- dept_name
            100,                                                -- manager_id
            SYSDATE - DBMS_RANDOM.VALUE(0, 365*5),              -- hire_date
            ROUND(DBMS_RANDOM.VALUE(20, 100), 2),               -- hourly_rate
            ROUND(DBMS_RANDOM.VALUE(0, 10000), 2),              -- bonus_amt
            ROUND(DBMS_RANDOM.VALUE(0, 0.3), 2),                -- comm_pct
            TRUNC(DBMS_RANDOM.VALUE(0, 10000)),                 -- stock_opts
            TRUNC(DBMS_RANDOM.VALUE(1, 6)),                     -- rating_perf
            'Performance review text ' || i,                    -- comments_perf
            v_blob,                                             -- file_data
            v_raw,                                              -- thumb_img
            '<config><id>' || i || '</id></config>',            -- xml_config
            '{"id": ' || i || '}',                              -- json_props
            'tag1,tag2,tag3',                                   -- tag_list
            TRUNC(DBMS_RANDOM.VALUE(1, 10)),                    -- category_id
            'SKU-' || LPAD(i, 5, '0'),                          -- prod_sku
            LPAD(i, 13, '0'),                                   -- ean_code
            LPAD(i, 12, '0'),                                   -- upc_code
            TRUNC(DBMS_RANDOM.VALUE(0, 1000)),                  -- qty_stock
            10,                                                 -- min_stock
            1000,                                               -- max_stock
            50,                                                 -- reorder_pt
            ROUND(DBMS_RANDOM.VALUE(10, 1000), 4),              -- cost_price
            ROUND(DBMS_RANDOM.VALUE(20, 2000), 4),              -- sell_price
            ROUND(DBMS_RANDOM.VALUE(0, 50), 1),                 -- discount_rt
            'A',                                                -- tax_group
            SYSDATE,                                            -- promo_start
            SYSDATE + 7,                                        -- promo_end
            'N'                                                 -- is_deleted
        );
        DBMS_LOB.FREETEMPORARY(v_blob);
    END LOOP;
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('100 rows inserted into DIVERSE_COLS_100.');
END;
/
EXIT;
