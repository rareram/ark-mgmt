# 결과 해석과 후처리

실행(`-o json`) 후 생성된 결과 파일은 단순한 텍스트가 아닙니다. **운영 관점**에서 이 결과를 해석하고, 안전하게 DB에 반영하는 방법을 익혀봅시다.

---

## 1. 결과 데이터 해석 (NDJson)

TableDiff의 결과는 **NDJson (New-line Delimited JSON)** 형식입니다. 즉, 한 줄에 하나의 완벽한 JSON 객체가 들어있어 리눅스 명령어(`grep`, `wc`, `head`)로 분석하기 매우 좋습니다.

### 결과 타입 4가지 의미

| 타입 | 의미 | 정렬키(SortKey) | 비교컬럼(CompCols) | 조치 필요 |
| :--- | :--- | :--- | :--- | :--- |
| **Same** | 완벽 일치 | 같음 | 같음 | 없음 |
| **Change** | 값 변경됨 | **같음** | **다름** | Update |
| **OnlyInA** | A에만 있음 | (A에만 존재) | - | Insert (to B) |
| **OnlyInB** | B에만 있음 | (B에만 존재) | - | Delete (from B) |

> **Tip**: 대량 데이터 비교 시 `Same` 결과가 너무 많으면 디스크 공간을 많이 차지할 수 있습니다. 운영 환경에서는 불일치 데이터만 남기는 것이 일반적입니다.

### 분석 실습
```bash
# 전체 건수 확인
wc -l result.json

# 변경 유형별 건수 집계
grep -c "Same" result.json
grep -c "Change" result.json
grep -c "OnlyInA" result.json
grep -c "OnlyInB" result.json

# 변경된 데이터 내용 눈으로 확인 (상위 5건)
grep "Change" result.json | head -n 5
```

---

## 2. 후처리(ApplyTo)는 "Mock 먼저"

가장 많이 하는 실수는 검증 없이 덮어놓고 DB에 반영(Apply)부터 하는 것입니다. **절대 금물**입니다. 항상 `mock` 모드로 검증하는 루틴을 지키세요.

### Step 1: Mock 모드 설정
설정 파일의 `Change` (또는 `OnlyIn...`) 블록에서 `use.db = "mock"`으로 설정합니다.

```hocon
Change {
    use.db = "mock"
    action = "update"
    ...
}
```

### Step 2: 실행 및 로그 확인
`-i json` 옵션으로 결과 파일을 입력받아 실행합니다.

```bash
java -jar TableDiff_0.6.3.jar -c config.conf -i json -f result.json
```

화면에 출력되는 로그를 확인합니다. 실제 DB에는 아무런 변화가 없으니 안심하세요.
```text
[Mock] UPDATE EMP_TGT SET NAME = ? WHERE ID = ?  :: 바인딩 값...
```
SQL 문장이 의도한 대로 생성되었는지, `WHERE` 절 조건은 맞는지 꼼꼼히 확인합니다.

### Step 3: 실 DB 반영
검증이 끝났다면 `use.db = "tableB"` (또는 `tableA`)로 변경하고 다시 실행하여 실제 반영을 수행합니다.

> **다음 단계**: 모든 게 완벽해 보일 때 발생하는 문제들! **[4. 실패로 배우는 제약조건](./troubleshooting.md)**에서 일부러 에러를 내보며 튼튼한 지식을 쌓아봅시다.