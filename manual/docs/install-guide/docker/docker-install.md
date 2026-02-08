# Docker 설치

이 가이드는 다양한 운영체제에 Docker를 설치하는 방법을 안내합니다. 데스크톱 환경인 Windows와 macOS에는 GUI 도구가 포함된 **Docker Desktop**을 설치하고, 서버 환경인 Linux에는 커맨드라인 기반의 **Docker Engine**을 설치하는 것을 기준으로 합니다.

---

사용 중인 운영체제에 맞는 탭을 선택하여 설치를 진행하세요.

=== ":fontawesome-brands-windows: Windows" 

    Windows 10/11 환경에서는 WSL 2 (Windows Subsystem for Linux 2)를 기반으로 동작하는 **Docker Desktop**을 설치합니다.

    **a. 사전 요구사항**

    - Windows 10 (21H2 이상) 또는 Windows 11 (21H2 이상)
    - WSL 2 기능 활성화. Docker Desktop 설치 시 자동으로 활성화를 제안합니다.
    - BIOS/UEFI에서 하드웨어 가상화(Hardware Virtualization) 활성화.

    **b. Docker Desktop 설치**

    a.  [Docker Desktop 공식 다운로드 페이지](https://www.docker.com/products/docker-desktop/)에 접속하여 Windows용 설치 파일을 다운로드합니다.
    b.  다운로드한 `Docker Desktop Installer.exe` 파일을 실행합니다.
    c.  설치 화면의 안내에 따라 진행합니다. **"Use WSL 2 instead of Hyper-V"** 옵션이 선택되었는지 확인하고 설치를 완료합니다.

    **c. 설치 확인**

    설치 완료 후 Docker Desktop이 실행되면, PowerShell이나 명령 프롬프트(cmd)를 열고 아래 명령어를 실행하여 정상적으로 설치되었는지 확인합니다.

    ```bash
    # Docker 버전 확인
    docker --version

    # 테스트용 컨테이너 실행
    docker run hello-world
    ```
    `hello-world` 컨테이너가 성공적으로 실행되면 설치가 완료된 것입니다.

=== ":material-apple: macOS" 

    macOS 환경에서도 GUI 도구를 포함하는 **Docker Desktop**을 설치합니다.

    **a. 사전 요구사항**

    - macOS 최신 3개 버전 중 하나 (예: Sonoma, Ventura, Monterey)
    - Apple Silicon(M1/M2/M3) 또는 Intel 프로세서

    **b. Docker Desktop 설치**

    a.  [Docker Desktop 공식 다운로드 페이지](https://www.docker.com/products/docker-desktop/)에 접속하여 Mac용 설치 파일을 다운로드합니다. (Apple/Intel Chip에 맞는 버전 선택)
    b.  다운로드한 `Docker.dmg` 파일을 엽니다.
    c.  Docker 아이콘을 `Applications` 폴더로 드래그하여 설치를 완료합니다.

    **c. 설치 확인**

    `Applications` 폴더에서 Docker를 실행한 후, 터미널을 열고 아래 명령어로 설치를 확인합니다.

    ```bash
    # Docker 버전 확인
    docker --version

    # 테스트용 컨테이너 실행
    docker run hello-world
    ```

=== ":material-ubuntu: Linux (Ubuntu/Debian)" 

    서버 환경인 Ubuntu/Debian에서는 Docker의 공식 `apt` 저장소를 등록하여 **Docker Engine**을 설치하는 것을 권장합니다.

    **a. 이전 버전 제거 (선택 사항)**

    비공식적으로 설치된 구버전 Docker가 있다면 먼저 제거합니다.
    ```bash
    sudo apt-get remove docker docker-engine docker.io containerd runc
    ```

    **b. Docker 공식 저장소 설정**

    ```bash
    # 1. apt 패키지 업데이트 및 https 전송에 필요한 패키지 설치
    sudo apt-get update
    sudo apt-get install ca-certificates curl gnupg

    # 2. Docker의 공식 GPG 키 추가
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

    # 3. apt 저장소 정보 추가
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \ 
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \ 
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # 4. apt 패키지 목록 다시 업데이트
    sudo apt-get update
    ```

    **c. Docker Engine 설치**

    ```bash
    # 최신 버전의 Docker Engine, CLI, Containerd, Docker Compose 설치
    sudo apt-get install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    ```

    **d. 설치 후 작업 (권장)**

    매번 `sudo`를 입력하지 않고 `docker` 명령어를 사용하기 위해, 현재 사용자를 `docker` 그룹에 추가합니다.

    ```bash
    # docker 그룹에 현재 사용자 추가
    sudo usermod -aG docker $USER

    # 변경사항을 적용하려면 로그아웃 후 다시 로그인하거나 아래 명령 실행
    newgrp docker
    ```

    **e. 설치 확인**

    `sudo` 없이 테스트 컨테이너를 실행하여 설치 및 권한 설정을 확인합니다.
    ```bash
    docker run hello-world
    ```

=== ":material-fedora: Linux (RHEL/Fedora/Rocky)" 

    RHEL 계열 Linux에서는 Docker의 공식 `yum`/`dnf` 저장소를 등록하여 **Docker Engine**을 설치합니다.

    **a. 이전 버전 제거 (선택 사항)**
    ```bash
    sudo yum remove docker docker-client docker-client-latest docker-common docker-latest docker-logrotate docker-engine
    ```

    **b. Docker 공식 저장소 설정**

    ```bash
    # 1. yum-utils 설치
    sudo yum install -y yum-utils

    # 2. Docker 저장소 정보 추가
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    ```

    **c. Docker Engine 설치**

    ```bash
    # 최신 버전의 Docker Engine, CLI, Containerd 설치
    sudo yum install -y docker-ce docker-ce-cli containerd.io
    ```

    **d. Docker 서비스 시작 및 활성화**

    Linux 서버에서는 Docker 데몬을 직접 시작하고, 시스템 부팅 시 자동으로 실행되도록 설정해야 합니다.

    ```bash
    # Docker 서비스 시작
    sudo systemctl start docker

    # 시스템 부팅 시 자동 실행 설정
    sudo systemctl enable docker
    ```

    **e. 설치 후 작업 (권장)**

    Ubuntu/Debian과 마찬가지로, `sudo` 없이 `docker` 명령어를 사용하기 위해 현재 사용자를 `docker` 그룹에 추가합니다.

    ```bash
    # docker 그룹에 현재 사용자 추가
    sudo usermod -aG docker $USER

    # 변경사항을 적용하려면 로그아웃 후 다시 로그인하거나 아래 명령 실행
    newgrp docker
    ```

    **f. 설치 확인**

    `sudo` 없이 테스트 컨테이미지를 실행하여 최종 확인합니다.
    ```bash
    docker run hello-world
    ```