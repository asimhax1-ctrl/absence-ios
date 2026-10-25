import SwiftUI
import UIKit
import WidgetKit

// ───────── الاختبارات ─────────
struct ExamsView: View {
    @EnvironmentObject var m: AppModel
    @State private var editing: Exam? = nil
    var body: some View {
        NavigationStack {
            List {
                if m.state.exams.isEmpty {
                    Text("ما عندك اختبارات. اضغط + وأضف اختبار مع تذكير.").font(.app(15)).foregroundStyle(Theme.secondary).listRowBackground(Theme.card)
                }
                ForEach(m.state.exams.sorted { ($0.date, $0.time) < ($1.date, $1.time) }) { e in
                    let n = Engine.examDaysLeft(e, now: m.now)
                    Button { editing = e } label: {
                        HStack(spacing: 14) {
                            VStack(spacing: 0) {
                                Text(m.t(String(Int(e.date.suffix(2)) ?? 0))).font(.app(22, .semibold))
                                Text(Term.months[(Int(e.date.dropFirst(5).prefix(2)) ?? 1) - 1]).font(.app(11, .medium))
                            }
                            .foregroundStyle(n < 0 ? Theme.secondary : Theme.accentInk)
                            .frame(width: 58, height: 58)
                            .background(n < 0 ? Theme.field : Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text((Term.course(e.courseId).map { $0.short + " — " } ?? "") + e.name).font(.app(16, .medium)).foregroundStyle(Theme.text)
                                Text(m.t(Term.days[Fmt.weekday(iso: e.date)] + " " + Words.time12(e.time) + " · " + (n < 0 ? "انتهى" : n == 0 ? "اليوم" : n == 1 ? "بكرة" : "بعد " + Words.days(n))))
                                    .font(.app(13)).foregroundStyle(Theme.secondary)
                            }
                        }
                    }
                    .listRowBackground(Theme.card)
                    .swipeActions { Button("حذف", role: .destructive) { m.deleteExam(e) } }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("الاختبارات")
            .toolbar {
                Button {
                    editing = Exam(id: UUID().uuidString, courseId: Term.courses.first?.id, name: "نصفي",
                                   date: Fmt.iso(Fmt.addDays(Date(), 7)), time: "09:00", remind: 1)
                } label: { Image(systemName: "plus") }
            }
            .sheet(item: $editing) { e in ExamSheet(exam: e).presentationDetents([.medium, .large]) }
        }
    }
}

struct ExamSheet: View {
    @EnvironmentObject var m: AppModel
    @Environment(\.dismiss) var dismiss
    @State var exam: Exam
    @State private var when = Date()
    private let reminds: [(String, Int)] = [("نفس اليوم ٧ الصبح", 0), ("قبل بيوم", 1), ("قبل بيومين", 2), ("قبل ٣ أيام", 3), ("قبل أسبوع", 7)]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("المادة", selection: Binding(get: { exam.courseId ?? "" }, set: { exam.courseId = $0.isEmpty ? nil : $0 })) {
                        ForEach(Term.courses) { Text($0.short).tag($0.id) }
                        Text("بدون مادة").tag("")
                    }
                    TextField("اسم الاختبار (نصفي، فاينل، كويز…)", text: $exam.name)
                }
                .listRowBackground(Theme.card)
                Section {
                    DatePicker("الموعد", selection: $when, displayedComponents: [.date, .hourAndMinute])
                    Picker("ذكّرني", selection: $exam.remind) { ForEach(reminds, id: \.1) { Text($0.0).tag($0.1) } }
                }
                .listRowBackground(Theme.card)
            }
            .font(.app(16))
            .scrollContentBackground(.hidden)
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("اختبار")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") {
                        exam.date = Fmt.iso(when)
                        let c = Fmt.cal.dateComponents([.hour, .minute], from: when)
                        exam.time = String(format: "%02d:%02d", c.hour ?? 9, c.minute ?? 0)
                        if exam.name.trimmingCharacters(in: .whitespaces).isEmpty { exam.name = "اختبار" }
                        m.saveExam(exam); m.say("انحفظ الاختبار والتذكير"); dismiss()
                    }
                }
            }
            .onAppear {
                if let d = Fmt.date(exam.date) {
                    let hm = exam.time.split(separator: ":").compactMap { Int($0) }
                    when = Fmt.cal.date(bySettingHour: hm.first ?? 9, minute: hm.count > 1 ? hm[1] : 0, second: 0, of: d) ?? d
                }
            }
        }
    }
}

// ───────── الإعدادات (أسلوب ب: معاينة حيّة فوق) ─────────
struct SettingsView: View {
    @EnvironmentObject var m: AppModel
    @State private var previewFont: FontChoice = .ruqaa
    @State private var confirmReset = false
    @State private var showSigning = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("الإعدادات").font(.app(32, .semibold)).padding(.horizontal, 6).padding(.top, 8)

                WidgetPreview(font: previewFont).frame(height: 150)

                SectionLabel(text: "خطوط الودجت — اضغط وشوف الشكل")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(FontChoice.allCases) { f in
                            Button { withAnimation(.snappy) { previewFont = f } } label: {
                                VStack(spacing: 2) {
                                    Text("أحد").font(f.font(23, bold: true)).lineLimit(1)
                                    Text(f.label).font(.app(11)).foregroundStyle(previewFont == f ? Theme.accentInk : Theme.secondary).lineLimit(1)
                                }
                                .frame(width: 88, height: 74)
                                .background(previewFont == f ? Theme.accentSoft : Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(previewFont == f ? Theme.accent : Theme.stroke, lineWidth: previewFont == f ? 2 : 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                Text("لتطبيق الخط على الودجت: اضغط مطولًا على الودجت ← تعديل الودجت ← الخط.").font(.app(12)).foregroundStyle(Theme.secondary).padding(.horizontal, 6)

                SectionLabel(text: "خط التطبيق")
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(AppFont.allCases) { f in
                        Button { m.appFont = f } label: {
                            Text(f.label).font(f.font(17, .medium)).foregroundStyle(Theme.text)
                                .frame(maxWidth: .infinity).frame(height: 60)
                                .background(m.appFont == f ? Theme.accentSoft : Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(m.appFont == f ? Theme.accent : Theme.stroke, lineWidth: m.appFont == f ? 2 : 1))
                        }
                        .buttonStyle(.plain)
                    }
                }

                SectionLabel(text: "المظهر")
                HStack(spacing: 10) {
                    themeThumb(0, "تلقائي")
                    themeThumb(1, "فاتح")
                    themeThumb(2, "داكن")
                }

                SectionLabel(text: "الحساب")
                VStack(spacing: 0) {
                    row {
                        Text("هامش الأمان").font(.app(16))
                        Spacer()
                        Stepper(m.t(m.state.buffer == 0 ? "بدون" : Words.hours(m.state.buffer)), value: Binding(get: { m.state.buffer }, set: { m.setBuffer($0) }), in: 0...4)
                            .font(.app(15)).fixedSize()
                    }
                    divider
                    row {
                        DatePicker("بداية الفصل", selection: Binding(get: { Fmt.date(m.state.semStart) ?? Date() }, set: { m.setSemStart($0) }), displayedComponents: .date)
                            .font(.app(16))
                    }
                    divider
                    row { Toggle("إظهار رقم الأسبوع", isOn: Binding(get: { m.state.showWeek }, set: { m.setShowWeek($0) })).font(.app(16)) }
                    divider
                    row { Toggle("أرقام عربية (١٢٣)", isOn: $m.arNum).font(.app(16)) }
                }
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                Text("هامش الأمان: ساعات تخليها احتياط في كل مادة، وما تنحسب ضمن الأيام المتاحة.").font(.app(12)).foregroundStyle(Theme.secondary).padding(.horizontal, 6)

                SectionLabel(text: "البيانات")
                VStack(spacing: 0) {
                    row {
                        Button("استيراد من Scriptable") {
                            let txt = UIPasteboard.general.string ?? ""
                            if m.importJSON(txt) { m.say("تم استيراد بياناتك") } else { m.say("الحافظة ما فيها بيانات الحاسبة", ok: false) }
                        }
                        .foregroundStyle(Theme.accentInk)
                        Spacer()
                        Image(systemName: "square.and.arrow.down").foregroundStyle(Theme.accentInk)
                    }
                    divider
                    row {
                        Button("نسخة احتياطية (نسخ للحافظة)") { UIPasteboard.general.string = m.exportJSON(); m.say("انسخت بياناتك") }
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Image(systemName: "doc.on.doc").foregroundStyle(Theme.secondary)
                    }
                    divider
                    row {
                        Button("الودجت ومشاركة البيانات") { showSigning = true }.foregroundStyle(Theme.text)
                        Spacer()
                        Text(Store.shared.sharedWithWidget ? "شغّالة" : "غير مدعومة").font(.app(12, .medium))
                            .foregroundStyle(Store.shared.sharedWithWidget ? Theme.accentInk : Theme.warn)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Store.shared.sharedWithWidget ? Theme.accentSoft : Theme.warnSoft, in: Capsule())
                    }
                    divider
                    row {
                        Button("رجّع السجل لغياب البوابة فقط", role: .destructive) { confirmReset = true }
                        Spacer()
                    }
                }
                .font(.app(16))
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                Text("الحرمان عند ٢٥٪ بدون عذر، والحد الآمن ٢٤٫٩٩٪. الغياب بعذر ما ينحسب.").font(.app(12)).foregroundStyle(Theme.secondary).padding(.horizontal, 6).padding(.top, 6)
            }
            .padding(.horizontal, 16).padding(.bottom, 30)
        }
        .background(Theme.ground.ignoresSafeArea())
        .confirmationDialog("يحذف كل تسجيلاتك ويرجّع غياب البوابة (حتى ٦ أكتوبر). الاختبارات تبقى.", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("رجّع", role: .destructive) { m.resetToPortal(); m.say("رجع السجل لغياب البوابة") }
        }
        .sheet(isPresented: $showSigning) { SigningSheet().presentationDetents([.medium, .large]) }
    }

    func row<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        HStack { content() }.padding(.horizontal, 16).frame(minHeight: 52)
    }
    var divider: some View { Rectangle().fill(Theme.separator).frame(height: 1).padding(.leading, 16) }

    func themeThumb(_ tag: Int, _ label: String) -> some View {
        Button { m.theme = tag } label: {
            VStack(spacing: 6) {
                Group {
                    if tag == 0 {
                        HStack(spacing: 0) { Color(white: 0.95); Color(white: 0.07) }
                    } else {
                        VStack(spacing: 5) {
                            RoundedRectangle(cornerRadius: 5).fill(tag == 1 ? Color.white : Color(white: 0.07)).frame(height: 13)
                            RoundedRectangle(cornerRadius: 5).fill(tag == 1 ? Color.white : Color(white: 0.07)).frame(height: 13)
                            Spacer()
                        }
                        .padding(.horizontal, 8).padding(.top, 10)
                        .background(tag == 1 ? Color(white: 0.95) : Color.black)
                    }
                }
                .frame(width: 60, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(m.theme == tag ? Theme.accent : Theme.stroke, lineWidth: m.theme == tag ? 2 : 1))
                Text(label).font(.app(13, m.theme == tag ? .semibold : .regular)).foregroundStyle(m.theme == tag ? Theme.accentInk : Theme.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// معاينة شكل ودجت شاشة القفل بالخط المختار (ببياناتك الحقيقية)
struct WidgetPreview: View {
    @EnvironmentObject var m: AppModel
    let font: FontChoice
    var body: some View {
        let v = Engine.verdict(m.state, now: m.now)
        let meta = Engine.headerMeta(m.state, v, now: m.now, showWeek: m.state.showWeek)
        let rows = v.items
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.navy)
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text(Fmt.dayName(meta.todayDay, kash: 5)).font(font.font(30, bold: true)).lineLimit(1).minimumScaleFactor(0.6)
                    Spacer()
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(meta.lines, id: \.self) { Text(m.t($0)).font(font.font(10.5, bold: false)).opacity(0.85).lineLimit(1) }
                    }
                }
                if let x = rows.first {
                    HStack(spacing: 8) {
                        Text(x.c.short).font(font.font(18, bold: true))
                        ProgressLine(p: x.sum.p, color: .white, height: 4)
                        Text(m.t(Fmt.pct(x.sum.p))).font(font.font(18, bold: true))
                        Text(m.t("←" + Fmt.pct(x.pAfter))).font(font.font(13, bold: false)).opacity(0.75)
                    }
                }
                if rows.count > 1 {
                    HStack {
                        Text(m.t(rows[1].c.mini + " " + Fmt.pct(rows[1].sum.p))).font(font.font(15, bold: true))
                        Spacer()
                        if rows.count > 2 { Text(m.t(rows[2].c.mini + " " + Fmt.pct(rows[2].sum.p))).font(font.font(15, bold: true)) }
                    }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 26).padding(.vertical, 18)
            .frame(maxHeight: .infinity)
            Text("معاينة ودجت شاشة القفل").font(.app(11)).foregroundStyle(.white.opacity(0.7)).padding(10)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

struct SigningSheet: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(Store.shared.sharedWithWidget
                         ? "الودجت يقرأ نفس بياناتك."
                         : "الشهادة اللي وقّعت فيها التطبيق ما تسمح يتشارك التطبيق والودجت البيانات (App Group / Keychain). عشان كذا الودجت يكتب «افتح التطبيق».")
                        .font(.app(15))
                    Text(Store.shared.backendsText).font(.system(size: 14, design: .monospaced)).card(14)
                    Text(Store.shared.profileText).font(.system(size: 12, design: .monospaced)).textSelection(.enabled).card(14)
                    Button("حدّث الودجت الحين") { WidgetCenter.shared.reloadAllTimelines() }.font(.app(16, .medium))
                }
                .padding(16)
            }
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("الودجت والتوقيع")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
