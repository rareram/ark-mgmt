# PostgreSQL 설치

이 문서는 다양한 운영체제(OS) 환경에 PostgreSQL 데이터베이스를 설치하는 상세한 방법을 안내합니다. 초보자도 쉽게 따라 할 수 있도록 각 단계를 자세히 설명합니다.

!!! success "PostgreSQL 이란?"
    PostgreSQL은 강력한 오픈소스 객체-관계형 데이터베이스 시스템입니다. 35년 이상 활발하게 개발되어 안정성, 기능의 견고함, 성능 면에서 높은 평가를 받고 있습니다. SQL 표준을 준수하며 많은 고급 기능들을 제공하여, 작고 간단한 웹 애플리케이션부터 거대하고 복잡한 데이터 처리 시스템에 이르기까지 널리 사용됩니다.

## 1. 버전 지원 정책

PostgreSQL은 매년 새로운 주요 버전을 출시하며, 각 주요 버전은 출시일로부터 **5년간 지원**됩니다. 지원 기간 동안에는 버그 수정, 보안 패치를 포함하는 마이너 업데이트가 정기적으로 제공됩니다. 5년이 지나면 해당 버전은 EOL(End of Life) 처리되어 더 이상 지원되지 않으므로, 보안 및 안정성을 위해 지원 기간 내의 버전을 사용하는 것이 중요합니다.

| 주요 버전 | 최초 출시일 | 지원 종료(EOL) 예정일 |
| :--- | :--- | :--- |
| 16 | 2023-09-14 | 2028-11-09 |
| 15 | 2022-10-13 | 2027-11-11 |
| 14 | 2021-09-30 | 2026-11-12 |
| 13 | 2020-09-24 | 2025-11-13 |
| 12 | 2019-10-03 | **2024-11-14** |

## 2. 운영체제별 설치 방법

---

사용 중인 운영체제에 맞는 탭을 선택하여 설치를 진행하세요.

=== "Windows"

    Windows 환경에서는 EDB(EnterpriseDB)에서 제공하는 공식 설치 관리자를 사용하는 것이 가장 간편합니다.

    **a. 설치 관리자 다운로드**

    a.  [PostgreSQL 공식 다운로드 페이지](https://www.enterprisedb.com/downloads/postgres-postgresql-downloads)에 접속합니다.
    b.  설치하려는 PostgreSQL 버전 (가급적 최신 버전)을 선택하고, **Windows x86-64** 플랫폼용 설치 프로그램을 다운로드합니다.

    **b. 설치 마법사 실행**

    a.  다운로드한 `.exe` 파일을 실행하여 설치를 시작합니다.
    b.  **설치 경로**: 기본 경로를 사용하거나 원하는 경로를 지정합니다.
    c.  **컴포넌트 선택**: 아래 4가지 핵심 컴포넌트를 모두 선택하는 것을 권장합니다.
        - `PostgreSQL Server`: 데이터베이스 서버 본체
        - `pgAdmin 4`: GUI 기반 데이터베이스 관리 도구
        - `Stack Builder`: 추가 도구 및 드라이버 설치 유틸리티
        - `Command Line Tools`: `psql` 등 명령줄 도구
    d.  **데이터 디렉토리**: 데이터베이스 파일이 저장될 경로를 지정합니다. 기본값을 유지하는 것이 일반적입니다.
    e.  **Superuser 비밀번호 설정**: `postgres` 관리자 계정의 비밀번호를 설정합니다. **이 비밀번호는 반드시 기억해야 합니다.**
    f.  **포트 설정**: 기본 포트인 `5432`를 사용합니다. 다른 서비스와 충돌하는 경우에만 변경합니다.
    g.  **로케일 설정**: `Default locale`을 선택하면 운영체제 설정에 맞춰 자동 지정됩니다.
    h.  설정 요약을 확인한 후 설치를 진행합니다.

    **c. 설치 확인**

    설치가 완료되면 시작 메뉴에서 `SQL Shell (psql)`을 찾아 실행합니다. 아래 정보를 차례로 입력하고 `postgres` 관리자 비밀번호를 입력했을 때 `postgres=#` 프롬프트가 나타나면 성공입니다.

    - `Server [localhost]`: Enter
    - `Database [postgres]`: Enter
    - `Port [5432]`: Enter
    - `Username [postgres]`: Enter
    - `Password for user postgres`: 설치 시 설정한 비밀번호 입력

    !!! tip "pgAdmin 4 활용"
        함께 설치된 `pgAdmin 4`를 실행하면 그래픽 인터페이스를 통해 데이터베이스를 훨씬 직관적으로 관리할 수 있습니다.

=== "Rocky Linux"

    Rocky Linux (RHEL 계열)에서는 `dnf` 패키지 관리자를 사용하거나, 소스 코드를 직접 컴파일하여 설치할 수 있습니다.

    ---

    **방법 1: 패키지 관리자(`dnf`)로 설치 (권장)**

    PostgreSQL 공식 YUM 저장소를 등록하여 최신 버전을 설치하는 방법입니다.

    **a. PostgreSQL YUM 저장소 추가**
    ```bash
    # 공식 저장소 설정 RPM을 설치합니다.
    sudo dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-$(rpm -E %{rhel})-x86_64/pgdg-redhat-repo-latest.noarch.rpm
    ```

    **b. 내장 PostgreSQL 모듈 비활성화**
    Rocky Linux의 기본 저장소에 포함된 PostgreSQL과의 충돌을 방지합니다.
    ```bash
    sudo dnf -qy module disable postgresql
    ```

    **c. PostgreSQL 설치**
    원하는 버전을 선택하여 서버와 클라이언트를 함께 설치합니다. (예: 16 버전)
    ```bash
    # PostgreSQL 16 서버 및 클라이언트 유틸리티 설치
    sudo dnf install -y postgresql16-server postgresql16
    ```

    **d. 데이터베이스 클러스터 초기화**
    `initdb` 명령으로 데이터베이스를 처음 사용할 수 있도록 초기화합니다.
    ```bash
    # /usr/pgsql-16/bin/ 경로에 설치된 유틸리티를 사용
    sudo /usr/pgsql-16/bin/postgresql-16-setup initdb
    ```

    **e. PostgreSQL 서비스 시작 및 자동 실행 등록**
    ```bash
    # 시스템 부팅 시 자동으로 서비스가 시작되도록 설정
    sudo systemctl enable postgresql-16

    # 지금 바로 서비스 시작
    sudo systemctl start postgresql-16

    # 서비스 상태 확인
    sudo systemctl status postgresql-16
    ```

    **f. 접속 테스트**
    `postgres` 시스템 사용자로 전환하여 `psql`에 접속합니다.
    ```bash
    sudo -i -u postgres
    psql
    # psql 종료는 \q 입력
    ```
    
    ---

    **방법 2: 소스 코드로 설치 (고급)**

    특정 버전이나 옵션으로 직접 컴파일하여 설치해야 할 때 사용합니다.

    **a. 빌드 도구 및 의존성 라이브러리 설치**
    ```bash
    sudo dnf groupinstall -y "Development Tools"
    sudo dnf install -y readline-devel zlib-devel
    ```

    **b. PostgreSQL 전용 시스템 사용자 생성**
    보안을 위해 `postgres` 라는 이름의 전용 사용자를 생성하여 데이터베이스를 관리합니다.
    ```bash
    # nologin 쉘로 시스템 로그인은 막고, 사용자/그룹만 생성
    sudo useradd -r -s /sbin/nologin postgres
    ```

    **c. 소스 코드 다운로드 및 컴파일**
    ```bash
    # /tmp 디렉토리로 이동
    cd /tmp

    # 원하는 버전의 소스 코드 다운로드 (예: 16.2)
    curl -O https://ftp.postgresql.org/pub/source/v16.2/postgresql-16.2.tar.bz2
    tar -xjf postgresql-16.2.tar.bz2
    cd postgresql-16.2

    # 설치 경로 지정하여 컴파일 환경 설정
    ./configure --prefix=/opt/postgresql-16.2

    # 컴파일 및 설치
    make
    sudo make install
    ```

    **d. 데이터 디렉토리 생성 및 권한 설정**
    ```bash
    # 설치 경로에 data 디렉토리 생성
    sudo mkdir /opt/postgresql-16.2/data

    # postgres 사용자에게만 접근 권한 부여
    sudo chown postgres:postgres /opt/postgresql-16.2/data
    sudo chmod 700 /opt/postgresql-16.2/data
    ```

    **e. 데이터베이스 클러스터 초기화**
    ```bash
    # postgres 사용자로 전환하여 initdb 실행
    sudo su - postgres -c "/opt/postgresql-16.2/bin/initdb --encoding=UTF8 --locale=en_US.UTF-8 -D /opt/postgresql-16.2/data -W"
    # -W 옵션으로 관리자 비밀번호 설정 프롬프트가 표시됩니다.
    ```

    **f. 서비스 실행**
    ```bash
    # postgres 사용자로 데이터베이스 서버 실행
    sudo su - postgres -c "/opt/postgresql-16.2/bin/pg_ctl -D /opt/postgresql-16.2/data -l /opt/postgresql-16.2/data/logfile start"
    ```

=== "Ubuntu"

    Ubuntu에서는 `apt` 패키지 관리자를 사용하는 것이 가장 일반적입니다.

    **a. PostgreSQL 공식 저장소 설정**

    Ubuntu 기본 저장소의 PostgreSQL은 버전이 낮을 수 있으므로, 최신 버전을 사용하기 위해 공식 PostgreSQL APT 저장소를 추가합니다.

    ```bash
    # 1. 의존성 패키지 설치
    sudo apt update
    sudo apt install -y curl ca-certificates gnupg

    # 2. 공식 PostgreSQL 저장소 GPG 키 가져오기
    curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/apt.postgresql.org.gpg >/dev/null

    # 3. PostgreSQL 저장소 정보 추가
    sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

    # 4. 패키지 목록 다시 업데이트
    sudo apt update
    ```

    **b. PostgreSQL 설치**

    원하는 버전을 지정하여 서버와 부가 기능(`contrib`)을 함께 설치합니다.

    ```bash
    # 예시: PostgreSQL 16 버전 설치
    sudo apt install -y postgresql-16 postgresql-contrib-16
    ```

    **c. 서비스 상태 확인**

    설치 후 서비스는 자동으로 시작되고 활성화됩니다.
    ```bash
    sudo systemctl status postgresql@16-main
    ```

    **d. PostgreSQL 접속**

    Ubuntu에서는 `postgres` 시스템 사용자로 자동 생성된 계정을 통해 다음과 같이 접속할 수 있습니다.
    ```bash
    # postgres 사용자로 전환하여 psql 실행
    sudo -i -u postgres
    psql
    ```
    `psql` 프롬프트에서 나오려면 `\q`를 입력하세요.

    **e. 관리자 비밀번호 설정 (권장)**

    외부에서 접속하거나 특정 사용자로 인증하려면 `postgres` 관리자 계정에 비밀번호를 설정해야 합니다.

    ```bash
    # 1. psql 접속
    sudo -i -u postgres
    psql

    # 2. psql 프롬프트에서 비밀번호 변경 명령어 실행
    ALTER USER postgres PASSWORD 'Your-Strong-Password';

    # 3. psql 종료
    \q
    ```

=== "macOS"

    macOS에서는 [Homebrew](https://brew.sh/) 패키지 관리자를 사용하여 PostgreSQL을 설치하고 관리하는 것이 가장 편리합니다.

    **a. Homebrew 설치 (아직 없다면)**

    터미널을 열고 아래 명령어를 실행하여 Homebrew를 설치합니다.
    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```

    **b. PostgreSQL 설치**

    Homebrew를 이용해 PostgreSQL을 설치합니다.
    ```bash
    # Homebrew 패키지 목록 업데이트
    brew update

    # PostgreSQL 최신 버전 설치
    brew install postgresql
    ```

    !!! info "특정 버전 설치"
        `brew install postgresql@15` 와 같이 `@` 기호를 사용하여 특정 버전을 설치할 수도 있습니다.

    **c. PostgreSQL 서비스 시작**

    `brew services` 명령을 사용하면 PostgreSQL 서버를 백그라운드 서비스로 등록하여 컴퓨터가 시작될 때마다 자동으로 실행되게 할 수 있습니다.

    ```bash
    # PostgreSQL 서비스 시작 및 자동 실행 등록
    brew services start postgresql
    ```

    서비스를 중지하려면 `brew services stop postgresql` 명령을 사용합니다.

    **d. PostgreSQL 접속**

    설치가 완료되면, macOS 사용자 계정 이름으로 된 데이터베이스 관리자 역할(role)이 생성됩니다. 터미널에서 다음 명령어로 바로 접속할 수 있습니다.

    ```bash
    psql -d postgres
    ```

    만약 `command not found: psql` 오류가 발생하면, 터미널 설정 파일(`~/.zshrc`, `~/.bash_profile` 등)에 아래 경로를 추가해야 할 수 있습니다.
    ```bash
    # M1/M2/M3 (Apple Silicon) Mac의 경우
    echo 'export PATH="/opt/homebrew/opt/postgresql/bin:$PATH"' >> ~/.zshrc
    
    # Intel Mac의 경우
    echo 'export PATH="/usr/local/opt/postgresql/bin:$PATH"' >> ~/.zshrc

    # 설정 적용
    source ~/.zshrc
    ```
