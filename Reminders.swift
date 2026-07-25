import SwiftUI
import SwiftData
import UserNotifications

// Ödeme hatırlatmaları: telefonun kendi bildirim sistemiyle çalışır,
// internet/sunucu gerektirmez.
//
// İşleyiş: ödeme gününden 1 gün önce bildirim gider. Kullanıcı bildirim
// kutusundan "Ödedim" işaretlerse o ayın ödeme günü bildirimi gönderilmez.
enum PaymentReminders {
    static let notifyHour = 10 // bildirimler sabah 10'da gönderilir
    static let scheduledMonthCount = 3 // önümüzdeki 3 ay planlanır

    static func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // Hangi bildirimlerin kurulacağını hesaplar (bildirim sistemine dokunmaz).
    // Ayrı tutuluyor ki tarih/ödendi mantığı tek başına sınanabilsin.
    // Bir ödeme, verilen ay için "Ödedim" işaretli mi?
    static func isPaid(_ payment: FixedPayment, inMonth month: Date,
                       paidRecords: [PaidPayment], calendar: Calendar = .current) -> Bool {
        paidRecords.contains {
            $0.paymentName == payment.name
                && calendar.isDate($0.monthStart, equalTo: month, toGranularity: .month)
        }
    }

    static func plannedReminders(payments: [FixedPayment],
                                 paidRecords: [PaidPayment],
                                 now: Date = .now,
                                 calendar: Calendar = .current) -> [PlannedReminder] {
        var planned: [PlannedReminder] = []
        let thisMonth = calendar.dateInterval(of: .month, for: now)!.start

        for offset in 0..<scheduledMonthCount {
            guard let month = calendar.date(byAdding: .month, value: offset, to: thisMonth)
            else { continue }

            for payment in payments where payment.isActive(inMonth: month, calendar: calendar) {
                // Ödendi işaretlenmiş aylar atlanır
                guard !isPaid(payment, inMonth: month, paidRecords: paidRecords,
                              calendar: calendar),
                      let due = payment.dueDate(inMonth: month, calendar: calendar)
                else { continue }

                let key = monthKey(month, calendar: calendar)
                let amount = payment.amount.formatted(.currency(code: "TRY"))
                let body = "\(payment.name) · \(amount)"

                // Ödeme gününden 1 gün önce
                if let dayBefore = calendar.date(byAdding: .day, value: -1, to: due),
                   let fire = fireDate(on: dayBefore, after: now, calendar: calendar) {
                    planned.append(PlannedReminder(
                        id: "pay-\(payment.name)-\(key)-pre",
                        fireDate: fire,
                        title: tr("Yarın ödemen var", "Payment due tomorrow"),
                        body: body
                    ))
                }

                // Ödeme günü (ödendi işaretlenirse bu da kurulmaz)
                if let fire = fireDate(on: due, after: now, calendar: calendar) {
                    planned.append(PlannedReminder(
                        id: "pay-\(payment.name)-\(key)-due",
                        fireDate: fire,
                        title: tr("Bugün ödemen var", "Payment due today"),
                        body: body
                    ))
                }
            }
        }
        return planned.sorted { $0.fireDate < $1.fireDate }
    }

    // O günün bildirim saati; zamanı geçtiyse nil (geçmişe bildirim kurulmaz)
    private static func fireDate(on day: Date, after now: Date, calendar: Calendar) -> Date? {
        var components = calendar.dateComponents([.year, .month, .day], from: day)
        components.hour = notifyHour
        components.minute = 0
        guard let date = calendar.date(from: components), date > now else { return nil }
        return date
    }

    // Tüm hatırlatmaları baştan kurar (ödeme eklenince/silinince/ödendi işaretlenince çağrılır)
    static func reschedule(payments: [FixedPayment], paidRecords: [PaidPayment],
                           calendar: Calendar = .current) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        for item in plannedReminders(payments: payments, paidRecords: paidRecords,
                                     calendar: calendar) {
            let content = UNMutableNotificationContent()
            content.title = item.title
            content.body = item.body
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute],
                                                     from: item.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(identifier: item.id,
                                             content: content,
                                             trigger: trigger))
        }
    }

    private static func monthKey(_ month: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month], from: month)
        return "\(components.year ?? 0)-\(components.month ?? 0)"
    }

    // Zil rozetinde gösterilecek sayı: bildirimi gitmiş ama hâlâ ödenmemiş olanlar
    // (ödeme günü yarın, bugün veya geçmiş)
    static func pendingCount(_ payments: [FixedPayment], paidRecords: [PaidPayment],
                             calendar: Calendar = .current) -> Int {
        currentMonthReminders(payments, paidRecords: paidRecords, calendar: calendar)
            .filter { !$0.isPaid && $0.hasArrived }
            .count
    }

    // Bu ayın ödemeleri, durumlarıyla birlikte (ödeme gününe göre sıralı)
    static func currentMonthReminders(_ payments: [FixedPayment],
                                      paidRecords: [PaidPayment],
                                      calendar: Calendar = .current) -> [PaymentReminder] {
        let today = calendar.startOfDay(for: .now)
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start

        return payments
            .filter { $0.isActive(inMonth: thisMonth, calendar: calendar) }
            .compactMap { payment in
                guard let due = payment.dueDate(inMonth: thisMonth, calendar: calendar)
                else { return nil }
                let daysLeft = calendar.dateComponents([.day], from: today,
                                                       to: calendar.startOfDay(for: due)).day ?? 0
                return PaymentReminder(
                    payment: payment,
                    dueDate: due,
                    daysLeft: daysLeft,
                    isPaid: isPaid(payment, inMonth: thisMonth, paidRecords: paidRecords,
                                   calendar: calendar)
                )
            }
            .sorted { $0.dueDate < $1.dueDate }
    }
}

// Kurulacak tek bir bildirim
struct PlannedReminder: Identifiable {
    let id: String
    let fireDate: Date
    let title: String
    let body: String
}

// Bildirim kutusundaki tek bir satır
struct PaymentReminder: Identifiable {
    let payment: FixedPayment
    let dueDate: Date
    let daysLeft: Int // 0 = bugün, 1 = yarın, negatif = gecikmiş
    let isPaid: Bool

    var id: PersistentIdentifier { payment.persistentModelID }

    // Bildirimi gitmiş mi? (1 gün önce gönderiliyor)
    var hasArrived: Bool { daysLeft <= 1 }

    var statusText: String {
        switch daysLeft {
        case 0:          return tr("Bugün ödenecek", "Due today")
        case 1:          return tr("Yarın ödenecek", "Due tomorrow")
        case ..<0:       return tr("\(-daysLeft) gün gecikti", "\(-daysLeft) days overdue")
        default:         return tr("\(daysLeft) gün sonra", "in \(daysLeft) days")
        }
    }

    var statusColor: Color {
        if isPaid { return .green }
        if daysLeft < 0 { return .red }
        if daysLeft <= 1 { return .orange }
        return .secondary
    }
}

// Giderler ekranının sağ üstündeki zil: bekleyen hatırlatma varsa rozet gösterir
struct RemindersButton: View {
    let payments: [FixedPayment]
    let paidRecords: [PaidPayment]
    @State private var showingSheet = false

    private var pendingCount: Int {
        PaymentReminders.pendingCount(payments, paidRecords: paidRecords)
    }

    var body: some View {
        Button {
            showingSheet = true
        } label: {
            // Sabit çerçeveli ZStack: rozet araç çubuğunda kırpılmadan,
            // zilin kendi noktasıyla çakışmadan temiz çizilir
            ZStack(alignment: .topTrailing) {
                Image(systemName: pendingCount > 0 ? "bell.fill" : "bell")
                    .font(.title3)
                    .frame(width: 28, height: 28, alignment: .bottomLeading)

                if pendingCount > 0 {
                    Text(pendingCount > 9 ? "9+" : "\(pendingCount)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 15, minHeight: 15)
                        .background(Capsule().fill(.red))
                        .fixedSize()
                }
            }
            .frame(width: 32, height: 30)
        }
        .sheet(isPresented: $showingSheet) {
            RemindersSheet()
        }
    }
}

// Bildirim kutusu: bu ayın ödemeleri, "Ödedim" işaretiyle
struct RemindersSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FixedPayment.dueDay) private var payments: [FixedPayment]
    @Query private var paidRecords: [PaidPayment]

    private var reminders: [PaymentReminder] {
        PaymentReminders.currentMonthReminders(payments, paidRecords: paidRecords)
    }

    private var arrived: [PaymentReminder] {
        reminders.filter { !$0.isPaid && $0.hasArrived }
    }

    private var upcoming: [PaymentReminder] {
        reminders.filter { !$0.isPaid && !$0.hasArrived }
    }

    private var paid: [PaymentReminder] {
        reminders.filter(\.isPaid)
    }

    var body: some View {
        NavigationStack {
            List {
                if !arrived.isEmpty {
                    Section {
                        ForEach(arrived) { reminder in
                            reminderRow(reminder)
                        }
                    } header: {
                        Text(tr("Bekleyen Ödemeler", "Pending Payments"))
                    } footer: {
                        Text(tr("Ödediklerini işaretle; ödeme gününde tekrar bildirim gelmez.", "Mark what you paid; you won't get another reminder on the due date."))
                    }
                }

                if !upcoming.isEmpty {
                    Section(tr("Yaklaşanlar", "Upcoming")) {
                        ForEach(upcoming) { reminder in
                            reminderRow(reminder)
                        }
                    }
                }

                if !paid.isEmpty {
                    Section(tr("Ödendi", "Paid")) {
                        ForEach(paid) { reminder in
                            reminderRow(reminder)
                        }
                    }
                }
            }
            .navigationTitle(tr("Bildirimler", "Reminders"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Kapat", "Close")) { dismiss() }
                }
            }
            .overlay {
                if reminders.isEmpty {
                    ContentUnavailableView(
                        tr("Bu ay ödeme yok", "No payments this month"),
                        systemImage: "bell.slash",
                        description: Text(tr("Sabit ödeme ekleyince, ödeme gününden bir gün önce hatırlatma gelir.", "Once you add fixed payments, you get a reminder the day before they are due."))
                    )
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func reminderRow(_ reminder: PaymentReminder) -> some View {
        HStack(spacing: 12) {
            // "Ödedim" işareti: dokununca açılıp kapanır
            Button {
                togglePaid(reminder)
            } label: {
                Image(systemName: reminder.isPaid ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(reminder.isPaid ? .green : .secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.payment.name)
                    .strikethrough(reminder.isPaid, color: .secondary)
                    .foregroundStyle(reminder.isPaid ? .secondary : .primary)
                HStack(spacing: 4) {
                    Text(reminder.dueDate.formatted(.dateTime.day().month(.abbreviated).locale(appLocale)))
                    Text("·")
                    Text(reminder.isPaid ? tr("Ödendi", "Paid") : reminder.statusText)
                        .foregroundStyle(reminder.statusColor)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(reminder.payment.amount, format: .currency(code: "TRY"))
                .font(.callout.weight(.semibold))
                .foregroundStyle(reminder.isPaid ? .secondary : .primary)
        }
    }

    private func togglePaid(_ reminder: PaymentReminder) {
        let calendar = Calendar.current
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        let name = reminder.payment.name

        if reminder.isPaid {
            // İşareti kaldır
            for record in paidRecords where record.paymentName == name
                && calendar.isDate(record.monthStart, equalTo: thisMonth, toGranularity: .month) {
                modelContext.delete(record)
            }
        } else {
            modelContext.insert(PaidPayment(paymentName: name, monthStart: thisMonth))
        }
        try? modelContext.save()

        // İşaret değişince o ayın bildirimi iptal edilir / geri kurulur
        let updated = (try? modelContext.fetch(FetchDescriptor<PaidPayment>())) ?? []
        PaymentReminders.reschedule(payments: payments, paidRecords: updated)
    }
}
