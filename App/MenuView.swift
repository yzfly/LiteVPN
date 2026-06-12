import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers
import TunnelKit

struct MenuView: View {
    @EnvironmentObject private var vpn: VPNController
    @EnvironmentObject private var store: ProfileStore

    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @AppStorage("clashCompatMode") private var clashCompatMode = false
    @State private var importErrorMessage: String?
    @State private var hoveredProfileID: UUID?
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(16)
            statusSection
            connectSection
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            sectionDivider
            profileSection
            sectionDivider
            settingsSection
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            sectionDivider
            footer
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .frame(width: 300)
        .background(Theme.bg)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isDropTargeted ? Theme.green : .clear, lineWidth: 2)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
    }

    // MARK: 标题 + 状态徽章

    private var header: some View {
        HStack {
            HStack(spacing: 7) {
                Image(systemName: "bolt.shield.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.green)
                Text("LiteVPN")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            statusBadge
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(statusColor)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.10), in: Capsule())
    }

    private var statusColor: Color {
        switch vpn.status {
        case .connected: return Theme.greenDark
        case .connecting, .disconnecting: return Theme.amber
        case .disconnected: return Theme.textSecondary
        }
    }

    private var statusText: String {
        switch vpn.status {
        case .connected: return "已连接"
        case .connecting: return "连接中"
        case .disconnecting: return "断开中"
        case .disconnected: return "未连接"
        }
    }

    // MARK: 连接信息卡片 + 错误条

    @ViewBuilder
    private var statusSection: some View {
        if vpn.status == .connected {
            HStack(spacing: 0) {
                statTile(label: "时长") {
                    if let date = vpn.connectedDate {
                        Text(date, style: .timer)
                    } else {
                        Text("—")
                    }
                }
                tileDivider
                statTile(label: "下行") {
                    Text(vpn.dataCount.map { format($0.received) } ?? "—")
                }
                tileDivider
                statTile(label: "上行") {
                    Text(vpn.dataCount.map { format($0.sent) } ?? "—")
                }
            }
            .background(Theme.bgSubtle)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .stroke(Theme.border, lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        if let message = vpn.lastErrorMessage ?? importErrorMessage {
            Text(message)
                .font(.system(size: 11))
                .foregroundStyle(Theme.red)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(Theme.red.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.radius))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
        }
    }

    private func statTile(label: String, @ViewBuilder value: () -> some View) -> some View {
        VStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
            value()
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private var tileDivider: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(width: 1, height: 28)
    }

    // MARK: 连接按钮

    private var connectSection: some View {
        Button(action: toggleConnection) {
            Text(buttonText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(buttonForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(buttonBackground, in: RoundedRectangle(cornerRadius: Theme.radius))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.radius)
                        .stroke(buttonBorder, lineWidth: 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: Theme.radius))
        }
        .buttonStyle(.plain)
        .disabled(vpn.status == .disconnected && store.selectedProfile == nil)
        .opacity(vpn.status == .disconnected && store.selectedProfile == nil ? 0.5 : 1)
    }

    private var buttonText: String {
        switch vpn.status {
        case .connected: return "断开连接"
        case .connecting: return "取消"
        case .disconnecting: return "断开中…"
        case .disconnected: return "连接"
        }
    }

    private var buttonBackground: Color {
        vpn.status == .disconnected ? Theme.green : Theme.bg
    }

    private var buttonForeground: Color {
        switch vpn.status {
        case .disconnected: return .white
        case .connected: return Theme.red
        case .connecting, .disconnecting: return Theme.textSecondary
        }
    }

    private var buttonBorder: Color {
        vpn.status == .disconnected ? Theme.greenDark : Theme.border
    }

    // MARK: 配置列表

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("配置")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Button(action: importFromPanel) {
                    Label("导入", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.greenDark)
                }
                .buttonStyle(.plain)
            }
            if store.profiles.isEmpty {
                emptyState
            } else {
                VStack(spacing: 2) {
                    ForEach(store.profiles) { profile in
                        profileRow(profile)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 16))
                .foregroundStyle(Theme.textSecondary)
            Text("拖入 .ovpn 文件即可导入")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: Theme.radius)
                .strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }

    private func profileRow(_ profile: Profile) -> some View {
        let isSelected = store.selectedProfileID == profile.id
        let isHovered = hoveredProfileID == profile.id
        return HStack(spacing: 8) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? Theme.green : Theme.border)
            Text(profile.name)
                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
            Spacer()
            if isSelected && vpn.status == .connected {
                Circle().fill(Theme.green).frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            isSelected ? Theme.greenTint : (isHovered ? Theme.bgSubtle : .clear),
            in: RoundedRectangle(cornerRadius: Theme.radius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radius)
                .stroke(isSelected ? Theme.green.opacity(0.35) : .clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            hoveredProfileID = hovering ? profile.id : nil
        }
        .onTapGesture {
            selectProfile(profile)
        }
        .contextMenu {
            Button("删除", role: .destructive) {
                if vpn.status != .disconnected && store.selectedProfileID == profile.id {
                    vpn.disconnect()
                }
                store.delete(profile)
            }
        }
    }

    private func selectProfile(_ profile: Profile) {
        guard store.selectedProfileID != profile.id else {
            return
        }
        store.selectedProfileID = profile.id
        // 已连接时切换配置 = 直接重连到新配置
        if vpn.status == .connected || vpn.status == .connecting {
            vpn.connect(using: profile)
        }
    }

    // MARK: 设置

    private var settingsSection: some View {
        VStack(spacing: 10) {
            settingRow(
                title: "Clash 兼容模式",
                subtitle: "不接管默认路由, 仅路由 VPN 网段",
                isOn: $clashCompatMode
            )
            settingRow(
                title: "开机启动",
                subtitle: nil,
                isOn: $launchAtLogin
            )
            .onChange(of: launchAtLogin) { enabled in
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }
        }
    }

    private func settingRow(title: String, subtitle: String?, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(Theme.green)
                .labelsHidden()
        }
    }

    // MARK: 底栏

    private var footer: some View {
        HStack {
            Text("v1.0.0")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textSecondary.opacity(0.7))
            Spacer()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: 操作

    private func toggleConnection() {
        switch vpn.status {
        case .disconnected:
            if let profile = store.selectedProfile {
                vpn.connect(using: profile)
            }
        default:
            vpn.disconnect()
        }
    }

    private func importFromPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "ovpn") ?? .data]
        panel.allowsMultipleSelection = true
        panel.message = "选择 .ovpn 配置文件"
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK else {
            return
        }
        importURLs(panel.urls)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        var handled = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            handled = true
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url, url.pathExtension.lowercased() == "ovpn" else {
                    return
                }
                Task { @MainActor in
                    importURLs([url])
                }
            }
        }
        return handled
    }

    private func importURLs(_ urls: [URL]) {
        importErrorMessage = nil
        for url in urls {
            do {
                try store.importProfile(from: url)
            } catch {
                importErrorMessage = "\(url.lastPathComponent): \(error.localizedDescription)"
            }
        }
    }

    private func format(_ bytes: UInt) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .binary)
    }
}
