---
name: shorts
description: YouTube Shorts 영상 제작 파이프라인 실행 (다국어 지원)
usage: /shorts [--topic <주제>] [--channel <young|middle|senior>] [--lang <ko|en|ja|...>] [--count <개수>] [--upload] [--visibility <public|unlisted|private>]
---

# /shorts - YouTube Shorts 제작 명령어

YouTube Shorts 영상 제작 파이프라인을 실행합니다.

> **워크플로우 상세**: `agents/main-orchestrator.md` 참조
> main-orchestrator가 전체 파이프라인을 관장합니다.

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

## 실행 요구사항

### 필수 환경 변수 (.env)
```bash
ELEVENLABS_API_KEY=xxx    # TTS (필수)
PEXELS_API_KEY=xxx        # 스톡 영상
OPENAI_API_KEY=xxx        # Sora AI 영상 (권장)
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
    ├── global-history.json
    ├── sessions/
    └── uploads/
```

## 주의사항

- 최대 5개 영상까지 병렬 생성 가능
- 품질 점수 7점 이상만 통과
- 업로드는 순차 처리 (중복 방지)
- 채널별 YouTube 토큰 필요 (단일 토큰으로 여러 채널 업로드 불가)
