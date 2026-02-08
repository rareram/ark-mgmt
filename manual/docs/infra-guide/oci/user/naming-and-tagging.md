# 리소스 명명 규칙 및 태그 정책

모든 사용자는 OCI 리소스를 생성할 때 다음 명명 규칙과 태그 정책을 준수해야 합니다. 이 정책은 리소스 관리의 효율성과 추적성을 높이기 위해 반드시 필요합니다.

## 1. 리소스 명명 규칙 (Resource Naming Convention)

리소스 이름은 다음 형식을 따릅니다.

```
{서비스 약어}-{환경}-{리소스 목적}-{버전/순번}
```

- **서비스 약어**: 리소스가 속한 서비스나 프로젝트를 나타내는 2~4글자의 약어 (예: `proj`, `iam`, `adm`)
- **환경**: 리소스의 배포 환경 (`prod`, `dev`, `stg`)
- **리소스 목적**: 리소스의 구체적인 역할이나 용도 (예: `web`, `was`, `db`, `net`)
- **버전/순번**: 식별을 위한 순번이나 버전 (예: `01`, `02`)

### 예시

- Compute Instance: `proj-prod-web-01`
- Compute Instance: `proj-dev-afc-224`
- Virtual Cloud Network: `proj-dev-net-01`
- Database: `proj-dev-afc-o19c01`

## 2. 태그 정책 (Tagging Policy)

단순한 라벨링을 넘어, 태그는 실제 클라우드 운영의 핵심적인 역할을 수행합니다.

### 태그의 3가지 핵심 용도

a. **비용 추적 (Billing & Cost Analysis)**
    - OCI 비용 분석 대시보드에서 `CostCenter` 또는 `Project` 태그를 기준으로 비용을 상세히 분석할 수 있습니다.
    - **사례**: 올해 총 예산 1,500만원 중 `CDC솔루션` 개발에 얼마를 썼고, `AI신사업` 테스트에 얼마를 썼는지 구분하는 유일한 방법입니다. (단순히 Compartment(구획)만으로는 비용 분리에 한계가 있습니다.)

b. **자동화 스크립트 대상 지정 (Automation)**
    - 특정 태그가 지정된 리소스 그룹에 대해 자동화된 작업을 수행할 수 있습니다.
    - **사례**: "매일 밤 10시에 개발 서버(`Environment:Dev`)만 자동으로 종료"하는 비용 절감 스크립트를 태그 기반으로 손쉽게 구현할 수 있습니다.

c. **리소스 관리 및 검색 (Resource Management)**
    - 수많은 리소스 중에서 특정 조건에 맞는 리소스를 신속하게 찾고 관리할 수 있습니다.
    - **사례**: "양희종(`Owner:heejong.yang`)이 생성한 서버만 모두 찾아줘"와 같은 요구사항을 즉시 처리할 수 있습니다.

### "자유 형식 태그" vs "정의된 태그"

- **자유 형식 태그 (Free-form Tags)**: 사용자가 키와 값을 마음대로 입력하는 방식입니다. **(비추천)**
    - **문제점**: `Project`, `project`, `PJT` 등 사용자마다 표현이 달라 태그 기반의 집계 및 자동화가 불가능해집니다.
- **정의된 태그 (Defined Tags)**: 관리자가 사전에 정의한 키와 값 목록 중에서만 선택(Dropdown)하도록 강제하는 방식입니다. **(권장)**
    - **장점**: 오타나 비표준 용어 사용을 원천 차단하여 전사적인 데이터 일관성과 표준을 유지할 수 있습니다.

### ArkData 표준 태그 전략

#### 1단계: 네임스페이스 (Namespace) 설정

네임스페이스는 태그들을 담는 '그룹'입니다. 다른 팀이나 컴파트먼트의 태그와 섞이지 않도록 고유한 이름을 사용합니다. (예: `ArkData_Common`, `ArkData_Standard`)

#### 2단계: 필수 태그 키 (Key)와 값 (Value) 설계

리소스를 생성할 때 모든 사용자가 반드시 입력해야 하는 5가지 핵심 태그입니다.

| 태그 키 (Key) | 설명 (용도) | 추천 값 예시 (Value) |
| :--- | :--- | :--- |
| `Project` | 어떤 프로젝트를 위한 리소스인가? (비용 분리) | `CDC_Solution`, `Internal_ERP`, `New_Biz_AI` |
| `Environment` | 어떤 환경인가? (자동화, 위험도 식별) | `Dev` (개발), `Stage` (검증), `Prod` (운영) |
| `CostCenter` | 비용이 청구되는 부서는 어디인가? | `DevTeam`, `QATeam`, `InfraTeam` |
| `Owner` | 실무 담당자는 누구인가? (문제 발생 시 연락처) | `heejong.yang`, `sunghoon.choi` (이메일 ID) |
| `Schedule` | 자동화 스케줄 (비용 절감) | `AlwaysOn` (24시간), `BizHours` (업무시간) |

#### 3단계: 실제 적용 시나리오 (예시)

사용자 양희종이 CDC 솔루션 프로젝트를 위해 생성한 개발 서버에는 다음과 같은 '정의된 태그'가 적용되어야 합니다.

- **Namespace**: `ArkData_Common`
    - **Project**: `CDC_Solution`
    - **Environment**: `Dev`
    - **CostCenter**: `DevTeam`
    - **Owner**: `heejong.yang`
    - **Schedule**: `BizHours`

---

*태그 정책을 준수하지 않은 리소스는 추적 및 관리가 어려워지며, 예고 없이 변경 또는 삭제될 수 있습니다.*

