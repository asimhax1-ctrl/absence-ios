import SwiftUI

@main
struct AbsenceApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var phase

    init() { FontRegistry.registerBundled() }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(model)
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, Locale(identifier: "ar"))
                .onChange(of: phase) { _, p in if p == .active { model.refresh() } }
                .onOpenURL { _ in model.refresh() }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        TabView {
            TodayView().tabItem { Label("اليوم", systemImage: "calendar") }
            CoursesView().tabItem { Label("المواد", systemImage: "chart.bar") }
            LogView().tabItem { Label("السجل", systemImage: "list.bullet") }
            ExamsView().tabItem { Label("الاختبارات", systemImage: "pencil.and.list.clipboard") }
            SettingsView().tabItem { Label("الإعدادات", systemImage: "gearshape") }
        }
    }
}

// ───────── اليوم: قرار الغياب + تسجيل بضغطة ─────────
struct TodayView: View {
    @EnvironmentObject var m: AppModel
    @State private var pending: [(String, String)]? = nil
    @State private var overNames = ""

    var body: some View {
        let v = Engine.verdict(m.state, now: m.now)
        let plan = Engine.restPlan(m.state)
        let meta = Engine.headerMeta(m.state, v, now: m.now, showWeek: m.state.showWeek)
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(Fmt.dayName(meta.todayDay, kash: 6)).font(.system(size: 30, weight: .bold))
                            Spacer()
                            VStack(alignment: .leading) { ForEach(meta.lines, id: \.self) { Text(m.t($0)).font(.caption).foregroundStyle(.secondary) } }
                        }
                        HStack {
                            Text(v.icon).font(.title2.bold()).foregroundStyle(v.icon == "✓" ? Color.green : v.icon == "!" ? Color.orange : Color.red)
                            Text(m.t("\(v.when): \(v.head)")).font(.headline)
                        }
                    }
                }
                Section(m.t("محاضرات \(Term.days[v.d]) " + Fmt.stamp(v.iso))) {
                    ForEach(Term.courses) { c in
                        ForEach(c.sessions.filter { $0.day == v.d }) { s in
                            SessionRow(c: c, s: s, iso: v.iso, onLog: { ask([(s.id, v.iso)]) })
                        }
                    }
                    let all = Term.courses.flatMap { c in c.sessions.filter { $0.day == v.d } }
                        .filter { !Engine.isCancelled(m.state, $0.id, v.iso) && !Engine.hasLog(m.state, $0.id, v.iso) }
                    if all.count > 1 {
                        Button("غبت اليوم كله (\(all.count) محاضرات)") { ask(all.map { ($0.id, v.iso) }) }
                            .bold()
                    }
                }
                Section("الغياب المتاح لنهاية الفصل") {
                    if let p = plan {
                        Text(m.t(p.bufferBlocked ? "هامش الأمان أكبر من المتبقي في مادة" : "\(Fmt.daysWord(p.total)) كاملة: \(p.text)"))
                        Text("اليوم الكامل = تغيب كل محاضرات اليوم. الرقم للفصل كله بشرط ما تغيب غيرها.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else { Text("تجاوزت الحد في مادة").foregroundStyle(.red) }
                }
            }
            .navigationTitle("حاسبة الحرمان")
            .refreshable { m.refresh() }
            .alert("⚠️ هذا الغياب يتجاوز الحد", isPresented: Binding(get: { pending != nil && !overNames.isEmpty }, set: { if !$0 { pending = nil; overNames = "" } })) {
                Button("سجّل الغياب", role: .destructive) { if let p = pending { m.log(p) }; pending = nil; overNames = "" }
                Button("إلغاء", role: .cancel) { pending = nil; overNames = "" }
            } message: { Text("بعد التسجيل تتجاوز الحد في: \(overNames)\nسجّله فقط إذا غبت فعلًا.") }
        }
    }

    func ask(_ items: [(String, String)]) {
        let o = Engine.overs(m.state, adding: items)
        if o.isEmpty { m.log(items) } else { overNames = o.map { $0.c.short }.joined(separator: "، "); pending = items }
    }
}

struct SessionRow: View {
    @EnvironmentObject var m: AppModel
    let c: Course, s: Session, iso: String
    let onLog: () -> Void
    var body: some View {
        let cancelled = Engine.isCancelled(m.state, s.id, iso)
        let logged = Engine.hasLog(m.state, s.id, iso)
        let x = Engine.summary(m.state).first { $0.c.id == c.id }!
        let after = Double(x.un + s.h) / Double(max(1, x.T)) * 100
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(c.short + " — " + s.type).font(.body.bold()).strikethrough(cancelled)
                Text(m.t("\(Fmt.pct(x.p, est: c.est)) الحين ← \(Fmt.pct(after, est: c.est)) لو غبت · باقي \(max(0, x.rem))س"))
                    .font(.caption).foregroundStyle(x.rem - s.h < 0 ? Color.red : Color.secondary)
            }
            Spacer()
            if cancelled { Text("ملغاة").font(.caption).foregroundStyle(.secondary) }
            else if logged { Button("مسجّل ✓") { m.unlog(s.id, iso) }.buttonStyle(.bordered).tint(.green) }
            else { Button("غبت") { onLog() }.buttonStyle(.borderedProminent) }
        }
        .swipeActions {
            Button(cancelled ? "مو ملغاة" : "ملغاة") { m.toggleCancel(s.id, iso) }.tint(.gray)
        }
    }
}

// ───────── المواد ─────────
struct CoursesView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        NavigationStack {
            List(Engine.summary(m.state)) { x in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(x.c.name).bold()
                        Spacer()
                        Text(m.t(Fmt.pct(x.p, 2, est: x.c.est))).bold().foregroundStyle(x.p >= 20 ? Color.red : x.p >= 12.5 ? Color.orange : Color.green)
                    }
                    ProgressView(value: min(x.p, 25), total: 25).tint(x.p >= 20 ? Color.red : x.p >= 12.5 ? Color.orange : Color.green)
                    Text(m.t("\(x.un)/\(x.T)س · الحد \(x.M)س · باقي \(max(0, x.rem))س" + (x.ex > 0 ? " · بعذر \(x.ex)س" : "")))
                        .font(.caption).foregroundStyle(.secondary)
                    let dc = Engine.dayCosts(x.c)
                    Text(m.t(dc.keys.sorted().map { "\(Term.days[$0]) ×\(max(0, x.rem / dc[$0]!))" }.joined(separator: " · ")))
                        .font(.caption2).foregroundStyle(.secondary)
                    if x.c.est { Text("≈ إجمالي الساعات تقديري").font(.caption2).foregroundStyle(.secondary) }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("المواد")
        }
    }
}

// ───────── السجل ─────────
struct LogView: View {
    @EnvironmentObject var m: AppModel
    @State private var adding = false
    var body: some View {
        NavigationStack {
            List {
                if Engine.dupCount(m.state) > 0 {
                    Button(m.t("حذف \(Engine.dupCount(m.state)) سجل مكرر")) { m.removeDuplicates() }
                }
                ForEach(m.state.log.sorted { ($0.d, $0.s) > ($1.d, $1.s) }) { e in
                    let info = Term.sessions[e.s]
                    HStack {
                        VStack(alignment: .leading) {
                            Text((info?.course.short ?? e.s) + " — " + (info?.session.type ?? "?")).bold()
                            Text(m.t(Fmt.weekdayStamp(e.d) + " · \(info?.session.h ?? 0)س" + (e.id.hasPrefix("p") ? " · من البوابة" : ""))).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if e.ex { Text("بعذر").font(.caption).padding(4).background(.blue.opacity(0.2), in: Capsule()) }
                    }
                    .swipeActions {
                        Button("حذف", role: .destructive) { m.remove(e) }
                        Button(e.ex ? "بدون عذر" : "بعذر") { m.toggleExcuse(e) }.tint(.blue)
                    }
                }
            }
            .navigationTitle("السجل")
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $adding) { AddLogSheet() }
        }
    }
}

struct AddLogSheet: View {
    @EnvironmentObject var m: AppModel
    @Environment(\.dismiss) var dismiss
    @State private var date = Date()
    @State private var picked = Set<String>()
    var body: some View {
        let iso = Fmt.iso(date), d = Fmt.weekday(date)
        let list = Term.courses.flatMap { c in c.sessions.filter { $0.day == d }.map { (c, $0) } }
        NavigationStack {
            Form {
                DatePicker("التاريخ", selection: $date, displayedComponents: .date)
                if list.isEmpty { Text("ما فيه محاضرات يوم \(Term.days[d])").foregroundStyle(.secondary) }
                ForEach(list, id: \.1.id) { pair in
                    let c = pair.0, s = pair.1
                    let done = Engine.hasLog(m.state, s.id, iso)
                    Button {
                        if picked.contains(s.id) { picked.remove(s.id) } else { picked.insert(s.id) }
                    } label: {
                        HStack {
                            Text("\(c.short) — \(s.type) (\(m.t(String(s.h)))س)")
                            Spacer()
                            if done { Text("مسجّل").foregroundStyle(.secondary) }
                            else if picked.contains(s.id) { Image(systemName: "checkmark") }
                        }
                    }
                    .disabled(done || Engine.isCancelled(m.state, s.id, iso))
                }
            }
            .navigationTitle("غبت بتاريخ")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("سجّل") { m.log(picked.map { ($0, iso) }); dismiss() }.disabled(picked.isEmpty)
                }
            }
            .onChange(of: date) { _, _ in picked = [] }
        }
    }
}
