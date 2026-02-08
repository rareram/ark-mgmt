# JVM 주요 옵션 설정

JVM으로 애플리케이션을 실행할 때, 다양한 옵션을 통해 JVM의 동작을 세밀하게 제어할 수 있습니다. 특히 메모리 관련 설정은 애플리케이션의 성능과 안정성에 직접적인 영향을 미치므로 매우 중요합니다.

이러한 옵션들은 `java` 명령어 뒤에 추가하여 사용합니다.

```bash
# 예시: 초기 힙 메모리를 256MB, 최대 힙 메모리를 1024MB로 설정하여 애플리케이션 실행
java -Xms256m -Xmx1024m -jar YourApplication.jar
```

---

## 1. 핵심 메모리 옵션

### 힙 메모리 크기 설정 (`-Xms`, `-Xmx`)

힙(Heap)은 JVM이 객체를 생성하고 관리하는 주 메모리 영역입니다.

- **`-Xms<size>`**: **초기 힙 크기 (Initial Heap Size)**
  - JVM이 시작될 때 할당하는 힙 메모리의 초기 크기를 지정합니다.
  - 예: `-Xms512m` (512 메가바이트)

- **`-Xmx<size>`**: **최대 힙 크기 (Maximum Heap Size)**
  - JVM이 최대로 사용할 수 있는 힙 메모리의 크기를 지정합니다.
  - 예: `-Xmx2g` (2 기가바이트)

!!! recommendation "권장 사항"
    **`-Xms`와 `-Xmx` 값을 동일하게 설정하는 것을 권장**합니다.
    - **이유**: 애플리케이션 실행 중에 JVM이 힙 크기를 동적으로 늘리거나 줄일 때 발생하는 불필요한 오버헤드와 Full GC를 방지할 수 있습니다. 이는 특히 서버 애플리케이션의 성능 일관성을 유지하는 데 도움이 됩니다.
    ```bash
    # 초기 힙과 최대 힙 크기를 2GB로 동일하게 설정
    java -Xms2g -Xmx2g -jar YourApplication.jar
    ```

### 스레드 스택 크기 설정 (`-Xss`)

스택(Stack)은 각 스레드(Thread)별로 생성되는 독립적인 메모리 영역으로, 메서드 호출 정보, 지역 변수 등이 저장됩니다.

- **`-Xss<size>`**: **스레드 스택 크기 (Thread Stack Size)**
  - 스레드 하나가 사용할 수 있는 스택 메모리의 최대 크기를 지정합니다.
  - 예: `-Xss1m` (1 메가바이트)

!!! warning "주의사항"
    이 값을 너무 크게 설정하면, 생성할 수 있는 전체 스레드의 수가 줄어들어 오히려 `OutOfMemoryError: unable to create new native thread` 오류가 발생할 수 있습니다. 애플리케이션이 깊은 재귀 호출 등으로 `StackOverflowError`를 발생시키는 경우가 아니라면 기본값을 사용하는 것이 일반적입니다.

### 메타스페이스 크기 설정 (`-XX:MaxMetaspaceSize`)

메타스페이스(Metaspace)는 Java 8부터 도입된 영역으로, 클래스의 메타데이터(클래스 구조, 메서드 정보 등)를 저장합니다. PermGen(Permanent Generation) 영역을 대체했으며, 네이티브 메모리(Native Memory)를 사용합니다.

- **`-XX:MaxMetaspaceSize=<size>`**: **최대 메타스페이스 크기**
  - 메타스페이스가 사용할 수 있는 네이티브 메모리의 최대 크기를 제한합니다.
  - 예: `-XX:MaxMetaspaceSize=256m`

!!! info "메타스페이스와 PermGen"
    - **PermGen (Java 7 이전)**: 힙 영역에 속해 있었고, 크기가 고정되어 `-XX:MaxPermSize` 옵션으로 설정했습니다. 이 크기를 넘어서면 `OutOfMemoryError: PermGen space`가 발생했습니다.
    - **Metaspace (Java 8 이후)**: 네이티브 메모리를 사용하므로, 별도로 크기를 지정하지 않으면 시스템의 가용 메모리까지 계속 늘어날 수 있습니다. 이로 인해 시스템 전체가 느려질 수 있으므로, 최대 크기를 설정하여 예측 가능성을 높이는 것이 좋습니다.

## 2. 기타 유용한 옵션

### Garbage Collection(GC) 알고리즘 선택

JVM은 다양한 GC 알고리즘을 제공하며, 애플리케이션의 특성에 따라 적절한 것을 선택할 수 있습니다.

- **`-XX:+UseG1GC`**: G1 (Garbage-First) GC를 활성화합니다. Java 9부터 기본 GC이며, 큰 힙 메모리와 예측 가능한 중단 시간(Pause time)이 요구되는 애플리케이션에 적합합니다.
- **`-XX:+UseParallelGC`**: Parallel GC를 활성화합니다. 처리량(Throughput)을 중시하는 배치(Batch) 작업 등에 유리합니다.
- **`-XX:+UseZGC`**: ZGC(Z Garbage Collector)를 활성화합니다. 매우 큰 힙(수백 GB ~ TB)에서도 아주 짧은 중단 시간을 목표로 하는 최신 GC입니다. (Java 11+ 실험적, Java 15+ 정식)

GC에 대한 더 자세한 내용은 **[GC(Garbage Collection) 관리](./gc-tuning.md)** 문서를 참고하세요.

### 오류 발생 시 힙 덤프 생성

`OutOfMemoryError`가 발생했을 때의 메모리 상태를 분석하기 위해 힙 덤프(Heap Dump) 파일을 자동으로 생성하게 할 수 있습니다.

- **`-XX:+HeapDumpOnOutOfMemoryError`**: `OutOfMemoryError` 발생 시 힙 덤프 파일을 생성합니다.
- **`-XX:HeapDumpPath=<path>`**: 힙 덤프 파일이 저장될 경로와 파일명을 지정합니다.
  - 예: `-XX:HeapDumpPath=/logs/heapdump.hprof`

