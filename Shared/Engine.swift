import Foundation

// ───────── التواريخ والتنسيق ─────────

enum Fmt {
    static var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        return c
    }()

    static func iso(_ d: Date) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
    static func date(_ iso: String) -> Date? {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3, iso.count == 10 else { return nil }
        var dc = DateComponents(); dc.year = p[0]; dc.month = p[1]; dc.day = p[2]
        guard let d = cal.date(from: dc) else { return nil }
        let back = cal.dateComponents([.year, .month, .day], from: d)
        return back.year == p[0] && back.month == p[1] && back.day == p[2] ? d : nil
    }
    static func weekday(_ d: Date) -> Int { cal.component(.weekday, from: d) - 1 }
    static func weekday(iso: String) -> Int { date(iso).map(weekday) ?? 0 }
    static func startOfDay(_ d: Date) -> Date { cal.startOfDay(for: d) }
    static func addDays(_ d: Date, _ n: Int) -> Date { cal.date(byAdding: .day, value: n, to: d) ?? d }
    static func minutes(_ d: Date) -> Int { cal.component(.hour, from: d) * 60 + cal.component(.minute, from: d) }

    // "٢٥ أكتوبر"
    static func stamp(_ iso: String) -> String {
        let p = iso.split(separator: "-").compactMap { Int($0) }
        guard p.count == 3 else { return iso }
        return "\(p[2]) \(Term.months[p[1] - 1])"
    }
    static func weekdayStamp(_ iso: String) -> String { Term.days[weekday(iso: iso)] + " " + stamp(iso) }

    // الأرقام العربية للعرض فقط
    static func ar(_ s: String, _ on: Bool = true) -> String {
        guard on else { return s }
        let digits = Array("٠١٢٣٤٥٦٧٨٩")
        var out = ""
        let chars = Array(s)
        for (i, ch) in chars.enumerated() {
            if let v = ch.wholeNumberValue, ch.isASCII { out.append(digits[v]) }
            else if ch == ".", i > 0, i + 1 < chars.count, chars[i - 1].isNumber, chars[i + 1].isNumber { out.append("٫") }
            else if ch == "%" { out.append("٪") }
            else { out.append(ch) }
        }
        return out
    }
    static func pct(_ p: Double, _ digits: Int = 1, est: Bool = false) -> String {
        (est ? "≈" : "") + String(format: "%.\(digits)f", p) + "%"
    }
    static func daysWord(_ n: Int) -> String {
        n <= 0 ? "ولا يوم" : n == 1 ? "يوم" : n == 2 ? "يومين" : n <= 10 ? "\(n) أيام" : "\(n) يوم"
    }
    static func dayName(_ d: Int, kash: Int) -> String {
        guard kash > 0, d >= 0, d < Term.dayParts.count else { return Term.days[max(0, min(6, d))] }
        let p = Term.dayParts[d]
        return p.0 + String(repeating: "ـ", count: kash) + p.1
    }
}

// ───────── الحسابات ─────────

struct CourseSummary: Identifiable {
    let c: Course
    let T: Int, un: Int, ex: Int, M: Int, rem: Int
    var id: String { c.id }
    var p: Double { T > 0 ? Double(un) / Double(T) * 100 : 0 }
    var over: Bool { rem < 0 }
}

struct VItem: Identifiable {
    let c: Course
    let sum: CourseSummary
    let cost: Int
    let after: Int
    let pAfter: Double
    let sessions: [Session]
    var id: String { c.id }
}

struct Verdict {
    let k: Int              // 0 اليوم، 1 بكرة، 2+ بعدها
    let d: Int              // يوم الأسبوع
    let date: Date
    let iso: String
    let items: [VItem]
    let logged: [CourseSummary]
    let cancelled: [(Course, Session)]
    let alreadyOver: [CourseSummary]
    let head: String
    let icon: String
    let ok: Bool
    var when: String { k == 0 ? "اليوم \(Term.days[d])" : k == 1 ? "بكرة \(Term.days[d])" : Term.days[d] }
}

struct RestPlan {
    let total: Int
    let n: [Int]           // أيام كاملة لكل يوم (أحد..أربعاء)
    let zeros: Int
    let bufferBlocked: Bool
    var text: String {
        let parts = n.enumerated().compactMap { $0.element > 0 ? "\($0.element) \(Term.days[$0.offset])" : nil }
        return parts.isEmpty ? "—" : parts.joined(separator: " + ")
    }
}

enum Engine {
    static func maxAllowed(_ T: Int) -> Int { Int(floor(Double(T) * 0.2499)) }

    static func isCancelled(_ st: AppState, _ sid: String, _ iso: String) -> Bool { st.cancel.contains { $0.s == sid && $0.d == iso } }
    static func hasLog(_ st: AppState, _ sid: String, _ iso: String) -> Bool { st.log.contains { $0.s == sid && $0.d == iso } }

    // كل محاضرة بتاريخها تنحسب مرة وحدة، وتنحسب بعذر فقط لو كل نسخها بعذر
    static func unique(_ st: AppState) -> [String: (s: String, d: String, ex: Bool, n: Int)] {
        var m: [String: (s: String, d: String, ex: Bool, n: Int)] = [:]
        for e in st.log {
            guard Term.sessions[e.s] != nil, Fmt.date(e.d) != nil else { continue }
            let k = e.s + "|" + e.d
            if var cur = m[k] { cur.ex = cur.ex && e.ex; cur.n += 1; m[k] = cur }
            else { m[k] = (e.s, e.d, e.ex, 1) }
        }
        return m
    }
    static func dupCount(_ st: AppState) -> Int { unique(st).values.reduce(0) { $0 + $1.n - 1 } }

    static func summary(_ st: AppState) -> [CourseSummary] {
        let U = unique(st)
        return Term.courses.map { c in
            var un = 0, ex = 0
            for e in U.values {
                guard let s = Term.sessions[e.s], s.course.id == c.id else { continue }
                if e.ex { ex += s.session.h } else { un += s.session.h }
            }
            let T = st.total(c), M = maxAllowed(T)
            return CourseSummary(c: c, T: T, un: un, ex: ex, M: M, rem: M - un)
        }
    }

    static func dayCosts(_ c: Course) -> [Int: Int] {
        var m: [Int: Int] = [:]
        for s in c.sessions { m[s.day, default: 0] += s.h }
        return m
    }

    // أقرب يوم دراسي: اليوم إذا ما خلصت آخر محاضرة، وإلا اللي بعده
    static func nextClassDay(_ now: Date) -> (k: Int, d: Int, date: Date) {
        let today = Fmt.startOfDay(now)
        for k in 0..<8 {
            let dt = Fmt.addDays(today, k)
            let d = Fmt.weekday(dt)
            guard let end = Term.dayEnd[d] else { continue }
            if k == 0 && Fmt.minutes(now) >= end { continue }
            return (k, d, dt)
        }
        return (1, Fmt.weekday(Fmt.addDays(today, 1)), Fmt.addDays(today, 1))
    }

    static func verdict(_ st: AppState, now: Date = Date()) -> Verdict {
        let t = nextClassDay(now), iso = Fmt.iso(t.date)
        let sum = summary(st)
        let buf = max(1, st.buffer)
        var items: [VItem] = [], logged: [CourseSummary] = [], cancelled: [(Course, Session)] = []
        for c in Term.courses {
            let todays = c.sessions.filter { $0.day == t.d }
            if todays.isEmpty { continue }
            guard let x = sum.first(where: { $0.c.id == c.id }) else { continue }
            let canc = todays.filter { isCancelled(st, $0.id, iso) }
            let done = todays.filter { !canc.contains($0) && hasLog(st, $0.id, iso) }
            let active = todays.filter { !canc.contains($0) && !done.contains($0) }
            canc.forEach { cancelled.append((c, $0)) }
            if !active.isEmpty {
                let cost = active.reduce(0) { $0 + $1.h }
                items.append(VItem(c: c, sum: x, cost: cost, after: x.rem - cost,
                                   pAfter: Double(x.un + cost) / Double(max(1, x.T)) * 100, sessions: active))
            } else if !done.isEmpty { logged.append(x) }
        }
        let over = items.filter { $0.after < 0 }
        let tight = items.filter { $0.after >= 0 && $0.after < buf }
        let alreadyOver = sum.filter { $0.over }
        var icon = "✓", head = "تقدر تغيب"
        if items.isEmpty { icon = alreadyOver.isEmpty ? "✓" : "✗"; head = logged.isEmpty ? "كل المحاضرات ملغاة" : "غيابك مسجّل" }
        else if !over.isEmpty { icon = "✗"; head = "لو غبت تنحرم في " + over.map { $0.c.short }.joined(separator: " و") }
        else if !tight.isEmpty { icon = "!"; head = "تقدر، بس على الحد" }
        return Verdict(k: t.k, d: t.d, date: t.date, iso: iso, items: items.sorted { $0.after < $1.after },
                       logged: logged, cancelled: cancelled, alreadyOver: alreadyOver, head: head, icon: icon,
                       ok: over.isEmpty && alreadyOver.isEmpty)
    }

    static func weekOf(_ st: AppState, _ dt: Date) -> Int {
        guard let start = Fmt.date(st.semStart) else { return 0 }
        let sunday = Fmt.addDays(start, -Fmt.weekday(start))
        let b = Fmt.startOfDay(dt)
        if b < start { return 0 }
        let days = Fmt.cal.dateComponents([.day], from: sunday, to: b).day ?? 0
        return days / 7 + 1
    }

    // أقصى عدد أيام كاملة تقدر تغيبها لنهاية الفصل (بحث شامل على الأحد..الأربعاء)
    static func restPlan(_ st: AppState) -> RestPlan? {
        let sum = summary(st)
        if sum.contains(where: { $0.rem < 0 }) { return nil }
        let cs = sum.map { (rem: $0.rem - st.buffer, dc: dayCosts($0.c)) }
        if cs.contains(where: { $0.rem < 0 }) { return RestPlan(total: 0, n: [0, 0, 0, 0], zeros: 0, bufferBlocked: true) }
        let cap = (0..<4).map { d -> Int in
            let xs = cs.filter { $0.dc[d] != nil }
            return xs.isEmpty ? 0 : xs.map { $0.rem / $0.dc[d]! }.min()!
        }
        var best = -1, bestPlan: (n: [Int], zeros: Int, sum: Int)? = nil
        for a in 0...cap[0] { for b in 0...cap[1] { for t in 0...cap[2] { for w in 0...cap[3] {
            let n = [a, b, t, w]
            var ok = true, zeros = 0, sm = 0
            for x in cs {
                var spent = 0
                for d in 0..<4 { spent += n[d] * (x.dc[d] ?? 0) }
                let left = x.rem - spent
                if left < 0 { ok = false; break }
                sm += left; if left == 0 { zeros += 1 }
            }
            if !ok { continue }
            let tot = a + b + t + w
            if tot > best { best = tot; bestPlan = (n, zeros, sm) }
            else if tot == best, let bp = bestPlan, zeros < bp.zeros || (zeros == bp.zeros && sm > bp.sum) { bestPlan = (n, zeros, sm) }
        }}}}
        guard let p = bestPlan else { return RestPlan(total: 0, n: [0, 0, 0, 0], zeros: 0, bufferBlocked: false) }
        return RestPlan(total: best, n: p.n, zeros: p.zeros, bufferBlocked: false)
    }

    // تسجيلات بتتجاوز الحد لو انضافت
    static func overs(_ st: AppState, adding: [(String, String)]) -> [CourseSummary] {
        var extra: [String: Int] = [:]
        for (sid, d) in adding where !hasLog(st, sid, d) {
            if let s = Term.sessions[sid] { extra[s.course.id, default: 0] += s.session.h }
        }
        return summary(st).filter { x in (extra[x.c.id] ?? 0) > 0 && x.un + (extra[x.c.id] ?? 0) > x.M }
    }

    static func nextExam(_ st: AppState, now: Date = Date()) -> Exam? {
        let t = Fmt.iso(now)
        return st.exams.filter { $0.date >= t }.sorted { ($0.date, $0.time) < ($1.date, $1.time) }.first
    }
    static func examDaysLeft(_ e: Exam, now: Date = Date()) -> Int {
        guard let d = Fmt.date(e.date) else { return 99 }
        return Fmt.cal.dateComponents([.day], from: Fmt.startOfDay(now), to: d).day ?? 99
    }

    // سطور رأس الودجت: تاريخ اليوم + الأسبوع، ثم ويكند/أوف/اليوم + اليوم الدراسي القادم، ثم اختبار قريب
    static func headerMeta(_ st: AppState, _ v: Verdict, now: Date = Date(), showWeek: Bool = true) -> (todayDay: Int, lines: [String]) {
        let td = Fmt.weekday(now)
        let wk = showWeek ? weekOf(st, now) : 0
        let next = (v.k == 1 ? "غدًا " : "") + Term.days[v.d]
        let hasClass = Term.dayEnd[td] != nil
        let line2 = v.k == 0 ? "اليوم" : !hasClass ? (td == 4 ? "أوف" : "ويكند") + " · " + next : next
        var lines = [Fmt.stamp(Fmt.iso(now)) + (wk >= 1 ? " · أسبوع \(wk)" : ""), line2]
        if let ex = nextExam(st, now: now) {
            let n = examDaysLeft(ex, now: now)
            if n >= 0 && n <= 2 {
                let c = Term.course(ex.courseId)
                let what = c.map { " " + $0.short } ?? (ex.name != "اختبار" ? " " + ex.name : "")
                lines.append("اختبار" + what + " " + (n == 0 ? "اليوم" : n == 1 ? "غدًا" : "بعد يومين"))
            }
        }
        return (td, lines)
    }

    // متى يعيد الودجت الحساب: بعد آخر محاضرة اليوم، ثم منتصف الليل
    static func refreshDates(now: Date = Date()) -> [Date] {
        let today = Fmt.startOfDay(now)
        var out: [Date] = []
        if let end = Term.dayEnd[Fmt.weekday(now)] {
            let e = Fmt.cal.date(byAdding: .minute, value: end + 1, to: today)!
            if e > now { out.append(e) }
        }
        out.append(Fmt.addDays(today, 1).addingTimeInterval(60))
        return out
    }
}
