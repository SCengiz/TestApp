import SwiftUI
import SwiftData

struct FixedPaymentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FixedPayment.dueDay) private var payments: [FixedPayment]
    @State private var showingAddSheet = false
    @State private var editingPayment: FixedPayment?
    @State private var monthOffset = 0 // -3 (3 ay geri) ... +3 (3 ay ileri)

    private var calendar: Calendar { .current }

    // Görüntülenen ay
    private var selectedMonth: Date {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        return calendar.date(byAdding: .month, value: monthOffset, to: thisMonth)!
    }

    // Seçili ayda geçerli ödemeler (biten taksitler ve başka aya özel
    // tek seferlikler o ayda listelenmez)
    private var monthPayments: [FixedPayment] {
        payments.filter { $0.isActive(inMonth: selectedMonth) }
    }

    private var monthlyTotal: Double {
        monthPayments.reduce(0) { $0 + $1.amount }
    }

    private var cardTitle: String {
        monthOffset == 0
            ? tr("Bu Ay Toplam", "This Month Total")
            : selectedMonth.formatted(.dateTime.month(.wide).year().locale(appLocale))
    }

    var body: some View {
        List {
            Section {
                StatCard(
                    title: cardTitle,
                    amount: monthlyTotal,
                    icon: "building.columns.fill",
                    colors: [.blue, .cyan]
                )
                // Ay gezinme okları: 3 ay geri / 3 ay ileri
                .overlay(alignment: .trailing) {
                    HStack(spacing: 8) {
                        monthArrow("chevron.left", enabled: monthOffset > -3) {
                            monthOffset -= 1
                        }
                        monthArrow("chevron.right", enabled: monthOffset < 3) {
                            monthOffset += 1
                        }
                    }
                    .padding(.trailing, 14)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(monthPayments) { payment in
                    Button {
                        editingPayment = payment
                    } label: {
                        HStack(spacing: 12) {
                            RowIcon(systemName: "creditcard.fill", color: .blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(payment.name)
                                    .foregroundStyle(.primary)
                                Text(subtitle(for: payment))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(payment.amount, format: .currency(code: "TRY"))
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deletePayments)
            } header: {
                Text(tr("Sabit Ödemeler", "Fixed Payments"))
            } footer: {
                Text(monthOffset == 0
                     ? tr("Düzenlemek veya silmek için ödemeye dokun. Karttaki oklarla geçmiş ve gelecek ayların planını görebilirsin.", "Tap a payment to edit or delete. Use the arrows on the card to see past and future months.")
                     : tr("Bu ayda ödenen/ödenecek kalemler. Değişiklikler tüm aylara yansır.", "Payments due in this month. Changes apply to all months."))
            }
        }
        .navigationTitle(tr("Sabit Ödemeler", "Fixed Payments"))
        .toolbar {
            Button {
                showingAddSheet = true
            } label: {
                Label(tr("Sabit Ödeme Ekle", "Add Fixed Payment"), systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddFixedPaymentView(payment: nil)
        }
        .sheet(item: $editingPayment) { payment in
            AddFixedPaymentView(payment: payment)
        }
        .overlay {
            if monthPayments.isEmpty {
                ContentUnavailableView(
                    monthOffset == 0
                        ? tr("Henüz sabit ödeme yok", "No fixed payments yet")
                        : tr("Bu aya ödeme yok", "No payments this month"),
                    systemImage: "creditcard",
                    description: Text(monthOffset == 0
                                      ? tr("Kredi kartı ekstresi, kredi taksidi gibi her ay tekrarlayan ödemeleri + ile ekle.", "Add recurring payments like card statements or loan installments with +.")
                                      : tr("Karttaki oklarla aylar arasında gezinebilirsin.", "Use the arrows on the card to browse months."))
                )
            }
        }
    }

    private func refreshReminders() {
        let all = (try? modelContext.fetch(FetchDescriptor<FixedPayment>())) ?? []
        let paid = (try? modelContext.fetch(FetchDescriptor<PaidPayment>())) ?? []
        PaymentReminders.reschedule(payments: all, paidRecords: paid)
    }

    private func monthArrow(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .foregroundStyle(.white.opacity(enabled ? 1 : 0.35))
                .frame(width: 36, height: 36)
                .background(Circle().fill(.white.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }

    private func deletePayments(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(monthPayments[index])
        }
        try? modelContext.save()
        refreshReminders()
    }

    // "Taksit 5/12 · kalan 7 ay · Her ayın 15'i" gibi alt satır
    private func subtitle(for payment: FixedPayment) -> String {
        // Tek seferlik ödeme: hangi aya ait olduğunu göster
        if payment.totalInstallments == 1, let first = payment.firstPaymentDate {
            let month = first.formatted(.dateTime.month(.wide).year().locale(appLocale))
            return tr("Tek seferlik · \(month) · Ayın \(payment.dueDay). günü", "One-time · \(month) · day \(payment.dueDay)")
        }
        if let total = payment.totalInstallments,
           let number = payment.installmentNumber(inMonth: selectedMonth) {
            return tr("Taksit \(number)/\(total) · kalan \(total - number) ay · Her ayın \(payment.dueDay). günü", "Installment \(number)/\(total) · \(total - number) months left · day \(payment.dueDay)")
        }
        if let total = payment.totalInstallments {
            return tr("Taksit bitti (\(total)/\(total)) · Her ayın \(payment.dueDay). günü", "Installments finished (\(total)/\(total)) · day \(payment.dueDay)")
        }
        return tr("Süresiz · Her ayın \(payment.dueDay). günü", "Open-ended · day \(payment.dueDay) each month")
    }
}

// Sabit ödeme ekleme / düzenleme formu (payment nil ise yeni kayıt)
struct AddFixedPaymentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let payment: FixedPayment?

    // Ödeme türü: her ay tekrar eden, taksitli veya sadece tek bir aya özel
    enum PaymentKind: String, CaseIterable {
        case recurring
        case installment
        case oneTime

        var title: String {
            switch self {
            case .recurring:   return tr("Süresiz", "Open-ended")
            case .installment: return tr("Taksitli", "Installments")
            case .oneTime:     return tr("Tek Seferlik", "One-time")
            }
        }
    }

    @State private var name = ""
    @State private var amount: Double?
    @State private var dueDay = 1
    @State private var kind: PaymentKind = .recurring
    @State private var totalInstallments = 12
    @State private var currentInstallment = 1
    @State private var oneTimeMonth: Date = Calendar.current.dateInterval(of: .month, for: .now)!.start

    // Tek seferlik ödeme için seçilebilecek aylar (bu ay + 12 ay ileri)
    private var monthOptions: [Date] {
        let calendar = Calendar.current
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        var options = (0...12).compactMap {
            calendar.date(byAdding: .month, value: $0, to: thisMonth)
        }
        if !options.contains(oneTimeMonth) {
            options.append(oneTimeMonth)
            options.sort()
        }
        return options
    }

    var body: some View {
        NavigationStack {
            Form {
                VoiceEntrySection(hint: tr("Sesle söyle", "Say it out loud")) { spoken in
                    let parsed = parseSpokenExpense(spoken)
                    if let spokenName = parsed.title { name = spokenName }
                    if let spokenAmount = parsed.amount { amount = spokenAmount }
                }

                Section(tr("Elle Gir", "Manual Entry")) {
                    TextField(tr("Adı (örn. Kredi kartı ekstresi)", "Name (e.g. Card statement)"), text: $name)
                        .textInputAutocapitalization(.words)

                    TextField(tr("Aylık tutar (TL)", "Monthly amount (TL)"), value: $amount, format: .number)
                        .keyboardType(.decimalPad)

                    Picker(tr("Ödeme günü", "Payment day"), selection: $dueDay) {
                        ForEach(1...28, id: \.self) { day in
                            Text(tr("Her ayın \(day). günü", "Day \(day) of each month")).tag(day)
                        }
                    }
                }

                Section {
                    Picker(tr("Ödeme türü", "Payment kind"), selection: $kind.animation()) {
                        ForEach(PaymentKind.allCases, id: \.self) { k in
                            Text(k.title).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)

                    if kind == .installment {
                        Picker(tr("Toplam taksit", "Total installments"), selection: $totalInstallments) {
                            ForEach(2...48, id: \.self) { n in
                                Text(tr("\(n) taksit", "\(n) installments")).tag(n)
                            }
                        }
                        Picker(tr("Şu an kaçıncı taksit", "Which installment now"), selection: $currentInstallment) {
                            ForEach(1...totalInstallments, id: \.self) { n in
                                Text(tr("\(n). taksit", "installment #\(n)")).tag(n)
                            }
                        }
                        Text(tr("Kalan: \(totalInstallments - currentInstallment) ay sonra bitecek", "Ends in \(totalInstallments - currentInstallment) months"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if kind == .oneTime {
                        Picker(tr("Hangi aya", "Which month"), selection: $oneTimeMonth) {
                            ForEach(monthOptions, id: \.self) { month in
                                Text(month.formatted(.dateTime.month(.wide).year().locale(appLocale))).tag(month)
                            }
                        }
                    }
                } footer: {
                    switch kind {
                    case .recurring:
                        Text(tr("Fatura, abonelik gibi her ay tekrar eden ödemeler için.", "For payments repeating every month, like bills or subscriptions."))
                    case .installment:
                        Text(tr("Kredi taksidi gibi belirli sayıda ödemesi olanlar için.", "For payments with a set number of installments, like loans."))
                    case .oneTime:
                        Text(tr("Sadece seçtiğin aya işlenir; diğer ayların planını etkilemez.", "Applies only to the selected month."))
                    }
                }

                // Var olan ödemeyi silme (plan grafiği anında güncellenir)
                if payment != nil {
                    Section {
                        Button(tr("Ödemeyi Sil", "Delete Payment"), role: .destructive) {
                            deletePayment()
                        }
                        .frame(maxWidth: .infinity)
                    } footer: {
                        Text(tr("Silince bu ödeme plandan kalkar; Ödeme Planı grafiği anında güncellenir.", "Deleting removes it from the plan; the chart updates instantly."))
                    }
                }
            }
            .navigationTitle(payment == nil ? tr("Sabit Ödeme Ekle", "Add Fixed Payment") : tr("Ödemeyi Düzenle", "Edit Payment"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Vazgeç", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Kaydet", "Save")) {
                        save()
                    }
                    .disabled(name.isEmpty || (amount ?? 0) <= 0)
                }
            }
            .onAppear {
                if let payment {
                    name = payment.name
                    amount = payment.amount
                    dueDay = payment.dueDay
                    if let total = payment.totalInstallments, let first = payment.firstPaymentDate {
                        if total == 1 {
                            kind = .oneTime
                            oneTimeMonth = Calendar.current.dateInterval(of: .month, for: first)!.start
                        } else {
                            kind = .installment
                            totalInstallments = total
                            currentInstallment = payment.installmentNumber(inMonth: .now) ?? total
                        }
                    } else {
                        kind = .recurring
                    }
                }
            }
        }
    }

    private func save() {
        guard let amount else { return }

        // Türe göre taksit alanlarını hazırla
        let total: Int?
        let firstPayment: Date?
        switch kind {
        case .recurring:
            total = nil
            firstPayment = nil
        case .installment:
            total = totalInstallments
            // "Şu an 5. taksitteyim" → ilk taksit 4 ay önceydi
            firstPayment = Calendar.current.date(byAdding: .month,
                                                 value: -(currentInstallment - 1), to: .now)
        case .oneTime:
            // Tek seferlik = 1 taksitlik ödeme, seçilen ayda
            total = 1
            firstPayment = oneTimeMonth
        }

        if let payment {
            payment.name = name
            payment.amount = amount
            payment.dueDay = dueDay
            payment.totalInstallments = total
            payment.firstPaymentDate = firstPayment
        } else {
            modelContext.insert(FixedPayment(name: name, amount: amount, dueDay: dueDay,
                                             totalInstallments: total,
                                             firstPaymentDate: firstPayment))
        }
        try? modelContext.save()
        refreshReminders()
        dismiss()
    }

    private func deletePayment() {
        if let payment {
            modelContext.delete(payment)
            try? modelContext.save()
        }
        refreshReminders()
        dismiss()
    }

    // Kayıt değişince hatırlatma planını baştan kur
    private func refreshReminders() {
        let all = (try? modelContext.fetch(FetchDescriptor<FixedPayment>())) ?? []
        let paid = (try? modelContext.fetch(FetchDescriptor<PaidPayment>())) ?? []
        PaymentReminders.reschedule(payments: all, paidRecords: paid)
    }
}

#Preview {
    FixedPaymentsView()
        .modelContainer(for: [Expense.self, FixedPayment.self], inMemory: true)
}
