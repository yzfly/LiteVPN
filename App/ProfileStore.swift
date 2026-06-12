import Foundation
import TunnelKitOpenVPN

struct Profile: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var ovpnText: String
    let createdAt: Date
}

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [Profile] = []
    @Published var selectedProfileID: UUID? {
        didSet {
            UserDefaults.standard.set(selectedProfileID?.uuidString, forKey: "SelectedProfileID")
        }
    }

    var selectedProfile: Profile? {
        profiles.first { $0.id == selectedProfileID }
    }

    enum ImportError: LocalizedError {
        case unreadable
        case needsCredentials

        var errorDescription: String? {
            switch self {
            case .unreadable:
                return "无法读取文件内容"
            case .needsCredentials:
                return "该配置需要用户名密码认证, 当前版本仅支持证书内嵌的配置"
            }
        }
    }

    private let fileURL: URL

    init() {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiteVPN", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("profiles.json")

        load()
        if let raw = UserDefaults.standard.string(forKey: "SelectedProfileID"),
           let id = UUID(uuidString: raw),
           profiles.contains(where: { $0.id == id }) {
            selectedProfileID = id
        } else {
            selectedProfileID = profiles.first?.id
        }
    }

    @discardableResult
    func importProfile(from url: URL) throws -> Profile {
        let secured = url.startAccessingSecurityScopedResource()
        defer {
            if secured {
                url.stopAccessingSecurityScopedResource()
            }
        }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            throw ImportError.unreadable
        }

        // 导入即校验, 解析失败直接抛 ConfigurationError
        let result = try OpenVPN.ConfigurationParser.parsed(fromContents: text)
        if result.configuration.authUserPass == true {
            throw ImportError.needsCredentials
        }

        let baseName = url.deletingPathExtension().lastPathComponent
        let profile = Profile(id: UUID(), name: uniqueName(baseName), ovpnText: text, createdAt: Date())
        profiles.append(profile)
        save()
        if selectedProfileID == nil {
            selectedProfileID = profile.id
        }
        return profile
    }

    func delete(_ profile: Profile) {
        profiles.removeAll { $0.id == profile.id }
        save()
        if selectedProfileID == profile.id {
            selectedProfileID = profiles.first?.id
        }
    }

    private func uniqueName(_ base: String) -> String {
        var name = base
        var counter = 2
        while profiles.contains(where: { $0.name == name }) {
            name = "\(base) \(counter)"
            counter += 1
        }
        return name
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            return
        }
        profiles = (try? JSONDecoder().decode([Profile].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(profiles) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }
}
