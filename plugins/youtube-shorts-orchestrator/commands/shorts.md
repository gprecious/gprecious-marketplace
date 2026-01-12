---
name: shorts
description: YouTube Shorts 영상 제작 파이프라인 실행
usage: /shorts [--topic <주제>] [--channel <연령대>] [--count <개수>] [--upload] [--visibility <public|unlisted|private>]
---

# /shorts - YouTube Shorts 제작 명령어

연령대별 YouTube Shorts 채널을 위한 영상 제작 파이프라인을 실행합니다.

## 사용법

```bash
# 기본 사용 (자동 소재 수집, 1개 영상)
/shorts

# 다중 영상 생성 (최대 5개)
/shorts --count 5

# 주제 지정
/shorts --topic "우주의 미스터리"

# 특정 채널 지정
/shorts --channel 30s "직장인 번아웃 예방법"

# 업로드 포함
/shorts --upload --visibility unlisted

# 전체 옵션
/shorts --topic "달의 비밀" --channel 20s --count 3 --upload --visibility private
```

## 파라미터

| 파라미터 | 설명 | 기본값 | 예시 |
|----------|------|--------|------|
| --topic | 영상 주제 지정 | 자동 수집 | "우주", "건강" |
| --channel | 타겟 채널 연령대 | 자동 결정 | 10s, 20s, ..., 70s |
| --count | 생성할 영상 수 | 1 | 1-5 |
| --upload | 업로드 여부 | false | 플래그 |
| --visibility | 공개 범위 | private | public, unlisted, private |

## 워크플로우

```
/shorts 실행
    │
    ▼
Phase 0: 환경 변수 체크 ⚠️
├── **프로젝트 루트**에 .env 파일 존재 확인
├── 필수 환경 변수 검증
│   ├── ELEVENLABS_API_KEY (TTS)
│   └── (--upload 시) YOUTUBE_* 변수
├── 미설정 시 → 설정 가이드 출력 후 중단
└── 설정 완료 → Phase 1 진행
    │
    ▼
Phase 1: 초기화
├── wisdom.md 로드
├── 파라미터 파싱
└── 채널 상태 확인
    │
    ▼
Phase 2: 소재 수집 (병렬)
├── curious-event-collector × count
└── 중복 제거 & 필터링
    │
    ▼
Phase 3-6: VIDEO PIPELINE × N (병렬)
├── scenario-writer → script-writer
├── neuroscientist 검증 (최대 3회)
├── impatient-viewer 검증 (최대 3회)
├── **voice-selector (스크립트 맞춤 음성 선택)**
├── shorts-video-generator (선택된 음성으로 TTS)
└── **subtitle-generator (자막 자동 생성)**
    │
    ▼
Phase 7: Oracle 채널 결정
├── 영상별 최적 채널 매칭
└── 배분 균형 고려
    │
    ▼
Phase 8: 업로드 (--upload 시)
├── video-uploader × N
└── history.json 업데이트
    │
    ▼
Phase 9: 마무리
├── wisdom.md 업데이트
└── 최종 리포트 출력
```

## 예시 시나리오

### 1. 빠른 테스트
```bash
/shorts --topic "신기한 과학 사실"
```
- 1개 영상 생성
- 업로드 없음
- Oracle이 채널 자동 결정

### 2. 대량 생산
```bash
/shorts --count 5
```
- 5개 이벤트 병렬 수집
- 5개 파이프라인 병렬 실행
- 성공한 영상만 결과 출력

### 3. 특정 채널 타겟
```bash
/shorts --channel 30s --topic "직장 생활" --count 3 --upload --visibility unlisted
```
- 30대 채널 타겟
- 3개 영상 생성
- unlisted로 업로드

### 4. 풀 프로덕션
```bash
/shorts --count 5 --upload --visibility public
```
- 5개 영상 생성
- 자동 채널 배분
- 공개로 업로드

## 출력 예시

```
╔════════════════════════════════════════════════════════════════╗
║  🎬 SHORTS PRODUCTION COMPLETE                                 ║
╠════════════════════════════════════════════════════════════════╣
║  ✓ 생성된 영상: 5/5                                            ║
║  ✓ 업로드 완료: 5/5                                            ║
║  ✓ 평균 품질 점수: 8.2/10                                      ║
╚════════════════════════════════════════════════════════════════╝

📊 결과 요약:
┌─────────────────────────────────────────────────────────────────┐
│ #  │ 채널      │ 제목                    │ 점수 │ URL          │
├─────────────────────────────────────────────────────────────────┤
│ 1  │ channel-30s│ NASA가 숨긴 달의 비밀   │ 8.5  │ youtu.be/xxx │
│ 2  │ channel-20s│ 잠을 자면 살이 빠지는 이유│ 8.0 │ youtu.be/yyy │
│ 3  │ channel-10s│ 틱톡에서 난리난 챌린지   │ 7.8  │ youtu.be/zzz │
│ 4  │ channel-40s│ 건강검진 전 이것만은     │ 8.3  │ youtu.be/aaa │
│ 5  │ channel-70s│ 예전에는 이랬는데        │ 8.4  │ youtu.be/bbb │
└─────────────────────────────────────────────────────────────────┘

📁 파일 위치: /tmp/shorts/session_20250112_153000/
📝 wisdom.md 업데이트 완료
```

## 에러 처리

### 환경 변수 미설정 시

환경 변수가 설정되지 않으면 다음과 같은 안내가 출력됩니다:

```
╔════════════════════════════════════════════════════════════════╗
║  ⚠️  환경 변수 설정 필요                                        ║
╠════════════════════════════════════════════════════════════════╣
║  다음 환경 변수가 설정되지 않았습니다:                           ║
║                                                                ║
║  ❌ ELEVENLABS_API_KEY (필수 - TTS 음성 생성)                   ║
║  ❌ YOUTUBE_CLIENT_ID (업로드 시 필수)                          ║
║  ❌ YOUTUBE_CLIENT_SECRET (업로드 시 필수)                      ║
║  ❌ YOUTUBE_REFRESH_TOKEN (업로드 시 필수)                      ║
╚════════════════════════════════════════════════════════════════╝

📋 설정 방법:

1. 프로젝트 루트에 .env 파일 생성:
   cp ~/.claude/plugins/cache/gprecious-marketplace/youtube-shorts-orchestrator/1.0.0/.env.example .env

2. .env 파일을 열어 API 키 입력:
   vi .env

3. API 키 발급:
   - ElevenLabs: https://elevenlabs.io
   - YouTube: https://console.cloud.google.com

자세한 설정 가이드는 README.md를 참고하세요.
```

### 환경 변수 체크 로직

```python
def check_env():
    required = {
        "ELEVENLABS_API_KEY": "TTS 음성 생성 (필수)",
    }

    upload_required = {
        "YOUTUBE_CLIENT_ID": "YouTube 업로드",
        "YOUTUBE_CLIENT_SECRET": "YouTube 업로드",
        "YOUTUBE_REFRESH_TOKEN": "YouTube 업로드",
    }

    optional = {
        "PEXELS_API_KEY": "스톡 영상",
        "OPENAI_API_KEY": "DALL-E 이미지",
    }

    missing = []
    for key, desc in required.items():
        if not os.getenv(key):
            missing.append(f"❌ {key} ({desc})")

    if "--upload" in args:
        for key, desc in upload_required.items():
            if not os.getenv(key):
                missing.append(f"❌ {key} ({desc})")

    if missing:
        print_setup_guide(missing)
        return False
    return True
```

### 파이프라인 실패 시
- 실패한 파이프라인은 건너뛰고 계속 진행
- 최종 리포트에 실패 원인 포함
- wisdom.md에 실패 패턴 기록

### API 제한 시
- YouTube API 할당량 초과: 업로드 건너뛰고 로컬 저장
- ElevenLabs 제한: 대기 후 재시도

## 주의사항

- 최대 5개 영상까지 병렬 생성 가능 (API 안정성)
- 업로드 전 영상 품질 자동 검증 (점수 7 이상만)
- 채널 ID 미설정 시 로컬 저장만 수행
- 민감한 주제는 자동 필터링
