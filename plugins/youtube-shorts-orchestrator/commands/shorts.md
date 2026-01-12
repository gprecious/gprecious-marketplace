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

# 다중 영상 생성 (최대 10개)
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
| --count | 생성할 영상 수 | 1 | 1-10 |
| --upload | 업로드 여부 | false | 플래그 |
| --visibility | 공개 범위 | private | public, unlisted, private |

## 워크플로우

```
/shorts 실행
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
└── shorts-video-generator
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
/shorts --count 10
```
- 10개 이벤트 병렬 수집
- 10개 파이프라인 병렬 실행
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

### 파이프라인 실패 시
- 실패한 파이프라인은 건너뛰고 계속 진행
- 최종 리포트에 실패 원인 포함
- wisdom.md에 실패 패턴 기록

### API 제한 시
- YouTube API 할당량 초과: 업로드 건너뛰고 로컬 저장
- ElevenLabs 제한: 대기 후 재시도

## 주의사항

- 최대 10개 영상까지 병렬 생성 가능
- 업로드 전 영상 품질 자동 검증 (점수 7 이상만)
- 채널 ID 미설정 시 로컬 저장만 수행
- 민감한 주제는 자동 필터링
