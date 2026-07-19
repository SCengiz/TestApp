import SwiftUI
import SwiftData

struct FixedPaymentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FixedPayment.dueDay) private var payments: [FixedPayment]
    @State private var showingAddSheet = false
    @State private var editingPayment: FixedPayment?

    private var monthlyTotal: Double {
        payments.reduce(0) { $0 + $1.amount }
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
                    if let total = payment.totalInstallments {
                        hasInstallments = true
                        totalInstallments = total
                        currentInstallment = payment.installmentNumber(inMonth: .now) ?? total
                    }
                }
            }
        }
    }

    private func save() {
        guard let amount else { return }
        // "Şu an 5. taksitteyim" → ilk taksit 4 ay önceydi
        let firstPayment = hasInstallments
            ? Calendar.current.date(byAdding: .month, value: -(currentInstallment - 1), to: .now)
            : nil

        if let payment {
            payment.name = name
            payment.amount = amount
            payment.dueDay = dueDay
            payment.totalInstallments = hasInstallments ? totalInstallments : nil
            payment.firstPaymentDate = firstPayment
        } else {
            modelContext.insert(FixedPayment(name: name, amount: amount, dueDay: dueDay,
                                             totalInstallments: hasInstallments ? totalInstallments : nil,
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
