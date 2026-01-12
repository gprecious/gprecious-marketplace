---
name: shorts-production
description: YouTube Shorts 제작 참조 문서 모음
---

# Shorts Production 참조 문서

YouTube Shorts 영상 제작을 위한 참조 문서 모음입니다.

> **실행**: `/shorts` 명령어 사용
> **워크플로우**: `agents/main-orchestrator.md` 참조

## 참조 문서 (references/)

| 문서 | 설명 |
|------|------|
| shorts-algorithm.md | Shorts 알고리즘 이해 |
| dopamine-patterns.md | 도파민 트리거 패턴 |
| age-group-insights.md | 연령대별 인사이트 |
| viral-mechanics.md | 바이럴 메카닉스 |
| hooking-patterns.md | 후킹 패턴 모음 |

## 품질 기준

| 항목 | 기준 |
|------|------|
| 최소 점수 | 7/10 |
| 최대 재시도 | 3회 |
| 영상 길이 | 15-60초 |
| 해상도 | 1080x1920 (9:16) |

## 에이전트 구성

### 오케스트레이션
- main-orchestrator: Sisyphus 패턴 전체 지휘
- oracle: 초기 전략 + 긴급 자문 + 채널 결정

### 콘텐츠 생산
- curious-event-collector: 바이럴 소재 수집
- scenario-writer: 시나리오 구조화
- script-writer: 스크립트 작성
- translator: 다국어 번역

### 품질 검증
- neuroscientist: 도파민 트리거 검증
- impatient-viewer: 스와이프 위험 검증

### 영상 제작
- voice-selector: 음성 선택
- bgm-selector: 배경음악 선택
- shorts-video-generator: 영상 생성 (Sora/Veo + 스톡)
- subtitle-generator: 자막 생성
- video-uploader: YouTube 업로드
