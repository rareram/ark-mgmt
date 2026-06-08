# CLion AI Assistant 설정 가이드

본 가이드는 CLion IDE에서 ChatGPT, Gemini 등 주요 AI 서비스를 연동하는 방법과, 내부망에서 실험적으로 운영되는 로컬 모델을 설정하는 절차를 안내합니다.

---

## 1. 주요 AI 서비스 연동 (ChatGPT & Gemini)

ChatGPT 또는 Gemini 유료 구독자를 위한 공식 연동 방법입니다. JetBrains IDE에 내장된 AI Assistant를 활용하거나 Google의 공식 플러그인을 사용할 수 있습니다.

### 1.1. JetBrains AI Assistant 연동 (권장)

IDE에 내장된 AI Assistant를 통해 여러 AI 서비스를 통합 관리하는 방식입니다.

**설정 경로**: `Settings (Ctrl+Alt+S) > Tools > AI Assistant > Models & API Keys`

1.  **경로 이동**: 위 설정 경로로 이동합니다.
2.  **서비스 선택 및 API 키 입력**:
    *   **ChatGPT 사용**:
        *   목록에서 `OpenAI`를 선택합니다.
        *   `API Key` 입력란에 ChatGPT Plus 구독을 통해 발급받은 API 키를 입력하고 `Test Connection`을 누릅니다.
    *   **Google Gemini 사용**:
        *   목록에서 `Google Gemini`를 선택합니다.
        *   Gemini API 키를 입력하면 즉시 연동됩니다.

> **더 알아보기**: JetBrains의 공식 문서를 통해 더 자세한 사용자 정의 모델 연동 방법을 확인할 수 있습니다.
> [Use custom models with AI Assistant](https://www.jetbrains.com/help/ai-assistant/use-custom-models.html)

### 1.2. Gemini Code Assist (Google 공식 플러그인)

Google Cloud 환경을 주로 사용하거나, Gemini의 모든 기능을 극대화하고 싶을 때 유용한 플러그인입니다.

1.  **플러그인 설치**: `Settings > Plugins > Marketplace` 탭에서 `"Gemini Code Assist"`를 검색하여 설치합니다.
2.  **로그인**: 설치 후 IDE 오른쪽 사이드바의 Gemini 아이콘을 통해 Google 계정으로 로그인합니다.
3.  **주요 기능**: **Full-codebase awareness (전체 프로젝트 코드 맥락 파악)**와 같은 고급 기능을 사용할 수 있어, 복잡한 프로젝트의 로직 분석이나 리팩토링에 강점이 있습니다.

> **더 알아보기**: Gemini Code Assist의 상세한 설정 및 사용법은 Google 공식 개발자 문서를 참고하세요.
> [Gemini Code Assist 설정 가이드](https://developers.google.com/gemini-code-assist/docs/set-up-gemini?hl=ko)

---

## 2. AI Agent 설정 (실험적 기능)

AI Assistant 내의 'Agent'는 단순 채팅을 넘어, 특정 목적을 가진 자동화 도구를 만들어 사용하는 기능입니다. 예를 들어, `gemini-cli`나 `opencode` 같은 CLI 도구를 IDE 내에서 에이전트로 등록할 수 있습니다.

**설정 경로**: `Settings (Ctrl+Alt+S) > Tools > AI Assistant > Agents`

### 2.1. Gemini CLI 에이전트 등록 예시

`gemini-cli`를 사용하여 현재 선택된 코드에 대한 설명을 요청하는 에이전트를 만드는 방법입니다.

1.  `Agents` 설정 화면에서 `+` 아이콘을 눌러 새 에이전트를 추가합니다.
2.  **Prompt**: 다음과 같이 프롬프트를 작성합니다.
    ```
    Explain the following code snippet using gemini-cli:
    
    ```
    {{selection}}
    ```
    ```
3.  **Agent command**: `gemini-cli -p`
4.  **저장**: 에이전트 이름을 `Explain with Gemini CLI` 등으로 저장합니다. 이제 코드 블록 선택 후 마우스 우클릭 > AI Actions 메뉴에서 해당 에이전트를 호출할 수 있습니다.

### 2.2. OpenCode 에이전트 등록 예시

`opencode`를 사용하여 코드베이스 관련 질문을 하는 에이전트를 만드는 방법입니다.

1.  새 에이전트를 추가합니다.
2.  **Prompt**:
    ```
    Answer the following question about the codebase using opencode:
    
    {{question}}
    ```
3.  **Agent command**: `opencode --ask`
4.  **저장**: 에이전트 이름을 `Ask OpenCode` 등으로 저장합니다.

---

## 3. 로컬 모델 연동 (내부 PoC)

이 설정은 서울 사무실 내부 네트워크에서만 접근 가능한 실험적인 PoC(Proof of Concept)입니다. 특정 데스크톱(RTX 5060 Ti)에서 구동되는 Ollama 서버를 사용하며, 다른 네트워크 환경(예: 대구 본사)에서는 접속할 수 없습니다.

### 3.1. Ollama (로컬 모델) 연동 방법

1.  **경로 이동**: `Settings > Tools > AI Assistant > Models & API Keys`로 이동합니다.
2.  **공급자 추가**: `Third-party AI providers` 섹션에서 `Ollama`를 선택합니다.
3.  **서버 연결**:
    *   **URL**: `http://192.168.0.78:11434`를 입력합니다.
    *   `Test Connection` 버튼을 눌러 "Success" 메시지를 확인합니다.
4.  **모델 할당**: 연결 성공 후, `Model Assignment`에서 각 기능에 사용할 로컬 모델을 지정합니다.

> **⚠️ 중요**: 이 방식은 JetBrains의 정책에 따라 **'JetBrains AI Pro' 구독이 필요**할 수 있습니다. 구독이 없는 경우, 아래의 오픈소스 플러그인을 사용하는 것이 좋습니다.

### 3.2. 역할별 추천 모델 (Ollama)

| 역할 | 추천 모델 | 이유 |
| --- | --- | --- |
| **Completion Model**<br>(실시간 코드 자동완성) | `qwen2:7b-instruct-q5_K_M` | FIM(Fill-In-the-Middle) 지원이 우수하며, C++ 코드 타이핑 시 응답 속도가 빠릅니다. |
| **Instant Helpers**<br>(코드 설명, 이름 추천 등) | `llama3:8b-instruct-q5_K_M` | 가벼워서 리소스 소모가 적고, 지연 시간이 거의 없어 간단한 요약이나 이름 생성에 쾌적한 경험을 제공합니다. |
| **Core Features**<br>(채팅, 로직 생성, 리팩토링) | `deepseek-coder-v2:16b-lite-instruct-q4_K_M` | C++ 논리 구조와 시스템 프로그래밍에 대한 이해도가 높아, 복잡한 코드 분석이나 생성 요청에 깊이 있는 답변을 제공합니다. |

---

## 4. 대안: 오픈소스 플러그인 (구독 불필요)

JetBrains 구독 없이 로컬 모델을 자유롭게 사용하고 싶다면, 아래의 오픈소스 플러그인들이 훌륭한 대안이 될 수 있습니다.

*   **Continue**: 다양한 모델을 세세하게 설정하고 관리할 수 있는 가장 강력한 오픈소스 플러그인.
*   **CodeGPT**: 설정이 간단하고 직관적인 플러그인.
