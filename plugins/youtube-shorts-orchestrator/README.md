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
- **자막 자동 생성** (AssemblyAI)
- 9:16 세로 영상 자동 생성 (15-60초)
- 언어별 채널 자동 배분 및 업로드

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

### 채널 ID 설정

```bash
# 언어별 × 연령대별 채널 구조
# 한국어 채널
CHANNEL_KO_YOUNG_ID=UC...
CHANNEL_KO_MIDDLE_ID=UC...
CHANNEL_KO_SENIOR_ID=UC...

# 영어 채널 (확장 시)
CHANNEL_EN_YOUNG_ID=UC...
CHANNEL_EN_MIDDLE_ID=UC...
CHANNEL_EN_SENIOR_ID=UC...
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

### 핵심 에이전트 (13개)

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
| shorts-video-generator | Shorts 영상 생성 | sonnet |
| subtitle-generator | 자막 자동 생성 (AssemblyAI) | haiku |
| video-uploader | YouTube 업로드 | haiku |

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
