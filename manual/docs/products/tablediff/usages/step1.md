# 기본 개념과 실행

이 튜토리얼은 TableDiff를 **처음 접하는 사용자가 구조를 이해하고, 직접 실행하며, 실패를 통해 배우는** 과정으로 구성되어 있습니다.

> **원칙**: 도구의 편의 기능에 의존하기 전에, 직접 명령어를 입력하며 동작 원리를 익히는 것이 중요합니다. 따라서 본 튜토리얼은 모든 과정을 **수동 실행(`java -jar`)** 기준으로 설명합니다.

---

## Step 0: 핵심 개념

단순한 `MINUS`나 `EXCEPT` 쿼리로는 수억 건의 데이터 차이를 찾거나, 어떤 컬럼이 변경되었는지 디테일하게 알기 어렵습니다.
TableDiff는 다음 **3가지 핵심 단계**를 통해 이 문제를 해결합니다.

1. **SQL로 뽑는다**: Source(A)와 Target(B) 데이터를 SQL로 조회합니다. (단, **정렬**이 핵심!)
2. **비교한다**: 정렬된 데이터를 스트리밍으로 읽으며 **Key로 매칭**하고, **Value로 비교**합니다.
3. **반영한다**: 결과를 `Change`, `OnlyInA` 등으로 정밀하게 분류하여 DB에 **자동 반영(Apply)**할 수 있게 합니다.

### 왜 "정렬"이 중요한가요?
TableDiff는 수억 건의 데이터도 메모리 문제없이 비교할 수 있는 **스트리밍(Streaming)** 방식을 사용합니다.
이를 위해서는 두 데이터가 **반드시 똑같은 기준(Key)으로 정렬**되어 있어야 합니다. 순서가 어긋나면 비교 자체가 불가능합니다.
---

## Step 1: 가장 작은 "정상 동작" 실행해보기

복잡한 설정은 잠시 잊고, 가장 간단한 설정으로 **일단 돌려보며** 결과를 확인합시다.

### 1. 테스트용 최소 설정 파일 작성 (`quickstart.conf`)
비교 범위를 100건 내외로 작게 잡는 것이 포인트입니다. 텍스트 에디터로 아래 내용을 작성해 저장하세요.

```hocon
TableA {
    driver = "oracle.jdbc.OracleDriver"
    jdbcUrl = "jdbc:oracle:thin:@//localhost:1521/XEPDB1"
    username = "cdctest"
    password = "cdctest"
    
    # 중요: ORDER BY가 반드시 포함되어야 함
    sql = "SELECT ID, NAME, AGE FROM EMP WHERE ID <= 100 ORDER BY ID ASC"
}

TableB {
    driver = "oracle.jdbc.OracleDriver"
    jdbcUrl = "jdbc:oracle:thin:@//localhost:1521/XEPDB1"
    username = "cdctest"
    password = "cdctest"
    
    # 중요: TableA와 동일한 정렬 조건
    sql = "SELECT ID, NAME, AGE FROM EMP_TGT WHERE ID <= 100 ORDER BY ID ASC"
}

compare {
    # 1번째 컬럼(ID)을 기준으로 정렬되어 있음을 명시
    sortKey = [ { colA: 1, colB: 1, ascending: true } ]
    # 2, 3번째 컬럼(NAME, AGE) 값이 같은지 비교
    compCols = [ { colA: 2, colB: 2 }, { colA: 3, colB: 3 } ]
}
```

### 2. 비교 실행 (Compare)
설명서를 읽기 전에 먼저 실행해서 결과 파일(`result.json`)을 만들어 봅니다.

```bash
java -jar TableDiff_0.6.3.jar -c quickstart.conf -o json > result.json
```

### 3. 성공 확인
에러 없이 종료되었다면 성공입니다. 이제 `result.json` 파일이 생성되었는지 확인해 보세요. 이 파일에는 비교 결과가 담겨 있습니다.

> **다음 단계**: 방금 작성한 설정 파일이 구체적으로 어떤 구조로 이루어져 있는지 **[2. 3-Block 설정 구조](./config.md)**에서 알아봅니다.