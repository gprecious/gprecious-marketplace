import SwiftUI
import DevSweepCore

/// The popover content: the reclaimable total + last-scan time, the top modules by size (each a
/// two-step confirm reclaim), a "Scan now" action, a free preview + a Pro-gated "reclaim all", the
/// skin picker with a Pro lock, the DevSweep Pro section + license-key sheet, and donation links.
struct MenuView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var licenseStore: LicenseStore
    @State private var licenseKeyInput = ""
    @State private var showingLicenseSheet = false
    @State private var confirmingModuleId: String?   // per-module reclaim confirm (rev #9)

    /// FDA 설정 딥링크 런처(기본 실제 구현) + "나중에" 팝오버 닫기 콜백(status item이 주입).
    var settingsLauncher: SettingsLauncher = SystemSettingsLauncher()
    var onDismiss: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !coordinator.hasFullDiskAccess {
                fdaBanner
                Divider()
            }
            header
            Divider()
            moduleList
            Divider()
            actions
            Divider()
            skinPicker
            Divider()
            proSection
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 300)
        .sheet(isPresented: $showingLicenseSheet) { licenseSheet }
        .onChange(of: coordinator.proGateHit) { _, hit in
            if hit != nil { showingLicenseSheet = true; coordinator.proGateHit = nil }
        }
    }

    /// 권한 없을 때만 노출되는 경고 배너 — ⚠ + 설명 + [설정 열기]/[나중에]. "나중에"는 영구 dismiss 아님
    /// (불변식 3): 권한 없으면 다음 팝오버 오픈 시 재등장.
    private var fdaBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("전체 디스크 접근 권한 필요")
                    .font(.callout)
                    .fontWeight(.semibold)
            }
            Text("권한이 없으면 디스크 스캔이 빈 결과를 반환합니다. 시스템 설정에서 DevSweep을 허용해 주세요.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Button("설정 열기") { settingsLauncher.openFullDiskAccessSettings() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("나중에") { onDismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("회수 가능 공간")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(humanBytes(coordinator.reclaimableBytes))
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
            if let last = coordinator.lastScanDate {
                Text("마지막 스캔 " + last.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("아직 스캔하지 않음")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var moduleList: some View {
        if coordinator.topModules.isEmpty {
            if coordinator.isScanning {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("스캔 중…")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
            } else {
                Text("회수할 항목이 없습니다")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(coordinator.topModules) { module in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(module.name).font(.callout).lineLimit(1)
                            Spacer()
                            Text(humanBytes(module.bytes)).font(.callout).monospacedDigit().foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { confirmingModuleId = (confirmingModuleId == module.module) ? nil : module.module }

                        if confirmingModuleId == module.module {
                            HStack(spacing: 8) {
                                Text("이 모듈을 휴지통으로 회수할까요?").font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                Button("회수") {
                                    let id = module.module
                                    confirmingModuleId = nil
                                    Task { _ = await coordinator.reclaimModule(id: id, dryRun: false) }
                                }.controlSize(.small)
                                Button("취소") { confirmingModuleId = nil }.controlSize(.small)
                            }
                        }
                    }
                }
            }
        }
    }

    private var actions: some View {
        let actionPresentation = MenuActionPresentation(
            hasFullDiskAccess: coordinator.hasFullDiskAccess,
            isScanning: coordinator.isScanning,
            isReclaiming: coordinator.isReclaiming,
            currentItemCount: coordinator.currentItems.count,
            hasDisplayedResults: coordinator.reclaimableBytes > 0 || !coordinator.topModules.isEmpty
        )

        return VStack(alignment: .leading, spacing: 8) {
            Button {
                coordinator.requestManualScan()
            } label: {
                HStack(spacing: 8) {
                    if coordinator.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .frame(width: 16)
                    }
                    Text(coordinator.isScanning ? "스캔 중…" : "지금 스캔")
                }
            }
            .disabled(actionPresentation.scanDisabled)
            .animation(.default, value: coordinator.isScanning)

            Button { Task { _ = await coordinator.reclaimAll(dryRun: true) } } label: {
                Label("회수 미리보기", systemImage: "eye")
            }
            .disabled(actionPresentation.reclaimDisabled)

            Button { Task { _ = await coordinator.reclaimAll(dryRun: false) } } label: {
                Label(licenseStore.isPro ? "전체 회수 실행" : "전체 회수 (Pro)",
                      systemImage: licenseStore.isPro ? "trash" : "lock.fill")
            }
            .disabled(actionPresentation.reclaimDisabled)

            if let unavailableMessage = actionPresentation.unavailableMessage {
                Label(unavailableMessage, systemImage: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let summary = coordinator.lastReclaimSummary {
                reclaimSummaryView(summary)
            }
        }
    }

    private func reclaimSummaryView(_ summary: ReclaimRunSummary) -> some View {
        let primaryBytes = summary.kind == .dryRun ? summary.plannedBytes : summary.reclaimedBytes
        let primaryText = summary.kind == .dryRun ? "삭제 예정" : "회수"
        let title = summary.kind == .dryRun ? "미리보기 완료" : "회수 완료"

        return VStack(alignment: .leading, spacing: 3) {
            Label("\(title): \(summary.actionCount)개, \(primaryText) \(humanBytes(primaryBytes))",
                  systemImage: summary.failedCount > 0 ? "exclamationmark.triangle" : "checkmark.circle")
                .font(.caption)
                .foregroundStyle(summary.failedCount > 0 ? .orange : .secondary)
                .fixedSize(horizontal: false, vertical: true)

            if summary.protectedCount > 0 || summary.failedCount > 0 {
                Text("보호됨 \(summary.protectedCount)개 · 실패 \(summary.failedCount)개")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Visual state used to preview each skin in the picker, mirroring the live reclaimable total.
    private var previewState: ReclaimVisualState {
        ReclaimVisualState(reclaimableBytes: coordinator.reclaimableBytes, config: coordinator.config)
    }

    private var skinPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("스킨").font(.caption).foregroundStyle(.secondary)
            ForEach(SkinCatalog.all, id: \.id) { skin in skinRow(skin) }
        }
    }
    @ViewBuilder private func skinRow(_ skin: any SkinModule) -> some View {
        let selectable = licenseStore.canSelect(skin)
        HStack(spacing: 8) {
            Image(nsImage: skin.image(for: previewState, height: 16)).frame(width: 44, alignment: .leading)
            Text(skin.displayName).font(.callout).foregroundStyle(selectable ? .primary : .secondary)
            Spacer()
            if selectable {
                Image(systemName: skin.id == coordinator.currentSkinId ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(skin.id == coordinator.currentSkinId ? Color.accentColor : Color.secondary)
            } else {
                Label("Pro", systemImage: "lock.fill").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selectable ? coordinator.setSkin(id: skin.id) : (showingLicenseSheet = true) }
    }

    @ViewBuilder private var proSection: some View {
        if licenseStore.isPro {
            VStack(alignment: .leading, spacing: 6) {
                Label("DevSweep Pro 활성화됨", systemImage: "checkmark.seal.fill").font(.callout).foregroundStyle(.green)
                Toggle("스캔 후 자동 청소 (캐시류만)", isOn: Binding(
                    get: { coordinator.autoCleanEnabled }, set: { coordinator.autoCleanEnabled = $0 }))
                    .toggleStyle(.switch).font(.callout)
                Button("이 기기에서 라이선스 해제") { Task { await coordinator.deactivateLicense() } }
                    .font(.caption).buttonStyle(.link)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("DevSweep Pro — \(licenseStore.displayPrice)").font(.callout).fontWeight(.semibold)
                Text("스캔 후 자동 청소 · 전 스킨 · 원클릭 전체 회수").font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    Button("Pro 구매") { NSWorkspace.shared.open(licenseStore.checkoutURL) }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                    Button("라이선스 키 입력") { showingLicenseSheet = true }
                        .buttonStyle(.bordered).controlSize(.small)
                }
            }
        }
    }
    private var licenseSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("라이선스 키 입력").font(.headline)
            TextField("XXXX-XXXX-XXXX-XXXX", text: $licenseKeyInput).textFieldStyle(.roundedBorder).frame(width: 280)
            if case .invalid(let reason) = licenseStore.activationState {
                Label(reason, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("키는 구매 후 받은 주문 이메일에서 확인할 수 있습니다.").font(.caption2).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("취소") { showingLicenseSheet = false }
                Button("활성화") {
                    Task {
                        await coordinator.activateLicense(key: licenseKeyInput)
                        if licenseStore.isPro { showingLicenseSheet = false }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(licenseStore.activationState == .activating || licenseKeyInput.isEmpty)
            }
        }
        .padding(20).frame(width: 340)
    }

    /// Reward-free donation footer (Apple 3.2.1 vii): voluntary support only, no perks offered or
    /// implied here, plus a reassurance that cleanup stays free.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("핵심 정리는 무료 · Pro로 자동 청소·전 스킨")
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 14) {
                Button {
                    DonationLinks.open(DonationLinks.buyMeACoffee)
                } label: {
                    Label("커피 한 잔", systemImage: "cup.and.saucer")
                }
                Button {
                    DonationLinks.open(DonationLinks.githubSponsors)
                } label: {
                    Label("GitHub Sponsors", systemImage: "heart")
                }
            }
            .font(.caption)
            .buttonStyle(.link)
        }
    }
}
