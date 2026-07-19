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
                    title: "Ödemelerim",
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
                Text("Sabit Ödemeler")
            } footer: {
                Text("Düzenlemek veya silmek için ödemeye dokun. Değişiklikler Ödeme Planı grafiğine anında yansır.")
            }
        }
        .navigationTitle("Sabit Ödemeler")
        .toolbar {
            Button {
                showingAddSheet = true
            } label: {
                Label("Sabit Ödeme Ekle", systemImage: "plus")
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
                    "Henüz sabit ödeme yok",
                    systemImage: "creditcard",
                    description: Text("Kredi kartı ekstresi, kredi taksidi gibi her ay tekrarlayan ödemeleri + ile ekle.")
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
            let month = first.formatted(.dateTime.month(.wide).year())
            return "Tek seferlik · \(month) · Ayın \(payment.dueDay). günü"
        }
        if let total = payment.totalInstallments,
           let number = payment.installmentNumber(inMonth: .now) {
            return "Taksit \(number)/\(total) · kalan \(total - number) ay · Her ayın \(payment.dueDay). günü"
        }
        if let total = payment.totalInstallments {
            return "Taksit bitti (\(total)/\(total)) · Her ayın \(payment.dueDay). günü"
        }
        return "Süresiz · Her ayın \(payment.dueDay). günü"
    }
}

// Sabit ödeme ekleme / düzenleme formu (payment nil ise yeni kayıt)
struct AddFixedPaymentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let payment: FixedPayment?

    // Ödeme türü: her ay tekrar eden, taksitli veya sadece tek bir aya özel
    enum PaymentKind: String, CaseIterable {
        case recurring = "Süresiz"
        case installment = "Taksitli"
        case oneTime = "Tek Seferlik"
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
                VoiceEntrySection(hint: "Sesle söyle") { spoken in
                    let parsed = parseSpokenExpense(spoken)
                    if let spokenName = parsed.title { name = spokenName }
                    if let spokenAmount = parsed.amount { amount = spokenAmount }
                }

                Section("Elle Gir") {
                    TextField("Adı (örn. Kredi kartı ekstresi)", text: $name)

                    TextField("Aylık tutar (TL)", value: $amount, format: .number)
                        .keyboardType(.decimalPad)

                    Picker("Ödeme günü", selection: $dueDay) {
                        ForEach(1...28, id: \.self) { day in
                            Text("Her ayın \(day). günü").tag(day)
                        }
                    }
                }

                Section {
                    Picker("Ödeme türü", selection: $kind.animation()) {
                        ForEach(PaymentKind.allCases, id: \.self) { k in
                            Text(k.rawValue).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)

                    if kind == .installment {
                        Picker("Toplam taksit", selection: $totalInstallments) {
                            ForEach(2...48, id: \.self) { n in
                                Text("\(n) taksit").tag(n)
                            }
                        }
                        Picker("Şu an kaçıncı taksit", selection: $currentInstallment) {
                            ForEach(1...totalInstallments, id: \.self) { n in
                                Text("\(n). taksit").tag(n)
                            }
                        }
                        Text("Kalan: \(totalInstallments - currentInstallment) ay sonra bitecek")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if kind == .oneTime {
                        Picker("Hangi aya", selection: $oneTimeMonth) {
                            ForEach(monthOptions, id: \.self) { month in
                                Text(month.formatted(.dateTime.month(.wide).year())).tag(month)
                            }
                        }
                    }
                } footer: {
                    switch kind {
                    case .recurring:
                        Text("Fatura, abonelik gibi her ay tekrar eden ödemeler için.")
                    case .installment:
                        Text("Kredi taksidi gibi belirli sayıda ödemesi olanlar için.")
                    case .oneTime:
                        Text("Sadece seçtiğin aya işlenir; diğer ayların planını etkilemez.")
                    }
                }

                // Var olan ödemeyi silme (plan grafiği anında güncellenir)
                if payment != nil {
                    Section {
                        Button("Ödemeyi Sil", role: .destructive) {
                            deletePayment()
                        }
                        .frame(maxWidth: .infinity)
                    } footer: {
                        Text("Silince bu ödeme plandan kalkar; Ödeme Planı grafiği anında güncellenir.")
                    }
                }
            }
            .navigationTitle(payment == nil ? "Sabit Ödeme Ekle" : "Ödemeyi Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
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
