# 데이터베이스 및 테이블 생성

PostgreSQL 설치가 완료되었으면, `pgcdc` 테스트에 사용할 데이터베이스와 테이블을 생성합니다.

## 1. 데이터베이스 접속

사용 중인 터미널이나 `SQL Shell`을 열어 PostgreSQL에 접속합니다.

```bash
# macOS 또는 Ubuntu
psql -d postgres

# Windows에서는 시작 메뉴의 'SQL Shell (psql)'을 사용하세요.
```

## 2. 데이터베이스 생성

`pgcdc_dev`라는 이름의 개발용 데이터베이스를 생성합니다.

```sql
CREATE DATABASE pgcdc_dev;
```

## 3. 생성한 데이터베이스에 접속

`\c` 명령어를 사용하여 새로 생성한 `pgcdc_dev` 데이터베이스로 이동합니다.

```sql
\c pgcdc_dev;
```

이제 프롬프트가 `pgcdc_dev=>` 와 같이 변경됩니다.

## 4. 샘플 테이블 생성

CDC 테스트를 위해 간단한 `products` 테이블을 생성합니다.

```sql
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

테이블이 잘 생성되었는지 확인하려면 `\dt` 명령어를 사용합니다.

```
pgcdc_dev=> \dt
          List of relations
 Schema |  Name   | Type  |  Owner
--------+---------+-------+----------
 public | products | table | your_user
(1 row)
```
