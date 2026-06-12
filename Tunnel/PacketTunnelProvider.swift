import Foundation
import TunnelKitOpenVPNAppExtension

final class PacketTunnelProvider: OpenVPNTunnelProvider {
    override func startTunnel(options: [String: NSObject]? = nil) async throws {
        // 每 2 秒向 App Group defaults 写一次流量统计 (单位: 毫秒)
        dataCountInterval = 2000
        try await super.startTunnel(options: options)
    }
}
