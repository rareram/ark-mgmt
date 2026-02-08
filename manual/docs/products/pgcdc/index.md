# PG CDC 개발 매뉴얼

`PG CDC` (PostgreSQL Change Data Capture) 솔루션 개발을 위한 매뉴얼입니다.

이 매뉴얼은 `PG CDC` 솔루션의 개발 환경 설정, 아키텍처, 핵심 로직, 테스트 방법 등을 상세히 다룹니다.

- **[로컬 개발 환경 설정](../../install-guide/postgresql/postgresql-install.md)**: 개발을 시작하기 위해 로컬 PC에 PostgreSQL을 설치하고 기본 설정을 진행합니다.
- **[기본 사용법](./usage/data-change.md)**: CDC 대상이 되는 데이터베이스의 변경 작업을 수행하고 확인합니다.
- **[Docker를 이용한 테스트](./testing/docker-testing.md)**: 다양한 버전의 PostgreSQL 환경에서 솔루션의 호환성을 테스트합니다.
