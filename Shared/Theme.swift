import SwiftUI
import UIKit

// ألوان الواجهة ١ «واضح» — فاتح ونسخة داكنة مريحة (مو أسود صافي)
enum Theme {
    private static func dyn(_ light: UInt32, _ dark: UInt32, _ la: CGFloat = 1, _ da: CGFloat = 1) -> Color {
        Color(UIColor { t in
            let v = t.userInterfaceStyle == .dark ? dark : light
            let a = t.userInterfaceStyle == .dark ? da : la
            return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: a)
        })
    }
    static let ground = dyn(0xF2F2F7, 0x111114)
    static let card = dyn(0xFFFFFF, 0x1D1D21)
    static let text = dyn(0x1C1C1E, 0xF2F2F5)
    static let secondary = dyn(0x6C6C70, 0x9C9CA3)
    static let separator = dyn(0xE5E5EA, 0x2C2C31)
    static let track = dyn(0xE5E5EA, 0x34343A)
    static let accent = dyn(0x0A84FF, 0x3D9BFF)
    static let accentSoft = dyn(0xE6F1FF, 0x16304F)
    static let accentInk = dyn(0x0060DF, 0x8CC3FF)
    static let warn = dyn(0xC25E00, 0xFFB35C)
    static let warnSoft = dyn(0xFFF2DE, 0x3A2A14)
    static let danger = dyn(0xD70015, 0xFF6B6B)
    static let dangerSoft = dyn(0xFFE5E7, 0x3D1A1D)
    static let good = dyn(0x248A3D, 0x5BD27A)
    static let goodSoft = dyn(0xE3F6E8, 0x163322)

    static func level(_ p: Double) -> (Color, Color) {
        p >= 20 ? (danger, dangerSoft) : p >= 12.5 ? (warn, warnSoft) : (accent, accentSoft)
    }
}

struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

extension View {
    func card(_ padding: CGFloat = 16) -> some View { modifier(CardStyle(padding: padding)) }
}

struct ProgressLine: View {
    let p: Double
    var color: Color = Theme.accent
    var height: CGFloat = 6
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.track)
                Capsule().fill(color).frame(width: max(height, g.size.width * min(1, max(0, p / 25))))
            }
        }
        .frame(height: height)
    }
}
