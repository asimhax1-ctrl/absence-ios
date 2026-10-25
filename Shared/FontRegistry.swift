import Foundation
import CoreText

// احتياط: لو ما تحمّلت الخطوط من UIAppFonts نسجّلها يدويًا من الحزمة
enum FontRegistry {
    static func registerBundled() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for u in urls { CTFontManagerRegisterFontsForURL(u as CFURL, .process, nil) }
    }
}
