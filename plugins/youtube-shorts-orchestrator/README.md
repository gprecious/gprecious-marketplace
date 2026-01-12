# YouTube Shorts Orchestrator

다국어 YouTube Shorts 채널을 통합 관리하는 Claude Code 플러그인.

## 개요

oh-my-opencode의 Sisyphus 패턴과 youtube-assistant의 피드백 루프 패턴을 결합하여 다중 영상 병렬 파이프라인을 구현합니다.

## 주요 기능

- **다국어 지원** (ko, en, ja, zh, es, pt, de, fr)
- 연령대별 3개 채널 통합 관리 (young, middle, senior)
- 신비한 이벤트 자동 수집
- 뇌과학 기반 도파민 트리거 최적화
- 극단적 시청자 페르소나 검증
- **스크립트 자동 번역** (문화적 로컬라이제이션)
- **언어/채널 맞춤 음성 자동 선택** (ElevenLabs)
- **AI 후킹 영상 생성** (Sora/Veo로 초반 3-5초 임팩트)
- **저작권 무료 BGM 자동 선택** (Pixabay Music)
- **Shorts 스타일 자막** (2-3단어씩, Bold, 하단)
- 9:16 세로 영상 자동 생성 (15-60초)
- **채널별 토큰 분리 업로드** (YouTube API 특성 반영)

## 설치

```bash
# 플러그인 설치
claude /install youtube-shorts-orchestrator@gprecious-marketplace
```

## 환경 변수 설정

**프로젝트 루트**에 `.env` 파일을 생성하고 API 키를 설정합니다.

### .env 파일 위치

```
/your-project/           ← /shorts 명령어를 실행하는 폴더
├── .env                 ← 여기에 생성
├── output/              ← 생성된 영상 저장
└── ...
```

### 설정 방법

```bash
# 1. 프로젝트 폴더로 이동
cd /path/to/your-project

# 2. .env.example 복사
cp ~/.claude/plugins/cache/gprecious-marketplace/youtube-shorts-orchestrator/1.0.0/.env.example .env

# 3. .env 파일 편집
vi .env
```

### 필수 환경 변수

```bash
# ===== YouTube API (업로드용) =====
YOUTUBE_CLIENT_ID=your_client_id
YOUTUBE_CLIENT_SECRET=your_client_secret

# ⚠️ 채널별 Refresh Token (각 채널마다 별도 발급 필수!)
YOUTUBE_REFRESH_TOKEN_YOUNG=token_for_young_channel
YOUTUBE_REFRESH_TOKEN_MIDDLE=token_for_middle_channel
YOUTUBE_REFRESH_TOKEN_SENIOR=token_for_senior_channel

# ===== TTS (음성 생성) =====
ELEVENLABS_API_KEY=your_elevenlabs_api_key

# ===== STT (자막 생성) =====
ASSEMBLYAI_API_KEY=your_assemblyai_api_key

# ===== AI 영상 생성 (초기 후킹용) =====
OPENAI_API_KEY=your_openai_api_key  # Sora
```

### ⚠️ YouTube 채널별 토큰 발급 (중요!)

YouTube API는 **토큰 발급 시 선택한 채널에만** 업로드됩니다.
단일 토큰으로 여러 채널에 업로드할 수 없습니다.

**각 채널(young, middle, senior)마다 아래 과정을 반복하세요:**

#### 1단계: Brand Account 채널로 전환
1. [YouTube Studio](https://studio.youtube.com) 접속
2. 우측 상단 프로필 클릭 → "채널 전환"
3. **업로드할 채널 선택** (예: young 채널)

#### 2단계: OAuth 인증 URL 접속
```
https://accounts.google.com/o/oauth2/v2/auth?
  client_id=YOUR_CLIENT_ID&
  redirect_uri=http://localhost:8080&
  response_type=code&
  scope=https://www.googleapis.com/auth/youtube.upload&
  access_type=offline&
  prompt=consent
```

#### 3단계: Authorization Code → Refresh Token
```bash
curl -X POST "https://oauth2.googleapis.com/token" \
  -d "client_id=${YOUTUBE_CLIENT_ID}" \
  -d "client_secret=${YOUTUBE_CLIENT_SECRET}" \
  -d "code=${AUTHORIZATION_CODE}" \
  -d "redirect_uri=http://localhost:8080" \
  -d "grant_type=authorization_code"

# 응답의 refresh_token을 YOUTUBE_REFRESH_TOKEN_YOUNG에 저장
```

#### 4단계: 다른 채널도 반복
- middle 채널로 전환 → 인증 → `YOUTUBE_REFRESH_TOKEN_MIDDLE`
- senior 채널로 전환 → 인증 → `YOUTUBE_REFRESH_TOKEN_SENIOR`

### 채널 ID 설정 (검증용)

```bash
# 업로드 전 채널 검증용
YOUTUBE_CHANNEL_ID_YOUNG=UC...
YOUTUBE_CHANNEL_ID_MIDDLE=UC...
YOUTUBE_CHANNEL_ID_SENIOR=UC...
```

### API 키 발급 방법

| 서비스 | 발급 URL | 용도 |
|--------|----------|------|
| YouTube | [Google Cloud Console](https://console.cloud.google.com) | 영상 업로드 |
| ElevenLabs | [elevenlabs.io](https://elevenlabs.io) | TTS 음성 |
| AssemblyAI | [assemblyai.com](https://www.assemblyai.com) | 자막 생성 |
| Pexels | [pexels.com/api](https://www.pexels.com/api/) | 스톡 영상/음악 |
| Pixabay | [pixabay.com/api](https://pixabay.com/api/docs/) | 스톡 영상/음악 |
| OpenAI | [platform.openai.com](https://platform.openai.com) | Sora AI 영상 |
| Google Cloud | [console.cloud.google.com](https://console.cloud.google.com) | Veo AI 영상 |

## 사용법

```bash
# 기본 사용 (한국어, 자동 소재 수집)
/shorts

# 영어 버전 생성
/shorts --lang en

# 다중 영상 생성 (최대 5개)
/shorts --count 5

# 주제 지정
/shorts --topic "우주의 미스터리"

# 특정 채널 + 언어 지정
/shorts --channel middle --lang en "Burnout prevention tips"

# 업로드 포함 (비공개)
/shorts --upload --visibility unlisted

# 전체 옵션
/shorts --topic "Moon secrets" --channel young --lang en --count 3 --upload
```

## 지원 언어

| 코드 | 언어 | TTS 품질 | 상태 |
|------|------|---------|------|
| ko | 한국어 | ⭐⭐⭐⭐ | 기본 |
| en | 영어 | ⭐⭐⭐⭐⭐ | 지원 |
| ja | 일본어 | ⭐⭐⭐⭐ | 지원 |
| zh | 중국어 | ⭐⭐⭐⭐ | 지원 |
| es | 스페인어 | ⭐⭐⭐⭐⭐ | 지원 |
| pt | 포르투갈어 | ⭐⭐⭐⭐ | 지원 |
| de | 독일어 | ⭐⭐⭐⭐ | 지원 |
| fr | 프랑스어 | ⭐⭐⭐⭐ | 지원 |

## 채널 구조

### 연령대별 (3개)

| 채널 | 타겟 | 주요 관심사 |
|------|------|------------|
| channel-young | 10-20대 | 트렌드, 밈, 자기계발, 연애 |
| channel-middle | 30-50대 | 직장, 건강, 육아, 재테크 |
| channel-senior | 60-70대 | 건강, 추억, 가족, 여유 |

### 언어별 채널 구조

```
channels/
├── ko/                    # 한국어
│   ├── channel-young/
│   ├── channel-middle/
│   └── channel-senior/
├── en/                    # 영어
│   ├── channel-young/
│   ├── channel-middle/
│   └── channel-senior/
└── ja/                    # 일본어 (확장)
    └── ...
```

## 아키텍처

```
/shorts 트리거
    |
Phase 1: 초기화
├── wisdom.md 로드
├── global-history.json 로드 (중복 방지)
├── --lang 파라미터 파싱
└── 채널 상태 확인
    |
Phase 2: 소재 수집
├── curious-event-collector × N (최대 5개 병렬)
├── 기존 영상과 중복 체크
└── 품질 필터링
    |
Phase 3-6: VIDEO PIPELINE × N (병렬)
├── scenario-writer → script-writer
├── neuroscientist 검증 (최대 3회)
├── impatient-viewer 검증 (최대 3회)
├── translator (다국어 번역)
├── voice-selector (언어/채널 맞춤 음성 선택)
├── shorts-video-generator (선택된 음성으로 TTS)
└── subtitle-generator (자막 하드코딩)
    |
Phase 7: Oracle 채널 결정 (일괄)
├── 언어별 채널 배분
└── 연령대 매칭
    |
Phase 8: 업로드 (병렬)
├── video-uploader × N
└── history.json 업데이트 (채널별 + 전역)
    |
Phase 9: 마무리
├── wisdom.md 업데이트
└── 최종 리포트 출력
```

## 에이전트

### 핵심 에이전트 (14개)

| 에이전트 | 역할 | 모델 |
|----------|------|------|
| main-orchestrator | Sisyphus 패턴 전체 지휘 | opus |
| oracle | 채널 결정 및 조율 | opus |
| curious-event-collector | 신비한 이벤트 수집 | sonnet |
| scenario-writer | 시나리오 작성 | sonnet |
| script-writer | 스크립트 작성 | sonnet |
| neuroscientist | 도파민 기반 hooking 연구 | opus |
| impatient-viewer | 쇼츠 중독 시청자 리뷰 | sonnet |
| translator | 다국어 번역 + 로컬라이제이션 | sonnet |
| voice-selector | 언어/채널 맞춤 음성 선택 | haiku |
| bgm-selector | 저작권 무료 BGM 선택 (Pixabay) | haiku |
| shorts-video-generator | Shorts 영상 생성 (Sora/Veo + 스톡) | sonnet |
| subtitle-generator | 자막 자동 생성 (2-3단어씩) | haiku |
| video-uploader | YouTube 업로드 (채널별 토큰) | haiku |

### 채널 관리 에이전트 (3개)

| 채널 | 타겟 | 주요 관심사 |
|------|------|------------|
| channel-young | 10-20대 | 트렌드, 밈, 게임, 자기계발, 연애 |
| channel-middle | 30-50대 | 직장, 건강, 육아, 재테크, 여행 |
| channel-senior | 60-70대 | 건강, 추억, 가족, 취미, 여유 |

## 병렬 실행 제한

API 안정성을 위해 병렬 실행이 제한됩니다.

| 항목 | 제한 |
|------|------|
| 최대 동시 파이프라인 | 5개 |
| --count 최대값 | 5 |
| 시나리오 재작성 | 최대 3회 |
| 피드백 루프 | 최대 3회 |
| 최소 품질 점수 | 7점 |

## 토큰 최적화

다중 파이프라인 실행 시 토큰 폭발 방지:
- XML 구조화 출력 (에이전트별 300~400 토큰 제한)
- 파일 기반 데이터 전달
- Frontmatter 기반 의사결정
- 5개 파이프라인 동시 실행: ~5,000 토큰 (기존 대비 90% 절감)

## 라이선스

MIT
