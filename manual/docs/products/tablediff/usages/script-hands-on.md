# 핸즈온: 스크립트 기반 운영 플레이북

본 문서는 실제 운영 환경과 유사한 시나리오에서 스크립트 3종(`gen_`, `run_`, `chk_`)을 활용하여 데이터 비교 작업을 수행하는 전체 흐름을 다룹니다.

## 1. 사전 준비 (Prerequisites)

실습을 위해 제공된 테스트 서버에 SSH로 접속합니다. Oracle DB와 PostgreSQL이 Docker Container로 구동 중이며, 데이터셋은 용량별(1만 ~ 1,000만 건)과 복잡한 컬럼(70개) 테이블이 준비되어 있습니다.

### 1.1. 서버 접속 정보

*   **Host**: `arkdata.iptime.org`
*   **Port**: `2222`
*   **User**: `user1` ~ `user5`
*   **Password**: *[교육 진행 시 별도 안내]*

```bash
# SSH 접속
ssh -p 2222 paul@arkdata.iptime.org

# 작업 디렉토리 이동
cd ~/TableDiff/
ls -F
# 확인: TableDiff_0.6.3.jar, gen_*.sh, run_*.sh, chk_*.sh, sch_*.sh 등
```

### 1.2. 실행 중인 컨테이너 및 데이터 확인

현재 서버에는 Oracle 및 PostgreSQL DB가 실행 중입니다.

```bash
# 실행 중인 컨테이너 확인
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

---

## 2. [Step 1] 설정 파일 생성 (gen_script)

`gen_tablediffconf_0.6.3.sh`를 실행하여 비교 설정을 생성합니다.

### 2.1. 기본 시나리오: 표준 테이블 (대용량)

가장 일반적인 형태의 테이블(`id`, `val`, `description`)을 대상으로 설정을 생성합니다. 이 테이블(`diff_test_large_A/B`)은 약 1,000만 건의 데이터를 포함하고 있습니다.

```bash
./gen_tablediffconf_0.6.3.sh
```

**입력 가이드:**

1.  **Source DB Connection**
    *   **DB Type**: `PostgreSQL` 선택
    *   **JDBC URL**: `jdbc:postgresql://localhost:5432/postgres`
    *   **User/Pass**: `postgres` / `postgres`
2.  **Target DB Connection**
    *   *(Source와 동일하게 입력)*
3.  **Table Info**
    *   **Source Table**: `diff_test_large_A`
    *   **Target Table**: `diff_test_large_B`
    *   **Columns**: `id, val, description` (직접 입력)
    *   **PK Columns**: `id`
4.  **Naming Convention (중요)**
    *   스크립트는 설정 파일명을 **직관적**으로 생성하기 위해 다양한 옵션을 제공합니다.
    *   `3) Table Name`을 선택하여 테이블명을 파일명에 포함시키거나, `4) Custom`을 선택하여 `large_10m_test`와 같이 식별하기 쉬운 이름을 지정합니다.
    *   **추천**: `large_10m_test`

### 2.2. [심화] 복잡한 스키마 처리 (sch_script 활용)

만약 `DIVERSE_COLS_100` 테이블(컬럼 70개 이상)과 같이 수동 입력이 불가능에 가까운 경우, **[보조 도구] 스키마 조회 스크립트**를 활용하여 컬럼 정보를 가져옵니다.

!!! tip "접근 제어 확인"
    이 방법은 **DB 원격 접속이 허용된 환경**에서만 사용 가능합니다. 보안상 접속이 제한된다면 DBA에게 스키마 정보를 별도로 요청해야 합니다.

1.  **스키마 조회 실행**:
    ```bash
    ./sch_tablediff_0.6.3.sh \
      --dbcode o \
      --jdbcUrl jdbc:oracle:thin:@//localhost:1521/XEPDB1 \
      --username cdctest --password cdctest \
      --table DIVERSE_COLS_100
    ```
2.  **결과 적용**:
    *   출력된 JSON의 `"columns"` 내용을 복사합니다.
    *   `gen_` 스크립트 실행 중 **Columns** 입력 단계에서 복사한 내용을 붙여넣습니다.
    *   파일명은 `diverse_cols_test` 등으로 지정하여 생성합니다.

---

## 3. [Step 2] 비교 작업 수행 (run_script)

생성된 설정 파일(`large_10m_test.conf` 등)을 사용하여 비교를 수행합니다.

### 3.1. 스크립트 실행 및 옵션 선택

```bash
./run_tablediff_0.6.3.sh
```

1.  **Select Mode**: `1) Compare Mode`
2.  **Select Config**: `large_10m_test.conf` (1,000만 건 테이블) 선택
3.  **Execution**:
    *   스크립트가 시스템 메모리를 감지하여 **Heap Size**를 자동으로 최적화(Total RAM의 60%)합니다.
    *   대용량 처리를 위한 `Batch Size` 등이 설정에 반영되어 고속 비교가 진행됩니다.

### 3.2. 로그 모니터링

```text
[INFO] TableDiff - Starting comparison for diff_test_large_A vs diff_test_large_B...
[INFO] TableDiff - Fetching rows... (Progress: 1,000,000 / 10,000,000)
...
[INFO] TableDiff - Job finished.
```

---

## 4. [Step 3] 결과 검증 및 리포트 (chk_script)

작업 완료 후 결과를 분석합니다.

```bash
./chk_tablediff_0.6.3.sh
```

### 4.1. 결과 리포트 해석

*   **Status**: `DIFF` (시나리오상 100만 건씩 차이가 존재함)
*   **Summary**:
    *   `Source Only`: 1,000,000 (A에만 존재)
    *   `Target Only`: 1,000,000 (B에만 존재)
    *   `Different`: 1,000,000 (데이터 불일치)
    *   `Match`: 7,000,000 (일치)

이처럼 `chk_` 스크립트를 사용하면 대용량 JSON 결과 파일을 직접 열어보지 않아도, **데이터 정합성 상태와 불일치 규모**를 즉시 파악할 수 있어 현장 엔지니어의 의사결정을 돕습니다.
