# CLion 초기 설정 가이드

본 가이드는 AFC 소스 코드를 로컬에 환경 구축하고, CLion의 코드 인텔리전스(자동 완성, 정의 이동 등) 기능을 활성화하기 위한 표준 절차입니다.

## 1. 소스 코드 복제 (Git Clone)

먼저 터미널을 열고 프로젝트를 복제합니다. 특정 브랜치를 바로 체크아웃합니다.

```bash
# 프로젝트 복제 및 특정 브랜치 이동
git clone -b develop/2.2.5 https://rnd.iarkdata.com/gitlab/ARK/CDC/arkcdc2.git
```

## 2. CLion에서 프로젝트 열기

1.  CLion을 실행합니다.
2.  `File -> Open`을 클릭합니다.
3.  복제한 폴더 내의 `CMakeLists.txt` 파일을 선택하고 **Open as Project**를 클릭합니다.

> **주의**: 폴더 자체를 여는 것보다 `CMakeLists.txt`를 선택해 여는 것이 정확한 프로젝트 로드를 보장합니다.

## 3. CMake 프로파일 설정 (가장 중요)

`Unsupported Database` 에러를 방지하고 인텔리전트 기능을 활성화하기 위한 핵심 단계입니다.

1.  `File -> Settings` (또는 `Ctrl+Alt+S`)로 이동합니다.
2.  `Build, Execution, Deployment -> CMake` 탭을 선택합니다.
3.  `Profiles` 항목에서 **Debug** 프로파일을 아래와 같이 설정합니다.

| 항목 | 설정 값 | 비고 |
| --- | --- | --- |
| **Build type** | `Debug` | |
| **Generator** | `Unix Makefiles` | (또는 팀 표준에 따라 Ninja) |
| **CMake options** | `-DDB_TYPE=_Oracle` | 데이터베이스 타입 지정 |
| **Build options**| `-- -j 8` | 본인 PC 코어 수에 맞게 조절 (예: 8~16) |

## 4. 환경 변수(Environment) 등록

빌드 및 라이브러리 참조를 위해 필수적인 경로를 등록해야 합니다.

1.  CMake 설정 화면의 `Environment` 필드 우측의 문서 아이콘을 클릭합니다.
2.  다음 변수들을 추가합니다.
    *   `ARKCDC_HOME`: `/home/oracle/ARKCDC` (실행 및 설치 기준 경로)
    *   `ORACLE_HOME`: `/app/oracle/product/19.0.0/dbhome_1` (오라클 설치 경로)

## 5. 설정 완료 및 확인

1.  `OK`를 눌러 설정을 저장합니다.
2.  CLion 하단의 `CMake` 탭에서 로그를 확인합니다. `Configuring done, Generating done` 문구가 뜨면 성공입니다.
3.  오른쪽 하단에 `Indexing...` 표시가 사라질 때까지 기다립니다.
4.  **확인**: 소스 코드(*.c)에서 함수 이름을 `Ctrl` + `클릭`했을 때 해당 정의로 바로 이동하는지 확인합니다.
