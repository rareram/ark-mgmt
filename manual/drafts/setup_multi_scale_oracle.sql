CREATE OR REPLACE PROCEDURE generate_diff_data(p_scale_name IN VARCHAR2, p_total_rows IN NUMBER) 
AUTHID CURRENT_USER
IS
    v_only_a_end NUMBER := p_total_rows * 0.1;
    v_change_end NUMBER := p_total_rows * 0.2;
    v_same_end   NUMBER := p_total_rows * 0.9;
    v_table_a    VARCHAR2(100) := 'diff_' || p_scale_name || '_a';
    v_table_b    VARCHAR2(100) := 'diff_' || p_scale_name || '_b';
    
    -- 배치 처리를 위한 내부 프로시저
    PROCEDURE insert_range(p_table VARCHAR2, p_start_id NUMBER, p_end_id NUMBER, p_val VARCHAR2, p_desc VARCHAR2) IS
        v_batch_size NUMBER := 500000; -- 50만 건씩 처리
        v_curr       NUMBER := p_start_id;
        v_limit      NUMBER;
    BEGIN
        WHILE v_curr <= p_end_id LOOP
            v_limit := LEAST(v_curr + v_batch_size - 1, p_end_id);
            -- DBMS_OUTPUT.PUT_LINE('  Inserting ' || p_table || ' ' || v_curr || ' ~ ' || v_limit);
            
            EXECUTE IMMEDIATE 'INSERT /*+ APPEND */ INTO ' || p_table || 
                              ' SELECT LEVEL + ' || (v_curr - 1) || ', TO_DATE(''' || p_val || ''', ''YYYY-MM-DD''), ''' || p_desc || ''' FROM DUAL CONNECT BY LEVEL <= ' || (v_limit - v_curr + 1);
            COMMIT;
            v_curr := v_limit + 1;
        END LOOP;
    END;

BEGIN
    -- Drop tables
    BEGIN EXECUTE IMMEDIATE 'DROP TABLE ' || v_table_a; EXCEPTION WHEN OTHERS THEN NULL; END;
    BEGIN EXECUTE IMMEDIATE 'DROP TABLE ' || v_table_b; EXCEPTION WHEN OTHERS THEN NULL; END;

    -- Create tables (No PK initially for performance)
    EXECUTE IMMEDIATE 'CREATE TABLE ' || v_table_a || ' (id NUMBER, val DATE, description VARCHAR2(100))';
    EXECUTE IMMEDIATE 'CREATE TABLE ' || v_table_b || ' (id NUMBER, val DATE, description VARCHAR2(100))';

    DBMS_OUTPUT.PUT_LINE('  - Table Created (No PK): ' || v_table_a || ', ' || v_table_b);

    -- 1. Only in A (10%)
    insert_range(v_table_a, 1, v_only_a_end, '2026-01-01', 'Only in A');

    -- 2. Changed (10%)
    insert_range(v_table_a, v_only_a_end + 1, v_change_end, '2026-01-01', 'Data Diff');
    insert_range(v_table_b, v_only_a_end + 1, v_change_end, '2026-01-02', 'Data Diff');

    -- 3. Same (70%)
    insert_range(v_table_a, v_change_end + 1, v_same_end, '2026-05-01', 'Identical');
    insert_range(v_table_b, v_change_end + 1, v_same_end, '2026-05-01', 'Identical');

    -- 4. Only in B (10%)
    insert_range(v_table_b, v_same_end + 1, p_total_rows, '2026-01-01', 'Only in B');
    
    -- Create PKs after insertion
    DBMS_OUTPUT.PUT_LINE('  - Building Primary Keys...');
    EXECUTE IMMEDIATE 'ALTER TABLE ' || v_table_a || ' ADD CONSTRAINT pk_' || v_table_a || ' PRIMARY KEY (id)';
    EXECUTE IMMEDIATE 'ALTER TABLE ' || v_table_b || ' ADD CONSTRAINT pk_' || v_table_b || ' PRIMARY KEY (id)';

    DBMS_OUTPUT.PUT_LINE('  - Data Generation Complete for ' || p_scale_name);
END;
/

SET SERVEROUTPUT ON;
BEGIN
    -- DBMS_OUTPUT.PUT_LINE('Generating 10K data...');
    -- generate_diff_data('10k', 10000);
    
    -- DBMS_OUTPUT.PUT_LINE('Generating 100K data...');
    -- generate_diff_data('100k', 100000);
    
    -- DBMS_OUTPUT.PUT_LINE('Generating 1M data...');
    -- generate_diff_data('1m', 1000000);
    
    DBMS_OUTPUT.PUT_LINE('Generating 10M data...');
    generate_diff_data('10m', 10000000);
END;
/
EXIT;