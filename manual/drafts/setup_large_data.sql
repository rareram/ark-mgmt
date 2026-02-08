-- 1. 기존 테이블 삭제 (초기화)
DROP TABLE IF EXISTS diff_test_large_A;
DROP TABLE IF EXISTS diff_test_large_B;

-- 2. 테이블 생성
CREATE TABLE diff_test_large_A (id INT PRIMARY KEY, val DATE, description TEXT);
CREATE TABLE diff_test_large_B (id INT PRIMARY KEY, val DATE, description TEXT);

-- [시나리오 구성]
\echo 'Inserting: Only in A (1,000,000 rows)...'
INSERT INTO diff_test_large_A SELECT i, '2026-01-01'::DATE, 'Only in A ' || i FROM generate_series(1, 1000000) AS s(i);

\echo 'Inserting: Changed data (1,000,000 rows)...'
INSERT INTO diff_test_large_A SELECT i, '2026-01-01'::DATE, 'Data Diff ' || i FROM generate_series(1000001, 2000000) AS s(i);
INSERT INTO diff_test_large_B SELECT i, '2026-01-02'::DATE, 'Data Diff ' || i FROM generate_series(1000001, 2000000) AS s(i); -- 날짜 다름

\echo 'Inserting: Identical data (7,000,000 rows)...'
INSERT INTO diff_test_large_A SELECT i, '2026-05-01'::DATE, 'Identical ' || i FROM generate_series(2000001, 9000000) AS s(i);
INSERT INTO diff_test_large_B SELECT i, '2026-05-01'::DATE, 'Identical ' || i FROM generate_series(2000001, 9000000) AS s(i);

\echo 'Inserting: Only in B (1,000,000 rows)...'
INSERT INTO diff_test_large_B SELECT i, '2026-01-01'::DATE, 'Only in B ' || i FROM generate_series(9000001, 10000000) AS s(i);

\echo 'Data generation complete.'