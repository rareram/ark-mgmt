# Oracle 데이터베이스 및 사용자 생성

Oracle DB 설치가 완료되었으면, `TableDiff` 테스트에 사용할 사용자(스키마)와 테이블을 생성합니다. Oracle은 PostgreSQL과 달리 데이터베이스와 사용자(스키마)가 더 강하게 연관되어 있으므로, 전용 사용자를 만드는 것이 일반적입니다.

## 1. 데이터베이스 접속

`sqlplus`를 사용하여 `system` 관리자 계정으로 접속합니다.

```bash
# Docker 환경에서 접속하는 경우
docker exec -it oracle-xe sqlplus system/your_strong_password

# Windows 환경인 경우, 시작 메뉴에서 SQL*Plus를 실행하고
# 사용자 이름에 'system', 비밀번호에 설치 시 지정한 암호를 입력합니다.
```

`your_strong_password` 부분은 `oracle-install.md` 가이드에서 설정한 관리자 비밀번호로 변경해야 합니다.

## 2. 테스트용 사용자 생성

`cdctest`라는 이름의 테스트용 사용자를 생성하고 필요한 권한을 부여합니다.

```sql
-- PDB에 세션을 연결합니다. XE의 기본 PDB는 XEPDB1입니다.
ALTER SESSION SET CONTAINER = XEPDB1;

-- 사용자 생성
CREATE USER cdctest IDENTIFIED BY cdctest
DEFAULT TABLESPACE users
TEMPORARY TABLESPACE temp;

-- 사용자에게 권한 부여
GRANT CONNECT, RESOURCE TO cdctest;
GRANT UNLIMITED TABLESPACE TO cdctest;
```

!!! tip "CDB와 PDB"
    Oracle 12c부터 도입된 멀티테넌트 아키텍처에서는 하나의 컨테이너 데이터베이스(CDB) 안에 여러 개의 플러거블 데이터베이스(PDB)가 존재할 수 있습니다. 사용자와 데이터는 보통 PDB 안에 생성합니다. Oracle XE 21c의 기본 PDB 이름은 `XEPDB1`입니다.

## 3. 생성한 사용자로 재접속

`exit` 명령어로 `system` 계정 접속을 종료하고, 새로 만든 `cdctest` 사용자로 다시 접속합니다.

```sql
-- system 계정 접속 종료
exit

-- cdctest 사용자로 접속
sqlplus cdctest/cdctest@//localhost:1521/XEPDB1
```

이제 프롬프트에 `SQL>` 가 표시되며, `cdctest` 사용자로 로그인된 상태입니다.

## 4. 샘플 테이블 생성

`TableDiff` 기능 테스트에 사용할 `TB_DIFF_SAMPLE` 테이블을 생성합니다.

```sql
CREATE TABLE TB_DIFF_SAMPLE (
    S_KEY1 VARCHAR2(10),
    S_KEY2 NUMBER(5),
    S_KEY3 DATE,
    C_VAL1 VARCHAR2(100),
    C_VAL2 NUMBER(10, 2),
    PRIMARY KEY (S_KEY1, S_KEY2, S_KEY3)
);
```

테이블이 잘 생성되었는지 확인하려면 아래 쿼리를 실행합니다.

```sql
SELECT table_name FROM user_tables WHERE table_name = 'TB_DIFF_SAMPLE';
```
`TB_DIFF_SAMPLE`이 출력되면 성공입니다.
