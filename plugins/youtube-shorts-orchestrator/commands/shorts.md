---
name: shorts
description: YouTube Shorts 영상 제작 파이프라인 실행 (다국어 지원)
usage: /shorts [--topic <주제>] [--channel <young|middle|senior>] [--lang <ko|en|ja|...>] [--count <개수>] [--upload] [--visibility <public|unlisted|private>]
---

# /shorts - YouTube Shorts 제작 명령어

다국어 YouTube Shorts 채널을 위한 영상 제작 파이프라인을 실행합니다.

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

# 전체 옵션
/shorts --topic "Moon secrets" --channel young --lang en --count 3 --upload --visibility private
```

## 파라미터

| 파라미터 | 설명 | 기본값 | 예시 |
|----------|------|--------|------|
| --topic | 영상 주제 지정 | 자동 수집 | "우주", "health" |
| --channel | 타겟 채널 연령대 | 자동 결정 | young, middle, senior |
| --lang | 콘텐츠 언어 | ko | ko, en, ja, zh, es, pt, de, fr |
| --count | 생성할 영상 수 | 1 | 1-5 |
| --upload | 업로드 여부 | false | 플래그 |
| --visibility | 공개 범위 | private | public, unlisted, private |

## 채널 구조

### 연령대별 (3개)

| 채널 | 타겟 | 설명 |
|------|------|------|
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

## 워크플로우

```
/shorts 실행
    │
    ▼
Phase 0: 환경 변수 체크 ⚠️
├── .env 파일 존재 확인
├── 필수 환경 변수 검증
└── 미설정 시 → 설정 가이드 출력 후 중단
    │
    ▼
Phase 1: 초기화
├── wisdom.md 로드
├── 파라미터 파싱 (--lang 포함)
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
├── **translator (--lang != ko 시 번역)**
├── **voice-selector (언어/채널 맞춤 음성 선택)**
├── shorts-video-generator (선택된 음성으로 TTS)
└── **subtitle-generator (자막 자동 생성)**
    │
    ▼
Phase 7: Oracle 채널 결정
├── 영상별 최적 채널 매칭
└── 언어별 채널 배분
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

### 1. 한국어 빠른 테스트
```bash
/shorts --topic "신기한 과학 사실"
```
- 한국어 1개 영상 생성
- Oracle이 채널 자동 결정

### 2. 영어 버전 생성
```bash
/shorts --lang en --topic "Amazing science facts" --count 3
```
- 영어 3개 영상 생성
- 영어권 채널에 배분

### 3. 특정 채널 타겟 (다국어)
```bash
/shorts --channel middle --lang en --topic "Work-life balance" --count 3 --upload
```
- 30-50대 영어 채널 타겟
- 3개 영상 생성 및 업로드

### 4. 일본어 시니어 콘텐츠
```bash
/shorts --channel senior --lang ja --topic "健康な毎日"
```
- 60-70대 일본어 채널 타겟
- 건강 관련 콘텐츠

### 5. 풀 프로덕션 (한국어)
```bash
/shorts --count 5 --upload --visibility public
```
- 한국어 5개 영상 생성
- 자동 채널 배분
- 공개로 업로드

## 출력 예시

```
╔════════════════════════════════════════════════════════════════╗
║  🎬 SHORTS PRODUCTION COMPLETE                                 ║
╠════════════════════════════════════════════════════════════════╣
║  ✓ 언어: en (영어)                                             ║
║  ✓ 생성된 영상: 3/3                                            ║
║  ✓ 업로드 완료: 3/3                                            ║
║  ✓ 평균 품질 점수: 8.2/10                                      ║
╚════════════════════════════════════════════════════════════════╝

📊 결과 요약:
┌─────────────────────────────────────────────────────────────────┐
│ #  │ 채널           │ 제목                    │ 점수 │ URL      │
├─────────────────────────────────────────────────────────────────┤
│ 1  │ en/middle      │ NASA's Hidden Secret    │ 8.5  │ youtu.be │
│ 2  │ en/young       │ This TikTok Trend...    │ 8.0  │ youtu.be │
│ 3  │ en/senior      │ Back in My Day...       │ 8.4  │ youtu.be │
└─────────────────────────────────────────────────────────────────┘

📁 파일 위치: /tmp/shorts/session_20250112_153000/
📝 wisdom.md 업데이트 완료
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

## 에러 처리

### 환경 변수 미설정 시

```
╔════════════════════════════════════════════════════════════════╗
║  ⚠️  환경 변수 설정 필요                                        ║
╠════════════════════════════════════════════════════════════════╣
║  ❌ ELEVENLABS_API_KEY (필수 - TTS 음성 생성)                   ║
║  ❌ YOUTUBE_CLIENT_ID (업로드 시 필수)                          ║
╚════════════════════════════════════════════════════════════════╝

📋 설정 방법: README.md 참고
```

### 번역 실패 시
- 원본 한국어 스크립트로 폴백
- 경고 메시지 출력

### API 제한 시
- YouTube API 할당량 초과: 로컬 저장
- ElevenLabs 제한: 대기 후 재시도

## 주의사항

- 최대 5개 영상까지 병렬 생성 가능 (API 안정성)
- 업로드 전 영상 품질 자동 검증 (점수 7 이상만)
- 채널 ID 미설정 시 로컬 저장만 수행
- 민감한 주제는 자동 필터링
- 비영어 언어는 eleven_multilingual_v2 모델 사용
