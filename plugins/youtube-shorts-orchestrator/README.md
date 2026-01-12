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
# 환경 변수 설정
cp .env.example .env
# .env 파일을 편집하여 API 키 입력
```

## 사용법

```bash
# 기본 사용 (자동 소재 수집)
/shorts

# 다중 영상 생성 (최대 10개)
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
Phase 1: 초기화 & 소재 수집
    |
curious-event-collector × N (최대 10개 병렬)
    |
VIDEO PIPELINE × N (병렬)
├── scenario-writer → script-writer
├── neuroscientist 검증 (최대 3회)
├── impatient-viewer 검증 (최대 3회)
└── shorts-video-generator
    |
Phase 7: Oracle 채널 결정 (일괄)
    |
Phase 8: 업로드 (병렬)
    |
Phase 9: 마무리
```

## 에이전트

### 핵심 에이전트 (9개)
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
