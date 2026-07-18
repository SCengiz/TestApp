import SwiftUI
import SwiftData

struct FixedPaymentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FixedPayment.dueDay) private var payments: [FixedPayment]
    @State private var showingAddSheet = false

    private var monthlyTotal: Double {
        payments.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
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

                Section("Sabit Ödemeler") {
                    ForEach(payments) { payment in
                        HStack(spacing: 12) {
                            RowIcon(systemName: "creditcard.fill", color: .blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(payment.name)
                                Text(subtitle(for: payment))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(payment.amount, format: .currency(code: "TRY"))
                                .font(.callout.weight(.semibold))
                        }
                    }
                    .onDelete(perform: deletePayments)
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
                AddFixedPaymentView()
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
    }

    private func deletePayments(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(payments[index])
        }
    }

    // "Taksit 5/12 · kalan 7 ay · Her ayın 15'i" gibi alt satır
    private func subtitle(for payment: FixedPayment) -> String {
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

// Yeni sabit ödeme ekleme formu
struct AddFixedPaymentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amount: Double?
    @State private var dueDay = 1
    @State private var hasInstallments = false
    @State private var totalInstallments = 12
    @State private var currentInstallment = 1

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
                    Toggle("Taksitli mi?", isOn: $hasInstallments.animation())

                    if hasInstallments {
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
                } footer: {
                    Text("Kredi taksidi gibi belirli sayıda ödemesi olanlar için açın. Fatura, abonelik gibi süresizler için kapalı bırakın.")
                }
            }
            .navigationTitle("Sabit Ödeme Ekle")
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
        }
    }

    private func save() {
        guard let amount else { return }
        if hasInstallments {
            // "Şu an 5. taksitteyim" → ilk taksit 4 ay önceydi
            let first = Calendar.current.date(byAdding: .month,
                                              value: -(currentInstallment - 1),
                                              to: .now)
            modelContext.insert(FixedPayment(name: name, amount: amount, dueDay: dueDay,
                                             totalInstallments: totalInstallments,
                                             firstPaymentDate: first))
        } else {
            modelContext.insert(FixedPayment(name: name, amount: amount, dueDay: dueDay))
        }
        dismiss()
    }
}

#Preview {
    FixedPaymentsView()
        .modelContainer(for: [Expense.self, FixedPayment.self], inMemory: true)
}
