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
                .preferredColorScheme(model.scheme)
                .tint(Theme.accent)
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
            CoursesView().tabItem { Label("المواد", systemImage: "chart.bar.fill") }
            LogView().tabItem { Label("السجل", systemImage: "list.bullet") }
            ExamsView().tabItem { Label("الاختبارات", systemImage: "list.clipboard") }
            SettingsView().tabItem { Label("الإعدادات", systemImage: "gearshape") }
        }
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text).font(.footnote.weight(.semibold)).foregroundStyle(Theme.secondary)
            .padding(.horizontal, 6).padding(.top, 10)
    }
}

// ───────── اليوم ─────────
struct TodayView: View {
    @EnvironmentObject var m: AppModel
    @State private var pending: [(String, String)]? = nil
    @State private var overNames = ""

    var body: some View {
        let v = Engine.verdict(m.state, now: m.now)
        let plan = Engine.restPlan(m.state)
        let meta = Engine.headerMeta(m.state, v, now: m.now, showWeek: m.state.showWeek)
        let sessions = Term.courses.flatMap { c in c.sessions.filter { $0.day == v.d }.map { (c, $0) } }
        let open = sessions.filter { !Engine.isCancelled(m.state, $0.1.id, v.iso) && !Engine.hasLog(m.state, $0.1.id, v.iso) }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.t(meta.lines.joined(separator: " · "))).font(.subheadline.weight(.medium)).foregroundStyle(Theme.secondary)
                    Text(Term.days[meta.todayDay]).font(.system(size: 36, weight: .bold))
                }
                .padding(.horizontal, 6).padding(.top, 8)

                VerdictCard(v: v)

                SectionLabel(text: m.t(v.k == 0 ? "محاضرات اليوم" : "محاضرات \(v.when) · " + Fmt.stamp(v.iso)))
                VStack(spacing: 0) {
                    ForEach(Array(sessions.enumerated()), id: \.element.1.id) { i, pair in
                        if i > 0 { Divider().overlay(Theme.separator).padding(.leading, 16) }
                        SessionRow(c: pair.0, s: pair.1, iso: v.iso, onLog: { ask([(pair.1.id, v.iso)]) })
                    }
                }
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                if open.count > 1 {
                    Button { ask(open.map { ($0.1.id, v.iso) }) } label: {
                        Text(m.t("غبت \(v.k == 0 ? "اليوم" : Term.days[v.d]) كله · \(open.reduce(0) { $0 + $1.1.h })س"))
                            .font(.body.weight(.semibold)).frame(maxWidth: .infinity).frame(height: 50)
                    }
                    .foregroundStyle(Theme.accentInk)
                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("غياب متاح لنهاية الفصل").font(.footnote).foregroundStyle(Theme.secondary)
                        Text(m.t(plan.map { $0.bufferBlocked ? "هامش الأمان أكبر من المتبقي" : $0.text } ?? "تجاوزت الحد في مادة"))
                            .font(.subheadline.weight(.medium))
                    }
                    Spacer()
                    if let p = plan, !p.bufferBlocked {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(m.t("\(p.total)")).font(.system(size: 34, weight: .bold))
                            Text(p.total == 1 ? "يوم" : p.total == 2 ? "يومين" : "أيام").font(.subheadline.weight(.semibold))
                        }
                        .foregroundStyle(Theme.accentInk)
                    }
                }
                .card(18)
                Text("اليوم الكامل = كل محاضرات ذاك اليوم. الرقم للفصل كله بشرط ما تغيب غيرها. اسحب على أي محاضرة لتعليمها ملغاة.")
                    .font(.caption).foregroundStyle(Theme.secondary).padding(.horizontal, 6)
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .background(Theme.ground.ignoresSafeArea())
        .refreshable { m.refresh() }
        .alert("⚠️ هذا الغياب يتجاوز الحد", isPresented: Binding(get: { pending != nil && !overNames.isEmpty }, set: { if !$0 { pending = nil; overNames = "" } })) {
            Button("سجّل الغياب", role: .destructive) { if let p = pending { m.log(p) }; pending = nil; overNames = "" }
            Button("إلغاء", role: .cancel) { pending = nil; overNames = "" }
        } message: { Text("بعد التسجيل تتجاوز الحد في: \(overNames)\nسجّله فقط إذا غبت فعلًا.") }
    }

    func ask(_ items: [(String, String)]) {
        let o = Engine.overs(m.state, adding: items)
        if o.isEmpty { m.log(items) } else { overNames = o.map { $0.c.short }.joined(separator: "، "); pending = items }
    }
}

struct VerdictCard: View {
    @EnvironmentObject var m: AppModel
    let v: Verdict
    var body: some View {
        let tightest = v.items.first
        let fg: Color = v.icon == "✓" ? Theme.accent : v.icon == "!" ? Theme.warn : Theme.danger
        let bg: Color = v.icon == "✓" ? Theme.accentSoft : v.icon == "!" ? Theme.warnSoft : Theme.dangerSoft
        let symbol = v.icon == "✓" ? "checkmark" : v.icon == "!" ? "exclamationmark" : "xmark"
        let title = v.icon == "✓" ? (v.k == 0 ? "تقدر تغيب اليوم" : "تقدر تغيب \(v.when)") : v.head
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 24, weight: .bold)).foregroundStyle(fg)
                .frame(width: 52, height: 52).background(bg, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(m.t(title)).font(.title3.weight(.bold))
                if let t = tightest {
                    Text(m.t("أضيق مادة: \(t.c.short) — يبقى لك \(max(0, t.after))س بعدها")).font(.subheadline).foregroundStyle(Theme.secondary)
                } else {
                    Text(m.t(v.head)).font(.subheadline).foregroundStyle(Theme.secondary)
                }
            }
        }
        .card(18)
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
        let lc: Color = Theme.level(after).0
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(c.short).font(.body.weight(.semibold)).strikethrough(cancelled)
                    Text(m.t("\(s.type) · \(s.h)س")).font(.footnote.weight(.medium)).foregroundStyle(Theme.secondary)
                    Spacer()
                    Text(m.t(Fmt.pct(x.p, est: c.est))).font(.body.weight(.bold))
                }
                ProgressLine(p: x.p, color: lc)
                Text(m.t(cancelled ? "ملغاة — ما تنحسب" : logged ? "مسجّل غياب · باقي \(max(0, x.rem))س" : "لو غبت \(Fmt.pct(after, est: c.est)) · باقي \(max(0, x.rem))س"))
                    .font(.footnote).foregroundStyle(x.rem - s.h < 0 && !logged && !cancelled ? Theme.danger : Theme.secondary)
            }
            Group {
                if cancelled {
                    Button("مو ملغاة") { m.toggleCancel(s.id, iso) }
                        .foregroundStyle(Theme.secondary).background(Theme.track.opacity(0.6), in: Capsule())
                } else if logged {
                    Button("مسجّل ✓") { m.unlog(s.id, iso) }
                        .foregroundStyle(Theme.good).background(Theme.goodSoft, in: Capsule())
                } else {
                    Button("غبت") { onLog() }
                        .foregroundStyle(Theme.accentInk).background(Theme.accentSoft, in: Capsule())
                }
            }
            .font(.subheadline.weight(.semibold))
            .buttonStyle(PillButton())
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .contentShape(Rectangle())
        .contextMenu {
            Button(cancelled ? "مو ملغاة" : "المحاضرة ملغاة", systemImage: "xmark.circle") { m.toggleCancel(s.id, iso) }
        }
    }
}

struct PillButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 18).frame(minHeight: 44)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// ───────── المواد ─────────
struct CoursesView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("المواد").font(.system(size: 34, weight: .bold)).padding(.horizontal, 6).padding(.top, 8)
                ForEach(Engine.summary(m.state)) { x in
                    let lc: Color = Theme.level(x.p).0
                    let ls: Color = Theme.level(x.p).1
                    let dc = Engine.dayCosts(x.c)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(x.c.name).font(.headline)
                            Spacer()
                            Text(m.t(Fmt.pct(x.p, 2, est: x.c.est))).font(.title3.weight(.bold)).foregroundStyle(lc)
                        }
                        ProgressLine(p: x.p, color: lc, height: 8)
                        HStack(spacing: 8) {
                            stat(m.t("\(x.un)/\(x.T)س"), "غياب")
                            stat(m.t("\(x.M)س"), "الحد")
                            stat(m.t("\(max(0, x.rem))س"), "باقي", lc, ls)
                        }
                        Text(m.t("أيام كاملة متاحة: " + dc.keys.sorted().map { "\(Term.days[$0]) ×\(max(0, x.rem / dc[$0]!))" }.joined(separator: " · ")))
                            .font(.footnote).foregroundStyle(Theme.secondary)
                        if x.ex > 0 { Text(m.t("بعذر \(x.ex)س (ما تنحسب)")).font(.footnote).foregroundStyle(Theme.secondary) }
                        if x.c.est { Text("≈ إجمالي الساعات تقديري").font(.caption).foregroundStyle(Theme.secondary) }
                    }
                    .card(18)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .background(Theme.ground.ignoresSafeArea())
    }

    func stat(_ value: String, _ label: String, _ fg: Color = Theme.text, _ bg: Color = Theme.ground) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.subheadline.weight(.bold)).foregroundStyle(fg)
            Text(label).font(.caption).foregroundStyle(Theme.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 8)
        .background(bg, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// ───────── السجل ─────────
struct LogView: View {
    @EnvironmentObject var m: AppModel
    @State private var adding = false
    var body: some View {
        let groups = Dictionary(grouping: m.state.log, by: { $0.d }).sorted { $0.key > $1.key }
        NavigationStack {
            List {
                if Engine.dupCount(m.state) > 0 {
                    Button(m.t("حذف \(Engine.dupCount(m.state)) سجل مكرر")) { m.removeDuplicates() }
                        .listRowBackground(Theme.card)
                }
                ForEach(groups, id: \.key) { g in
                    Section(m.t(Fmt.weekdayStamp(g.key))) {
                        ForEach(g.value.sorted { $0.s < $1.s }) { e in
                            let info = Term.sessions[e.s]
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(info?.course.short ?? e.s).font(.body.weight(.semibold))
                                    Text(m.t("\(info?.session.type ?? "?") · \(info?.session.h ?? 0)س" + (e.id.hasPrefix("p") ? " · من البوابة" : "")))
                                        .font(.footnote).foregroundStyle(Theme.secondary)
                                }
                                Spacer()
                                if e.ex {
                                    Text("بعذر").font(.caption.weight(.semibold)).foregroundStyle(Theme.good)
                                        .padding(.horizontal, 10).padding(.vertical, 4).background(Theme.goodSoft, in: Capsule())
                                }
                            }
                            .listRowBackground(Theme.card)
                            .swipeActions {
                                Button("حذف", role: .destructive) { m.remove(e) }
                                Button(e.ex ? "بدون عذر" : "بعذر") { m.toggleExcuse(e) }.tint(Theme.good)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("السجل")
            .toolbar { Button { adding = true } label: { Image(systemName: "plus.circle.fill").font(.title3) } }
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
                    .listRowBackground(Theme.card)
                if list.isEmpty { Text("ما فيه محاضرات يوم \(Term.days[d])").foregroundStyle(Theme.secondary).listRowBackground(Theme.card) }
                ForEach(list, id: \.1.id) { pair in
                    let c = pair.0, s = pair.1
                    let done = Engine.hasLog(m.state, s.id, iso)
                    Button {
                        if picked.contains(s.id) { picked.remove(s.id) } else { picked.insert(s.id) }
                    } label: {
                        HStack {
                            Text("\(c.short) — \(s.type) (\(m.t(String(s.h)))س)").foregroundStyle(Theme.text)
                            Spacer()
                            if done { Text("مسجّل").foregroundStyle(Theme.secondary) }
                            else if picked.contains(s.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent) }
                            else { Image(systemName: "circle").foregroundStyle(Theme.track) }
                        }
                    }
                    .disabled(done || Engine.isCancelled(m.state, s.id, iso))
                    .listRowBackground(Theme.card)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("غبت بتاريخ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("سجّل") { m.log(picked.map { ($0, iso) }); dismiss() }.bold().disabled(picked.isEmpty)
                }
            }
            .onChange(of: date) { _, _ in picked = [] }
        }
    }
}
