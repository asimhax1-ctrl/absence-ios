import WidgetKit
import SwiftUI
import UIKit
import AppIntents

// ───────── إعدادات الودجت (اضغط مطولًا › تعديل الودجت) — نفس فكرة أذكار ─────────
struct WidgetConfig: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "غياب"
    static var description = IntentDescription("نسبة غيابك الحالية ونسبتك لو غبت")

    @Parameter(title: "الخط", default: .system)
    var font: FontChoice

    @Parameter(title: "حجم الخط", default: 0, controlStyle: .stepper, inclusiveRange: (-3, 4))
    var size: Int

    @Parameter(title: "خط عريض", default: true)
    var bold: Bool

    @Parameter(title: "تمديد اسم اليوم", default: true)
    var kashida: Bool

    @Parameter(title: "الخلفية", default: false)
    var background: Bool

    @Parameter(title: "أرقام عربية", default: true)
    var arabicDigits: Bool

    @Parameter(title: "إظهار الأسبوع", default: true)
    var showWeek: Bool

    @Parameter(title: "إظهار نسبة لو غبت", default: true)
    var showAfter: Bool
}

struct Entry: TimelineEntry {
    let date: Date
    let state: AppState
    let shared: Bool
    let cfg: WidgetConfig
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), state: .fresh(), shared: true, cfg: WidgetConfig()) }
    func snapshot(for configuration: WidgetConfig, in context: Context) async -> Entry { make(configuration, Date()) }
    func timeline(for configuration: WidgetConfig, in context: Context) async -> Timeline<Entry> {
        let now = Date()
        var entries = [make(configuration, now)]
        for d in Engine.refreshDates(now: now) { entries.append(make(configuration, d)) }
        return Timeline(entries: entries, policy: .atEnd)
    }
    private func make(_ cfg: WidgetConfig, _ date: Date) -> Entry {
        let store = Store.shared
        let st = store.load()
        store.widgetSeen(st != nil)
        return Entry(date: date, state: st ?? .fresh(), shared: st != nil, cfg: cfg)
    }
}

// ───────── أدوات الرسم ─────────
struct Look {
    let cfg: WidgetConfig
    let k: CGFloat
    func f(_ base: CGFloat, _ bold: Bool = false) -> Font { cfg.font.font(max(6, (base + CGFloat(cfg.size)) * k), bold: bold || cfg.bold) }
    func t(_ s: String) -> String { Fmt.ar(s, cfg.arabicDigits) }
}

struct Bar: View {
    let p: Double
    let after: Double
    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(0.25))
                Capsule().fill(Color.primary).frame(width: max(2, g.size.width * min(1, max(0.03, p / 25))))
            }
        }
        .frame(height: 3.5)
    }
}

// ───────── شاشة القفل: مستطيل ─────────
struct RectView: View {
    let e: Entry
    var body: some View {
        GeometryReader { g in
            RectContent(e: e, size: g.size)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

struct RectContent: View {
    let e: Entry
    let size: CGSize

    var v: Verdict { Engine.verdict(e.state, now: e.date) }

    // ارتفاع تقديري لكل المحتوى؛ إذا زاد عن الودجت نصغّر كل شي بنسبة وحدة
    func scale(_ metaCount: Int, _ rowCount: Int) -> CGFloat {
        let extra = CGFloat(e.cfg.size)
        let dayH: CGFloat = (23 + extra) * 1.25
        let metaH: CGFloat = CGFloat(metaCount) * (9.5 + extra * 0.5) * 1.3
        let rows: CGFloat = CGFloat(min(2, max(1, rowCount)))
        let rowsH: CGFloat = rows * (15 + extra) * 1.3
        let need: CGFloat = max(dayH, metaH) + rowsH + 2
        return min(1, size.height / need)
    }

    var body: some View {
        let verdict = v
        let meta = Engine.headerMeta(e.state, verdict, now: e.date, showWeek: e.cfg.showWeek)
        let rows = verdict.items
        let L = Look(cfg: e.cfg, k: scale(meta.lines.count, rows.count))
        return VStack(alignment: .leading, spacing: 1) {
            if !e.shared {
                Text("افتح التطبيق مرة").font(L.f(13, true))
                Text("البيانات غير مشتركة مع الودجت").font(L.f(10)).opacity(0.8)
            } else {
                header(L, meta, verdict)
                bodyRows(L, verdict, rows)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    @ViewBuilder
    func bodyRows(_ L: Look, _ verdict: Verdict, _ rows: [VItem]) -> some View {
        if let first = rows.first {
            fullRow(L, first)
            if rows.count == 2 { fullRow(L, rows[1]) }
            if rows.count >= 3 {
                HStack(spacing: 4) {
                    cell(L, rows[1])
                    Spacer(minLength: 2)
                    cell(L, rows[2])
                }
            }
        } else if !verdict.alreadyOver.isEmpty {
            let names = verdict.alreadyOver.map { $0.c.short }.joined(separator: "، ")
            Text(L.t("✗ تجاوزت الحد: " + names)).font(L.f(12, true)).lineLimit(1).minimumScaleFactor(0.5)
        } else {
            Text(L.t(verdict.head)).font(L.f(13, true)).lineLimit(1).minimumScaleFactor(0.5)
        }
    }

    func header(_ L: Look, _ meta: (todayDay: Int, lines: [String]), _ v: Verdict) -> some View {
        HStack(alignment: .center, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                if e.cfg.kashida {
                    Text(Fmt.dayName(meta.todayDay, kash: 8)).font(L.f(23, true)).lineLimit(1)
                    Text(Fmt.dayName(meta.todayDay, kash: 5)).font(L.f(23, true)).lineLimit(1)
                    Text(Fmt.dayName(meta.todayDay, kash: 2)).font(L.f(23, true)).lineLimit(1)
                }
                Text(Term.days[meta.todayDay]).font(L.f(23, true)).lineLimit(1).minimumScaleFactor(0.6)
            }
            .layoutPriority(1)
            Spacer(minLength: 2)
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(meta.lines.enumerated()), id: \.offset) { _, s in
                    Text(L.t(s)).font(L.f(meta.lines.count > 2 ? 9 : 10.5)).lineLimit(1).minimumScaleFactor(0.6).opacity(0.85)
                }
            }
        }
    }

    func mark(_ x: VItem) -> String { x.after < 0 ? "✗ " : x.after < max(1, e.state.buffer) ? "! " : "" }

    func fullRow(_ L: Look, _ x: VItem) -> some View {
        HStack(spacing: 4) {
            Text(L.t(mark(x) + x.c.short)).font(L.f(14)).lineLimit(1).minimumScaleFactor(0.6).layoutPriority(1)
            Bar(p: x.sum.p, after: x.pAfter).frame(minWidth: 12)
            Text(L.t(Fmt.pct(x.sum.p, est: x.c.est))).font(L.f(15, true)).lineLimit(1).minimumScaleFactor(0.6).layoutPriority(2)
            if e.cfg.showAfter {
                Text(L.t("←" + Fmt.pct(x.pAfter, est: x.c.est))).font(L.f(11)).lineLimit(1).minimumScaleFactor(0.6).opacity(0.75).layoutPriority(2)
            }
        }
    }

    func cell(_ L: Look, _ x: VItem) -> some View {
        HStack(spacing: 3) {
            Text(L.t(mark(x) + x.c.mini)).font(L.f(12)).lineLimit(1).minimumScaleFactor(0.6).opacity(0.9)
            Text(L.t(Fmt.pct(x.sum.p, est: x.c.est))).font(L.f(13, true)).lineLimit(1).minimumScaleFactor(0.6)
        }
    }
}

// ───────── شاشة القفل: سطر و دائرة ─────────
struct InlineView: View {
    let e: Entry
    var body: some View {
        let v = Engine.verdict(e.state, now: e.date)
        Text(Fmt.ar("\(v.when): \(v.ok ? "تقدر تغيب" : "لا تغيب")", e.cfg.arabicDigits))
    }
}

struct CircularView: View {
    let e: Entry
    var body: some View {
        let v = Engine.verdict(e.state, now: e.date)
        let worst = v.items.first
        VStack(spacing: 0) {
            Text(v.icon).font(e.cfg.font.font(20, bold: true))
            Text(Fmt.ar(worst.map { Fmt.pct($0.sum.p, 0) } ?? Term.days[v.d], e.cfg.arabicDigits))
                .font(e.cfg.font.font(10, bold: false)).lineLimit(1).minimumScaleFactor(0.5)
        }
    }
}

// ───────── الشاشة الرئيسية ─────────
struct HomeView: View {
    let e: Entry
    @Environment(\.widgetFamily) var family
    var body: some View {
        let v = Engine.verdict(e.state, now: e.date)
        let L = Look(cfg: e.cfg, k: family == .systemSmall ? 0.85 : 1)
        let sum = Engine.summary(e.state).sorted { $0.rem < $1.rem }
        let plan = Engine.restPlan(e.state)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(L.t(v.when)).font(L.f(18, true)).lineLimit(1).minimumScaleFactor(0.6)
                Spacer()
                Text(v.icon).font(L.f(18, true))
            }
            Text(L.t(v.head)).font(L.f(12)).lineLimit(1).minimumScaleFactor(0.6).opacity(0.8)
            ForEach(v.items.prefix(family == .systemSmall ? 2 : 3)) { x in
                HStack(spacing: 6) {
                    Text(L.t(x.c.short)).font(L.f(13)).lineLimit(1).minimumScaleFactor(0.6)
                    Bar(p: x.sum.p, after: x.pAfter)
                    Text(L.t(Fmt.pct(x.sum.p, est: x.c.est))).font(L.f(13, true)).lineLimit(1)
                    if e.cfg.showAfter && family != .systemSmall {
                        Text(L.t("←" + Fmt.pct(x.pAfter, est: x.c.est))).font(L.f(11)).opacity(0.7).lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
            if family != .systemSmall {
                Text(L.t(sum.prefix(4).map { "\($0.over ? "✗ " : "")\($0.c.short) \(max($0.rem, 0))س" }.joined(separator: " · ")))
                    .font(L.f(10)).lineLimit(1).minimumScaleFactor(0.6).opacity(0.75)
                Text(L.t("غياب متاح للفصل: " + Fmt.daysWord(plan?.total ?? 0)))
                    .font(L.f(10)).lineLimit(1).minimumScaleFactor(0.6).opacity(0.75)
            }
        }
        .padding(family == .systemSmall ? 12 : 14)
        .environment(\.layoutDirection, .rightToLeft)
    }
}

struct AbsenceWidgetView: View {
    let e: Entry
    @Environment(\.widgetFamily) var family
    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: RectView(e: e)
            case .accessoryInline: InlineView(e: e)
            case .accessoryCircular: CircularView(e: e)
            default: HomeView(e: e)
            }
        }
        .widgetURL(URL(string: "absence1448://open"))
        .containerBackground(for: .widget) {
            if family == .accessoryRectangular || family == .accessoryCircular {
                if e.cfg.background { AccessoryWidgetBackground() } else { Color.clear }
            } else if family == .accessoryInline {
                Color.clear
            } else {
                Color(UIColor.systemBackground)
            }
        }
    }
}

struct AbsenceWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "AbsenceWidget", intent: WidgetConfig.self, provider: Provider()) { e in
            AbsenceWidgetView(e: e)
        }
        .configurationDisplayName("غياب")
        .description("نسبة غيابك الحالية ونسبتك لو غبت")
        .supportedFamilies([.accessoryRectangular, .accessoryInline, .accessoryCircular, .systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

@main
struct AbsenceWidgets: WidgetBundle {
    var body: some Widget { AbsenceWidget() }
}
