# JVM 설치 (OpenJDK)

이 가이드에서는 다양한 운영체제에 OpenJDK(Java Development Kit)를 설치하고 환경을 설정하는 방법을 안내합니다. OpenJDK는 무료 오픈소스 JDK 구현체이며, Java 애플리케이션을 개발하고 실행하는 데 필요한 모든 것을 제공합니다.

일반적으로 최신 LTS(Long-Term Support) 버전을 설치하는 것을 권장합니다. (예: Java 11, 17, 21 등)

---

사용 중인 운영체제에 맞는 탭을 선택하여 설치를 진행하세요.

=== "Windows"

    Windows에서는 공식 설치 파일(.msi)을 사용하거나, 수동으로 압축 파일을 해제하여 설치할 수 있습니다.

    **방법 1: 공식 설치 관리자(.msi) 사용 (권장)**

    a.  [Microsoft Build of OpenJDK](https://learn.microsoft.com/ko-kr/java/openjdk/download) 또는 [Adoptium](https://adoptium.net/temurin/releases/) 사이트에 접속합니다.
    b.  설치하려는 OpenJDK 버전(예: 21 LTS)의 `.msi` 설치 파일을 다운로드합니다.
    c.  다운로드한 파일을 실행하고, 설치 마법사의 안내에 따라 진행합니다.
    d.  설치 과정에서 **"Set JAVA_HOME variable"** 및 **"Add to PATH"** 옵션을 활성화하는 것이 좋습니다. 이 옵션들은 대부분 자동으로 선택되어 있으며, 설치 관리자가 환경 변수 설정을 자동으로 처리해 줍니다.

    **방법 2: 수동으로 설치**

    a.  위 사이트에서 `.zip` 압축 파일을 다운로드합니다.
    b.  `C:\Program Files\Java` 와 같은 원하는 경로에 압축을 해제합니다. (예: `C:\Program Files\Java\jdk-21.0.2+13`)

    **환경 변수 설정 (수동 설치 시 필수)**

    a.  `시스템 환경 변수 편집`을 검색하여 실행합니다.
    b.  `환경 변수` 버튼을 클릭합니다.
    c.  `시스템 변수` 섹션에서 `새로 만들기`를 클릭하고, 다음과 같이 `JAVA_HOME` 변수를 추가합니다.
        - **변수 이름**: `JAVA_HOME`
        - **변수 값**: JDK가 설치된 경로 (예: `C:\Program Files\Java\jdk-21.0.2+13`)
    d.  `시스템 변수` 목록에서 `Path`를 선택하고 `편집`을 클릭합니다.
    e.  `새로 만들기`를 클릭하고 `%JAVA_HOME%\bin` 을 추가한 후 `확인`을 누릅니다.

    **설치 확인**

    명령 프롬프트(cmd)나 PowerShell을 열고 아래 명령어를 실행하여 버전 정보가 올바르게 출력되는지 확인합니다.
    ```bash
    java -version
    javac -version
    ```

=== "macOS"

    macOS에서는 [Homebrew](https://brew.sh/)를 사용하는 것이 가장 간편합니다.

    **a. Homebrew 설치 (아직 없다면)**
    ```bash
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    ```

    **b. OpenJDK 설치**
    ```bash
    # 최신 버전의 OpenJDK 설치
    brew install openjdk

    # 특정 LTS 버전(예: 17)을 설치하려면
    # brew install openjdk@17
    ```

    **c. 환경 변수 설정**

    Homebrew가 설치 후 안내 메시지를 통해 심볼릭 링크(Symbolic Link)를 생성하라고 알려줄 수 있습니다. 보통 아래와 같은 명령을 실행하면 시스템의 기본 Java로 설정됩니다.
    ```bash
    # 예시: sudo ln -sfn /opt/homebrew/opt/openjdk/libexec/openjdk.jdk /Library/Java/JavaVirtualMachines/openjdk.jdk
    ```
    또한, `.zshrc` 또는 `.bash_profile` 같은 쉘 설정 파일에 `JAVA_HOME`을 추가해야 합니다.
    ```bash
    # .zshrc 파일에 JAVA_HOME 설정 추가
    echo 'export JAVA_HOME=$(/usr/libexec/java_home)' >> ~/.zshrc

    # 변경사항 적용
    source ~/.zshrc
    ```
    
    **d. 설치 확인**

    터미널을 새로 열거나, 위 `source` 명령 실행 후 아래 명령어로 설치를 확인합니다.
    ```bash
    java -version
    ```

=== "Linux (RHEL/CentOS/Rocky)"

    RHEL(Red Hat Enterprise Linux), CentOS, Rocky Linux, Oracle Linux 등 Red Hat 계열에서는 `dnf` 또는 `yum` 패키지 관리자를 사용하여 설치합니다.

    **a. OpenJDK 설치**

    `dnf` (또는 `yum`)를 사용하여 원하는 버전의 OpenJDK 개발자 패키지(`-devel`)를 설치합니다. `-devel` 패키지에는 JRE와 JDK가 모두 포함되어 있습니다.

    ```bash
    # 예시 1: 시스템의 기본 JDK 설치 (주로 안정적인 LTS 버전이 선택됨)
    sudo dnf install java-latest-openjdk-devel

    # 예시 2: 특정 버전(17)을 명시하여 설치
    # sudo dnf install java-17-openjdk-devel

    # 예시 3: 특정 버전(11)을 명시하여 설치
    # sudo dnf install java-11-openjdk-devel
    ```

    !!! tip "dnf vs yum"
        - 최신 RHEL 계열(8, 9 버전 이상)에서는 `dnf`를 사용합니다.
        - 구 버전(CentOS 7 등)에서는 `yum`을 사용합니다. 명령어는 `dnf`를 `yum`으로 바꾸면 동일하게 동작합니다.

    **b. 시스템 기본 Java 버전 변경 (선택 사항)**

    시스템에 여러 버전의 Java가 설치된 경우, `alternatives` 명령을 사용하여 기본으로 사용할 버전을 선택할 수 있습니다.

    ```bash
    # 설치된 Java 버전들과 경로 확인
    sudo alternatives --config java
    
    # 목록에서 원하는 버전의 번호를 입력하고 Enter
    ```
    위 명령은 `java`뿐 아니라 `javac` 컴파일러에 대해서도 동일하게 실행하여 버전을 맞춰주는 것이 좋습니다. (`sudo alternatives --config javac`)

    **c. 환경 변수 설정**

    `alternatives`를 통해 설정하면 대부분의 경우 `JAVA_HOME`이 자동으로 잡히지만, 명시적으로 설정하려면 `/etc/profile` 또는 개별 사용자의 `~/.bash_profile`에 추가할 수 있습니다.

    ```bash
    # .bash_profile 에 JAVA_HOME 추가
    # JAVA_HOME 경로는 'alternatives --config java' 가 보여주는 경로를 참고
    echo 'export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))' >> ~/.bash_profile
    
    # 변경사항 적용
    source ~/.bash_profile
    ```

    **d. 설치 확인**

    터미널을 열고 아래 명령어로 설치를 확인합니다.
    ```bash
    java -version
    javac -version
    ```

=== "Linux (Ubuntu/Debian)"

    Ubuntu/Debian 계열에서는 `apt` 패키지 관리자를 사용하여 쉽게 설치할 수 있습니다.

    **a. 패키지 목록 업데이트**
    ```bash
    sudo apt update
    ```

    **b. OpenJDK 설치**

    `apt` 저장소에 있는 여러 버전 중 선택하여 설치할 수 있습니다.

    ```bash
    # 기본 JDK 버전 설치 (Ubuntu 배포판이 권장하는 버전)
    sudo apt install default-jdk

    # 또는 특정 버전(예: 21)을 명시하여 설치
    # sudo apt install openjdk-21-jdk
    ```

    !!! tip "JDK vs JRE"
        - **JDK (Java Development Kit)**: 컴파일러(`javac`) 등 개발 도구를 포함합니다. 개발 환경에는 JDK를 설치해야 합니다.
        - **JRE (Java Runtime Environment)**: 이미 컴파일된 Java 애플리케이션을 '실행'만 할 때 필요합니다. 서버 환경에서 `.jar` 파일 실행이 목적이라면 `default-jre` 또는 `openjdk-21-jre`만 설치해도 충분할 수 있습니다.

    **c. 환경 변수 확인 및 설정**

    `apt`로 설치하면 대부분의 경우 `/etc/environment` 파일 등에 `JAVA_HOME`이 자동으로 설정됩니다. `printenv JAVA_HOME` 또는 `echo $JAVA_HOME` 명령으로 확인해 보세요.

    만약 설정되어 있지 않다면, `update-java-alternatives` 명령으로 시스템의 기본 Java를 설정하거나, `/etc/environment` 파일에 직접 추가할 수 있습니다.

    ```bash
    # 설치된 모든 Java 버전 확인
    update-java-alternatives --list

    # /etc/environment 파일 열기
    sudo nano /etc/environment
    # 파일 끝에 아래 내용 추가 (경로는 위 list 명령 결과에 따라 다름)
    # JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64"
    ```
    
    **d. 설치 확인**

    터미널을 열고 아래 명령어로 설치를 확인합니다.
    ```bash
    java -version
    ```

=== "Unix (AIX, Solaris, HP-UX)"

    레거시 Unix 환경에서는 각 벤더사가 제공하는 JDK나 특정 빌드를 사용해야 하는 경우가 많습니다. OpenJDK 11 이상을 기준으로 설명합니다.

    ---
    
    **IBM AIX**

    AIX 환경에서는 IBM이 직접 빌드하고 지원하는 **IBM Semeru Runtimes**를 사용하는 것이 표준입니다.

    a.  **JDK 다운로드**: [IBM Semeru Runtimes 다운로드 페이지](https://developer.ibm.com/languages/java/semeru-runtimes/downloads)에 접속하여 'AIX' 운영체제와 'ppc64' 아키텍처에 맞는 JDK 버전(예: 11)의 `.tar.gz` 파일을 다운로드합니다.
    b.  **압축 해제**: 원하는 경로(예: `/opt/java`)에 다운로드한 파일의 압축을 해제합니다.
        ```bash
        # /opt/java 디렉토리가 없다면 생성
        mkdir -p /opt/java
        cd /opt/java
        
        # 다운로드한 파일 압축 해제
        gunzip -c ibm-semeru-certified-jdk_ppc64_aix_11.0.21.0.tar.gz | tar -xf -
        ```
    c.  **환경 변수 설정**: `.profile` 또는 `/etc/profile` 파일에 `JAVA_HOME`과 `PATH`를 설정합니다.
        ```bash
        # .profile 파일에 추가
        export JAVA_HOME=/opt/java/jdk-11.0.21+9
        export PATH=$JAVA_HOME/bin:$PATH
        ```
        `jdk-11.0.21+9` 부분은 실제 압축 해제 후 생성된 디렉토리 이름으로 변경해야 합니다.
    d.  **설치 확인**: 터미널을 새로 열거나 `source ~/.profile` 명령 실행 후 버전을 확인합니다.
        ```bash
        java -version
        ```

    ---

    **Oracle Solaris**

    Solaris(x86, SPARC) 환경에서는 **Azul Zulu for Solaris** 와 같은 사전 빌드된 OpenJDK를 사용하는 것이 편리합니다.

    a.  **JDK 다운로드**: [Azul Downloads 페이지](https://www.azul.com/downloads/?os=solaris)에 접속하여 시스템 아키텍처(x86 또는 SPARC)에 맞는 JDK 버전(예: 11)의 `.tar.gz` 파일을 다운로드합니다.
    b.  **압축 해제**: AIX와 유사하게, 원하는 경로(예: `/opt/java`)에 압축을 해제합니다.
        ```bash
        mkdir -p /opt/java
        cd /opt/java
        
        gunzip -c zulu11.68.17-ca-jdk11.0.21-solaris-x64.tar.gz | tar -xf -
        ```
    c.  **환경 변수 설정**: `.profile`, `.bash_profile` 등에 `JAVA_HOME`과 `PATH`를 설정합니다.
        ```bash
        # .profile 파일에 추가
        export JAVA_HOME=/opt/java/zulu11.68.17-ca-jdk11.0.21-solaris-x64
        export PATH=$JAVA_HOME/bin:$PATH
        ```
        디렉토리 이름은 다운로드한 버전에 맞게 변경합니다.
    d.  **설치 확인**: 터미널을 새로 열어 버전을 확인합니다.
        ```bash
        java -version
        ```

    ---

    **HP-UX**

    !!! danger "지원 제한"
        HP-UX 환경에서 OpenJDK 11 이상의 공식 빌드나 신뢰할 수 있는 서드파티 빌드를 찾는 것은 매우 어렵습니다. HP는 자체적으로 구버전의 Java(예: 8)를 제공했으나, 최신 OpenJDK 버전에 대한 지원은 사실상 중단된 상태입니다.
        
        따라서 HP-UX에 Java 11 이상을 설치해야 하는 경우, 소스 코드를 직접 컴파일하는 매우 전문적인 과정이 필요하거나, 해당 OS에서의 실행을 재고해야 할 수 있습니다. 이 문서에서는 간단한 설치 방법을 제공하기 어렵습니다.
