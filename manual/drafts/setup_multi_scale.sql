-- 규모별 데이터 생성 함수 정의
CREATE OR REPLACE PROCEDURE generate_diff_data(scale_name TEXT, total_rows INT)
LANGUAGE plpgsql
AS $$
DECLARE
    only_a_end INT := total_rows * 0.1;
    change_end INT := total_rows * 0.2;
    same_end   INT := total_rows * 0.9;
    table_a TEXT := 'diff_' || scale_name || '_a';
    table_b TEXT := 'diff_' || scale_name || '_b';
BEGIN
    -- 테이블 초기화
    EXECUTE 'DROP TABLE IF EXISTS ' || table_a;
    EXECUTE 'DROP TABLE IF EXISTS ' || table_b;
    EXECUTE 'CREATE TABLE ' || table_a || ' (id INT PRIMARY KEY, val DATE, description TEXT)';
    EXECUTE 'CREATE TABLE ' || table_b || ' (id INT PRIMARY KEY, val DATE, description TEXT)';

    -- Only in A (10%)
    EXECUTE 'INSERT INTO ' || table_a || ' SELECT i, ''2026-01-01''::DATE, ''Only in A'' FROM generate_series(1, ' || only_a_end || ') AS s(i)';

    -- Changed (10%)
    EXECUTE 'INSERT INTO ' || table_a || ' SELECT i, ''2026-01-01''::DATE, ''Data Diff'' FROM generate_series(' || (only_a_end + 1) || ', ' || change_end || ') AS s(i)';
    EXECUTE 'INSERT INTO ' || table_b || ' SELECT i, ''2026-01-02''::DATE, ''Data Diff'' FROM generate_series(' || (only_a_end + 1) || ', ' || change_end || ') AS s(i)';

    -- Same (70%)
    EXECUTE 'INSERT INTO ' || table_a || ' SELECT i, ''2026-05-01''::DATE, ''Identical'' FROM generate_series(' || (change_end + 1) || ', ' || same_end || ') AS s(i)';
    EXECUTE 'INSERT INTO ' || table_b || ' SELECT i, ''2026-05-01''::DATE, ''Identical'' FROM generate_series(' || (change_end + 1) || ', ' || same_end || ') AS s(i)';

    -- Only in B (10%)
    EXECUTE 'INSERT INTO ' || table_b || ' SELECT i, ''2026-01-01''::DATE, ''Only in B'' FROM generate_series(' || (same_end + 1) || ', ' || total_rows || ') AS s(i)';

    COMMIT;
END;
$$;

-- 실행부
\echo 'Generating 10K data...'
CALL generate_diff_data('10k', 10000);

\echo 'Generating 100K data...'
CALL generate_diff_data('100k', 100000);

\echo 'Generating 1M data...'
CALL generate_diff_data('1m', 1000000);

\echo 'Generating 10M data...'
CALL generate_diff_data('10m', 10000000);

\echo 'All multi-scale data generated successfully.'
