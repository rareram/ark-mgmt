# Oracle Database 설치

이 문서는 Oracle Database Express Edition (XE)를 설치하는 방법을 안내합니다. XE 버전은 개발 및 소규모 환경에서 무료로 사용할 수 있는 Oracle Database의 에디션입니다.

!!! success "Oracle Database 란?"
    Oracle Database는 세계적으로 가장 널리 사용되는 관계형 데이터베이스 관리 시스템(RDBMS) 중 하나입니다. 대규모 엔터프라이즈 환경에서 요구하는 뛰어난 성능, 안정성, 보안 및 확장성을 제공하는 것으로 알려져 있습니다.

## 1. 버전 정보

이 가이드는 **Oracle Database 21c Express Edition**을 기준으로 작성되었습니다. Oracle XE는 특정 버전에 대해 패치나 업데이트를 제공하지 않으며, 새로운 기능이나 보안 업데이트를 위해서는 다음 버전의 XE를 설치해야 합니다.

## 2. 운영체제별 설치 방법

---


사용 중인 환경에 맞는 탭을 선택하여 설치를 진행하세요. Docker를 사용하는 방법은 Linux, macOS, Windows 모두에서 동일하게 적용할 수 있어 권장됩니다.

=== "Docker"

    Docker를 사용하면 복잡한 설치 과정 없이 격리된 환경에 Oracle DB를 빠르고 쉽게 구성할 수 있습니다.

    **a. Docker 설치**

    사용자의 운영체제에 [Docker Desktop](https://www.docker.com/products/docker-desktop)이 설치되어 있어야 합니다.

    **b. Oracle XE 이미지 다운로드**

    터미널 또는 명령 프롬프트를 열고 아래 명령어를 실행하여 Oracle Container Registry에서 공식 XE 이미지를 다운로드합니다.
    ```bash
    docker pull container-registry.oracle.com/database/express:latest
    ```
    로그인이 필요하다는 메시지가 나타나면, [Oracle Container Registry](https://container-registry.oracle.com/)에 접속하여 `database/express` 이미지를 찾아 라이선스에 동의한 후, 터미널에서 `docker login container-registry.oracle.com` 명령으로 로그인해야 할 수 있습니다.

    **c. Docker 컨테이너 실행**

    `docker run` 명령어를 사용하여 데이터베이스 컨테이너를 생성하고 실행합니다.

    ```bash
    docker run -d \
      --name oracle-xe \
      -p 1521:1521 \
      -e ORACLE_PWD=your_strong_password \
      -v oracle-data:/opt/oracle/oradata \
      container-registry.oracle.com/database/express:latest
    ```

    - `-d`: 컨테이너를 백그라운드에서 실행합니다.
    - `--name oracle-xe`: 컨테이너의 이름을 `oracle-xe`로 지정합니다.
    - `-p 1521:1521`: 호스트의 1521 포트를 컨테이너의 1521 포트로 매핑합니다.
    - `-e ORACLE_PWD=your_strong_password`: `SYS`, `SYSTEM` 등 관리자 계정의 비밀번호를 설정합니다. **반드시 강력한 비밀번호로 변경하세요.**
    - `-v oracle-data:/opt/oracle/oradata`: Docker 볼륨을 생성하여 데이터베이스 파일을 영속적으로 저장합니다. 컨테이너가 삭제되어도 데이터가 보존됩니다.

    **d. 설치 확인**

    데이터베이스가 초기화되고 시작되는 데 몇 분 정도 소요될 수 있습니다. 아래 명령어로 로그를 확인하여 데이터베이스가 준비되었는지 확인할 수 있습니다.
    ```bash
    docker logs -f oracle-xe
    ```
    로그에 `DATABASE IS READY TO USE!` 메시지가 나타나면 성공입니다.

    `sqlplus`를 사용하여 접속을 테스트할 수 있습니다.
    ```bash
    docker exec -it oracle-xe sqlplus system/your_strong_password@//localhost:1521/XEPDB1
    ```

=== "Linux"

    Linux 환경에서는 Docker를 사용하는 것이 가장 일반적이고 권장되는 방법입니다. 위의 "Docker" 탭의 지침을 따르세요. Docker를 사용하면 복잡한 의존성 관리나 패키지 충돌 없이 Oracle Database를 쉽고 안정적으로 운영할 수 있습니다.

=== "Windows"

    Windows 환경에서는 공식 설치 관리자를 사용하여 설치합니다.

    **a. 설치 파일 다운로드**

    a.  [Oracle Database XE 다운로드 페이지](https://www.oracle.com/database/technologies/xe-downloads.html)에 접속합니다.
    b.  `Oracle Database 21c Express Edition for Windows x64` 버전을 다운로드합니다. (Oracle 계정 필요)

    **b. 설치 마법사 실행**

    a.  다운로드한 `.zip` 파일의 압축을 해제합니다.
    b.  압축 해제된 폴더에서 `setup.exe` 파일을 **관리자 권한으로 실행**합니다.
    c.  **라이선스 동의**: 라이선스 약관에 동의하고 'Next'를 클릭합니다.
    d.  **설치 경로**: 기본 설치 경로를 사용하거나 원하는 경로를 지정합니다. 경로에 공백이나 한글이 포함되지 않도록 주의합니다.
    e.  **데이터베이스 비밀번호 설정**: `SYS`, `SYSTEM`, `PDBADMIN` 관리자 계정에서 사용할 통합 비밀번호를 입력합니다. **이 비밀번호는 반드시 기억해야 합니다.**
    f.  **설정 요약 확인**: 설치 경로와 데이터베이스 SID(`XE`) 등 설정 정보를 확인하고 'Install' 버튼을 클릭하여 설치를 시작합니다.
    g.  설치가 완료될 때까지 15~30분 정도 소요될 수 있습니다.

    **c. 설치 확인**

    설치가 완료되면 SQL*Plus를 통해 접속을 테스트합니다.

    a.  시작 메뉴에서 `SQL Plus`를 검색하여 실행합니다.
    b.  사용자 이름에 `system`을 입력합니다.
    c.  비밀번호에 설치 시 설정한 비밀번호를 입력합니다.
    d.  `SQL>` 프롬프트가 나타나면 성공적으로 접속된 것입니다.

    !!! tip "Oracle Net Listener"
        Windows 서비스(`services.msc`)를 확인하면 `OracleServiceXE`와 `OracleXE_TNSListener` 서비스가 실행 중인 것을 볼 수 있습니다. 이 서비스들이 실행되어야 데이터베이스에 접속할 수 있습니다.
