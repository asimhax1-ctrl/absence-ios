import SwiftUI
import UIKit

// ألوان الواجهة ٢ «ليل» — داكن أسود + نسخة فاتحة بنفس الروح، والأخضر النعناعي للحالة
enum Theme {
    private static func dyn(_ light: UInt32, _ dark: UInt32, _ la: CGFloat = 1, _ da: CGFloat = 1) -> Color {
        Color(UIColor { t in
            let v = t.userInterfaceStyle == .dark ? dark : light
            let a = t.userInterfaceStyle == .dark ? da : la
            return UIColor(red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255, blue: CGFloat(v & 0xFF) / 255, alpha: a)
        })
    }
    static let ground = dyn(0xF2F2F7, 0x000000)
    static let card = dyn(0xFFFFFF, 0x121212)
    static let field = dyn(0xF2F2F7, 0x1C1C1E)
    static let stroke = dyn(0xE5E5EA, 0x2C2C2E)
    static let text = dyn(0x1C1C1E, 0xF5F5F7)
    static let secondary = dyn(0x6C6C70, 0xA1A1A6)
    static let separator = dyn(0xE5E5EA, 0x232326)
    static let track = dyn(0xE5E5EA, 0x262626)
    static let accent = dyn(0x1DB87A, 0x3DDC97)        // الحلقة والأشرطة
    static let accentSoft = dyn(0xDDF5E9, 0x10261C)
    static let accentInk = dyn(0x0F7A4F, 0x3DDC97)     // نص أخضر مقروء
    static let warn = dyn(0xC25E00, 0xFFB35C)
    static let warnSoft = dyn(0xFFF2DE, 0x3A2A14)
    static let danger = dyn(0xD70015, 0xFF6B6B)
    static let dangerSoft = dyn(0xFFE5E7, 0x3D1A1D)
    static let good = accentInk
    static let goodSoft = accentSoft
    static let navy = Color(red: 27 / 255, green: 42 / 255, blue: 78 / 255)

    static func level(_ p: Double) -> (Color, Color) {
        p >= 20 ? (danger, dangerSoft) : p >= 12.5 ? (warn, warnSoft) : (accent, accentSoft)
    }
}

// ───────── خط التطبيق ─────────
enum AppFont: String, CaseIterable, Identifiable {
    case readex, system, tajawal, messiri, reemKufi, notoKufi
    var id: String { rawValue }
    var label: String {
        switch self {
        case .readex: return "ريدكس"
        case .system: return "خط النظام"
        case .tajawal: return "تجوّل"
        case .messiri: return "المسيري"
        case .reemKufi: return "ريم كوفي"
        case .notoKufi: return "نوتو كوفي"
        }
    }
    static var current: AppFont = AppFont(rawValue: UserDefaults.standard.string(forKey: "appFont") ?? "") ?? .readex

    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        switch self {
        case .system: return .system(size: size, weight: weight)
        case .readex: return Font.custom("Readex Pro", fixedSize: size).weight(weight)
        case .messiri: return Font.custom("El Messiri", fixedSize: size * 1.04).weight(weight)
        case .reemKufi: return Font.custom("Reem Kufi", fixedSize: size).weight(weight)
        case .notoKufi: return Font.custom("Noto Kufi Arabic", fixedSize: size * 0.94).weight(weight)
        case .tajawal:
            let heavy = [Font.Weight.semibold, .bold, .heavy, .black].contains(weight)
            return Font.custom(heavy ? "Tajawal-Black" : "Tajawal-Regular", fixedSize: size * 1.06)
        }
    }
}

extension Font {
    // كل نصوص التطبيق تمر من هنا عشان يتغير الخط من الإعدادات
    static func app(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font { AppFont.current.font(size, weight) }
}

struct CardStyle: ViewModifier {
    var padding: CGFloat = 16
    var radius: CGFloat = 22
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

extension View {
    func card(_ padding: CGFloat = 16, radius: CGFloat = 22) -> some View { modifier(CardStyle(padding: padding, radius: radius)) }
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

struct Ring: View {
    let fraction: Double
    var lineWidth: CGFloat = 12
    var body: some View {
        ZStack {
            Circle().stroke(Theme.track, lineWidth: lineWidth)
            Circle().trim(from: 0, to: max(0.02, min(1, fraction)))
                .stroke(Theme.accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// ───────── صياغة عربية سليمة للأعداد ─────────
enum Words {
    static func hours(_ n: Int) -> String { n <= 0 ? "ولا ساعة" : n == 1 ? "ساعة" : n == 2 ? "ساعتين" : n <= 10 ? "\(n) ساعات" : "\(n) ساعة" }
    static func times(_ n: Int) -> String { n <= 0 ? "ولا مرة" : n == 1 ? "مرة" : n == 2 ? "مرتين" : n <= 10 ? "\(n) مرات" : "\(n) مرة" }
    static func days(_ n: Int) -> String { n <= 0 ? "ولا يوم" : n == 1 ? "يوم" : n == 2 ? "يومين" : n <= 10 ? "\(n) أيام" : "\(n) يومًا" }
    static func plan(_ p: RestPlan) -> String {
        let parts = p.n.enumerated().compactMap { $0.element > 0 ? "\(Term.days[$0.offset]) \(times($0.element))" : nil }
        return parts.isEmpty ? "ولا يوم كامل" : parts.joined(separator: " + ")
    }
    static func time12(_ hhmm: String) -> String {
        let p = hhmm.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return hhmm }
        let h = p[0], m = p[1]
        let part = h < 12 ? "الصبح" : h < 15 ? "الظهر" : h < 18 ? "العصر" : "المساء"
        let h12 = h % 12 == 0 ? 12 : h % 12
        return m == 0 ? "\(h12) \(part)" : String(format: "%d:%02d ", h12, m) + part
    }
}
