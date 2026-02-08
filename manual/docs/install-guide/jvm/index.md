# JVM (Java Virtual Machine) 설치 및 관리 가이드

JVM(Java Virtual Machine)은 자바 애플리케이션을 실행하기 위한 핵심적인 가상 머신 환경입니다. Scala, Kotlin 등 JVM 위에서 동작하는 다른 언어로 작성된 애플리케이션(.jar 파일)을 실행하는 데도 필수적입니다. 또한, Kafka, Elasticsearch, Logstash 등 많은 고성능 서버 애플리케이션이 JVM 기반으로 동작하므로, 안정적인 시스템 운영을 위해 JVM에 대한 이해는 매우 중요합니다.

이 가이드는 다음과 같은 내용을 다룹니다.

- **[JVM 설치](./installation.md)**: 다양한 운영체제(Windows, macOS, Linux) 환경에 맞는 OpenJDK를 설치하고 환경 변수를 설정하는 방법을 안내합니다.
- **[JVM 주요 옵션](./options.md)**: 애플리케이션의 성능과 안정성에 직접적인 영향을 미치는 메모리(Heap) 설정 등 핵심 JVM 옵션을 설명합니다.
- **[GC(Garbage Collection) 관리](./gc-tuning.md)**: JVM의 자동 메모리 관리 기능인 GC의 동작 방식과 다양한 GC 종류를 이해하고, 기본적인 튜닝 방향을 알아봅니다.
- **[트러블슈팅](./troubleshooting.md)**: `OutOfMemoryError`와 같은 일반적인 문제를 진단하고, `jps`, `jstat` 등 기본 제공되는 도구를 활용하는 방법을 소개합니다.

각 섹션을 통해 시스템 환경에 맞는 JVM을 올바르게 설치하고, 운영하는 애플리케이션의 특성에 맞게 최적화하며, 문제가 발생했을 때 효과적으로 대응하는 능력을 기를 수 있습니다.