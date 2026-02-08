# OracleDB 구성 (compose)

TableDiff 및 CDC 기능 테스트를 위해 Oracle Database 환경을 Docker Compose로 구성하는 방법을 설명합니다.

---

## 연결 정보

`TableDiff`의 설정 파일(`tablediff.conf`) 작성 시 아래 정보를 참고하여 `jdbcUrl`을 구성합니다.

### 1. 포트 및 JDBC URL

| DB 버전 | 구분 | 호스트 포트 | PDB 이름 | JDBC URL (예시) |
| :--- | :--- | :--- | :--- | :--- |
| **21c** | Source | `1921` | `XEPDB1` | `jdbc:oracle:thin:@//localhost:1921/XEPDB1` |
| **21c** | Target | `1922` | `XEPDB1` | `jdbc:oracle:thin:@//localhost:1922/XEPDB1` |
| **23ai** | Source | `2321` | `FREEPDB1` | `jdbc:oracle:thin:@//localhost:2321/FREEPDB1` |
| **23ai**| Target | `2322` | `FREEPDB1` | `jdbc:oracle:thin:@//localhost:2322/FREEPDB1` |

### 2. 접속 계정
* **사용자(User)**: `cdctest`
* **비밀번호(Password)**: `cdctest`

> **참고**: 이 계정 정보는 `compose.yml` 파일의 `environment` 섹션에 `APP_USER` 및 `APP_USER_PASSWORD`로 정의되어 있습니다.

---

## 빠른 시작 (Setup)

1. **디렉토리 구조 생성**
   `compose.yml` 파일이 위치할 디렉토리에 아래 구조를 생성합니다.
   ```text
   .
   ├── compose.yml
   ├── 21c/
   │   ├── src-init/
   │   └── dst-init/
   ├── 23ai/
   │   ├── src-init/
   │   └── dst-init/
   └── volumes/
   ```

2. **컨테이너 실행**
   ```bash
   docker compose up -d
   ```
   * 데이터베이스가 완전히 시작되어 Health Check를 통과하기까지 약 2~5분 정도 소요될 수 있습니다.

---

## compose.yml 파일

아래 내용을 복사하여 `compose.yml` 파일로 저장합니다.

```yaml
# compose.yml
services:
  # ============ 21c (19c 대체) - SOURCE ============
  orcl_21c_src:
    image: gvenzl/oracle-xe:21-slim
    container_name: orcl_21c_src
    hostname: orcl21src
    restart: unless-stopped
    environment:
      ORACLE_PASSWORD: cdctest
      APP_USER: cdctest
      APP_USER_PASSWORD: cdctest
    ports:
      - "1921:1521" # 21c 소스 DB 포트
    volumes:
      - ./21c/src-init:/container-entrypoint-initdb.d
      - ./volumes/21c-src-data:/opt/oracle/oradata
    healthcheck:
      test: ["CMD", "healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 120s
    networks: [oracle-net]

  # ============ 21c (19c 대체) - DESTINATION ============
  orcl_21c_dst:
    image: gvenzl/oracle-xe:21-slim
    container_name: orcl_21c_dst
    hostname: orcl21dst
    restart: unless-stopped
    environment:
      ORACLE_PASSWORD: cdctest
      APP_USER: cdctest
      APP_USER_PASSWORD: cdctest
    ports:
      - "1922:1521" # 21c 목적지 DB 포트
    volumes:
      - ./21c/dst-init:/container-entrypoint-initdb.d
      - ./volumes/21c-dst-data:/opt/oracle/oradata
    healthcheck:
      test: ["CMD", "healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 120s
    networks: [oracle-net]

  # ============ 23ai Free - SOURCE ============
  orcl_23ai_src:
    image: gvenzl/oracle-free:latest
    container_name: orcl_23ai_src
    hostname: orcl23src
    restart: unless-stopped
    environment:
      ORACLE_PASSWORD: cdctest
      APP_USER: cdctest
      APP_USER_PASSWORD: cdctest
    ports:
      - "2321:1521" # 23ai 소스 DB 포트
    volumes:
      - ./23ai/src-init:/container-entrypoint-initdb.d
      - ./volumes/23ai-src-data:/opt/oracle/oradata
    healthcheck:
      test: ["CMD", "healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 120s
    networks: [oracle-net]

  # ============ 23ai Free - DESTINATION ============
  orcl_23ai_dst:
    image: gvenzl/oracle-free:latest
    container_name: orcl_23ai_dst
    hostname: orcl23dst
    restart: unless-stopped
    environment:
      ORACLE_PASSWORD: cdctest
      APP_USER: cdctest
      APP_USER_PASSWORD: cdctest
    ports:
      - "2322:1521" # 23ai 목적지 DB 포트
    volumes:
      - ./23ai/dst-init:/container-entrypoint-initdb.d
      - ./volumes/23ai-dst-data:/opt/oracle/oradata
    healthcheck:
      test: ["CMD", "healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 10
      start_period: 120s
    networks: [oracle-net]

networks:
  oracle-net:
    driver: bridge
```