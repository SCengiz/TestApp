import SwiftUI
import SwiftData

struct FixedPaymentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FixedPayment.dueDay) private var payments: [FixedPayment]
    @State private var showingAddSheet = false
    @State private var editingPayment: FixedPayment?

    // Bu ay geçerli ödemelerin toplamı (gelecek aya özel tek seferlikler dahil edilmez)
    private var monthlyTotal: Double {
        payments
            .filter { $0.isActive(inMonth: .now) }
            .reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        List {
            Section {
                StatCard(
                    title: tr("Ödemelerim", "My Payments"),
                    amount: monthlyTotal,
                    icon: "building.columns.fill",
                    colors: [.blue, .cyan]
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                ForEach(payments) { payment in
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
                Text(tr("Düzenlemek veya silmek için ödemeye dokun. Değişiklikler Ödeme Planı grafiğine anında yansır.", "Tap a payment to edit or delete. Changes reflect on the Payment Plan chart instantly."))
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
            if payments.isEmpty {
                ContentUnavailableView(
                    tr("Henüz sabit ödeme yok", "No fixed payments yet"),
                    systemImage: "creditcard",
                    description: Text(tr("Kredi kartı ekstresi, kredi taksidi gibi her ay tekrarlayan ödemeleri + ile ekle.", "Add recurring payments like card statements or loan installments with +."))
                )
            }
        }
    }

    private func deletePayments(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(payments[index])
        }
    }

    // "Taksit 5/12 · kalan 7 ay · Her ayın 15'i" gibi alt satır
    private func subtitle(for payment: FixedPayment) -> String {
        // Tek seferlik ödeme: hangi aya ait olduğunu göster
        if payment.totalInstallments == 1, let first = payment.firstPaymentDate {
            let month = first.formatted(.dateTime.month(.wide).year().locale(appLocale))
            return tr("Tek seferlik · \(month) · Ayın \(payment.dueDay). günü", "One-time · \(month) · day \(payment.dueDay)")
        }
        if let total = payment.totalInstallments,
           let number = payment.installmentNumber(inMonth: .now) {
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
        dismiss()
    }

    private func deletePayment() {
        if let payment {
            modelContext.delete(payment)
        }
        dismiss()
    }
}

#Preview {
    FixedPaymentsView()
        .modelContainer(for: [Expense.self, FixedPayment.self], inMemory: true)
}
