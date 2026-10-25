import Foundation
import Security

// التخزين المشترك بين التطبيق والودجت.
// التوقيع عبر ESign بشهادة متجر غالبًا ما يدعم App Groups (الملف الشخصي wildcard)،
// لذلك نجرّب ثلاث طرق ونكتب في كل طريقة تشتغل، ونقرأ الأحدث:
//   1) App Group   2) Keychain مشترك بنفس الفريق (TEAMID.*)   3) ملف محلي (غير مشترك مع الودجت)
final class Store {
    static let shared = Store()

    static let groupID = "group.com.asim.absence1448"
    private let fileName = "absence-1448.json"
    private let kcService = "com.asim.absence1448.state"
    private let kcHeartbeat = "com.asim.absence1448.widget-seen"

    private(set) var teamPrefix: String? = nil
    private(set) var groupURL: URL? = nil
    private(set) var keychainOK = false

    private init() {
        if let u = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Store.groupID) {
            let probe = u.appendingPathComponent(".probe")
            if (try? Data("ok".utf8).write(to: probe)) != nil { groupURL = u }
        }
        teamPrefix = Store.findTeamPrefix()
        keychainOK = probeKeychain()
    }

    var sharedWithWidget: Bool { groupURL != nil || keychainOK }
    var backendsText: String {
        var a: [String] = []
        a.append(groupURL != nil ? "✓ App Group" : "✗ App Group")
        a.append(keychainOK ? "✓ Keychain مشترك" : "✗ Keychain مشترك")
        a.append("✓ ملف محلي")
        return a.joined(separator: "\n")
    }

    // ── قراءة / كتابة ──
    func load() -> AppState? {
        var candidates: [AppState] = []
        if let u = groupURL, let d = try? Data(contentsOf: u.appendingPathComponent(fileName)), let s = AppState.from(json: d) { candidates.append(s) }
        if keychainOK, let d = kcRead(kcService), let s = AppState.from(json: d) { candidates.append(s) }
        if let d = try? Data(contentsOf: localURL), let s = AppState.from(json: d) { candidates.append(s) }
        return candidates.max { ($0.changedAt ?? "") < ($1.changedAt ?? "") }
    }

    func save(_ st: AppState) {
        let d = st.jsonData()
        if let u = groupURL { try? d.write(to: u.appendingPathComponent(fileName), options: .atomic) }
        if keychainOK { kcWrite(kcService, d) }
        try? d.write(to: localURL, options: .atomic)
        let bak = localURL.deletingPathExtension().appendingPathExtension("bak.json")
        try? d.write(to: bak, options: .atomic)
    }

    // الودجت يكتب متى قرأ البيانات آخر مرة، عشان التطبيق يتأكد أن المشاركة شغالة
    func widgetSeen(_ ok: Bool) {
        let txt = ISO8601DateFormatter().string(from: Date()) + (ok ? "|ok" : "|empty")
        let d = Data(txt.utf8)
        if let u = groupURL { try? d.write(to: u.appendingPathComponent("widget-seen.txt"), options: .atomic) }
        if keychainOK { kcWrite(kcHeartbeat, d) }
    }
    func lastWidgetSeen() -> String? {
        if let u = groupURL, let d = try? Data(contentsOf: u.appendingPathComponent("widget-seen.txt")) { return String(data: d, encoding: .utf8) }
        if keychainOK, let d = kcRead(kcHeartbeat) { return String(data: d, encoding: .utf8) }
        return nil
    }

    private var localURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return dir.appendingPathComponent(fileName)
    }

    // ── Keychain ──
    private var accessGroup: String? { teamPrefix.map { $0 + ".com.asim.absence1448.shared" } }

    // نضيف عنصرًا بدون مجموعة ثم نقرأ مجموعته الافتراضية: "TEAMID.bundle.id" → نأخذ TEAMID
    private static func findTeamPrefix() -> String? {
        let q: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                kSecAttrService as String: "com.asim.absence1448.team-probe",
                                kSecAttrAccount as String: "probe",
                                kSecReturnAttributes as String: true]
        var res: CFTypeRef?
        var st = SecItemCopyMatching(q as CFDictionary, &res)
        if st == errSecItemNotFound {
            var add = q; add[kSecValueData as String] = Data("p".utf8)
            st = SecItemAdd(add as CFDictionary, &res)
        }
        guard st == errSecSuccess, let a = res as? [String: Any], let g = a[kSecAttrAccessGroup as String] as? String else { return nil }
        return g.components(separatedBy: ".").first
    }

    private func baseQuery(_ service: String) -> [String: Any]? {
        guard let g = accessGroup else { return nil }
        return [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: "data",
                kSecAttrAccessGroup as String: g,
                kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock]
    }
    private func kcWrite(_ service: String, _ data: Data) {
        guard let q = baseQuery(service) else { return }
        let st = SecItemUpdate(q as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if st == errSecItemNotFound { var a = q; a[kSecValueData as String] = data; SecItemAdd(a as CFDictionary, nil) }
    }
    private func kcRead(_ service: String) -> Data? {
        guard var q = baseQuery(service) else { return nil }
        q.removeValue(forKey: kSecAttrAccessible as String)
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var res: CFTypeRef?
        return SecItemCopyMatching(q as CFDictionary, &res) == errSecSuccess ? res as? Data : nil
    }
    private func probeKeychain() -> Bool {
        guard let q = baseQuery("com.asim.absence1448.probe") else { return false }
        let st = SecItemUpdate(q as CFDictionary, [kSecValueData as String: Data("1".utf8)] as CFDictionary)
        if st == errSecSuccess { return true }
        if st == errSecItemNotFound { var a = q; a[kSecValueData as String] = Data("1".utf8); return SecItemAdd(a as CFDictionary, nil) == errSecSuccess }
        return false
    }
}
