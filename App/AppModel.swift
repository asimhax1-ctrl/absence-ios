import SwiftUI
import WidgetKit
import UserNotifications

final class AppModel: ObservableObject {
    @Published private(set) var state: AppState
    @Published var arNum: Bool = UserDefaults.standard.object(forKey: "arNum") as? Bool ?? true {
        didSet { UserDefaults.standard.set(arNum, forKey: "arNum") }
    }
    @Published var now = Date()

    init() {
        if let s = Store.shared.load() { state = s }
        else { state = .fresh(); state.changedAt = ISO8601DateFormatter().string(from: Date()); Store.shared.save(state) }
        cleanCancels()
    }

    func t(_ s: String) -> String { Fmt.ar(s, arNum) }

    func refresh() {
        now = Date()
        if let s = Store.shared.load(), s != state { state = s }
    }

    func mutate(_ f: (inout AppState) -> Void) {
        var s = state
        f(&s)
        s.changedAt = ISO8601DateFormatter().string(from: Date())
        state = s
        Store.shared.save(s)
        WidgetCenter.shared.reloadAllTimelines()
    }

    // الإلغاءات الأقدم من 30 يوم ما لها داعي
    private func cleanCancels() {
        let cutoff = Fmt.iso(Fmt.addDays(Date(), -30))
        if state.cancel.contains(where: { $0.d < cutoff }) { mutate { $0.cancel.removeAll { $0.d < cutoff } } }
    }

    // ── الغياب ──
    func log(_ items: [(String, String)]) {
        mutate { s in
            for (sid, d) in items where !Engine.hasLog(s, sid, d) {
                s.log.append(LogEntry(id: "a" + String(UUID().uuidString.prefix(8)), s: sid, d: d, ex: false))
            }
        }
    }
    func unlog(_ sid: String, _ d: String) { mutate { $0.log.removeAll { $0.s == sid && $0.d == d } } }
    func remove(_ e: LogEntry) { mutate { $0.log.removeAll { $0.id == e.id } } }
    func toggleExcuse(_ e: LogEntry) {
        mutate { s in
            let v = !e.ex
            for i in s.log.indices where s.log[i].s == e.s && s.log[i].d == e.d { s.log[i].ex = v }
        }
    }
    func removeDuplicates() {
        mutate { s in
            var seen = Set<String>()
            s.log = s.log.filter { seen.insert($0.s + "|" + $0.d).inserted }
        }
    }
    func toggleCancel(_ sid: String, _ d: String) {
        mutate { s in
            if Engine.isCancelled(s, sid, d) { s.cancel.removeAll { $0.s == sid && $0.d == d } }
            else { s.cancel.append(CancelEntry(s: sid, d: d)); s.log.removeAll { $0.s == sid && $0.d == d } }
        }
    }

    // ── الإعدادات ──
    func setBuffer(_ b: Int) { mutate { $0.buffer = max(0, min(10, b)) } }
    func setSemStart(_ d: Date) { mutate { $0.semStart = Fmt.iso(d) } }
    func setShowWeek(_ v: Bool) { mutate { $0.showWeek = v } }
    func importJSON(_ text: String) -> Bool {
        guard let d = text.data(using: .utf8), var s = AppState.from(json: d) else { return false }
        s.changedAt = ISO8601DateFormatter().string(from: Date())
        state = s; Store.shared.save(s); WidgetCenter.shared.reloadAllTimelines()
        scheduleExams()
        return true
    }
    func exportJSON() -> String { String(data: state.jsonData(), encoding: .utf8) ?? "" }
    func resetToPortal() { let ch = state.exams; mutate { s in s = .fresh(); s.exams = ch } }

    // ── الاختبارات + التذكير ──
    func saveExam(_ e: Exam) {
        mutate { s in s.exams.removeAll { $0.id == e.id }; s.exams.append(e) }
        scheduleExams()
    }
    func deleteExam(_ e: Exam) { mutate { $0.exams.removeAll { $0.id == e.id } }; scheduleExams() }

    func scheduleExams() {
        let c = UNUserNotificationCenter.current()
        let exams = state.exams
        c.requestAuthorization(options: [.alert, .sound, .badge]) { ok, _ in
            guard ok else { return }
            c.removeAllPendingNotificationRequests()
            for e in exams {
                guard let day = Fmt.date(e.date) else { continue }
                var dc = Fmt.cal.dateComponents([.year, .month, .day], from: Fmt.addDays(day, -e.remind))
                dc.hour = e.remind == 0 ? 7 : 8; dc.minute = 0
                guard let fire = Fmt.cal.date(from: dc), fire > Date() else { continue }
                let n = UNMutableNotificationContent()
                let course = Term.course(e.courseId)
                n.title = e.remind == 0 ? "اختبار اليوم" : "اختبار قريب"
                n.body = (course.map { $0.short + " — " } ?? "") + e.name + "\n" + Fmt.weekdayStamp(e.date) + " · " + e.time
                n.sound = .default
                c.add(UNNotificationRequest(identifier: "exam-" + e.id, content: n,
                                            trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: false)))
            }
        }
    }
}
