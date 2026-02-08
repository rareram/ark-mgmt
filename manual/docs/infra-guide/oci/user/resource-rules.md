# 리소스별 상세 규칙

이 문서에서는 각 OCI 리소스 유형별로 적용해야 할 구체적인 설정, 한도, 보안 규칙을 정의합니다.

## 1. Compute

### Instance (가상 머신)

- **Shape**: `VM.Standard.E4.Flex` 사용을 기본으로 하며, 초과 사양이 필요할 경우 사전 협의가 필요합니다.
- **OS**: Oracle Linux 8을 기본으로 사용합니다.
- **네트워킹**: 모든 인스턴스는 Private Subnet에 생성하는 것을 원칙으로 합니다. Public IP 할당은 금지됩니다.
- **부트 볼륨**: 기본 크기(50GB)를 사용하며, 추가 스토리지는 Block Volume을 사용해 연결합니다.

## 2. Networking

### VCN (Virtual Cloud Network)

- **CIDR 블록**: `/16`을 초과하는 대규모 CIDR 블록은 할당할 수 없습니다.
- **서브넷**: 용도에 따라 Public Subnet과 Private Subnet으로 분리하여 사용합니다.
    - Public Subnet: Bastion Host, Load Balancer 등 외부 통신이 필요한 리소스만 배치합니다.
    - Private Subnet: Compute Instance, Database 등 내부 리소스를 배치합니다.

## 3. Database

### Autonomous Database

- **유형**: Transaction Processing 타입을 기본으로 사용합니다.
- **네트워킹**: Private Endpoint를 사용하며, VCN 내부에서만 접근 가능하도록 설정합니다.
- **백업**: 일일 자동 백업을 활성화하고, 보존 기간은 30일로 설정합니다.

---

*여기에 각 리소스별 상세 규칙을 계속해서 추가합니다.*

