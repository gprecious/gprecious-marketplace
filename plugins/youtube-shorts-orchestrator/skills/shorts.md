---
name: shorts
description: YouTube Shorts 영상 제작 파이프라인 실행 (다국어 지원)
command: /shorts
agents:
  - main-orchestrator
---

# /shorts - YouTube Shorts 제작 스킬

다국어 YouTube Shorts 채널을 위한 영상 제작 파이프라인을 실행합니다.

## 실행 방법

이 스킬은 `main-orchestrator` 에이전트를 호출하여 전체 파이프라인을 실행합니다.

### 에이전트 호출

```
Task(main-orchestrator, prompt="{user_input}")
```

### 필수 에이전트

| 에이전트 | 역할 | 모델 |
|----------|------|------|
| main-orchestrator | Sisyphus 패턴 전체 지휘 | opus |
| oracle | 초기 전략 + 긴급 자문 + 채널 결정 | sonnet |
| curious-event-collector | 신비한 이벤트 수집 | sonnet |
| scenario-writer | 시나리오 작성 | sonnet |
| script-writer | 스크립트 작성 | sonnet |
| neuroscientist | 도파민 기반 hooking 검증 | opus |
| impatient-viewer | 쇼츠 중독 시청자 리뷰 | sonnet |
| translator | 다국어 번역 + 로컬라이제이션 | sonnet |
| voice-selector | 언어/채널 맞춤 음성 선택 | haiku |
| bgm-selector | 저작권 무료 BGM 선택 | haiku |
| shorts-video-generator | Shorts 영상 생성 | sonnet |
| subtitle-generator | 자막 자동 생성 | haiku |
| video-uploader | YouTube 업로드 | haiku |

## 파라미터

| 파라미터 | 설명 | 기본값 |
|----------|------|--------|
| --topic | 영상 주제 | 자동 수집 |
| --channel | 타겟 채널 (young/middle/senior) | 자동 결정 |
| --lang | 언어 (ko/en/ja/zh/es/pt/de/fr) | ko |
| --count | 생성할 영상 수 (1-5) | 1 |
| --upload | 업로드 여부 | false |
| --visibility | 공개 범위 (public/unlisted/private) | private |

## 워크플로우

```
/shorts 트리거
    │
Phase 0: 환경 변수 체크
├── .env 파일 존재 확인
├── 필수 API 키 검증
└── 미설정 시 → 중단
    │
Phase 1: 초기화
├── wisdom.md 로드
├── global-history.json 로드 (중복 방지)
└── 파라미터 파싱
    │
Phase 2: 소재 수집 (병렬)
├── curious-event-collector × count
└── 중복 제거 & 필터링
    │
Phase 2.5: Oracle 초기 전략 자문 ⭐
├── 이벤트별 채널 힌트
├── 접근 전략 사전 조언
└── 예상 난이도 평가
    │
Phase 3-6: VIDEO PIPELINE × N (병렬)
├── scenario-writer → script-writer (oracle 힌트 반영)
├── neuroscientist 검증 (2회 실패 → oracle 긴급 자문)
├── impatient-viewer 검증 (2회 실패 → oracle 긴급 자문)
├── translator (lang != ko)
├── voice-selector
├── bgm-selector
├── shorts-video-generator
└── subtitle-generator
    │
Phase 7: Oracle 채널 결정
├── 영상별 최적 채널 매칭
└── 언어별 채널 배분
    │
Phase 8: 업로드 (--upload 시)
├── video-uploader × N
└── history.json 업데이트
    │
Phase 9: 결과물 저장 & 마무리
├── output/{date}_{event_id}/ 에 저장
│   ├── scenario.json
│   ├── script.md
│   ├── final.mp4
│   └── metadata.json
├── wisdom.md 업데이트
└── 최종 리포트 출력
```

## 실행 시 전달할 프롬프트

```
YouTube Shorts 제작 파이프라인을 실행합니다.

파라미터:
- topic: {topic 또는 "자동 수집"}
- channel: {channel 또는 "자동 결정"}
- lang: {lang}
- count: {count}
- upload: {upload}
- visibility: {visibility}

agents/ 폴더의 에이전트 정의를 참조하여 Sisyphus 패턴으로 실행하세요.
모든 Todo가 완료될 때까지 중단하지 마세요.
```

## 에이전트 파일 위치

모든 에이전트 정의는 `agents/` 폴더에 있습니다:

```
agents/
├── main-orchestrator.md
├── oracle.md
├── curious-event-collector.md
├── scenario-writer.md
├── script-writer.md
├── neuroscientist.md
├── impatient-viewer.md
├── translator.md
├── voice-selector.md
├── bgm-selector.md
├── shorts-video-generator.md
├── subtitle-generator.md
└── video-uploader.md
```

## 참고

- 최대 5개 영상 병렬 생성 (API 안정성)
- 품질 점수 7점 이상만 통과
- 비영어 언어는 eleven_multilingual_v2 모델 사용
- 최종 결과물은 반드시 output/ 폴더에 저장
