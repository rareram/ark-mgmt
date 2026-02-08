# OCI IAM 상세 가이드

이 문서는 Oracle Cloud Infrastructure (OCI)의 IAM(Identity and Access Management) 서비스에 대한 상세 가이드입니다. 관리자는 이 문서를 통해 사용자, 그룹, 정책을 효과적으로 관리하고 최소 권한 원칙을 적용할 수 있습니다.

## 1. IAM 핵심 구성요소

OCI IAM은 다음 네 가지 핵심 구성요소를 기반으로 동작합니다.

- **Compartments (구획)**: 리소스를 논리적으로 격리하고 접근을 제어하는 기본 단위입니다. (예: `cmp-dev`, `cmp-prod`)
- **Users (사용자)**: OCI 콘솔에 로그인하고 API를 호출할 수 있는 개별 주체입니다.
- **Groups (그룹)**: 사용자들의 집합입니다. 권한은 개별 사용자가 아닌 그룹에 부여하는 것이 원칙입니다.
- **Policies (정책)**: 어떤 그룹이 어떤 구획의 어떤 리소스에 대해 어떤 작업을 수행할 수 있는지 정의하는 규칙입니다.

## 2. 권한 관리 시나리오 기반 가이드

### 시나리오: "개발팀(Dev-Team)이 개발 구획(cmp-dev)의 모든 리소스를 관리하도록 허용"

#### 사용자(User) 생성

- 신규 입사자 'Suhong.Kim'에 대한 사용자 계정을 생성합니다.
- **가이드**:
    a. OCI 콘솔 > Identity & Security > Users 로 이동합니다.
    b. 'Create User'를 클릭하고 사용자 정보(Suhong.Kim)를 입력합니다.
    c. 생성된 사용자에게는 초기 패스워드 설정 링크가 이메일로 발송됩니다.

#### 그룹(Group)에 사용자 추가

- 'Dev-Team'이라는 그룹이 없다면 먼저 생성합니다.
- **가이드**:
    a. Identity & Security > Groups 로 이동합니다.
    b. 'Create Group'을 클릭하여 'Dev-Team' 그룹을 생성합니다.
    c. 생성된 그룹을 선택하고 'Add User to Group' 버튼을 통해 'Suhong.Kim' 사용자를 그룹에 추가합니다.

#### 정책(Policy) 작성 및 연결

- 'Dev-Team' 그룹에게 'cmp-dev' 구획에 대한 관리 권한을 부여하는 정책을 작성합니다.
- **가이드**:
    a. Identity & Security > Policies 로 이동합니다.
    b. 'Create Policy'를 클릭합니다.
    c. **정책 구문 (Policy Syntax)**:
        ```sql
        Allow group Dev-Team to manage all-resources in compartment cmp-dev
        ```
    d. 위 구문을 입력하고, 정책이 적용될 구획(Compartment)을 선택합니다. (일반적으로 상위 구획에서 하위 구획의 정책을 관리합니다)

### 정책 구문 심화

- **`Allow group <그룹명> to <권한> <리소스타입> in compartment <구획명>`**

- **권한 (Verb)**:
    - `inspect`: 리소스 목록 보기 (읽기 전용)
    - `read`: 리소스 정보 및 사용자 데이터 읽기
    - `use`: 리소스 사용 (기존 리소스 수정, 재시작 등)
    - `manage`: 모든 권한 (생성, 수정, 삭제 포함)

- **리소스 타입 (Resource-Type)**:
    - `all-resources`: 모든 리소스
    - `vcns`, `instances`, `buckets`, `autonomous-databases` 등 특정 리소스 타입 지정 가능

#### 예시 1: QA팀이 QA 구획의 네트워크만 보고 인스턴스는 수정하게 하기

```sql
Allow group QA-Team to inspect vcns in compartment cmp-qa
Allow group QA-Team to use instances in compartment cmp-qa
```

#### 예시 2: 특정 사용자에게만 비용 청구 정보를 보게 하기 (테넌시 레벨 정책)

```sql
Allow group Finance-Team to read usage-reports in tenancy
```

## 3. IAM 설계 원칙 및 역할 기반 정책 예시

효과적인 IAM 관리를 위해서는 **최소 권한(Least Privilege) 원칙**을 적용하고, 개별 사용자가 아닌 **역할(Role) 기반으로 그룹**에 권한을 부여해야 합니다.

- **최소 권한 원칙**: 각 사용자 및 그룹은 업무를 수행하는 데 필요한 최소한의 권한만 가져야 합니다.
- **역할 기반 접근 제어 (RBAC)**: 사용자를 역할(직무)에 따라 그룹화하고, 권한을 그룹에 할당합니다.

### 역할별 정책 설계 예시

- **운영팀 (Operations Team)**
    - **역할**: 프로덕션 환경의 모든 리소스를 관리합니다.
    - **정책**: `Allow group Ops-Team to manage all-resources in compartment cmp-prod`

- **개발/QA팀 (Development/QA Team)**
    - **역할**: 개발 및 테스트 환경의 리소스를 자유롭게 사용하고 관리합니다.
    - **정책**: `Allow group Dev-Team to manage all-resources in compartment cmp-dev`
    - **정책**: `Allow group QA-Team to manage all-resources in compartment cmp-qa`

- **공통 인프라팀 (Common Infra Team)**
    - **역할**: 모든 환경에 걸쳐있는 공통 인프라(네트워크, VPN 등)를 관리합니다.
    - **정책**: `Allow group Infra-Team to manage all-resources in compartment infra-common`

- **중요 권한 제한**
    - 리소스 생성·삭제와 같이 비용 및 보안에 큰 영향을 미치는 권한은 특정 그룹(예: `Lead-Dev-Team`)이나 책임자에게만 부여하고, 승인 프로세스를 따르도록 정책화하는 것이 안전합니다.

---
*이 가이드는 기본적인 시나리오를 다루며, 더 복잡한 정책 조합은 OCI 공식 문서를 참고하십시오.*

