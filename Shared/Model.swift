import Foundation

// ───────── بيانات الفصل الأول 1448 (نفس سكربت Scriptable) ─────────

struct Session: Hashable, Identifiable {
    let id: String
    let day: Int        // 0 = الأحد … 6 = السبت
    let type: String
    let h: Int
}

struct Course: Hashable, Identifiable {
    let id: String
    let short: String
    let mini: String
    let name: String
    let total: Int
    let est: Bool
    let sessions: [Session]
}

enum Term {
    static let courses: [Course] = [
        Course(id: "c271", short: "إلكترونيات", mini: "إلكترو", name: "إلكترونيات", total: 75, est: false, sessions: [
            Session(id: "c271-lec", day: 0, type: "نظري", h: 2),
            Session(id: "c271-lab", day: 1, type: "عملي", h: 2),
            Session(id: "c271-tut", day: 1, type: "تمارين", h: 1)]),
        Course(id: "c213", short: "دوائر 2", mini: "دوائر ٢", name: "دوائر كهربائية 2", total: 56, est: false, sessions: [
            Session(id: "c213-lab", day: 2, type: "عملي", h: 2),
            Session(id: "c213-lec", day: 3, type: "نظري", h: 1),
            Session(id: "c213-tut", day: 3, type: "تمارين", h: 1)]),
        Course(id: "c336", short: "معادلات", mini: "معادلات", name: "المعادلات التفاضلية", total: 41, est: false, sessions: [
            Session(id: "c336-sun", day: 0, type: "نظري", h: 1),
            Session(id: "c336-wed", day: 3, type: "نظري", h: 2)]),
        Course(id: "c214", short: "كهرومغناطيسي", mini: "كهرومغ", name: "حقل كهرومغناطيسي", total: 60, est: false, sessions: [
            Session(id: "c214-lec", day: 0, type: "نظري", h: 1),
            Session(id: "c214-tut", day: 0, type: "تمارين", h: 1),
            Session(id: "c214-lab", day: 1, type: "عملي", h: 2)]),
        Course(id: "c221", short: "الحماية", mini: "الحماية", name: "الحماية من الكهرباء", total: 56, est: true, sessions: [
            Session(id: "c221-lab", day: 2, type: "عملي", h: 2),
            Session(id: "c221-lec", day: 3, type: "نظري", h: 1),
            Session(id: "c221-tut", day: 3, type: "تمارين", h: 1)]),
    ]

    // غياب البوابة حتى 6 أكتوبر 2026 (مرجع البداية)
    static let portalLog: [(String, String)] = [
        ("c336-sun", "2026-08-23"), ("c336-wed", "2026-09-30"),
        ("c271-tut", "2026-08-24"), ("c271-tut", "2026-08-31"), ("c271-lec", "2026-09-06"), ("c271-lab", "2026-09-28"), ("c271-tut", "2026-09-28"),
        ("c214-lab", "2026-09-21"),
        ("c213-lab", "2026-09-01"), ("c213-lec", "2026-09-16"), ("c213-tut", "2026-09-16"), ("c213-lec", "2026-09-30"),
    ]

    // نهاية آخر محاضرة لكل يوم دراسي (بالدقائق من منتصف الليل)
    static let dayEnd: [Int: Int] = [0: 14 * 60 + 50, 1: 13 * 60 + 50, 2: 14 * 60 + 50, 3: 14 * 60 + 50]
    static let semDefault = "2026-08-23"

    static let days = ["الأحد", "الاثنين", "الثلاثاء", "الأربعاء", "الخميس", "الجمعة", "السبت"]
    static let months = ["يناير", "فبراير", "مارس", "أبريل", "مايو", "يونيو", "يوليو", "أغسطس", "سبتمبر", "أكتوبر", "نوفمبر", "ديسمبر"]
    static let dayParts: [(String, String)] = [("الأح", "د"), ("الاثني", "ن"), ("الثلاث", "اء"), ("الأربع", "اء"), ("الخمي", "س"), ("الجمع", "ة"), ("السب", "ت")]

    static let sessions: [String: (course: Course, session: Session)] = {
        var m: [String: (course: Course, session: Session)] = [:]
        for c in courses { for s in c.sessions { m[s.id] = (c, s) } }
        return m
    }()
    static func course(_ id: String?) -> Course? { courses.first { $0.id == id } }
}

// ───────── الحالة المحفوظة (متوافقة مع JSON سكربت Scriptable) ─────────

struct LogEntry: Codable, Hashable, Identifiable {
    var id: String
    var s: String
    var d: String
    var ex: Bool
}

struct CancelEntry: Codable, Hashable {
    var s: String
    var d: String
}

struct Exam: Codable, Hashable, Identifiable {
    var id: String
    var courseId: String?
    var name: String
    var date: String
    var time: String
    var remind: Int
}

struct AppState: Codable, Equatable {
    var v: Int = 5
    var log: [LogEntry] = []
    var totals: [String: Int] = [:]
    var buffer: Int = 0
    var cancel: [CancelEntry] = []
    var exams: [Exam] = []
    var semStart: String = Term.semDefault
    var showWeek: Bool = true
    var changedAt: String? = nil

    static func fresh() -> AppState {
        var s = AppState()
        s.log = Term.portalLog.enumerated().map { LogEntry(id: "p\($0.offset)", s: $0.element.0, d: $0.element.1, ex: false) }
        for c in Term.courses { s.totals[c.id] = c.total }
        return s
    }

    func total(_ c: Course) -> Int { totals[c.id] ?? c.total }

    // قراءة متسامحة: تقبل ملف Scriptable كما هو (حقول ناقصة/زايدة/أرقام عشرية)
    static func from(json data: Data) -> AppState? {
        guard let o = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        var s = AppState()
        for c in Term.courses { s.totals[c.id] = c.total }
        if let t = o["totals"] as? [String: Any] {
            for (k, v) in t { if let n = (v as? NSNumber)?.intValue, n > 0 { s.totals[k] = n } }
        }
        if let l = o["log"] as? [[String: Any]] {
            s.log = l.enumerated().compactMap { i, e in
                guard let sid = e["s"] as? String, let d = e["d"] as? String else { return nil }
                return LogEntry(id: (e["id"] as? String) ?? "m\(i)", s: sid, d: d, ex: (e["ex"] as? Bool) ?? false)
            }
        } else { return nil }
        if let c = o["cancel"] as? [[String: Any]] {
            s.cancel = c.compactMap { e in
                guard let sid = e["s"] as? String, let d = e["d"] as? String, Fmt.date(d) != nil else { return nil }
                return CancelEntry(s: sid, d: d)
            }
        }
        if let ex = o["exams"] as? [[String: Any]] {
            s.exams = ex.compactMap { e in
                guard let d = e["date"] as? String, Fmt.date(d) != nil, let t = e["time"] as? String else { return nil }
                let r = (e["remind"] as? NSNumber)?.intValue ?? 1
                return Exam(id: (e["id"] as? String) ?? UUID().uuidString, courseId: e["courseId"] as? String,
                            name: (e["name"] as? String) ?? "اختبار", date: d, time: t, remind: [0, 1, 2, 3, 7].contains(r) ? r : 1)
            }
        }
        if let b = (o["buffer"] as? NSNumber)?.intValue { s.buffer = max(0, min(10, b)) }
        if let ss = o["semStart"] as? String, Fmt.date(ss) != nil { s.semStart = ss }
        if let w = o["showWeek"] as? Bool { s.showWeek = w }
        s.changedAt = o["changedAt"] as? String
        return s
    }

    func jsonData() -> Data {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        return (try? enc.encode(self)) ?? Data()
    }
}
