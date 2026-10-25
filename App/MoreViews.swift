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
                    Text("ما فيه اختبارات. اضغط + لإضافة اختبار وتذكير.").foregroundStyle(Theme.secondary).listRowBackground(Theme.card)
                }
                ForEach(m.state.exams.sorted { ($0.date, $0.time) < ($1.date, $1.time) }) { e in
                    let n = Engine.examDaysLeft(e, now: m.now)
                    Button { editing = e } label: {
                        HStack(spacing: 14) {
                            VStack(spacing: 0) {
                                Text(m.t(String(Int(e.date.suffix(2)) ?? 0))).font(.title2.weight(.bold))
                                Text(Term.months[(Int(e.date.dropFirst(5).prefix(2)) ?? 1) - 1]).font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(n < 0 ? Theme.secondary : Theme.accentInk)
                            .frame(width: 56, height: 56)
                            .background(n < 0 ? Theme.ground : Theme.accentSoft, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text((Term.course(e.courseId).map { $0.short + " — " } ?? "") + e.name).font(.body.weight(.semibold)).foregroundStyle(Theme.text)
                                Text(m.t(Term.days[Fmt.weekday(iso: e.date)] + " · " + e.time + " · " + (n < 0 ? "انتهى" : n == 0 ? "اليوم" : n == 1 ? "بكرة" : "بعد " + Fmt.daysWord(n))))
                                    .font(.footnote).foregroundStyle(Theme.secondary)
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
                } label: { Image(systemName: "plus.circle.fill").font(.title3) }
            }
            .sheet(item: $editing) { e in ExamSheet(exam: e) }
        }
    }
}

struct ExamSheet: View {
    @EnvironmentObject var m: AppModel
    @Environment(\.dismiss) var dismiss
    @State var exam: Exam
    @State private var when = Date()
    private let reminds: [(String, Int)] = [("نفس اليوم ٧ص", 0), ("قبل يوم ٨ص", 1), ("قبل يومين", 2), ("قبل ٣ أيام", 3), ("قبل أسبوع", 7)]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("المادة", selection: Binding(get: { exam.courseId ?? "" }, set: { exam.courseId = $0.isEmpty ? nil : $0 })) {
                        ForEach(Term.courses) { Text($0.short).tag($0.id) }
                        Text("بدون مادة").tag("")
                    }
                    TextField("اسم الاختبار (نصفي، فاينال، كويز…)", text: $exam.name)
                }
                .listRowBackground(Theme.card)
                Section {
                    DatePicker("الموعد", selection: $when, displayedComponents: [.date, .hourAndMinute])
                    Picker("التذكير", selection: $exam.remind) { ForEach(reminds, id: \.1) { Text($0.0).tag($0.1) } }
                }
                .listRowBackground(Theme.card)
            }
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
                        m.saveExam(exam); dismiss()
                    }
                    .bold()
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

// ───────── الإعدادات ─────────
struct SettingsView: View {
    @EnvironmentObject var m: AppModel
    @State private var msg: String? = nil
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section("المظهر") {
                    Picker("المظهر", selection: $m.theme) {
                        Text("تلقائي").tag(0)
                        Text("فاتح").tag(1)
                        Text("داكن").tag(2)
                    }
                    .pickerStyle(.segmented)
                    Toggle("أرقام عربية داخل التطبيق", isOn: $m.arNum)
                }
                .listRowBackground(Theme.card)
                Section("الحساب") {
                    Stepper(m.t("هامش الأمان: \(m.state.buffer) ساعة لكل مادة"), value: Binding(get: { m.state.buffer }, set: { m.setBuffer($0) }), in: 0...4)
                    DatePicker("بداية الفصل", selection: Binding(get: { Fmt.date(m.state.semStart) ?? Date() }, set: { m.setSemStart($0) }), displayedComponents: .date)
                    Toggle("إظهار رقم الأسبوع", isOn: Binding(get: { m.state.showWeek }, set: { m.setShowWeek($0) }))
                }
                .listRowBackground(Theme.card)
                Section {
                    NavigationLink("معرض الخطوط") { FontGallery() }
                    Text("لتغيير خط الودجت وحجمه وعرضه وخلفيته: اضغط مطولًا على الودجت › تعديل الودجت.")
                        .font(.footnote).foregroundStyle(Theme.secondary)
                } header: { Text("الودجت") }
                .listRowBackground(Theme.card)
                Section {
                    Text(Store.shared.backendsText).font(.callout.monospaced())
                    Text(widgetStatus).font(.footnote)
                    Button("حدّث الودجت الحين") { WidgetCenter.shared.reloadAllTimelines(); msg = "طلبت من iOS يحدّث الودجت." }
                } header: { Text("مشاركة البيانات مع الودجت") } footer: {
                    Text(Store.shared.sharedWithWidget ? "الودجت يقرأ نفس بياناتك." : "التوقيع الحالي ما يسمح بالمشاركة، فالودجت بيكتب «افتح التطبيق».")
                }
                .listRowBackground(Theme.card)
                Section("نقل البيانات") {
                    Button("استيراد من Scriptable (الصق من الحافظة)") {
                        let txt = UIPasteboard.general.string ?? ""
                        msg = m.importJSON(txt) ? "تم الاستيراد ✓" : "الحافظة ما فيها بيانات الحاسبة. في Scriptable: الإعدادات › تصدير البيانات لتطبيق iOS."
                    }
                    Button("نسخ بياناتي (نسخة احتياطية)") { UIPasteboard.general.string = m.exportJSON(); msg = "انسخت إلى الحافظة." }
                    Button("إرجاع السجل لغياب البوابة فقط", role: .destructive) { confirmReset = true }
                }
                .listRowBackground(Theme.card)
                Section {
                    Text("الحرمان عند ٢٥٪ بدون عذر، والحد الآمن ٢٤٫٩٩٪. الغياب بعذر ما ينحسب.").font(.footnote).foregroundStyle(Theme.secondary)
                }
                .listRowBackground(Theme.card)
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground.ignoresSafeArea())
            .navigationTitle("الإعدادات")
            .alert(msg ?? "", isPresented: Binding(get: { msg != nil }, set: { if !$0 { msg = nil } })) { Button("تم") {} }
            .confirmationDialog("يحذف كل تسجيلاتك ويرجع لغياب البوابة (حتى ٦ أكتوبر). الاختبارات تبقى.", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("إرجاع", role: .destructive) { m.resetToPortal() }
            }
        }
    }

    var widgetStatus: String {
        guard let s = Store.shared.lastWidgetSeen() else { return "الودجت ما قرأ البيانات للحين. أضفه لشاشة القفل ثم ارجع هنا." }
        let parts = s.split(separator: "|")
        let when = parts.first.flatMap { ISO8601DateFormatter().date(from: String($0)) }
        let f = DateFormatter(); f.locale = Locale(identifier: "ar"); f.dateStyle = .short; f.timeStyle = .short
        return "آخر قراءة من الودجت: " + (when.map { f.string(from: $0) } ?? "?") + (parts.count > 1 && parts[1] == "ok" ? " ✓" : " (ما لقى بيانات)")
    }
}

struct FontGallery: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        List(FontChoice.allCases) { f in
            VStack(alignment: .leading, spacing: 4) {
                Text(f.label).font(.caption).foregroundStyle(Theme.secondary)
                Text(m.t("الأحــــد  معادلات 7.3% ←9.8%")).font(f.font(26, bold: true)).lineLimit(1).minimumScaleFactor(0.5)
                Text(m.t("الأحــــد  معادلات 7.3%")).font(f.font(20, bold: false)).lineLimit(1).minimumScaleFactor(0.5).opacity(0.8)
            }
            .padding(.vertical, 4)
            .listRowBackground(Theme.card)
        }
        .scrollContentBackground(.hidden)
        .background(Theme.ground.ignoresSafeArea())
        .navigationTitle("الخطوط")
    }
}
