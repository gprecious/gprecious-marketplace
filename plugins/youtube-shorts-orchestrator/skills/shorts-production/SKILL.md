---
name: shorts-production
description: YouTube Shorts 영상 제작 스킬. Sisyphus 패턴 기반 병렬 파이프라인.
---

# Shorts Production Skill

YouTube Shorts 영상 제작을 위한 종합 스킬.
Sisyphus 패턴 기반으로 다중 영상 병렬 생산.

## 개요

연령대별(10~70대) 7개 채널에 최적화된 Shorts 영상을 자동 생산합니다.
신비한 이벤트 수집부터 YouTube 업로드까지 전 과정을 자동화합니다.

## 핵심 원칙

### 1. Sisyphus 패턴
- 모든 Todo 완료 전까지 중단 없음
- 피드백 루프 최대 3회 (무한 루프 방지)
- 실패해도 다른 파이프라인 계속 진행

### 2. 병렬 실행
- 최대 10개 파이프라인 동시 실행
- 독립적 작업은 항상 병렬
- 토큰 최적화로 컨텍스트 관리

### 3. 품질 보장
- 뇌과학 검증 (neuroscientist)
- 극단적 시청자 검증 (impatient-viewer)
- 점수 7/10 이상만 통과

### 4. 도파민 트리거
- Variable Reward 패턴
- 정보 공백 (Information Gap)
- 예측 위반

## 에이전트 구성

### 오케스트레이션
| 에이전트 | 역할 |
|----------|------|
| main-orchestrator | Sisyphus 패턴 전체 지휘 |
| oracle | 채널 결정 및 전략 자문 |

### 콘텐츠 생산
| 에이전트 | 역할 |
|----------|------|
| curious-event-collector | 바이럴 소재 수집 |
| scenario-writer | 시나리오 구조화 |
| script-writer | 스크립트 작성 |

### 품질 검증
| 에이전트 | 역할 |
|----------|------|
| neuroscientist | 도파민 트리거 검증 |
| impatient-viewer | 스와이프 위험 검증 |

### 영상 제작
| 에이전트 | 역할 |
|----------|------|
| shorts-video-generator | 9:16 영상 생성 |
| video-uploader | YouTube 업로드 |

### 채널 관리
| 에이전트 | 역할 |
|----------|------|
| channel-10s ~ channel-70s | 연령대별 채널 관리 |

## 워크플로우

```
Phase 1: 초기화
    │
Phase 2: 소재 수집 (병렬)
    │
Phase 3-6: VIDEO PIPELINE × N (병렬)
    ├── 시나리오 작성
    ├── 스크립트 작성
    ├── 뇌과학 검증 루프 (최대 3회)
    ├── 시청자 검증 루프 (최대 3회)
    └── 영상 생성
    │
Phase 7: Oracle 채널 결정
    │
Phase 8: 업로드 (병렬)
    │
Phase 9: 마무리
```

## 참고 문서

### references/
- shorts-algorithm.md - Shorts 알고리즘 이해
- dopamine-patterns.md - 도파민 트리거 패턴
- age-group-insights.md - 연령대별 인사이트
- viral-mechanics.md - 바이럴 메카닉스
- hooking-patterns.md - 후킹 패턴 모음

## 사용법

```bash
# 기본 실행
/shorts

# 옵션 지정
/shorts --topic "주제" --channel 30s --count 5 --upload
```

## 품질 기준

| 항목 | 기준 |
|------|------|
| 최소 점수 | 7/10 |
| 최대 재시도 | 3회 |
| 영상 길이 | 15-60초 |
| 해상도 | 1080x1920 (9:16) |

## 토큰 최적화

- XML 구조화 출력
- 파일 기반 데이터 전달
- Frontmatter 기반 의사결정
- 10개 파이프라인 동시 실행: ~9,500 토큰
