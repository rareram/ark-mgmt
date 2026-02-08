# TableDiff 개요

TableDiff는 **데이터베이스 간의 데이터 일관성을 검증**하고 **변경 사항을 효과적으로 비교 분석**하기 위해 설계된 강력한 도구입니다. 특히 CDC(Change Data Capture) 솔루션의 검증 과정에서 원본 데이터베이스와 대상 데이터베이스 간의 차이를 정밀하게 식별하는 데 활용됩니다.

주요 기능:

* 두 개의 SQL ResultSet을 기반으로 정렬된 스트리밍 비교를 수행합니다.
* 비교 결과를 `Same`, `Change`, `OnlyInA`, `OnlyInB` 네 가지 카테고리로 분류하여 제공합니다.
* 다양한 데이터베이스 환경(**Oracle**, **PostgreSQL** 등)을 지원하며, Docker Compose를 통해 손쉽게 테스트 환경을 구축할 수 있습니다.
    * [:material-docker: OracleDB 테스트 환경 구성](./getting-started/oracle-compose.md)
    * [:material-docker: PostgreSQL 테스트 환경 구성](./getting-started/postgres-compose.md)
## 실행 구성 요소

TableDiff를 사용하여 데이터 정합성을 검증하고 변경 사항을 반영하기 위해서는 다음과 같은 구성 요소가 필요합니다.

* **자바 런타임 (Java Runtime)**: 최적의 성능과 안정성을 위해 **Java 17 이상의 LTS 버전** 사용을 강력히 권장합니다.
    * **권장 가이드라인**: 최소 **Java 11** 이상의 환경 구축을 권장합니다.
    * **레거시 지원**: 일부 구형 OS와의 호환성을 위해 Java 8(1.8)에서도 실행은 가능하나, 이는 최후의 수단으로만 고려되어야 하며 최적의 성능을 보장하지 않습니다.
* **TableDiff JAR**: 실제 비교 엔진이 담긴 실행 파일입니다. (예: `TableDiff_0.6.3.jar`)
* **설정 파일 (.conf)**: 비교 대상이 되는 원본/대상 테이블 정보, 접속 정보, 비교 조건(SortKey, CompCols) 및 후처리(ApplyTo) 계획을 HOCON 형식으로 정의한 파일입니다.
* **결과 파일 (json/bin)**: 비교 실행 시 생성되는 결과 데이터 파일입니다. 한 줄씩 읽기 쉬운 NDJson 형식(`.json`) 또는 대용량 처리에 유리한 바이너리 형식(`.bin`)으로 저장할 수 있습니다.

??? info "참고: 왜 표준 JSON이 아닌 NDJson인가요?"
    TableDiff는 대용량 데이터를 처리하기 위해 **NDJson (New-line Delimited JSON)** 형식을 채택했습니다. 이는 한 줄에 하나의 JSON 객체를 기록하는 방식으로, 표준 JSON과 다음과 같은 차이가 있습니다.

    | 구분 | 표준 JSON (Standard JSON) | NDJson (New-line Delimited JSON) |
    | :--- | :--- | :--- |
    | **구조** | 전체가 하나의 거대한 배열(`[...]`) 또는 객체(`{...}`) | **한 줄에 하나의 완전한 JSON 객체**가 나열됨 |
    | **구분자** | 쉼표(`,`) | **줄바꿈 문자** (`\n`) |
    | **파싱** | 파일 전체를 읽어야 파싱 가능 (메모리 부담 큼) | **한 줄씩 읽어서 스트리밍 처리 가능** |
    | **활용** | 설정 파일, 소규모 API 응답 | **대용량 로그, 데이터 스트림, 파이프라인 처리** |

    이러한 특징 덕분에 TableDiff의 결과 파일은 수 기가바이트(GB)가 넘더라도 메모리 문제없이 `grep`, `awk` 등 리눅스 표준 도구로 즉시 분석할 수 있습니다.

---

TableDiff 프로젝트는 내부 GitLab에서 관리되고 있습니다.

* :fontawesome-brands-gitlab: [TableDiff Source Code Repository](https://rnd.iarkdata.com/gitlab/ARK/CDC/tablediff)
* :fontawesome-brands-gitlab: [TableDiff Test Automation Repository](https://rnd.iarkdata.com/gitlab/ARK/CDC/TEST/test_tablediff)

!!! tip "리포지토리 분리 및 CI 파이프라인 운영"
    소스 코드 리포지토리의 변경 이력을 명확히 관리하기 위해 테스트 자동화 리포지토리를 별도로 분리하여 운영합니다.
    
    * **CI Stage**: `Build` → `Verify` → `Release` (총 3단계)
    * **Verify 단계**: 수동 실행 단계로, 테스트 자동화 리포지토리를 참조하여 실제 기능 검증을 수행합니다.
    * 이를 통해 빈번한 테스트 코드 수정이 소스 코드의 품질 추적에 영향을 주지 않으면서도 철저한 검증이 가능합니다.