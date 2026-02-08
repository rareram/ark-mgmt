# PostgreSQL 구성 (compose)

TableDiff 및 CDC 기능 테스트를 위해 다양한 버전(11, 14, 15, 16)의 PostgreSQL 환경을 Docker Compose로 구성하는 방법을 설명합니다.

---

## 구성 개요

제공되는 `compose.yml` 파일은 다음과 같은 구성을 포함합니다.

* **다중 버전 지원**: PostgreSQL 11, 14, 15, 16 버전을 동시에 실행합니다.
* **Source / Target 분리**: 각 버전별로 Source(`src`)와 Target(`dst`) DB 컨테이너를 쌍으로 구성하여 복제 및 비교 테스트에 최적화되어 있습니다.
* **CDC 설정 적용**: `wal_level=logical` 등 CDC(Logical Replication)에 필요한 설정이 미리 적용되어 있습니다.
* **모니터링**: `postgres-exporter`가 각 인스턴스에 사이드카로 배치되어 프로메테우스 연동이 가능합니다.

---

## 포트 정보

| 버전 | Source (src) Port | Target (dst) Port |
| :--- | :--- | :--- |
| **PG 11** | 5411 | 5421 |
| **PG 14** | 5414 | 5424 |
| **PG 15** | 5415 | 5425 |
| **PG 16** | 5416 | 5426 |

---

## 접속 정보

* **Database**: `cdc`
* **User**: `postgres`
* **Password**: `postgres`

---

## 디렉토리 구조 및 볼륨

데이터 영속성을 위해 호스트 경로를 볼륨으로 마운트합니다.

```text
/opt/docker-compose/postgres/
├── compose.yml
├── common-init/          # 초기화 스크립트 (모든 컨테이너 공통)
├── pg11_src/data/
├── pg11_dst/data/
├── pg14_src/data/
├── pg14_dst/data/
...
```

---

## compose.yml 파일

```yaml
name: pg-cdc-lab

networks:
  pgnet:
    driver: bridge

x-pg-common: &pg-common
  restart: unless-stopped
  environment:
    POSTGRES_USER: postgres
    POSTGRES_PASSWORD: postgres
    POSTGRES_DB: cdc
  networks:
    - pgnet
  command:
    - postgres
    - -c
    - wal_level=logical
    - -c
    - max_replication_slots=20
    - -c
    - max_wal_senders=20
    # desktop-friendly tuning (기능 테스트 목적)
    - -c
    - max_connections=100
    - -c
    - shared_buffers=128MB
    - -c
    - work_mem=4MB
    - -c
    - maintenance_work_mem=64MB
    - -c
    - max_wal_size=512MB
    - -c
    - checkpoint_timeout=15min
    - -c
    - log_min_duration_statement=2000

x-exp-common: &exp-common
  image: prometheuscommunity/postgres-exporter:latest
  restart: unless-stopped
  networks:
    - pgnet

services:
  # =========================
  # PostgreSQL 11 (src/dst)
  # =========================
  pg11_src:
    <<: *pg-common
    image: postgres:11
    container_name: pg11_src
    ports:
      - "5411:5432"
    volumes:
      - /opt/docker-compose/postgres/pg11_src/data:/var/lib/postgresql/data
      - /opt/docker-compose/postgres/common-init:/docker-entrypoint-initdb.d:ro

  pg11_dst:
    <<: *pg-common
    image: postgres:11
    container_name: pg11_dst
    ports:
      - "5421:5432"
    volumes:
      - /opt/docker-compose/postgres/pg11_dst/data:/var/lib/postgresql/data
      - /opt/docker-compose/postgres/common-init:/docker-entrypoint-initdb.d:ro

  pg11_src_exporter:
    <<: *exp-common
    container_name: pg11_src_exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:postgres@pg11_src:5432/postgres?sslmode=disable"
    ports:
      - "9487:9187"
    depends_on:
      - pg11_src

  pg11_dst_exporter:
    <<: *exp-common
    container_name: pg11_dst_exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:postgres@pg11_dst:5432/postgres?sslmode=disable"
    ports:
      - "9488:9187"
    depends_on:
      - pg11_dst

  # =========================
  # PostgreSQL 14 (src/dst)
  # =========================
  pg14_src:
    <<: *pg-common
    image: postgres:14
    container_name: pg14_src
    ports:
      - "5414:5432"
    volumes:
      - /opt/docker-compose/postgres/pg14_src/data:/var/lib/postgresql/data
      - /opt/docker-compose/postgres/common-init:/docker-entrypoint-initdb.d:ro

  pg14_dst:
    <<: *pg-common
    image: postgres:14
    container_name: pg14_dst
    ports:
      - "5424:5432"
    volumes:
      - /opt/docker-compose/postgres/pg14_dst/data:/var/lib/postgresql/data
      - /opt/docker-compose/postgres/common-init:/docker-entrypoint-initdb.d:ro

  pg14_src_exporter:
    <<: *exp-common
    container_name: pg14_src_exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:postgres@pg14_src:5432/postgres?sslmode=disable"
    ports:
      - "9489:9187"
    depends_on:
      - pg14_src

  pg14_dst_exporter:
    <<: *exp-common
    container_name: pg14_dst_exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:postgres@pg14_dst:5432/postgres?sslmode=disable"
    ports:
      - "9490:9187"
    depends_on:
      - pg14_dst

  # =========================
  # PostgreSQL 15 (src/dst)
  # =========================
  pg15_src:
    <<: *pg-common
    image: postgres:15
    container_name: pg15_src
    ports:
      - "5415:5432"
    volumes:
      - /opt/docker-compose/postgres/pg15_src/data:/var/lib/postgresql/data
      - /opt/docker-compose/postgres/common-init:/docker-entrypoint-initdb.d:ro

  pg15_dst:
    <<: *pg-common
    image: postgres:15
    container_name: pg15_dst
    ports:
      - "5425:5432"
    volumes:
      - /opt/docker-compose/postgres/pg15_dst/data:/var/lib/postgresql/data
      - /opt/docker-compose/postgres/common-init:/docker-entrypoint-initdb.d:ro

  pg15_src_exporter:
    <<: *exp-common
    container_name: pg15_src_exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:postgres@pg15_src:5432/postgres?sslmode=disable"
    ports:
      - "9491:9187"
    depends_on:
      - pg15_src

  pg15_dst_exporter:
    <<: *exp-common
    container_name: pg15_dst_exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:postgres@pg15_dst:5432/postgres?sslmode=disable"
    ports:
      - "9492:9187"
    depends_on:
      - pg15_dst

  # =========================
  # PostgreSQL 16 (src/dst)
  # =========================
  pg16_src:
    <<: *pg-common
    image: postgres:16
    container_name: pg16_src
    ports:
      - "5416:5432"
    volumes:
      - /opt/docker-compose/postgres/pg16_src/data:/var/lib/postgresql/data
      - /opt/docker-compose/postgres/common-init:/docker-entrypoint-initdb.d:ro

  pg16_dst:
    <<: *pg-common
    image: postgres:16
    container_name: pg16_dst
    ports:
      - "5426:5432"
    volumes:
      - /opt/docker-compose/postgres/pg16_dst/data:/var/lib/postgresql/data
      - /opt/docker-compose/postgres/common-init:/docker-entrypoint-initdb.d:ro

  pg16_src_exporter:
    <<: *exp-common
    container_name: pg16_src_exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:postgres@pg16_src:5432/postgres?sslmode=disable"
    ports:
      - "9493:9187"
    depends_on:
      - pg16_src

  pg16_dst_exporter:
    <<: *exp-common
    container_name: pg16_dst_exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://postgres:postgres@pg16_dst:5432/postgres?sslmode=disable"
    ports:
      - "9494:9187"
    depends_on:
      - pg16_dst
```