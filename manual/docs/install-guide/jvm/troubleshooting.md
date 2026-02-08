# JVM 트러블슈팅

애플리케이션을 운영하다 보면 `OutOfMemoryError`나 `StackOverflowError`와 같이 JVM과 관련된 여러 문제를 마주할 수 있습니다. 이 가이드는 일반적인 문제의 원인을 진단하고, JDK에 포함된 기본 도구를 사용하여 해결하는 방법을 소개합니다.

## 1. 일반적인 오류와 해결 방안

### `OutOfMemoryError: Java heap space`

- **원인**: 힙(Heap) 메모리가 부족하여 더 이상 새로운 객체를 할당할 수 없을 때 발생합니다. 이는 단순히 힙 크기가 작게 설정되었거나, 애플리케이션의 메모리 누수(Memory Leak)로 인해 발생할 수 있습니다.
- **해결 방안**:
  a.  **힙 크기 증가**: `-Xmx` 옵션 값을 늘려 힙 메모리의 최대 크기를 더 크게 설정합니다. (가장 간단한 임시 해결책)
      ```bash
      java -Xmx4g -jar YourApplication.jar
      ```
  b.  **힙 덤프(Heap Dump) 분석**: 근본적인 원인인 메모리 누수를 찾기 위해 힙 덤프를 분석해야 합니다. 아래 `jmap` 도구 설명을 참고하여 덤프를 생성하고, Eclipse MAT 같은 분석 도구로 어떤 객체가 메모리를 비정상적으로 점유하고 있는지 확인합니다.
      - `-XX:+HeapDumpOnOutOfMemoryError` 옵션을 JVM 시작 시 추가하면, 오류 발생 시점에 자동으로 힙 덤프 파일을 생성해 주어 편리합니다.

### `OutOfMemoryError: Metaspace`

- **원인**: Java 8 이상에서 클래스의 메타데이터를 저장하는 메타스페이스(Metaspace) 영역이 부족할 때 발생합니다. 동적으로 클래스를 계속 로딩하는 애플리케이션(예: 일부 프레임워크나 플러그인 시스템)에서 발생할 수 있습니다.
- **해결 방안**: `-XX:MaxMetaspaceSize` 옵션 값을 늘려 메타스페이스의 최대 허용 크기를 증가시킵니다.
  ```bash
  java -XX:MaxMetaspaceSize=512m -jar YourApplication.jar
  ```

### `StackOverflowError`

- **원인**: 하나의 스레드가 사용하는 스택(Stack) 메모리 영역을 모두 소진했을 때 발생합니다. 대부분의 경우, 자기 자신을 무한히 호출하는 재귀(Recursive) 함수 호출에 버그가 있을 때 발생합니다.
- **해결 방안**:
  a.  **코드 리뷰**: 스택 트레이스(Stack trace)를 확인하여 어떤 메서드가 무한히 호출되는지 찾아내고 코드의 로직을 수정하는 것이 근본적인 해결책입니다.
  b.  **스택 크기 증가**: 코드 수정이 어렵고, 정상적인 로직임에도 스택이 부족한 경우에만 `-Xss` 옵션을 사용하여 스택 크기를 늘리는 것을 고려합니다. (예: `-Xss2m`)

## 2. 기본 진단 도구

JDK의 `bin` 디렉토리에는 실행 중인 JVM을 진단하는 데 유용한 여러 커맨드라인 도구들이 포함되어 있습니다.

### `jps` (Java Virtual Machine Process Status Tool)

- **용도**: 현재 시스템에서 실행 중인 Java 프로세스들의 목록과 ID(PID)를 보여줍니다. 진단의 가장 첫 단계입니다.
- **주요 사용법**:
  ```bash
  # 기본 사용법 (PID와 Main 클래스명 표시)
  jps

  # Main 클래스의 전체 패키지명과 전달된 인자까지 표시
  jps -l -v
  ```

### `jstat` (JVM Statistics Monitoring Tool)

- **용도**: 특정 Java 프로세스의 GC 활동, 힙 영역별 사용량, 클래스 로딩 등을 실시간으로 모니터링합니다.
- **주요 사용법**:
  ```bash
  # <pid> 프로세스의 GC 상태를 1초(1000ms) 간격으로 계속 표시
  jstat -gc <pid> 1000

  # 예시 출력
  # S0C S1C S0U S1U   EC      EU      OC        OU       MC     MU    ...
  # ... (각 영역의 Capacity와 Utilization 정보가 숫자로 출력됨)
  ```

### `jmap` (Memory Map)

- **용도**: 특정 Java 프로세스의 힙 메모리 상세 정보나 힙 덤프를 파일로 생성할 때 사용합니다.
- **주요 사용법**:
  ```bash
  # <pid> 프로세스의 힙 요약 정보 출력
  jmap -heap <pid>

  # <pid> 프로세스의 현재 힙 상태를 heapdump.hprof 파일로 덤프
  jmap -dump:format=b,file=heapdump.hprof <pid>
  ```

### `jstack` (Stack Trace)

- **용도**: 특정 Java 프로세스의 모든 스레드 상태와 스택 트레이스를 출력합니다. 애플리케이션이 멈추는 현상(Hang)이나 데드락(Deadlock) 상태를 분석하는 데 결정적입니다.
- **주요 사용법**:
  ```bash
  # <pid> 프로세스의 모든 스레드 덤프를 출력
  jstack <pid>
  ```

## 3. 힙 덤프 분석 도구

`jmap`으로 생성된 힙 덤프 파일(`.hprof`)은 바이너리 파일이므로 직접 열어볼 수 없습니다. 이 파일을 분석하려면 아래와 같은 별도의 전문 도구가 필요합니다.

- **Eclipse MAT (Memory Analyzer Tool)**: 가장 널리 사용되는 강력한 힙 덤프 분석 도구입니다. 메모리 누수 용의자를 자동으로 찾아주는 기능이 뛰어납니다.
- **VisualVM**: JDK에 포함된 `jvisualvm`을 실행하거나, 별도로 설치하여 사용할 수 있는 경량 프로파일링/모니터링 도구입니다. 실시간 모니터링과 힙 덤프 분석 기능을 모두 제공합니다.
