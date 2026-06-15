# DevSweep — Full Disk Access 온보딩 설계

**상태:** 설계 승인됨 (2026-06-15). 다음 단계: writing-plans.
**선행:** M1~M7 완료 (main, notarized Developer ID 배포). 이 문서는 기존 menubar UI(`StatusItemController` + SwiftUI `MenuView`) + `AppCoordinator` 위에 FDA 권한 온보딩 레이어를 얹는다.

---

## 1. 동기 / 문제

DevSweep은 비샌드박스 Developer ID 앱으로, 디스크 회수를 위해 홈 전반(`~/Documents/dev/**/node_modules`, `~/.npm`, `~/.gradle`, git worktree 등)을 스캔한다. macOS의 TCC가 `~/Documents`·`~/Downloads`·`~/Desktop` 및 타 앱 데이터를 게이트하므로, **Full Disk Access(FDA)가 없으면 스캔이 조용히 빈 결과를 반환**한다.

**실측 (2026-06-15):** 빌드된 `.app`을 새 경로에서 실행 → 메뉴바 표시가 계속 `Zero bytes`. 디렉토리 enumeration이 권한으로 막혀 detector가 0을 반환한 것이며, 사용자에게는 "앱이 고장난 것"처럼 보인다. 현재 코드에는 **FDA 감지·안내가 전무**하다.

FDA는 자동 요청 API가 없다(샌드박스 권한과 달리 프롬프트를 띄울 수 없음). 사용자를 **시스템 설정의 FDA 패널로 보내 수동 허용**하게 하는 것이 유일한 경로다. 따라서 "권한 없음을 감지 → 명확히 안내 → 설정으로 보냄 → 허용 후 자동 정상화"하는 온보딩이 필요하다.

## 2. 범위 결정 (사용자 승인)

1. **안내 표면 = 팝오버 내 경고 배너.** 별도 창/알림 아님. 권한 없을 때 기존 메뉴바 팝오버 최상단에 ⚠ 배너를 띄우고, 권한 부여되면 배너가 사라진다.
2. **발견성 = 자동 팝오버(첫 실행 1회) + 경고 아이콘(지속).** 권한 없으면 (a) 메뉴바 아이콘을 경고 tint로 바꿔 시선을 끌고, (b) **첫 실행 시 팝오버를 1회 자동으로** 띄운다. 이후 실행에서는 경고 아이콘만 지속(매 실행마다 팝오버로 자동으로 도배하지 않음).
3. **감지 방식 = TCC.db open-probe.** `~/Library/Application Support/com.apple.TCC/TCC.db`를 읽기로 `open()` 시도 → 성공=FDA 있음, `EPERM`=없음. 항상 존재하는 파일이며 내용은 읽지 않는다(권한 체크용 fd만).

비범위(후속/YAGNI): 권한 영구 dismiss, 다국어, Documents-only 부분 권한 세분화, 인앱 권한 자동 요청(FDA는 API 없음), 권한 없을 때 일부 모듈만 부분 동작시키는 분기.

## 3. 아키텍처 — 격리·테스트 가능 단위 3개

기존 코드 스타일(주입 가능한 IO + 순수 decider + `@Published` 상태 + AppKit status item 푸시)을 그대로 따른다.

### 3.1 `FullDiskAccessProbe` (protocol, DevSweepCore)

```swift
enum FDAStatus: Sendable, Equatable { case granted, denied }

protocol FullDiskAccessProbe: Sendable {
    func check() -> FDAStatus
}
```

실제 구현 `TCCDatabaseProbe`:
- 경로 `~/Library/Application Support/com.apple.TCC/TCC.db`를 `open(path, O_RDONLY)` 시도.
- fd ≥ 0 → `close(fd)` 후 `.granted`.
- `errno == EPERM || EACCES` → `.denied`.
- **그 외 에러(`ENOENT` 등) → fail-safe `.denied`** (§5 참조).
- 주입 가능하므로 단위 테스트는 stub probe(granted/denied 고정)를 쓴다.

### 3.2 `FDAOnboardingDecision` (순수 함수, DevSweepCore)

기존 `SkinSelectionReconciler`와 동일한 순수-decider 패턴. 부수효과 없음 → 100% 단위 테스트.

```swift
struct FDAOnboardingDecision: Equatable {
    let showBanner: Bool        // 팝오버 배너 표시
    let autoOpenPopover: Bool    // 팝오버 1회 자동 오픈
    let warnIcon: Bool           // 메뉴바 아이콘 경고 tint
}

struct FDAOnboardingDecider {
    /// status=denied → showBanner=true, warnIcon=true.
    /// autoOpenPopover = (denied && !didAutoShowBefore) — 첫 실행 1회만.
    /// status=granted → 모두 false.
    func decide(status: FDAStatus, didAutoShowBefore: Bool) -> FDAOnboardingDecision
}
```

### 3.3 `SettingsLauncher` (protocol, DevSweepApp)

FDA 설정 딥링크를 연다. 주입 가능 → 테스트는 호출 기록 stub.

```swift
protocol SettingsLauncher: Sendable {
    func openFullDiskAccessSettings()
}
```

실제 구현: `NSWorkspace.shared.open(URL("x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles"))`. 열기 실패 시 조용히 무시.

## 4. 통합 지점

### 4.1 `AppCoordinator`

- 새 의존성 주입: `init(..., fdaProbe: FullDiskAccessProbe = TCCDatabaseProbe())`. 기본값으로 기존 호출부 무변경.
- 새 발행 상태: `@Published private(set) var hasFullDiskAccess: Bool`.
- 새 콜백(status item용): `var onFDAStateChange: ((Bool) -> Void)?`, `var requestAutoOpenPopover: (() -> Void)?`.
- `refreshFDA()` 메서드: `probe.check()` → decision 계산 → `hasFullDiskAccess` 발행 + 콜백 발화. **denied→granted 전환을 감지하면 즉시 `scanNow()` 재실행.**
- 자동-팝오버 1회 게이팅: `UserDefaults("DevSweep.didAutoShowFDAOnboarding")`. 이 flag 값을 `didAutoShowBefore`로 decider에 넘긴다(단일 게이트). `decision.autoOpenPopover == true`면 `requestAutoOpenPopover?()` 발화 + flag를 true로 저장(이중 체크 없음 — decider가 이미 flag를 반영).
- 호출 시점: `start()` 진입 시 1회, `scanNow()` 직전(권한 상태 최신화). 팝오버 오픈 시(아래 4.3)에도 호출.
- `start()` 흐름: `refreshFDA()` → granted면 기존대로 watcher + 초기 scan. denied여도 watcher는 시작(권한 부여 후 트리거 가능)하되 배너로 안내.

### 4.2 `MenuView`

- `coordinator.hasFullDiskAccess == false`이면 `header` 위 최상단에 `fdaBanner` 섹션 + `Divider()`.
- 배너 구성: ⚠ 아이콘 + "전체 디스크 접근 권한 필요" + 보조설명 1줄 + `[설정 열기]`(→ `settingsLauncher.openFullDiskAccessSettings()`) + `[나중에]`(→ 팝오버 닫기, 영구 dismiss 아님).
- `settingsLauncher`를 `MenuView`에 주입(coordinator 경유 또는 별도 프로퍼티).

### 4.3 `StatusItemController`

- `coordinator.onFDAStateChange` 구독 → FDA 없으면 status item 아이콘을 **경고 tint**(예: `.systemRed`/경고 글리프)로, 있으면 기존 게이지 tint로 복귀. 기존 `render(bytes:)`의 tint 로직과 합성(FDA 경고가 우선).
- `coordinator.requestAutoOpenPopover` 구독 → 팝오버를 프로그램적으로 1회 표시(기존 `togglePopover`의 show 분기 재사용).
- 사용자가 팝오버를 열 때마다(`togglePopover`의 show 분기) `coordinator.refreshFDA()` 호출 → 권한 부여 후 다시 열면 배너 즉시 제거 + 재스캔.

## 5. 데이터 흐름

```
launch → AppDelegate.applicationDidFinishLaunching
  → coordinator.start()
      → refreshFDA(): probe.check()
          → decision = decide(status, didAutoShowBefore)
          → hasFullDiskAccess 발행, onFDAStateChange 발화(아이콘 tint)
          → denied && 첫 실행 → requestAutoOpenPopover 발화 + flag 저장
      → granted → 기존 watcher + scanNow()
      → denied  → watcher 시작, 배너로 안내(스캔은 0 반환하므로 굳이 강행 안 함)

[사용자] 배너 "설정 열기" → SettingsLauncher → FDA 패널
        → DevSweep 켜기 → (macOS가 "종료 후 다시 열기" 유도)
        → 재실행 시 launch refreshFDA = granted → 배너/경고 사라짐 + 정상 scan

[재실행 없이도] 팝오버 다시 열기 → togglePopover.show → refreshFDA()
        → granted 전환 감지 → 배너 제거 + scanNow()
```

## 6. 에러 처리

- probe가 `EPERM/EACCES` 외 예기치 못한 에러(`ENOENT`, 경로 변경 등) → **fail-safe = `.denied`**. 무권한인데 정상으로 오판해 Zero bytes를 방치하는 것보다, 권한 있는데 배너가 한 번 더 뜨는 쪽이 안전(거짓 양성 < 거짓 음성).
- `SettingsLauncher` 딥링크 열기 실패 → 조용히 무시(앱은 계속 동작, 로깅만).
- `UserDefaults` 접근 실패 → 자동 팝오버가 매 실행 떠도 기능상 안전(경고 아이콘과 중복일 뿐). 단정 깨짐 없음.

## 7. 테스트 (Swift Testing)

- **`FDAOnboardingDeciderTests`** (순수): `granted` → 모두 false. `denied & !didAutoShowBefore` → showBanner·warnIcon·autoOpenPopover 모두 true. `denied & didAutoShowBefore` → autoOpenPopover만 false(배너·아이콘은 유지). **"자동 팝오버는 1회만" 불변식**.
- **`AppCoordinatorFDATests`** (stub probe 주입): denied probe → `hasFullDiskAccess=false`. granted probe → true. **denied→granted 전환 시 재스캔 1회 호출**(스파이 scanCoordinator/플래그). 첫 호출에서만 `requestAutoOpenPopover` 발화(두 번째 refresh에선 미발화).
- **`SettingsLauncher` stub**: 배너 "설정 열기" 경로가 `openFullDiskAccessSettings()`를 정확히 1회 호출.
- **`TCCDatabaseProbe` smoke**: 크래시 없이 `FDAStatus` 값 반환만 검증(현 머신 권한 상태 의존 → 값 단정 없음).

## 8. 불변식 (회귀 가드)

1. **FDA 자동 요청 시도 금지** — 설정 딥링크로 보내는 것이 유일 경로(샌드박스 권한 API 오용 금지).
2. **자동 팝오버는 첫 실행 1회만** — `didAutoShowFDAOnboarding` flag로 강제, 이후엔 경고 아이콘만.
3. **"나중에"는 영구 dismiss 아님** — 권한 없으면 다음 팝오버 오픈 시 배너 재등장(앱이 무권한으로 기능 불능이므로 숨기지 않음).
4. **probe 불확실 시 denied로 fail-safe** — 거짓 음성(무권한 방치) 금지.
5. **권한 전환 자동 정상화** — granted 감지 시 재스캔으로 즉시 결과 반영(수동 "지금 스캔" 강요 안 함).
6. **기존 호출부 무변경** — 새 의존성은 기본값 주입으로 추가, 기존 `AppCoordinator()` 호출 그대로 컴파일.
