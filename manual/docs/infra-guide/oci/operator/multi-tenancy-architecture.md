# OCI Multi-Tenancy Architecture Guide

## 1. 개요 (Overview)
본 문서는 **`arkdata`** 테넌시 내에서 ArkData와 관계사가 OCI 크레딧을 공유하여 사용하면서도, 상호 독립적인 운영 환경을 보장하고 기술적으로 협업하기 위한 아키텍처 및 거버넌스 가이드입니다.

### 핵심 원칙
* **독립적 운영 (Isolation):** 각 조직은 상대방의 리소스, 사용자, 정책을 임의로 수정/삭제할 수 없도록 격리하여 운영 독립성을 확보합니다.
* **권한 위임 (Delegation):** 각 조직의 관리자(Admin)는 할당된 구획(Compartment) 내에서만 사용자 생성, 리소스 관리 등의 모든 작업을 직접 수행합니다.
* **예산 기반 통제 (Budget Control):** 약속된 크레딧(예산) 내에서만 자원을 사용할 수 있도록 할당량(Quota)을 설정하여 예산 초과를 방지합니다.
* **기술 협업 (Collaboration):** 관계사는 Oracle 파트너로서 전문성을 활용해 ArkData의 인프라 구성을 검토하고 기술을 지원할 수 있는 최소한의 읽기 권한을 가집니다.

### 기본 정보
* **Tenancy Name:** `arkdata`
* **Root Admin:** `ark_infraops@iarkdata.com` (전체 총괄 관리자)
* **운영 모델:** 논리적 멀티 테넌시 (Logical Multi-tenancy)

### 크레딧 운영 계획
* **총 크레딧:** 2,500만 원 (1년 소진 목표)
* **ArkData 사용 예산:** 1,500만 원
* **관계사 사용 예산:** 1,000만 원

---

## 2. 구획 및 도메인 구조 (Architecture)
단순히 그룹만 나누는 것이 아니라, **Identity Domain(ID 관리)**과 **Compartment(자원 관리)**를 모두 분리하여 각 조직이 논리적으로 독립된 회사처럼 운영되도록 구성합니다.

### 계층 구조도 (Hierarchy)
```text
Root (Tenancy: arkdata)
├── [Compartment] Shared_Network (공용 네트워크/VPN)
│
├── [Compartment] Comp_ArkData (ArkData 전용)
│    └── [Domain] Domain_ArkData (ArkData 임직원 로그인용)
│         ├── Users: 사내 개발자, 운영자 등
│         └── Groups: Grp_Dev, Grp_Ops ...
│
└── [Compartment] Comp_DataBank (관계사 전용)
     └── [Domain] Domain_Partner (관계사 로그인용)
          ├── Users: 관계사 직원
          └── Groups: Grp_Partner_Admin, Grp_Partner_Dev ...
```

## 3. 상세 구성 가이드
### 1단계: 컴파트먼트(Compartment) 구성
가장 먼저 자원이 담길 '방'을 격리합니다.
* **위치:** Root 바로 하위
* **Comp_ArkData:** ArkData 내부 프로젝트용
* **Comp_Partner:** 관계사 전용 공간
* **Shared_Network:** (선택사항) 양사가 공통으로 사용해야 하는 전용선, VPN 등이 있을 경우 이곳에 구성

### 2단계: 아이덴티티 도메인(Identity Domain) 분리
가장 중요한 단계입니다. Default 도메인에 다른 조직의 계정을 섞지 말고, 별도 도메인을 생성합니다.
* **생성 위치:** ID & Security > Domains > Create Domain
* **Domain Type:** Free (기본 기능만 사용 시)
* **생성 경로:**
    * **ArkData용:** `Comp_ArkData` 구획 내부에 `Domain_ArkData` 생성
    * **관계사용:** `Comp_Partner` 구획 내부에 `Domain_Partner` 생성
* **Admin 할당:** 이미 생성된 관계사 Admin 계정을 `Domain_Partner`의 초기 관리자로 등록합니다.
* **Result:** 관계사는 별도의 로그인 URL을 가지며, ArkData의 사용자 목록을 조회할 수 없습니다.

### 3단계: 그룹(Group) 및 역할 정의
각 도메인 내부에서는 '직무(Role)' 기반으로 그룹을 생성할 것을 권장합니다.

| 도메인 | 그룹명 | 권한 설명 |
|---|---|---|
| ArkData | Grp_Dev | 개발 환경(Dev) Full Access, 운영 환경(Prod) Read Only |
| ArkData | Grp_Ops | 모든 환경 인프라 관리 및 배포 권한 |
| Partner | Grp_Partner_Admin | 관계사 구획 내 사용자 생성 및 모든 자원 관리 + **ArkData 구획 읽기 권한(기술 지원용)** |
| Partner | Grp_Partner_Dev | 관계사 구획 내 개발 자원 관리 |

## 4. 정책 (Policies) 설정
Root Admin(`ark_infraops`)이 테넌시 레벨(Root)에서 설정해야 하는 정책입니다. 이 정책이 있어야 완벽한 격리와 제어된 협업이 가능해집니다.

### ArkData용 정책
```plaintext
# ArkData 관리자가 자신의 구획을 관리하도록 허용
Allow group Domain_ArkData/Grp_Ops to manage all-resources in compartment Comp_ArkData

# (선택) 공용 네트워크는 읽기만 가능 (실수 방지)
Allow group Domain_ArkData/Grp_Dev to read all-resources in compartment Shared_Network
```

### 관계사용 정책 (격리 및 협업)
```plaintext
# 1. 관계사 Admin이 자기 구획 내의 자원만 관리하도록 허용 (운영 독립성)
Allow group Domain_Partner/Grp_Partner_Admin to manage all-resources in compartment Comp_Partner

# 2. 관계사 Admin이 자기 도메인(사용자/그룹)을 직접 관리하도록 위임
Allow group Domain_Partner/Grp_Partner_Admin to manage domains in compartment Comp_Partner

# 3. 관계사 Admin이 ArkData 구획을 읽을 수 있도록 허용 (기술 지원 협업)
Allow group Domain_Partner/Grp_Partner_Admin to read all-resources in compartment Comp_ArkData
```

!!! warning "주의사항"
위 정책을 적용하면 관계사는 `Comp_Partner` 외부의 리소스(예: `Comp_ArkData`)를 **수정/삭제할 수 없으며**, 오직 기술 지원을 위한 **읽기만 가능**합니다.

## 5. 자원 할당량 제한 (Compartment Quotas)
공유 크레딧을 예산 내에서 사용하도록 각 구획별로 자원 생성 한도를 설정합니다. 이는 예상치 못한 비용 발생을 막는 가장 효과적인 방법입니다.
**설정 위치:** Governance & Administration > Quota Policies

### 예산 기반 할당량 정책 예시
```plaintext
# [ArkData: 1,500만원 예산]
# 예시: 표준 VM(Intel/AMD)을 최대 30 OCPU까지 사용 가능
set compartment Comp_ArkData limit compute-core-count to 30
set compartment Comp_ArkData limit block-storage-size to 10TB

# [관계사: 1,000만원 예산]
# 예시: 표준 VM(Intel/AMD)을 최대 20 OCPU까지만 사용 가능
set compartment Comp_Partner limit compute-core-count to 20
set compartment Comp_Partner limit block-storage-size to 5TB

# 공통: 양사 모두 고성능/고비용 GPU 인스턴스 생성은 불가
zero compartment Comp_ArkData limit gpu-count
zero compartment Comp_Partner limit gpu-count
```

## 6. 운영 프로세스 요약
* **신규 입사자 (ArkData):** `Domain_ArkData`에 계정 생성 → `Grp_Dev` 등의 그룹 할당 → 자동 권한 부여.
* **관계사 인원 변경:** Root Admin(`ark_infraops`) 개입 불필요. `Grp_Partner_Admin` 권한을 가진 관계사 관리자가 직접 본인 도메인에서 처리.
* **비용 모니터링:** Root Admin은 Cost Analysis에서 `Compartment` 태그를 기준으로 양사의 크레딧 소진 현황을 분리하여 추적.

### ✨ 가이드 작성 시 참고사항
* **Admin 계정 마이그레이션:** 만약 이미 관계사 Admin을 `Default` 도메인(Root)에 만드셨다면, 위 가이드에 따라 **관계사용 도메인(`Domain_Partner`)을 새로 생성하고 그곳에 계정을 다시 생성**하는 것이 보안상 안전합니다. (기존 계정은 삭제 권장)
* **확장성:** 이 구조는 추후 또 다른 협력사가 추가되어도 `Comp_Company_C` + `Domain_Company_C` 세트만 복사하면 되므로 확장에 매우 유리합니다.
