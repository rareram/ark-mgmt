# 3-Block 설정 구조

TableDiff의 설정 파일(HOCON)은 크게 **3가지 블록**으로 나뉩니다. 각 블록은 도구의 동작 단계와 직결됩니다.

---

## Block 1: 데이터 추출 (TableA / TableB)

**"비교할 두 목록을 어떻게 뽑을 것인가"**를 정의합니다.

```hocon
TableA {
    driver = "..."
    jdbcUrl = "..."
    # ... 접속 정보 ...
    
    sql = """
        SELECT ID, NAME, AGE
        FROM EMP
        ORDER BY ID ASC
    """
}
```

### 핵심 제약 (Failure Point)
실무에서 가장 많이 실수하는 부분입니다. 아래 조건이 맞지 않으면 비교가 불가능하거나 엉뚱한 결과가 나옵니다.

1. **컬럼 개수와 순서 일치**: `SELECT` 절의 컬럼 개수와 순서가 A와 B 양쪽에서 정확히 같아야 합니다.
2. **정렬 조건 완전 일치**: `ORDER BY` 절의 컬럼 순서, `ASC/DESC`, `NULLS FIRST/LAST`까지 완벽하게 동일해야 합니다.
3. **타입 일치**: 비교할 컬럼끼리는 데이터 타입이 호환되어야 합니다. (예: 문자열 "123" vs 숫자 123은 정렬 순서가 다르므로 SQL에서 `CAST`로 맞춰야 합니다.)

> **Tip**: 양쪽 테이블의 컬럼명이 다르다면 `AS` 별칭(Alias)을 사용하여 이름을 통일해 주는 것이 좋습니다. 나중에 로그를 볼 때 훨씬 헷갈리지 않습니다.

---

## Block 2: 비교 로직 (compare)

**"어떻게 줄을 세우고(정렬), 무엇을 같다고 볼 것인가(비교)"**를 정의합니다.

```hocon
compare {
    # 정렬 키 (Key)
    sortKey = [ { colA: 1, colB: 1, ascending: true } ]
    
    # 비교 컬럼 (Value)
    compCols = [ { colA: 2, colB: 2 }, { colA: 3, colB: 3 } ]
}
```

### 1. sortKey (정렬 기준)
행(Row)을 1:1로 매칭시키는 기준입니다. TableDiff는 스트리밍 방식이므로 정렬 순서를 알아야만 "이 데이터는 저쪽에 없구나(OnlyIn...)"라고 판단하고 넘어갈 수 있습니다.
* **필수 조건**: SortKey는 결과셋 내에서 **유일(Unique)**해야 합니다. 중복이 있으면 1:1 매칭이 깨집니다.

### 2. compCols (값 비교)
Key가 일치했을 때, 나머지 데이터가 같은지 확인하는 컬럼들입니다. 정렬 순서 정보는 필요 없으며, 단순히 같음(`Same`)과 다름(`Change`)만 판정합니다.

---

## Block 3: 후처리 규칙 (ApplyTo)

**"발견된 차이를 어떻게 반영할 것인가"**를 정의합니다. (선택 사항)
설정 파일 내에 `Change`, `OnlyInA` 등의 이름으로 블록을 만들면, 해당 결과가 나왔을 때 수행할 동작을 지정할 수 있습니다.

```hocon
Change {
    use.db = "mock"    # 안전 장치 (SQL만 출력)
    action = "update"  # 수행할 DML (insert/update/delete)
    
    # DB 컬럼명 = "JSON 데이터 경로"
    cols = { 
        NAME = "rowA.cols.2"  # TableA의 2번째 SELECT 컬럼 값을 NAME에 set
    }
    
    # WHERE 조건 매핑
    where = { 
        ID = "rowB.keys.1"    # TableB의 1번째 Key 컬럼 값을 ID 조건으로 사용
    }
}
```

* **use.db**: `mock`으로 설정하면 실제 DB에 반영하지 않고 실행될 SQL을 로그로 보여줍니다. **반드시 `mock`으로 먼저 검증**하는 습관을 들이세요.

> **다음 단계**: 실행 결과를 해석하고, `mock` 모드를 통해 안전하게 데이터를 반영하는 **[3. 결과 해석과 후처리](./output.md)** 방법을 알아봅니다.