import SwiftUI
import AppIntents

// الخطوط: خطوط iOS + خطوط مفتوحة الترخيص (OFL) مضمّنة داخل التطبيق والودجت
enum FontChoice: String, AppEnum, CaseIterable, Identifiable {
    case system, rounded, black, geeza, damascus, alnile, farah
    case ruqaa, ruqaaInk, amiri, reemKufi, notoKufi, kufam, changa, elMessiri, tajawal, lalezar, rakkas, marhey, jomhuria

    var id: String { rawValue }

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "الخط"
    static var caseDisplayRepresentations: [FontChoice: DisplayRepresentation] = [
        .system: "خط النظام (SF Arabic)",
        .rounded: "SF مدوّر",
        .black: "SF أسود عريض",
        .geeza: "الجيزة (Geeza Pro)",
        .damascus: "دمشق (Damascus)",
        .alnile: "النيل (Al Nile)",
        .farah: "فرح (Farah)",
        .ruqaa: "رقعة (Aref Ruqaa)",
        .ruqaaInk: "رقعة حبر (Aref Ruqaa Ink)",
        .amiri: "أميري — نسخ (Amiri)",
        .reemKufi: "ريم كوفي (Reem Kufi)",
        .notoKufi: "نوتو كوفي (Noto Kufi)",
        .kufam: "كوفام (Kufam)",
        .changa: "شنقا (Changa)",
        .elMessiri: "المسيري (El Messiri)",
        .tajawal: "تجوّل (Tajawal)",
        .lalezar: "لاله‌زار (Lalezar)",
        .rakkas: "رقّاص (Rakkas)",
        .marhey: "مرحي (Marhey)",
        .jomhuria: "جمهورية (Jomhuria)",
    ]

    var label: String {
        switch self {
        case .system: return "خط النظام"
        case .rounded: return "SF مدوّر"
        case .black: return "SF أسود"
        case .geeza: return "الجيزة"
        case .damascus: return "دمشق"
        case .alnile: return "النيل"
        case .farah: return "فرح"
        case .ruqaa: return "رقعة"
        case .ruqaaInk: return "رقعة حبر"
        case .amiri: return "أميري"
        case .reemKufi: return "ريم كوفي"
        case .notoKufi: return "نوتو كوفي"
        case .kufam: return "كوفام"
        case .changa: return "شنقا"
        case .elMessiri: return "المسيري"
        case .tajawal: return "تجوّل"
        case .lalezar: return "لاله‌زار"
        case .rakkas: return "رقّاص"
        case .marhey: return "مرحي"
        case .jomhuria: return "جمهورية"
        }
    }

    // (عادي، عريض، مقياس، خط متغيّر الوزن؟)
    private var names: (String, String, CGFloat, Bool)? {
        switch self {
        case .system, .rounded, .black: return nil
        case .geeza: return ("GeezaPro", "GeezaPro-Bold", 1, false)
        case .damascus: return ("Damascus", "DamascusBold", 1, false)
        case .alnile: return ("AlNile", "AlNile-Bold", 1, false)
        case .farah: return ("Farah", "Farah", 1.05, false)
        case .ruqaa: return ("ArefRuqaa-Regular", "ArefRuqaa-Bold", 1.12, false)
        case .ruqaaInk: return ("ArefRuqaaInk-Regular", "ArefRuqaaInk-Bold", 1.12, false)
        case .amiri: return ("Amiri-Regular", "Amiri-Bold", 1.08, false)
        case .reemKufi: return ("ReemKufi", "ReemKufi", 1, true)
        case .notoKufi: return ("NotoKufiArabic-Regular", "NotoKufiArabic-Regular", 0.92, true)
        case .kufam: return ("Kufam-Regular", "Kufam-Regular", 0.95, true)
        case .changa: return ("Changa-Regular", "Changa-Regular", 1, true)
        case .elMessiri: return ("ElMessiri-Regular", "ElMessiri-Regular", 1, true)
        case .tajawal: return ("Tajawal-Regular", "Tajawal-Black", 1.05, false)
        case .lalezar: return ("Lalezar-Regular", "Lalezar-Regular", 1, false)
        case .rakkas: return ("Rakkas-Regular", "Rakkas-Regular", 1, false)
        case .marhey: return ("Marhey-Light", "Marhey-Light", 1, true)
        case .jomhuria: return ("Jomhuria-Regular", "Jomhuria-Regular", 1.45, false)
        }
    }

    func font(_ size: CGFloat, bold: Bool) -> Font {
        switch self {
        case .system: return .system(size: size, weight: bold ? .bold : .regular)
        case .rounded: return .system(size: size, weight: bold ? .heavy : .medium, design: .rounded)
        case .black: return .system(size: size, weight: .black)
        default:
            guard let n = names else { return .system(size: size) }
            let f = Font.custom(bold ? n.1 : n.0, fixedSize: size * n.2)
            return n.3 ? f.weight(bold ? .bold : .regular) : f
        }
    }
}
