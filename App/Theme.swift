import SwiftUI

/// Supabase 风格设计 token (亮色)
enum Theme {
    /// 品牌绿 — Supabase #3ECF8E
    static let green = Color(hex: 0x3ECF8E)
    static let greenDark = Color(hex: 0x2EBD80)
    static let greenTint = Color(hex: 0x3ECF8E).opacity(0.10)

    static let bg = Color.white
    static let bgSubtle = Color(hex: 0xF8F9FA)
    static let border = Color(hex: 0xE6E8EB)

    static let textPrimary = Color(hex: 0x11181C)
    static let textSecondary = Color(hex: 0x687076)

    static let red = Color(hex: 0xE5484D)
    static let amber = Color(hex: 0xF5A623)

    static let radius: CGFloat = 6
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
