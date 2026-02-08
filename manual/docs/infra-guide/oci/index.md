# OCI (Oracle Cloud Infrastructure) 개요

Oracle Cloud Infrastructure(OCI)는 Oracle에서 제공하는 클라우드 컴퓨팅 서비스입니다. 후발주자인 만큼, 경쟁사(AWS, Azure, GCP) 대비 저렴한 비용과 고성능을 내세우고 있습니다. 특히 데이터베이스, 네트워킹, 고성능 컴퓨팅(HPC) 분야에서 강점을 보입니다.

## 1. 주요 클라우드 서비스 비교

각 클라우드 제공업체는 유사한 서비스에 대해 서로 다른 이름을 사용합니다. 아래 표는 AWS, Azure, GCP, OCI의 주요 서비스를 비교한 것입니다.

| 구분 | AWS (Amazon Web Services) | Azure (Microsoft Azure) | GCP (Google Cloud Platform) | OCI (Oracle Cloud Infrastructure) |
| :--- | :--- | :--- | :--- | :--- |
| **컴퓨트 (VM)** | EC2 (Elastic Compute Cloud) | Virtual Machines | Compute Engine | Compute Instances |
| **오브젝트 스토리지** | S3 (Simple Storage Service) | Blob Storage | Cloud Storage | Object Storage |
| **블록 스토리지** | EBS (Elastic Block Store) | Managed Disks | Persistent Disk | Block Volume |
| **네트워킹 (VPC)** | VPC (Virtual Private Cloud) | VNet (Virtual Network) | VPC (Virtual Private Cloud) | VCN (Virtual Cloud Network) |
| **관계형 데이터베이스** | RDS (Relational Database Service) | Azure SQL Database | Cloud SQL | Oracle Database |
| **서버리스** | Lambda | Functions | Cloud Functions | Oracle Functions |
| **컨테이너 오케스트레이션**| EKS (Elastic Kubernetes Service)| AKS (Azure Kubernetes Service) | GKE (Google Kubernetes Engine) | OKE (Oracle Kubernetes Engine) |
| **API 게이트웨이** | API Gateway | API Management | API Gateway | API Gateway |

## 2. 관리 체계 및 정책 비교

클라우드 리소스를 구성하고 접근을 제어하는 방식은 각 제공업체마다 구조적인 차이가 있습니다.

### 관리 단위 (Administrative Hierarchy)

각 클라우드는 리소스를 논리적으로 그룹화하고 관리하기 위한 계층 구조를 가지고 있습니다.

* **AWS**: `조직(Organization)` > `계정(Account)` > `리소스`
    - 각 계정은 독립적인 단위로 운영되며, 조직을 통해 여러 계정을 중앙에서 관리할 수 있습니다.
* **Azure**: `테넌트(Azure AD Tenant)` > `구독(Subscription)` > `리소스 그룹(Resource Group)`
    - 모든 리소스는 리소스 그룹에 속해야 하며, 구독 단위로 비용이 청구되고 관리가 이루어집니다.
* **GCP**: `조직(Organization)` > `폴더(Folder)` > `프로젝트(Project)`
    - 프로젝트가 기본적인 리소스 컨테이너 역할을 하며, 폴더를 이용해 프로젝트를 그룹화할 수 있습니다.
* **OCI**: `테넌시(Tenancy)` > `구획(Compartment)`
    - 테넌시는 OCI 계정의 최상위 루트 컨테이너이며, 구획을 사용하여 리소스를 격리하고 접근을 제어합니다. AWS의 계정이나 GCP의 프로젝트와 유사한 역할을 수행하지만, 더 유연한 계층 구조를 만들 수 있습니다.

### 정책 및 권한 관리 (Policy & IAM)

리소스에 대한 접근 권한을 부여하고 제어하는 정책 모델도 차이가 있습니다.

* **AWS**: **IAM (Identity and Access Management)**
    - JSON 형식의 정책 문서를 사용하여 사용자, 그룹, 역할(Role)에 권한을 할당합니다.
    - `Action`, `Resource`, `Effect`, `Principal` 등의 요소를 조합하여 매우 세밀한 제어가 가능합니다.
* **Azure**: **RBAC (Role-Based Access Control)**
    - 특정 범위(Scope)에 대해 역할(예: Owner, Contributor, Reader)을 할당하는 방식입니다.
    - 역할 정의는 JSON 형식으로 되어 있으며, 특정 작업(Action)의 집합으로 구성됩니다.
* **GCP**: **IAM (Identity and Access Management)**
    - `누가(Member)`, `어떤 역할(Role)`을 `어떤 리소스(Resource)`에 대해 갖는지를 정의합니다.
    - 역할은 원시 역할(Primitive), 사전 정의된 역할(Predefined), 커스텀 역할(Custom)로 나뉩니다.
* **OCI**: **IAM (Identity and Access Management)**
    - 사람이 읽기 쉬운 선언적 구문(OCI-specific syntax)을 사용합니다.
    - 예: `Allow group <group_name> to <verb> <resource-type> in compartment <compartment_name>`
    - `verb`는 `inspect`, `read`, `use`, `manage` 4가지로 단순화되어 있어 정책 이해가 직관적입니다.

OCI는 다른 클라우드에 비해 정책 구문이 간결하여 초기 학습이 용이한 장점이 있습니다.

## 3. 가이드

OCI 인프라 활용을 위해 역할별 가이드를 제공합니다.

* **[운영자 가이드](./operator/index.md)**:  
    OCI 테넌시의 초기 설정, 네트워크 구성, 보안 정책, 사용자 및 그룹 관리 등 인프라 전체를 관리하는 운영자를 위한 절차와 기준을 다룹니다.

* **[사용자 가이드](./user/index.md)**:  
    할당된 구획(Compartment) 내에서 컴퓨트 인스턴스, 스토리지, 데이터베이스 등 필요한 리소스를 생성하고 사용하는 개발자 및 QA 담당자를 위한 실용적인 예제와 방법을 안내합니다.
