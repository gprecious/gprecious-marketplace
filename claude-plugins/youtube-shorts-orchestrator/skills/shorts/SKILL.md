---
name: shorts
description: YouTube Shorts 영상 제작 파이프라인 실행 (다국어 지원)
license: MIT
compatibility: opencode
metadata:
  audience: content-creators
  workflow: youtube-shorts
---

# /shorts - YouTube Shorts 제작

YouTube Shorts 영상을 자동으로 제작하는 파이프라인을 실행합니다.

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

| 파라미터 | 설명 | 기본값 |
|----------|------|--------|
| --topic | 영상 주제 | 자동 수집 |
| --channel | 타겟 채널 (young/middle/senior) | 자동 결정 |
| --lang | 언어 (ko/en/ja/zh/es/pt/de/fr) | ko |
| --count | 생성할 영상 수 (1-5) | 1 |
| --upload | 업로드 여부 | false |
| --visibility | 공개 범위 (public/unlisted/private) | private |

## 실행 시 동작

이 스킬이 호출되면:

### Step 1: 컨텍스트 수집

현재 작업 디렉토리를 프로젝트 루트로 사용합니다.

### Step 2: 파라미터 파싱

$ARGUMENTS에서 옵션을 추출합니다.

### Step 3: main-orchestrator 호출

다음 형식으로 main-orchestrator에 위임:

```xml
<shorts_context>
  <project_root>{현재 작업 디렉토리}</project_root>
  <env_file>{현재 작업 디렉토리}/.env</env_file>
  <output_dir>{현재 작업 디렉토리}/output</output_dir>
  <history_dir>{현재 작업 디렉토리}/history</history_dir>
</shorts_context>

<parameters>
  <topic>{파싱된 값}</topic>
  <channel>{파싱된 값}</channel>
  <lang>{파싱된 값}</lang>
  <count>{파싱된 값}</count>
  <upload>{파싱된 값}</upload>
  <visibility>{파싱된 값}</visibility>
</parameters>

<user_input>$ARGUMENTS</user_input>
```

### Step 4: 결과 대기

main-orchestrator가 완료될 때까지 대기합니다.

## 환경 변수 요구사항

### 필수 (.env)

```bash
ELEVENLABS_API_KEY=xxx    # TTS (필수)
PEXELS_API_KEY=xxx        # 스톡 영상
OPENAI_API_KEY=xxx        # Sora AI 영상
```

### 업로드 시 추가 필요

```bash
YOUTUBE_CLIENT_ID=xxx
YOUTUBE_CLIENT_SECRET=xxx
YOUTUBE_REFRESH_TOKEN_KO_YOUNG=xxx  # 채널별 토큰
```

## 결과물 저장 위치

```
{project}/
├── output/                    # 최종 영상
│   └── {YYYYMMDD}_{event_id}/
│       ├── final.mp4
│       ├── script.md
│       └── metadata.json
└── history/                   # 기록 (중복 방지)
    └── global-history.json
```

## 채널 구조

| 채널 | 타겟 | 콘텐츠 |
|------|------|--------|
| young | 10-20대 | 트렌드, 밈, 자기계발 |
| middle | 30-50대 | 직장, 건강, 육아, 재테크 |
| senior | 60-70대 | 건강, 추억, 가족 |

## 지원 언어

| 코드 | 언어 | 코드 | 언어 |
|------|------|------|------|
| ko | 한국어 | es | 스페인어 |
| en | 영어 | pt | 포르투갈어 |
| ja | 일본어 | de | 독일어 |
| zh | 중국어 | fr | 프랑스어 |

---

## 사용자 입력

$ARGUMENTS