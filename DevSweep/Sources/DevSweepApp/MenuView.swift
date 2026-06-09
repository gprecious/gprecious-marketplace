import SwiftUI
import DevSweepCore

/// The popover content: the reclaimable total + last-scan time, the top modules by size, a
/// "Scan now" action, a dry-run-toggled reclaim of the reviewed items, and placeholders for
/// settings/donation (real behavior lands in M6).
struct MenuView: View {
    @ObservedObject var coordinator: AppCoordinator
    @State private var dryRun = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            moduleList
            Divider()
            actions
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
            Text(coordinator.isScanning ? "스캔 중…" : "회수할 항목이 없습니다")
                .font(.callout)
                .foregroundStyle(.secondary)
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
                Label("지금 스캔", systemImage: "arrow.clockwise")
            }
            .disabled(coordinator.isScanning)

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

    private var footer: some View {
        HStack {
            Text("설정")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
            Text("기부")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}
