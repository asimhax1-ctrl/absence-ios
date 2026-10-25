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
                .font(.app(17))
                .preferredColorScheme(model.scheme)
                .tint(Theme.accentInk)
                .id(model.appFont)
                .onChange(of: phase) { _, p in if p == .active { model.refresh() } }
                .onOpenURL { _ in model.refresh() }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        TabView {
            Tab("اليوم", systemImage: "calendar") { TodayView() }
            Tab("المواد", systemImage: "chart.bar") { CoursesView() }
            Tab("السجل", systemImage: "list.bullet") { LogView() }
            Tab("الاختبارات", systemImage: "list.clipboard") { ExamsView() }
            Tab("الإعدادات", systemImage: "gearshape") { SettingsView() }
        }
        .minimizeTabBarOnScroll()
        .overlay(alignment: .top) {
            if let t = m.toast {
                HStack(spacing: 10) {
                    Image(systemName: t.ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(t.ok ? Theme.accentInk : Theme.warn)
                    Text(t.text).font(.app(15, .medium)).multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 18).padding(.vertical, 12)
                .glassCapsule()
                .padding(.horizontal, 24).padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { m.toast = nil }
            }
        }
    }
}

struct SectionLabel: View {
    let text: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text).font(.app(13)).foregroundStyle(Theme.secondary)
            Spacer()
            if let t = trailing { Text(t).font(.app(13)).foregroundStyle(Theme.accentInk) }
        }
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
        let sum = Engine.summary(m.state)
        let tight = sum.filter { !$0.over }.min { $0.rem < $1.rem }
        let sessions = Term.courses.flatMap { c in c.sessions.filter { $0.day == v.d }.map { (c, $0) } }
        let open = sessions.filter { !Engine.isCancelled(m.state, $0.1.id, v.iso) && !Engine.hasLog(m.state, $0.1.id, v.iso) }
        let wk = m.state.showWeek ? Engine.weekOf(m.state, m.now) : 0
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.t((wk >= 1 ? "الأسبوع \(wk) · " : "") + Fmt.stamp(Fmt.iso(m.now)))).font(.app(14)).foregroundStyle(Theme.secondary)
                        Text(Term.days[Fmt.weekday(m.now)]).font(.app(34, .semibold))
                    }
                    Spacer()
                    VerdictPill(v: v)
                }
                .padding(.horizontal, 6).padding(.top, 8)

                // البطاقة الرئيسية: الحلقة + الأيام المتاحة
                HStack(spacing: 18) {
                    ZStack {
                        Ring(fraction: tight.map { Double(max(0, $0.rem)) / Double(max(1, $0.M)) } ?? 0)
                        VStack(spacing: 0) {
                            Text(m.t("\(plan?.total ?? 0)")).font(.app(34, .semibold))
                            Text((plan?.total ?? 0) <= 2 && (plan?.total ?? 0) > 0 ? ((plan?.total ?? 0) == 1 ? "يوم" : "يومين") : "أيام").font(.app(12)).foregroundStyle(Theme.secondary)
                        }
                    }
                    .frame(width: 108, height: 108)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("أيام تقدر تغيبها لنهاية الفصل").font(.app(17, .medium))
                        if let p = plan {
                            Text(m.t(p.bufferBlocked ? "هامش الأمان أكبر من الباقي في مادة" : Words.plan(p))).font(.app(14)).foregroundStyle(Theme.text.opacity(0.85))
                        } else {
                            Text("تجاوزت الحد في مادة").font(.app(14)).foregroundStyle(Theme.danger)
                        }
                        if let t = tight {
                            Text(m.t("أقرب مادة للحرمان: \(t.c.short)، باقي لك \(Words.hours(max(0, t.rem))) من \(t.M)"))
                                .font(.app(13)).foregroundStyle(Theme.secondary)
                        }
                    }
                }
                .card(20, radius: 30)

                SectionLabel(text: m.t(v.k == 0 ? "محاضرات اليوم" : "محاضرات \(v.when) · " + Fmt.stamp(v.iso)), trailing: examLine(v))

                ForEach(sessions, id: \.1.id) { pair in
                    SessionRow(c: pair.0, s: pair.1, iso: v.iso, isToday: v.k == 0, onLog: { ask([(pair.1.id, v.iso)]) })
                }

                if open.count > 1 {
                    Button { ask(open.map { ($0.1.id, v.iso) }) } label: {
                        Text(m.t("غبت \(v.k == 0 ? "اليوم" : Term.days[v.d]) كله (\(Words.hours(open.reduce(0) { $0 + $1.1.h })))"))
                            .font(.app(16, .medium)).frame(maxWidth: .infinity).frame(height: 52)
                    }
                    .foregroundStyle(Theme.accentInk)
                    .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                Text("اضغط مطولًا على أي محاضرة إذا كانت ملغاة.").font(.app(12)).foregroundStyle(Theme.secondary).padding(.horizontal, 6)
            }
            .padding(.horizontal, 16).padding(.bottom, 30)
        }
        .background(Theme.ground.ignoresSafeArea())
        .refreshable { m.refresh() }
        .alert("⚠️ هذا الغياب يتجاوز الحد", isPresented: Binding(get: { pending != nil && !overNames.isEmpty }, set: { if !$0 { pending = nil; overNames = "" } })) {
            Button("سجّل الغياب", role: .destructive) { if let p = pending { m.log(p) }; pending = nil; overNames = "" }
            Button("إلغاء", role: .cancel) { pending = nil; overNames = "" }
        } message: { Text("لو سجّلته تنحرم في: \(overNames). سجّله فقط إذا غبت فعلًا.") }
    }

    func examLine(_ v: Verdict) -> String? {
        guard let e = Engine.nextExam(m.state, now: m.now) else { return nil }
        let n = Engine.examDaysLeft(e, now: m.now)
        guard n >= 0 && n <= 3 else { return nil }
        let what = Term.course(e.courseId).map { $0.short } ?? e.name
        let when = n == 0 ? "اليوم" : n == 1 ? "بكرة" : Term.days[Fmt.weekday(iso: e.date)]
        return m.t("اختبار \(what) \(when) \(Words.time12(e.time))")
    }

    func ask(_ items: [(String, String)]) {
        let o = Engine.overs(m.state, adding: items)
        if o.isEmpty { m.log(items) } else { overNames = o.map { $0.c.short }.joined(separator: "، "); pending = items }
    }
}

struct VerdictPill: View {
    @EnvironmentObject var m: AppModel
    let v: Verdict
    var body: some View {
        let fg: Color = v.icon == "✓" ? Theme.accentInk : v.icon == "!" ? Theme.warn : Theme.danger
        let bg: Color = v.icon == "✓" ? Theme.accentSoft : v.icon == "!" ? Theme.warnSoft : Theme.dangerSoft
        let symbol = v.icon == "✓" ? "checkmark" : v.icon == "!" ? "exclamationmark" : "xmark"
        let title = v.icon == "✓" ? (v.k == 0 ? "تقدر تغيب اليوم" : v.k == 1 ? "تقدر تغيب بكرة" : "تقدر تغيب \(Term.days[v.d])")
            : v.icon == "!" ? "على الحد" : "لا تغيب"
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 13, weight: .bold))
            Text(title).font(.app(14, .medium))
        }
        .foregroundStyle(fg)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(bg, in: Capsule())
    }
}

struct SessionRow: View {
    @EnvironmentObject var m: AppModel
    let c: Course, s: Session, iso: String
    var isToday = true
    let onLog: () -> Void
    var body: some View {
        let cancelled = Engine.isCancelled(m.state, s.id, iso)
        let logged = Engine.hasLog(m.state, s.id, iso)
        let x = Engine.summary(m.state).first { $0.c.id == c.id }!
        let after = Double(x.un + s.h) / Double(max(1, x.T)) * 100
        let lineColor: Color = Theme.level(logged ? x.p : after).0
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(c.short).font(.app(16, .medium)).strikethrough(cancelled)
                    Text("· \(s.type)، \(Words.hours(s.h))").font(.app(12)).foregroundStyle(Theme.secondary)
                }
                if cancelled {
                    Text("ملغاة — ما تنحسب عليك").font(.app(13)).foregroundStyle(Theme.secondary)
                } else if logged {
                    Text(m.t("سجّلت غيابك\(isToday ? " اليوم" : "") · نسبتك صارت \(Fmt.pct(x.p, est: c.est))")).font(.app(13)).foregroundStyle(Theme.accentInk)
                } else {
                    (Text(m.t("نسبتك \(Fmt.pct(x.p, est: c.est)) ← تصير ")).foregroundStyle(Theme.secondary)
                     + Text(m.t(Fmt.pct(after, est: c.est))).foregroundStyle(x.rem - s.h < 0 ? Theme.danger : Theme.text).fontWeight(.medium)
                     + Text(" لو غبت").foregroundStyle(Theme.secondary))
                        .font(.app(13))
                }
                Text(m.t(x.rem < 0 ? "تجاوزت الحد" : "باقي لك \(Words.hours(x.rem)) قبل الحرمان")).font(.app(12)).foregroundStyle(x.rem < 0 ? Theme.danger : Theme.secondary)
                ProgressLine(p: x.p, color: lineColor, height: 4).padding(.top, 2)
            }
            Group {
                if cancelled {
                    Button("ملغاة") { m.toggleCancel(s.id, iso) }
                        .foregroundStyle(Theme.secondary).background(Theme.field, in: Capsule())
                } else if logged {
                    Button("غبت ✓") { m.unlog(s.id, iso) }
                        .foregroundStyle(Theme.accentInk).background(Theme.accentSoft, in: Capsule())
                } else {
                    Button("غبت") { onLog() }
                        .foregroundStyle(Theme.text).background(Theme.field, in: Capsule())
                        .overlay(Capsule().stroke(Theme.stroke, lineWidth: 1))
                }
            }
            .font(.app(15))
            .buttonStyle(PillButton())
        }
        .card(16)
        .contentShape(RoundedRectangle(cornerRadius: 22))
        .contextMenu {
            Button(cancelled ? "مو ملغاة" : "المحاضرة ملغاة", systemImage: "xmark.circle") { m.toggleCancel(s.id, iso) }
        }
    }
}

struct PillButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 18).frame(minWidth: 76, minHeight: 44)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

// ───────── المواد ─────────
struct CoursesView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("المواد").font(.app(32, .semibold)).padding(.horizontal, 6).padding(.top, 8)
                ForEach(Engine.summary(m.state)) { x in
                    let lc: Color = Theme.level(x.p).0
                    let ls: Color = Theme.level(x.p).1
                    let dc = Engine.dayCosts(x.c)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(x.c.name).font(.app(17, .medium))
                            Spacer()
                            Text(m.t(Fmt.pct(x.p, 1, est: x.c.est))).font(.app(22, .semibold)).foregroundStyle(lc)
                        }
                        ProgressLine(p: x.p, color: lc, height: 8)
                        HStack(spacing: 8) {
                            stat(m.t(Words.hours(x.un)), "غبت")
                            stat(m.t(Words.hours(x.M)), "الحد")
                            stat(m.t(Words.hours(max(0, x.rem))), "باقي لك", lc, ls)
                        }
                        Text(m.t("تقدر تغيب أيام كاملة: " + dc.keys.sorted().map { "\(Term.days[$0]) \(Words.times(max(0, x.rem / dc[$0]!)))" }.joined(separator: " · ")))
                            .font(.app(13)).foregroundStyle(Theme.secondary)
                        if x.ex > 0 { Text(m.t("غياب بعذر \(Words.hours(x.ex)) — ما ينحسب")).font(.app(13)).foregroundStyle(Theme.secondary) }
                        if x.c.est { Text("≈ إجمالي ساعات المادة تقديري").font(.app(12)).foregroundStyle(Theme.secondary) }
                    }
                    .card(18, radius: 26)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 30)
        }
        .background(Theme.ground.ignoresSafeArea())
    }

    func stat(_ value: String, _ label: String, _ fg: Color = Theme.text, _ bg: Color = Theme.field) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.app(14, .semibold)).foregroundStyle(fg).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.app(11)).foregroundStyle(Theme.secondary)
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
                    Button(m.t("حذف السجلات المكررة (\(Engine.dupCount(m.state)))")) { m.removeDuplicates() }
                        .font(.app(16)).listRowBackground(Theme.card)
                }
                ForEach(groups, id: \.key) { g in
                    Section {
                        ForEach(g.value.sorted { $0.s < $1.s }) { e in
                            let info = Term.sessions[e.s]
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(info?.course.short ?? e.s).font(.app(16, .medium))
                                    Text(m.t("\(info?.session.type ?? "?")، \(Words.hours(info?.session.h ?? 0))" + (e.id.hasPrefix("p") ? " · من البوابة" : "")))
                                        .font(.app(13)).foregroundStyle(Theme.secondary)
                                }
                                Spacer()
                                if e.ex {
                                    Text("بعذر").font(.app(12, .medium)).foregroundStyle(Theme.accentInk)
                                        .padding(.horizontal, 10).padding(.vertical, 4).background(Theme.accentSoft, in: Capsule())
                                }
                            }
                            .listRowBackground(Theme.card)
                            .swipeActions {
                                Button("حذف", role: .destructive) { m.remove(e) }
                                Button(e.ex ? "بدون عذر" : "بعذر") { m.toggleExcuse(e) }.tint(Theme.accent)
                            }
                        }
                    } header: { Text(m.t(Fmt.weekdayStamp(g.key))).font(.app(13)) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("السجل")
            .toolbar { Button { adding = true } label: { Image(systemName: "plus") } }
            .sheet(isPresented: $adding) { AddLogSheet().presentationDetents([.medium, .large]) }
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
                    .font(.app(16)).listRowBackground(Theme.card)
                if list.isEmpty { Text("ما عندك محاضرات يوم \(Term.days[d])").font(.app(15)).foregroundStyle(Theme.secondary).listRowBackground(Theme.card) }
                ForEach(list, id: \.1.id) { pair in
                    let c = pair.0, s = pair.1
                    let done = Engine.hasLog(m.state, s.id, iso)
                    Button {
                        if picked.contains(s.id) { picked.remove(s.id) } else { picked.insert(s.id) }
                    } label: {
                        HStack {
                            Text("\(c.short) · \(s.type)، \(Words.hours(s.h))").font(.app(16)).foregroundStyle(Theme.text)
                            Spacer()
                            if done { Text("مسجّلة").font(.app(13)).foregroundStyle(Theme.secondary) }
                            else if picked.contains(s.id) { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accentInk) }
                            else { Image(systemName: "circle").foregroundStyle(Theme.stroke) }
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
                    Button("سجّل") { m.log(picked.map { ($0, iso) }); dismiss() }.disabled(picked.isEmpty)
                }
            }
            .onChange(of: date) { _, _ in picked = [] }
        }
    }
}

// ميزات iOS 26 مع بديل للإصدارات الأقدم
extension View {
    @ViewBuilder func minimizeTabBarOnScroll() -> some View {
        if #available(iOS 26.0, *) { self.tabBarMinimizeBehavior(.onScrollDown) } else { self }
    }
    @ViewBuilder func glassCapsule() -> some View {
        if #available(iOS 26.0, *) { self.glassEffect(.regular, in: Capsule()) } else { self.background(.regularMaterial, in: Capsule()) }
    }
    @ViewBuilder func glassCard(_ radius: CGFloat = 22) -> some View {
        if #available(iOS 26.0, *) { self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius, style: .continuous)) }
        else { self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius, style: .continuous)) }
    }
}
