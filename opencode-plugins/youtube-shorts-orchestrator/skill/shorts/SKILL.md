---
name: shorts
description: YouTube Shorts 영상 제작 파이프라인 실행 (다국어 지원)
license: MIT
compatibility: opencode
metadata:
  audience: content-creators
  workflow: youtube-shorts
  complexity: advanced
  estimated_time: 30-60min
---

# /shorts - YouTube Shorts 제작 워크플로우

YouTube Shorts 영상을 자동으로 제작하는 9-phase 파이프라인.

```
┌─────────────────────────────────────────────────────────────────┐
│                    WORKFLOW ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────┤
│  INPUT: /shorts [options]                                       │
│                                                                  │
│  ┌────────────────────┐                                         │
│  │ PHASE 0: ENV CHECK │  환경 변수 검증                          │
│  └─────────┬──────────┘                                         │
│            ▼                                                     │
│  ┌────────────────────┐                                         │
│  │ PHASE 1: INIT      │  세션 초기화, 히스토리 로드               │
│  └─────────┬──────────┘                                         │
│            ▼                                                     │
│  ┌────────────────────┐                                         │
│  │ PHASE 2: COLLECT   │  소재 수집 (병렬, 최대 5개)              │
│  │ librarian          │  ← Sisyphus 기본 에이전트               │
│  │ (websearch)        │                                         │
│  └─────────┬──────────┘                                         │
│            ▼                                                     │
│  ┌────────────────────┐                                         │
│  │ PHASE 2.5: ORACLE  │  초기 전략 자문                          │
│  │ (Sisyphus 내장)    │  ← Sisyphus 기본 oracle 사용             │
│  └─────────┬──────────┘                                         │
│            ▼                                                     │
│  ┌────────────────────┐  ┌──────────────────────────────────┐   │
│  │ PHASE 3-6: VIDEO   │  │ 병렬 파이프라인 (최대 5개)        │   │
│  │ PIPELINE × N       │  │ ├─ scenario-writer               │   │
│  │                    │→ │ ├─ script-writer                 │   │
│  │                    │  │ ├─ neuroscientist (검증)         │   │
│  │                    │  │ ├─ impatient-viewer (검증)       │   │
│  │                    │  │ ├─ Sisyphus 직접 번역            │   │
│  │                    │  │ ├─ voice-selector                │   │
│  │                    │  │ ├─ bgm-selector                  │   │
│  │                    │  │ ├─ shorts-video-generator        │   │
│  │                    │  │ └─ subtitle-generator            │   │
│  └─────────┬──────────┘  └──────────────────────────────────┘   │
│            ▼                                                     │
│  ┌────────────────────┐                                         │
│  │ PHASE 7: CHANNEL   │  Oracle 채널 결정 (일괄)                 │
│  │ assign_channels    │                                         │
│  └─────────┬──────────┘                                         │
│            ▼                                                     │
│  ┌────────────────────┐                                         │
│  │ PHASE 8: UPLOAD    │  YouTube 업로드 (순차 - 락 파일)         │
│  │ video-uploader     │  ⚠️ 병렬 금지 (레이스 컨디션)            │
│  └─────────┬──────────┘                                         │
│            ▼                                                     │
│  ┌────────────────────┐                                         │
│  │ PHASE 9: FINALIZE  │  결과 저장, wisdom 업데이트              │
│  └─────────┬──────────┘                                         │
│            ▼                                                     │
│  OUTPUT: output/{date}_{event_id}/ 폴더에 최종 영상              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 사용법

```bash
# 기본 사용 (한국어, 자동 소재 수집, 1개 영상)
/shorts

# 영어 버전 생성
/shorts --lang en

# 다중 영상 생성 (최대 5개)
/shorts --count 5

# 주제 지정
/shorts --topic "우주의 미스터리"

# 특정 채널 + 언어 지정
/shorts --channel middle --lang en "Burnout prevention tips"

# 업로드 포함
/shorts --upload --visibility unlisted
```

## 파라미터

| 파라미터 | 설명 | 기본값 | 유효값 |
|----------|------|--------|--------|
| --topic | 영상 주제 | 자동 수집 | 문자열 |
| --channel | 타겟 채널 | 자동 결정 | young/middle/senior |
| --lang | 언어 | ko | ko/en/ja/zh/es/pt/de/fr |
| --count | 생성할 영상 수 | 1 | 1-5 |
| --upload | 업로드 여부 | false | flag |
| --visibility | 공개 범위 | private | public/unlisted/private |

---

## 핵심 원칙 (MUST FOLLOW)

1. **모든 Todo 완료 전까지 멈추지 않음** - 중도 포기 금지
2. **결과 검증 필수** - "서브에이전트는 거짓말한다"
3. **병렬 실행** - 독립 작업은 `background_task` 사용
4. **Phase 8 순차 실행** - 업로드는 절대 병렬 금지

---

## 시작 시 생성할 TODO (MUST)

스킬 시작 시 `todowrite`로 아래 항목 모두 생성:

```
Phase 0-1:
- 환경 변수 검증
- History 초기화

Phase 2-2.5:
- 소재 수집 ({count}개, {lang})
- Oracle 초기 전략 자문

Phase 3-6 (파이프라인 × {count}):
- 시나리오 작성 ({count}개)
- 스크립트 작성 ({count}개)
- 품질 검증 (neuroscientist + impatient-viewer)
- 음성 선택 (voice-selector)
- BGM 선택 (bgm-selector)
- 영상 생성 (shorts-video-generator):
  ├─ AI 후킹 영상 (Sora → DALL-E fallback, 0-5초)
  ├─ 스톡 영상 수집 (Pexels)
  ├─ TTS 음성 생성 (ElevenLabs)
  ├─ BGM 믹싱 (음성+배경음악)
  └─ 영상 합성 (AI후킹+스톡+오디오, 자막 없이)
- ⚠️ 자막 생성 (subtitle-generator) ← 별도 호출 필수!
  ├─ AssemblyAI STT
  ├─ SRT 생성 (2-3단어씩)
  └─ ffmpeg 하드코딩

Phase 7-9:
- 채널 결정 (Oracle)
- YouTube 업로드 ({count}개) - upload 플래그 시
- 결과물 저장 (output/)
```

### ⚠️ 흔한 실수 방지

```
shorts-video-generator 완료 후:
→ "영상 완성됐으니 다음 Phase로" ← 틀림!
→ "subtitle-generator 호출 확인" ← 맞음!

체크 순서:
1. final.mp4 존재? → shorts-video-generator 성공
2. subtitle.srt 존재? → subtitle-generator 성공
3. final.mp4에 자막 포함? → 하드코딩 성공
```

---

## Phase 0: 환경 변수 체크 [NOT STARTED]

**Agent**: 직접 실행 (Read tool)
**Dependencies**: None
**Goal**: 필수 API 키 존재 확인

### Steps

1. 현재 작업 디렉토리에서 `.env` 파일 읽기:
   ```
   Read("{CWD}/.env")
   ```

2. 필수 변수 확인:
   - `ELEVENLABS_API_KEY` (TTS 필수)
   - `OPENAI_API_KEY` 또는 `GCP_PROJECT_ID` (AI 영상)
   - `PEXELS_API_KEY` 또는 `PIXABAY_API_KEY` (스톡 영상)
   - `--upload` 시: `YOUTUBE_CLIENT_ID`, `YOUTUBE_CLIENT_SECRET`

### Success Criteria

- [ ] 필수 환경 변수 모두 존재
- [ ] 환경 변수 값이 비어있지 않음

### Error Handling

IF 필수 변수 누락:
- 누락된 변수 목록 출력
- **즉시 중단** (Phase 0 실패는 복구 불가)

---

## Phase 1: 초기화 [NOT STARTED]

**Agent**: 직접 실행
**Dependencies**: Phase 0 complete
**Goal**: 세션 초기화 및 히스토리 로드

### Steps

1. 세션 ID 생성:
   ```
   session_{YYYYMMDD}_{HHMMSS}
   ```

2. 디렉토리 변수 설정:
   ```
   PROJECT_ROOT = {현재 작업 디렉토리}
   OUTPUT_DIR = {PROJECT_ROOT}/output
   HISTORY_DIR = {PROJECT_ROOT}/history
   ```

3. 히스토리 파일 로드/초기화:
   ```
   {HISTORY_DIR}/global-history.json
   ```

4. 임시 작업 폴더 생성:
   ```
   /tmp/shorts/{session_id}/pipelines/
   ```

### Success Criteria

- [ ] 세션 ID 생성됨
- [ ] 디렉토리 경로 설정됨
- [ ] 히스토리 파일 로드됨

---

## Phase 2: 소재 수집 [NOT STARTED]

**Agent**: `librarian` (Sisyphus 기본 에이전트)
**Dependencies**: Phase 1 complete
**Pattern**: 병렬 실행 (count > 1 시)
**Goal**: 바이럴 소재 수집

> **Note**: 기존 `curious-event-collector`는 Sisyphus 내장 `librarian`으로 대체됨.
> librarian은 websearch, context7, GitHub 검색 기능을 통합 제공.

### Steps

1. **타겟 채널 결정** (현재 파라미터 기준):
   ```
   IF --channel 지정됨:
     target_channel = "{lang}-{channel}"  # 예: ko-middle
   ELSE:
     target_channels = ["{lang}-young", "{lang}-middle", "{lang}-senior"]
   ```

2. **해당 채널의 기존 주제 추출** (global-history.json > channels_index):
   ```
   exclude_topics = channels_index[target_channel].topics
   exclude_keywords = channels_index[target_channel].keywords
   
   # --channel이 auto면 해당 언어 모든 채널의 topics 합집합
   ```
   
   **중복 체크 규칙**:
   - 같은 채널에 이미 있는 주제만 제외
   - 다른 언어 채널은 같은 주제 재사용 가능

3. **librarian 호출** (exclude_topics 전달):
   ```
   background_task(
     agent="librarian",
     prompt="""
     YouTube Shorts용 바이럴 소재를 {count}개 수집하세요.
     
     [수집 카테고리]
     - 미스터리: 미해결 사건, UFO, 초자연
     - 과학: 새로운 발견, 반직관적 사실
     - 역사: 숨겨진 역사, 흥미로운 사실
     - 심리: 인간 행동, 뇌과학
     - 트렌드: 현재 화제
     
     [제외 주제]: {exclude_topics}
     [언어]: {lang}
     [출력 형식]: XML (event id, title, category, hook, viral_potential)
     """
   )
   ```

4. --topic이 지정된 경우:
   - 수집 건너뛰고 지정된 주제 사용
   - 단, exclude_topics에 해당 주제가 있으면 경고 출력

### Output Format

```xml
<task_result agent="librarian" type="material_collection">
  <summary>5개 이벤트 수집 완료</summary>
  <events>
    <event id="evt_001">
      <title>달의 뒷면에서 발견된 이상한 구조물</title>
      <category>미스터리</category>
      <hook>NASA가 숨기려 했던 사진이 유출됐습니다</hook>
      <viral_potential>9/10</viral_potential>
    </event>
  </events>
</task_result>
```

### Success Criteria

- [ ] 요청한 수만큼 이벤트 수집
- [ ] 중복 주제 없음
- [ ] viral_potential >= 7

---

## Phase 2.5: Oracle 초기 전략 [NOT STARTED]

**Agent**: Sisyphus 내장 `oracle` (GPT-5.2 급 추론)
**Dependencies**: Phase 2 complete
**Goal**: 이벤트별 채널 힌트 및 접근 전략

> **Note**: 기존 플러그인 `oracle.md`는 Sisyphus 내장 oracle로 대체됨.
> Sisyphus oracle은 더 강력한 추론 능력과 전략적 판단력을 제공.

### Steps

1. Sisyphus oracle 호출 (초기 전략):
   ```
   task(
     agent="oracle",
     prompt="""
     YouTube Shorts 초기 전략을 수립하세요.
     
     [채널 프로필]
     - channel-young (10-20대): 트렌드, 밈, 자기계발, 연애 | 빠르고 친근
     - channel-middle (30-40대): 직장, 육아, 건강, 재테크 | 실용적, 공감
     - channel-senior (50대+): 건강, 추억, 가족, 여유 | 여유롭고 따뜻
     
     [수집된 이벤트]: {events}
     [언어]: {lang}
     
     각 이벤트별로:
     1. 채널 힌트 (confidence 포함)
     2. 접근 전략 (톤앤매너, 스타일)
     3. 난이도 평가
     """
   )
   ```
   
   **Note**: 중복 체크는 Phase 2에서 이미 처리됨. Oracle은 순수하게 전략만 제공.

### Output Format

```xml
<task_result agent="sisyphus-oracle" type="initial_strategy">
  <summary>5개 이벤트 전략 수립 완료</summary>
  <strategies>
    <strategy event_id="evt_001">
      <channel_hint confidence="0.8">channel-young</channel_hint>
      <approach>트렌디한 밈 스타일, 빠른 컷 전환</approach>
      <difficulty>medium</difficulty>
    </strategy>
  </strategies>
</task_result>
```

### Success Criteria

- [ ] 모든 이벤트에 전략 수립됨
- [ ] 채널 힌트 제공됨

---

## Phase 3-6: 비디오 파이프라인 [NOT STARTED]

**Pattern**: FAN-OUT (병렬 실행, 최대 5개)
**Dependencies**: Phase 2.5 complete
**Goal**: 각 이벤트별 영상 생성

### 파이프라인 구성

각 이벤트(evt_001, evt_002, ...)에 대해 순차 실행:

#### Step 3a: 시나리오 작성

**Agent**: `scenario-writer`
```
task(
  agent="scenario-writer",
  prompt="event={event}, oracle_hint={hint}"
)
```

**Output**:
```xml
<task_result agent="scenario-writer" event_id="evt_001">
  <summary>15-60초 시나리오 작성 완료</summary>
  <scenario>
    <duration>45</duration>
    <sections>
      <hook seconds="0-5">충격적인 오프닝</hook>
      <build seconds="5-30">긴장감 조성</build>
      <payoff seconds="30-45">결론 및 반전</payoff>
    </sections>
    <dopamine_triggers>mystery, curiosity_gap, variable_reward</dopamine_triggers>
  </scenario>
  <file_ref>/tmp/shorts/{session}/pipelines/evt_001/scenario.json</file_ref>
</task_result>
```

#### Step 3b: 스크립트 작성

**Agent**: `script-writer`
```
task(
  agent="script-writer",
  prompt="scenario={scenario}"
)
```

**Output**:
```xml
<task_result agent="script-writer" event_id="evt_001">
  <summary>스크립트 작성 완료 (450자)</summary>
  <script>
    <opening>"이 사진을 보세요. NASA가 50년간 숨겨왔습니다."</opening>
    <body>...</body>
    <closing>...</closing>
  </script>
  <file_ref>/tmp/shorts/{session}/pipelines/evt_001/script.md</file_ref>
</task_result>
```

#### Step 4: 뇌과학 검증

**Agent**: `neuroscientist`
```
task(
  agent="neuroscientist",
  prompt="script={script}"
)
```

**Validation Logic**:
```
IF score < 7:
  IF attempt < 3:
    → Sisyphus oracle 긴급 자문 (emergency_consult)
    → script-writer 재작성 (피드백 반영)
    → 재검증
  ELSE:
    → 최선의 버전으로 진행 (경고 출력)
```

#### Step 5: 시청자 검증

**Agent**: `impatient-viewer`
```
task(
  agent="impatient-viewer",
  prompt="script={script}"
)
```

**Validation Logic**: Step 4와 동일 (3회 실패 시 경고와 함께 진행)

#### Step 5.5: 번역 (lang != ko 시)

**Agent**: Sisyphus 직접 처리 (별도 에이전트 불필요)

> **Note**: 기존 `translator` 에이전트는 Sisyphus가 직접 처리하도록 변경됨.
> 번역은 LLM의 기본 기능이며, 로컬라이제이션 원칙을 프롬프트에 포함.

```
IF lang != "ko":
  # Sisyphus가 직접 번역 수행 (에이전트 호출 불필요)
  번역 시 다음 원칙 적용:
  1. 문화적 레퍼런스 → 현지 이해 가능한 비유로 대체
  2. 유머 → 현지 유머 코드에 맞게 조정
  3. 숫자/단위 → 현지 단위로 변환 (kg, miles 등)
  4. 톤앤매너 → 언어별 적절한 격식체 적용
  
  지원 언어:
  - en: 영어 (글로벌 표준)
  - ja: 일본어 (경어 체계 고려)
  - zh: 중국어 (간체/번체 구분)
  - es: 스페인어 (라틴아메리카/스페인 차이)
  - pt: 포르투갈어 (브라질/포르투갈 차이)
  - de: 독일어 (격식체)
  - fr: 프랑스어 (격식체)
```

#### Step 6a: 음성 선택

**Agent**: `voice-selector`

> ⚠️ **한국어(ko)**: 반드시 `script_concept`을 전달하여 2-Tier 선택 활성화
> - Tier 1: ElevenLabs API 동적 검색 (스크립트 톤/무드 기반)
> - Tier 2: Fallback 목록 (API 실패 시)

```
task(
  agent="voice-selector",
  prompt="""
    script={script}
    lang={lang}
    channel={channel_hint}
    script_concept={
      "tone": "{scenario_tone}",      # energetic | professional | warm | friendly | calm
      "topic": "{event_title}",
      "gender": null                   # male | female | null (자동 선택)
    }
  """
)
```

**tone 결정 기준** (scenario에서 추출):
| 채널 | 기본 tone | 조정 조건 |
|------|----------|----------|
| young | energetic | 감성적 주제 → friendly |
| middle | professional | 건강/가족 주제 → warm |
| senior | warm | 정보성 주제 → calm |

**Output**:
```xml
<task_result agent="voice-selector">
  <summary>voice_id 선택: Taemin (따뜻하고 자연스러움)</summary>
  <voice_id>Ir7oQcBXWiq4oFGROCfj</voice_id>
  <method>api_search</method>  <!-- api_search | fallback -->
  <settings>
    <model_id>eleven_multilingual_v2</model_id>
    <stability>0.35</stability>
    <similarity_boost>0.75</similarity_boost>
    <speed>1.15</speed>
  </settings>
  <selection_log>
    <tier_1_query>korean young energetic bright</tier_1_query>
    <tier_1_result>success</tier_1_result>
  </selection_log>
</task_result>
```

#### Step 6b: BGM 선택

**Agent**: `bgm-selector`
```
task(
  agent="bgm-selector",
  prompt="script={script}, mood={scenario_mood}"
)
```

#### Step 6c: 영상 생성 (자막 없이)

**Agent**: `shorts-video-generator`
```
task(
  agent="shorts-video-generator",
  prompt="script={script}, voice_id={voice_id}, bgm_path={bgm_path}"
)
```

**Process**:
1. AI 후킹 영상 생성 (0-5초)
   - **Primary**: Sora API (OPENAI_API_KEY)
   - **Fallback**: DALL-E 3 이미지 + Ken Burns 효과 (줌인/패닝)
   - ⚠️ Sora API 미응답 또는 비활성화 시 자동 fallback
2. TTS 음성 생성 (ElevenLabs)
3. 스톡 영상 수집 (Pexels/Pixabay)
4. BGM 믹싱 (음성+배경음악)
5. 영상 합성 (9:16, 15-60초) - **자막 없이 출력**

**Output**: `/tmp/shorts/{session}/pipelines/{event_id}/output/final.mp4` (자막 미포함)

#### Step 6d: 자막 생성 및 하드코딩 ⚠️ 필수 별도 호출

**Agent**: `subtitle-generator`
**Dependencies**: Step 6c 완료 (final.mp4 존재)
**⚠️ CRITICAL**: shorts-video-generator와 별도로 반드시 호출해야 함!

```
task(
  agent="subtitle-generator",
  prompt="video_path=/tmp/shorts/{session}/pipelines/{event_id}/output/final.mp4, lang={lang}"
)
```

**Process**:
1. AssemblyAI로 음성 → 텍스트 변환 (STT)
2. Shorts 스타일 SRT 생성 (2-3단어씩, Bold)
3. ffmpeg로 자막 하드코딩
4. 최종 영상 덮어쓰기 (final.mp4 → 자막 포함)

**Output**: 
- `/tmp/shorts/{session}/pipelines/{event_id}/subtitle.srt`
- `/tmp/shorts/{session}/pipelines/{event_id}/output/final.mp4` (자막 포함)

### 파이프라인 병렬 실행

```
# 각 이벤트를 독립 파이프라인으로 병렬 실행
FOR event IN events:
  background_task(
    agent="pipeline-executor",  # 개념적 - 실제로는 순차 에이전트 호출
    prompt="Execute steps 3a-6d for event={event}"
  )
```

### Success Criteria

- [ ] 모든 이벤트에 대해 최종 영상 생성
- [ ] **Step 6d (subtitle-generator) 호출 완료** ← 별도 확인 필수!
- [ ] 자막 파일 존재: `/tmp/shorts/{session}/pipelines/{event_id}/subtitle.srt`
- [ ] 자막 하드코딩 완료 (final.mp4에 자막 포함)
- [ ] /tmp/shorts/{session}/pipelines/{event_id}/output/final.mp4 존재

### ⚠️ 검증 체크 (Phase 6 완료 시)

shorts-video-generator 완료 후 **반드시** 확인:
```bash
# 자막 파일 존재 확인
ls /tmp/shorts/{session}/pipelines/{event_id}/subtitle.srt

# 자막이 영상에 하드코딩되었는지 확인 (ffprobe)
ffprobe -i final.mp4 -show_streams 2>&1 | grep subtitle
```

**자막 파일 없으면**: subtitle-generator 누락 → 즉시 호출

---

## Phase 7: Oracle 채널 결정 [NOT STARTED]

**Agent**: Sisyphus 내장 `oracle`
**Dependencies**: All Phase 6 pipelines complete
**Goal**: 최종 채널 배정

> **Note**: Sisyphus 내장 oracle을 사용하여 채널 배정 결정.

### Steps

1. 모든 완료된 영상 수집

2. Sisyphus oracle 호출 (채널 배정):
   ```
   task(
     agent="oracle",
     prompt="""
     완성된 YouTube Shorts 영상들의 최적 채널을 결정하세요.
     
     [채널 프로필]
     - channel-young (10-20대): 트렌드, 밈, 자기계발, 연애 | 빠르고 친근
     - channel-middle (30-40대): 직장, 육아, 건강, 재테크 | 실용적, 공감
     - channel-senior (50대+): 건강, 추억, 가족, 여유 | 여유롭고 따뜻
     
     [완료된 영상]: {videos}
     [언어]: {lang}
     
     각 영상별로:
     1. 최적 채널 (confidence 포함)
     2. 배정 이유
     3. 채널 간 균형 고려
     """
   )
   ```
   
   **Note**: 중복 체크는 Phase 2 수집 단계에서 이미 처리됨.
   Oracle은 주제 적합성과 연령대 매칭만 고려하여 채널 결정.

### Output Format

```xml
<task_result agent="sisyphus-oracle" type="assign_channels">
  <summary>5개 영상 채널 배정 완료</summary>
  <assignments>
    <assignment video_id="evt_001">
      <channel confidence="0.9">channel-young</channel>
      <reasoning>트렌디한 주제, 빠른 템포</reasoning>
    </assignment>
  </assignments>
</task_result>
```

### Success Criteria

- [ ] 모든 영상에 채널 배정됨
- [ ] 채널별 균형 고려됨

---

## Phase 8: YouTube 업로드 [NOT STARTED]

**Agent**: `video-uploader`
**Dependencies**: Phase 7 complete AND --upload flag
**Pattern**: **순차 실행 (병렬 금지!)**
**Goal**: YouTube 업로드

### ⚠️ Critical Constraint

```
업로드는 반드시 순차 실행!
병렬 업로드 시 레이스 컨디션으로 히스토리 충돌 발생
락 파일 사용: {HISTORY_DIR}/.upload.lock
```

### Steps

1. 락 파일 확인/생성:
   ```bash
   if [ -f "{HISTORY_DIR}/.upload.lock" ]; then
     # 대기 (최대 5분)
   fi
   touch "{HISTORY_DIR}/.upload.lock"
   ```

2. 각 영상 순차 업로드:
   ```
   FOR video IN assigned_videos:
     task(
       agent="video-uploader",
       prompt="video={video}, channel={channel}, visibility={visibility}"
     )
     # 히스토리 즉시 업데이트
   ```

3. 락 파일 해제:
   ```bash
   rm "{HISTORY_DIR}/.upload.lock"
   ```

### Success Criteria

- [ ] 모든 영상 업로드 성공
- [ ] 히스토리 업데이트 완료
- [ ] 락 파일 해제됨

### Skip Condition

IF --upload 플래그 없음:
- Phase 8 건너뛰기
- 로컬 저장만 수행

---

## Phase 9: 결과 저장 [NOT STARTED]

**Agent**: 직접 실행
**Dependencies**: Phase 7 (또는 Phase 8) complete
**Goal**: 최종 결과물 아카이빙

### Steps

1. 결과물 이동:
   ```bash
   mkdir -p "{OUTPUT_DIR}/{YYYYMMDD}_{event_id}"
   mv /tmp/shorts/{session}/pipelines/{event_id}/* "{OUTPUT_DIR}/{YYYYMMDD}_{event_id}/"
   ```

2. 메타데이터 생성:
   ```json
   // {OUTPUT_DIR}/{YYYYMMDD}_{event_id}/metadata.json
   {
     "event_id": "evt_001",
     "title": "달의 뒷면에서 발견된 이상한 구조물",
     "channel": "channel-young",
     "lang": "ko",
     "duration": 45,
     "created_at": "2025-01-13T11:40:00Z",
     "uploaded": true,
     "youtube_url": "https://youtube.com/shorts/xxx"
   }
   ```

3. 글로벌 히스토리 업데이트:
   ```json
   // {HISTORY_DIR}/global-history.json에 추가
   {
     "event_id": "evt_001",
     "title": "달의 뒷면에서 발견된 이상한 구조물",
     "created_at": "2025-01-13T11:40:00Z"
   }
   ```

4. 세션 로그 저장:
   ```
   {HISTORY_DIR}/sessions/{session_id}.json
   ```

5. 임시 폴더 정리:
   ```bash
   rm -rf /tmp/shorts/{session_id}
   ```

### Success Criteria

- [ ] 모든 결과물 output/에 저장됨
- [ ] 메타데이터 파일 생성됨
- [ ] 히스토리 업데이트됨
- [ ] 임시 파일 정리됨

---

## 서브에이전트 목록

### Sisyphus 기본 에이전트 (대체됨)

| 에이전트 | 역할 | 대체 전 | Phase |
|----------|------|---------|-------|
| **librarian** | 소재 수집 (websearch) | curious-event-collector | 2 |
| **oracle** | 전략 자문 + 채널 결정 | oracle.md | 2.5, 4, 5, 7 |
| (Sisyphus 직접) | 다국어 번역 | translator.md | 5.5 |

### 플러그인 커스텀 에이전트 (유지)

| 에이전트 | 역할 | 모델 | Temp |
|----------|------|------|------|
| scenario-writer | 시나리오 작성 | sonnet | 0.6 |
| script-writer | 스크립트 작성 | sonnet | 0.5 |
| neuroscientist | 뇌과학 검증 | sonnet | 0.3 |
| impatient-viewer | 시청자 검증 | sonnet | 0.5 |
| voice-selector | ElevenLabs 음성 선택 | haiku | 0.2 |
| bgm-selector | Pixabay BGM 선택 | haiku | 0.2 |
| shorts-video-generator | 영상 생성 | sonnet | 0.3 |
| subtitle-generator | AssemblyAI 자막 | haiku | 0.2 |
| video-uploader | YouTube 업로드 | haiku | 0.1 |

---

## 상수

```
MAX_EVENTS = 5
MAX_SCENARIO_ITERATIONS = 3
MAX_FEEDBACK_ITERATIONS = 3
MIN_SCORE = 7
```

---

## 에러 복구

| 에러 | Phase | 복구 액션 |
|------|-------|-----------|
| 환경 변수 누락 | 0 | **즉시 중단** (복구 불가) |
| 소재 수집 실패 | 2 | 재시도 3회, 실패 시 중단 |
| 검증 점수 < 7 | 4, 5 | Oracle 긴급 자문 → 재작성 (최대 3회) |
| TTS 실패 | 6c | 대체 voice_id로 재시도 |
| 업로드 실패 | 8 | 재시도 3회, 실패 시 로컬 저장 |

---

## 검증 체크리스트 (Phase 완료 시)

각 Phase 완료 후 확인:

- [ ] 예상 출력 파일 존재
- [ ] 에러 없음
- [ ] 다음 Phase 진행 가능

---

## 사용자 입력

$ARGUMENTS
