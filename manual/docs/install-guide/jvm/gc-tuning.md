# GC(Garbage Collection) 관리

Garbage Collection(GC)은 JVM의 핵심 기능 중 하나로, 프로그래머가 직접 메모리를 해제하지 않아도 JVM이 알아서 더 이상 사용되지 않는 객체(Garbage)를 찾아내어 메모리에서 제거하는 자동 메모리 관리 프로세스입니다.

## 1. GC의 기본 개념

### Stop-the-World

GC를 실행하기 위해, JVM은 애플리케이션 실행을 일시적으로 멈춥니다. 이 멈춤 현상을 **'Stop-the-World'** 라고 부릅니다. 모든 GC 알고리즘은 정도의 차이가 있을 뿐 이 과정을 포함하며, 'Stop-the-World' 시간이 길어질수록 애플리케이션의 응답 시간 저하, 타임아웃 등의 문제로 이어질 수 있습니다. 따라서 좋은 GC 알고리즘은 이 시간을 최소화하는 것을 목표로 합니다.

### 힙(Heap)의 구조와 세대 가설 (Generational Hypothesis)

대부분의 GC는 **세대 가설**에 기반하여 힙 메모리를 여러 영역으로 나누어 관리합니다.

a.  **대부분의 객체는 금방 접근 불가능 상태(Unreachable)가 된다.**
b.  **오래 살아남은 객체에서 젊은 객체로의 참조는 아주 적게 존재한다.**

이 가설에 따라 힙은 크게 **Young Generation**과 **Old Generation**으로 나뉩니다.

- **Young Generation**:
  - 새롭게 생성된 객체들이 할당되는 영역입니다.
  - 이 영역에서 발생하는 GC를 **Minor GC**라고 부릅니다. Minor GC는 매우 빈번하고 빠르게 발생합니다.
  - Young 영역은 다시 **Eden** 영역과 두 개의 **Survivor** 영역으로 나뉩니다.
    a.  새 객체는 Eden에 할당됩니다.
    b.  Minor GC가 발생하면, 살아남은 객체는 Survivor 영역 중 하나로 이동합니다.
    c.  이 과정을 여러 번 반복하며 계속 살아남은 객체는 결국 Old Generation으로 이동(Promotion)됩니다.

- **Old Generation**:
  - Young Generation에서 오랫동안 살아남은 객체들이 존재하는 영역입니다.
  - 이 영역이 꽉 차면 **Major GC** (또는 **Full GC**)가 발생합니다. Major GC는 일반적으로 Minor GC보다 훨씬 오래 걸리며, 'Stop-the-World' 시간이 길어 시스템 전체 성능에 큰 영향을 미칩니다.

!['세대별 GC'](https://raw.githubusercontent.com/rareram/manual_mkdocs/main/docs/assets/images/generational-gc.png)
*(이미지: 세대별 가비지 컬렉션 동작 원리)*

## 2. GC 성능 지표

GC 튜닝의 목표는 주로 아래 두 가지 상충 관계(Trade-off)에 있는 지표를 조율하는 것입니다.

- **처리량 (Throughput)**: 전체 실행 시간 중 GC에 소요되는 시간을 제외한, 즉 순수하게 애플리케이션 코드 실행에 사용되는 시간의 비율입니다. (예: 100분 중 GC 시간이 1분이면 처리량은 99%)
- **응답 시간/지연 (Latency)**: 'Stop-the-World'로 인해 애플리케이션이 멈추는 시간입니다. 웹 애플리케이션처럼 사용자와의 상호작용이 중요한 시스템에서는 이 시간이 짧아야 합니다.

처리량을 높이는 GC는 지연 시간이 길어질 수 있고, 지연 시간을 줄이는 GC는 잦은 GC로 인해 처리량이 낮아질 수 있습니다.

## 3. 주요 GC 종류

JVM은 다양한 GC 알고리즘을 제공하며, `-XX:+Use<GC_Name>` 옵션을 통해 선택할 수 있습니다.

| GC 종류 | JVM 옵션 | 특징 및 주 사용처 |
| :--- | :--- | :--- |
| **Serial GC** | `-XX:+UseSerialGC` | - GC를 1개의 스레드로만 처리<br>- 'Stop-the-World' 시간이 김<br>- **사용처**: 클라이언트 PC, 아주 작은 힙 메모리를 사용하는 간단한 애플리케이션 |
| **Parallel GC** | `-XX:+UseParallelGC` | - **처리량(Throughput) 중시형 GC**<br>- Young/Old 영역 GC를 모두 여러 스레드로 처리<br>- Java 8의 기본 GC<br>- **사용처**: 데이터 처리, 배치 작업 등 응답 시간보다 전체 처리량이 중요한 시스템 |
| **G1 GC** | `-XX:+UseG1GC` | - **응답 시간 중시형 GC**<br>- 힙을 여러 개의 작은 영역(Region)으로 나누어 관리<br>- 예측 가능한 'Stop-the-World' 시간을 목표로 함<br>- Java 9부터 기본 GC<br>- **사용처**: 웹 서버 등 대부분의 현대 서버 애플리케이션 |
| **ZGC** | `-XX:+UseZGC` | - **초저지연(Ultra Low-Latency) GC**<br>- 수백 GB ~ TB 단위의 매우 큰 힙에서도 수 밀리초(ms) 이내의 'Stop-the-World'를 목표로 함<br>- Java 15부터 정식 지원<br>- **사용처**: 금융 거래 시스템 등 응답 시간이 극도로 중요한 대용량 메모리 시스템 |

## 4. 기본 튜닝 가이드

GC 튜닝은 매우 전문적인 영역이지만, 가장 효과적인 튜닝은 **애플리케이션의 특성에 맞는 올바른 GC를 선택하고 적절한 힙 크기를 지정**하는 것에서 시작됩니다.

a.  **힙 크기 조절이 최우선**: 대부분의 GC 성능 문제는 힙 메모리가 너무 작거나 너무 크게 설정되었을 때 발생합니다. [JVM 주요 옵션](./options.md) 가이드를 참고하여 `-Xms`와 `-Xmx` 값을 적절하게 설정하는 것이 가장 중요합니다.

b.  **GC 알고리즘 변경 고려**: 현재 GC의 응답 시간(Latency)이 문제가 된다면 G1 GC나 ZGC 도입을 고려해볼 수 있습니다. 반대로 처리량(Throughput)이 중요하다면 Parallel GC를 유지하거나 변경할 수 있습니다.

c.  **목표 중단 시간 설정 (G1 GC)**: G1 GC를 사용한다면, `-XX:MaxGCPauseMillis=<ms>` 옵션으로 목표 'Stop-the-World' 시간을 JVM에 제시할 수 있습니다. JVM은 이 목표를 맞추기 위해 Young Generation의 크기 등을 동적으로 조절합니다. (이 값이 너무 낮으면 오히려 GC가 너무 자주 발생하여 전체 성능이 저하될 수 있습니다.)

d.  **GC 로깅 활성화**: `-Xlog:gc*:file=gc.log` 와 같은 옵션으로 GC 로그를 활성화하여 실제 GC 동작을 모니터링하는 것이 튜닝의 첫걸음입니다.

!!! warning "과도한 튜닝은 금물"
    JVM과 GC는 매우 지능적으로 동작하도록 발전해왔습니다. 대부분의 경우, 기본 GC(G1)와 적절한 힙 크기 설정만으로도 충분한 성능을 냅니다. 명확한 성능 문제와 데이터 분석 없이 세부 옵션을 튜닝하는 것은 오히려 성능을 악화시킬 수 있습니다.
