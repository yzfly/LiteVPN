import Foundation
import NetworkExtension
import TunnelKit
import TunnelKitOpenVPN

@MainActor
final class VPNController: ObservableObject {
    @Published private(set) var status: VPNStatus = .disconnected
    @Published private(set) var connectedDate: Date?
    @Published private(set) var dataCount: DataCount?
    @Published var lastErrorMessage: String?

    private let vpn = NetworkExtensionVPN()
    private var dataCountTimer: Timer?

    init() {
        let nc = NotificationCenter.default
        // 直接读 userInfo, 避开 TunnelKit 便捷访问器在键缺失时的 fatalError
        nc.addObserver(forName: VPNNotification.didChangeStatus, object: nil, queue: .main) { [weak self] note in
            guard note.userInfo?["BundleIdentifier"] as? String == AppConstants.tunnelBundleId,
                  let status = note.userInfo?["Status"] as? VPNStatus else {
                return
            }
            let date = note.userInfo?["ConnectionDate"] as? Date
            Task { @MainActor in
                self?.statusDidChange(to: status, connectedAt: date)
            }
        }
        nc.addObserver(forName: VPNNotification.didFail, object: nil, queue: .main) { [weak self] note in
            let message = (note.userInfo?["Error"] as? Error)?.localizedDescription
            Task { @MainActor in
                self?.lastErrorMessage = message
            }
        }
        Task {
            await vpn.prepare()
        }
    }

    func connect(using profile: Profile) {
        lastErrorMessage = nil
        Task {
            do {
                let parsed = try OpenVPN.ConfigurationParser.parsed(fromContents: profile.ovpnText)
                var ovpnConfiguration = parsed.configuration
                if UserDefaults.standard.bool(forKey: "clashCompatMode") {
                    // Clash 兼容: 不接管默认路由, 只保留配置/服务器下发的具体网段路由,
                    // 让 Clash 的系统代理继续处理其余流量
                    var builder = ovpnConfiguration.builder()
                    builder.routingPolicies = []
                    ovpnConfiguration = builder.build()
                }
                var cfg = OpenVPN.ProviderConfiguration(
                    profile.name,
                    appGroup: AppConstants.appGroup,
                    configuration: ovpnConfiguration
                )
                cfg.shouldDebug = true
                cfg.debugLogPath = "debug.log"
                try await vpn.reconnect(
                    AppConstants.tunnelBundleId,
                    configuration: cfg,
                    extra: nil,
                    after: .seconds(1)
                )
            } catch {
                lastErrorMessage = error.localizedDescription
            }
        }
    }

    func disconnect() {
        Task {
            await vpn.disconnect()
        }
    }

    private func statusDidChange(to newStatus: VPNStatus, connectedAt date: Date?) {
        status = newStatus
        connectedDate = date
        switch newStatus {
        case .connected:
            lastErrorMessage = nil
            startDataCountTimer()
        case .disconnected:
            stopDataCountTimer()
            dataCount = nil
        default:
            stopDataCountTimer()
        }
    }

    private func startDataCountTimer() {
        dataCountTimer?.invalidate()
        dataCountTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            let count = UserDefaults(suiteName: AppConstants.appGroup)?.openVPNDataCount
            Task { @MainActor in
                self?.dataCount = count
            }
        }
    }

    private func stopDataCountTimer() {
        dataCountTimer?.invalidate()
        dataCountTimer = nil
    }
}
