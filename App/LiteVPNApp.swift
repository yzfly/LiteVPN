import SwiftUI

@main
struct LiteVPNApp: App {
    @StateObject private var vpn = VPNController()
    @StateObject private var store = ProfileStore()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(vpn)
                .environmentObject(store)
        } label: {
            Image(systemName: menuIcon)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuIcon: String {
        switch vpn.status {
        case .connected:
            return "lock.shield.fill"
        case .connecting, .disconnecting:
            return "shield.lefthalf.filled"
        case .disconnected:
            return "shield"
        }
    }
}
