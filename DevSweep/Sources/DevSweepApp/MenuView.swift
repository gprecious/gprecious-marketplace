import SwiftUI
import DevSweepCore

/// The popover content: the reclaimable total + last-scan time, the top modules by size, a
/// "Scan now" action, a dry-run-toggled reclaim of the reviewed items, the skin picker with IAP
/// buy/restore, and reward-free donation links.
struct MenuView: View {
    @ObservedObject var coordinator: AppCoordinator
    @ObservedObject var skinStore: SkinStore
    @State private var dryRun = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            moduleList
            Divider()
            actions
            Divider()
            skinPicker
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 300)
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
                    HStack {
                        Text(module.name)
                            .font(.callout)
                            .lineLimit(1)
                        Spacer()
                        Text(humanBytes(module.bytes))
                            .font(.callout)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            .disabled(coordinator.isScanning)
            .animation(.default, value: coordinator.isScanning)

            Toggle("드라이런(미삭제 시뮬레이션)", isOn: $dryRun)
                .toggleStyle(.switch)
                .font(.callout)

            Button {
                let items = coordinator.currentItems
                let runDry = dryRun
                Task { _ = await coordinator.reclaim(approved: items, dryRun: runDry) }
            } label: {
                Label(dryRun ? "회수 미리보기" : "승인 회수 실행", systemImage: "trash")
            }
            .disabled(coordinator.currentItems.isEmpty || coordinator.isScanning || coordinator.isReclaiming)
        }
    }

    /// Visual state used to preview each skin in the picker, mirroring the live reclaimable total.
    private var previewState: ReclaimVisualState {
        ReclaimVisualState(reclaimableBytes: coordinator.reclaimableBytes, config: coordinator.config)
    }

    private var skinPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("스킨")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(SkinCatalog.all, id: \.id) { skin in
                skinRow(skin)
            }

            allAccessRow

            Button("구매 복원") {
                Task { await skinStore.restorePurchases() }
            }
            .font(.caption)
            .buttonStyle(.link)
            .disabled(skinStore.purchaseInFlight)
        }
    }

    /// One skin row: a live preview + name, then a selection radio (free / unlocked) or a "Buy $X"
    /// button (locked, sold standalone) or a lock glyph (locked, pack/All-Access-only).
    @ViewBuilder private func skinRow(_ skin: any SkinModule) -> some View {
        let selectable = skinStore.canSelect(skin)
        HStack(spacing: 8) {
            Image(nsImage: skin.image(for: previewState, height: 16))
                .frame(width: 44, alignment: .leading)
            Text(skin.displayName)
                .font(.callout)
                .foregroundStyle(selectable ? .primary : .secondary)
            Spacer()
            if selectable {
                Image(systemName: skin.id == coordinator.currentSkinId ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(skin.id == coordinator.currentSkinId ? Color.accentColor : Color.secondary)
            } else if let product = ProductCatalog.singleSkinProduct(skinId: skin.id) {
                Button(price(for: product.id)) {
                    Task {
                        if await skinStore.buy(product.id) {
                            coordinator.setSkin(id: skin.id) // unlocked now → auto-select ("Keep it")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(skinStore.purchaseInFlight)
            } else {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if selectable { coordinator.setSkin(id: skin.id) } // no-op for locked skins
        }
    }

    /// All-Access bundle row — shown until every paid skin is owned. Anchored against single prices.
    @ViewBuilder private var allAccessRow: some View {
        if let allAccess = ProductCatalog.product(id: ProductCatalog.allAccessId),
           skinStore.unlockedSkinIds.count < SkinCatalog.paid.count {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .frame(width: 44, alignment: .leading)
                    .foregroundStyle(.secondary)
                Text("올 액세스 — 모든 스킨")
                    .font(.callout)
                Spacer()
                Button(price(for: allAccess.id)) {
                    Task { _ = await skinStore.buy(allAccess.id) }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(skinStore.purchaseInFlight)
            }
        }
    }

    /// Reward-free donation footer (Apple 3.2.1 vii): voluntary support only, no perks offered or
    /// implied here, plus a reassurance that cleanup stays free.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("모든 정리 기능은 계속 무료입니다.")
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

    /// Localized StoreKit price when loaded, else the catalog's recommended USD price.
    private func price(for productId: String) -> String {
        skinStore.products.first { $0.id == productId }?.displayPrice
            ?? ProductCatalog.product(id: productId)?.displayPrice
            ?? ""
    }
}
