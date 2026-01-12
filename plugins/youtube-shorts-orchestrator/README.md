# YouTube Shorts Orchestrator

연령대별(10~70대) YouTube Shorts 채널을 통합 관리하는 Claude Code 플러그인.

## 개요

oh-my-opencode의 Sisyphus 패턴과 youtube-assistant의 피드백 루프 패턴을 결합하여 다중 영상 병렬 파이프라인을 구현합니다.

## 주요 기능

- 연령대별 7개 채널 통합 관리 (10대~70대)
- 신비한 이벤트 자동 수집
- 뇌과학 기반 도파민 트리거 최적화
- 극단적 시청자 페르소나 검증
- 9:16 세로 영상 자동 생성 (15-60초)
- 채널별 자동 배분 및 업로드

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
YOUTUBE_REFRESH_TOKEN=your_refresh_token

# ===== TTS (음성 생성) =====
ELEVENLABS_API_KEY=your_elevenlabs_api_key
ELEVENLABS_VOICE_ID=your_preferred_voice_id

# ===== STT (자막 생성) =====
ASSEMBLYAI_API_KEY=your_assemblyai_api_key
```

### 선택 환경 변수

```bash
# 스톡 영상 (둘 중 하나 이상)
PEXELS_API_KEY=your_pexels_api_key
PIXABAY_API_KEY=your_pixabay_api_key

# AI 이미지/영상 생성
OPENAI_API_KEY=your_openai_api_key        # DALL-E 이미지
REPLICATE_API_TOKEN=your_replicate_token   # AI 영상 생성

# 작업 디렉토리
SHORTS_WORK_DIR=/tmp/shorts
SHORTS_OUTPUT_DIR=./output
```

### 채널 ID 설정 (채널 생성 후)

```bash
CHANNEL_10S_ID=UC...
CHANNEL_20S_ID=UC...
CHANNEL_30S_ID=UC...
CHANNEL_40S_ID=UC...
CHANNEL_50S_ID=UC...
CHANNEL_60S_ID=UC...
CHANNEL_70S_ID=UC...
```

### API 키 발급 방법

| 서비스 | 발급 URL | 용도 |
|--------|----------|------|
| YouTube | [Google Cloud Console](https://console.cloud.google.com) | 영상 업로드 |
| ElevenLabs | [elevenlabs.io](https://elevenlabs.io) | TTS 음성 |
| AssemblyAI | [assemblyai.com](https://www.assemblyai.com) | 자막 생성 |
| Pexels | [pexels.com/api](https://www.pexels.com/api/) | 스톡 영상 |
| Pixabay | [pixabay.com/api](https://pixabay.com/api/docs/) | 스톡 영상 |
| OpenAI | [platform.openai.com](https://platform.openai.com) | DALL-E 이미지 |
| Replicate | [replicate.com](https://replicate.com) | AI 영상 생성 |

### YouTube OAuth 토큰 발급

1. [Google Cloud Console](https://console.cloud.google.com) 접속
2. 새 프로젝트 생성
3. **YouTube Data API v3** 활성화
4. **사용자 인증 정보** → **OAuth 2.0 클라이언트 ID** 생성
5. **OAuth 동의 화면** 설정 (테스트 사용자 추가)
6. Refresh Token 발급:

```bash
# OAuth Playground 사용
# https://developers.google.com/oauthplayground/

# 또는 CLI 도구 사용
npx google-auth-library
```

## YouTube 채널 생성

한 Google 계정으로 여러 브랜드 채널을 만들 수 있습니다.

### 채널 생성 방법

1. YouTube 우측 상단 **프로필 아이콘** 클릭
2. **"설정"** 클릭
3. **"채널 추가 또는 관리"** 클릭
4. **"채널 만들기"** 버튼 클릭
5. 채널 이름 입력 → 완료

또는 직접 접속: https://www.youtube.com/channel_switcher

### 추천 채널 이름

| 채널 | 추천 이름 예시 |
|------|---------------|
| channel-10s | 10대를 위한 신기한 세상 |
| channel-20s | 20대 브레인 업그레이드 |
| channel-30s | 30대 직장인 꿀지식 |
| channel-40s | 40대를 위한 슬기로운 생활 |
| channel-50s | 50대 인생 2막 |
| channel-60s | 60대 여유로운 하루 |
| channel-70s | 70대 행복한 일상 |

### 채널 ID 확인

1. 채널 페이지 → **YouTube Studio** → **설정** → **채널** → **고급 설정**
2. 또는 URL에서 확인: `youtube.com/channel/UC...` ← UC로 시작하는 부분이 채널 ID

## 사용법

```bash
# 기본 사용 (자동 소재 수집)
/shorts

# 다중 영상 생성 (최대 5개)
/shorts --count 5

# 주제 지정
/shorts --topic "우주의 미스터리"

# 특정 채널 지정
/shorts --channel 30s "직장인 번아웃 예방법"

# 업로드 포함 (비공개)
/shorts --upload --visibility unlisted
```

## 아키텍처

```
/shorts 트리거
    |
Phase 1: 초기화
├── wisdom.md 로드
├── global-history.json 로드 (중복 방지)
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
├── shorts-video-generator
└── subtitle-generator (자막 하드코딩)
    |
Phase 7: Oracle 채널 결정 (일괄)
    |
Phase 8: 업로드 (병렬)
├── video-uploader × N
└── history.json 업데이트 (채널별 + 전역)
    |
Phase 9: 마무리
├── wisdom.md 업데이트
└── 최종 리포트 출력
```

## 중복 방지

이미 생성한 영상과 유사한 주제는 자동으로 필터링됩니다.

### 히스토리 파일

| 파일 | 위치 | 용도 |
|------|------|------|
| global-history.json | `history/` | 전체 영상 통합 기록 |
| history.json | `channels/{channel}/` | 채널별 업로드 기록 |

### 중복 체크 규칙

| 규칙 | 조건 | 결과 |
|------|------|------|
| 제목 유사도 | 70% 이상 | 제외 |
| 키워드 중복 | 3개 이상 겹침 | 제외 |
| 주제 변형 | 같은 주제, 다른 앵글 | 허용 |

## 병렬 실행 제한

API 안정성을 위해 병렬 실행이 제한됩니다.

| 항목 | 제한 |
|------|------|
| 최대 동시 파이프라인 | 5개 |
| --count 최대값 | 5 |
| 시나리오 재작성 | 최대 3회 |
| 피드백 루프 | 최대 3회 |
| 최소 품질 점수 | 7점 |

## 에이전트

### 핵심 에이전트 (10개)
| 에이전트 | 역할 | 모델 |
|----------|------|------|
| main-orchestrator | Sisyphus 패턴 전체 지휘 | opus |
| oracle | 채널 결정 및 조율 | opus |
| curious-event-collector | 신비한 이벤트 수집 | sonnet |
| scenario-writer | 시나리오 작성 | sonnet |
| script-writer | 스크립트 작성 | sonnet |
| neuroscientist | 도파민 기반 hooking 연구 | opus |
| impatient-viewer | 쇼츠 중독 시청자 리뷰 | sonnet |
| shorts-video-generator | Shorts 영상 생성 | sonnet |
| subtitle-generator | 자막 자동 생성 (AssemblyAI) | haiku |
| video-uploader | YouTube 업로드 | haiku |

### 채널 관리 에이전트 (7개)
| 채널 | 주요 관심사 |
|------|------------|
| channel-10s | 트렌드, 밈, 게임, K-POP |
| channel-20s | 자기계발, 재테크, 연애, 취업 |
| channel-30s | 직장생활, 육아, 건강, 재테크 |
| channel-40s | 자녀교육, 건강, 노후준비, 여행 |
| channel-50s | 건강, 취미, 노후준비, 자녀 |
| channel-60s | 건강, 추억, 가족, 여유로운 삶 |
| channel-70s | 건강, 추억, 일상, 손주 |

## 토큰 최적화

다중 파이프라인 실행 시 토큰 폭발 방지:
- XML 구조화 출력 (에이전트별 300~400 토큰 제한)
- 파일 기반 데이터 전달
- Frontmatter 기반 의사결정
- 10개 파이프라인 동시 실행: ~9,500 토큰 (기존 대비 90% 절감)

## 라이선스

MIT
