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
                        title: "Aylık Sabit Yük",
                        amount: monthlyTotal,
                        icon: "creditcard.fill",
                        colors: [.orange, .yellow]
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section("Sabit Ödemeler") {
                    ForEach(payments) { payment in
                        HStack(spacing: 12) {
                            RowIcon(systemName: "creditcard.fill", color: .orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(payment.name)
                                Text("Her ayın \(payment.dueDay). günü")
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
}

// Yeni sabit ödeme ekleme formu
struct AddFixedPaymentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var amount: Double?
    @State private var dueDay = 1

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
        modelContext.insert(FixedPayment(name: name, amount: amount, dueDay: dueDay))
        dismiss()
    }
}

#Preview {
    FixedPaymentsView()
        .modelContainer(for: [Expense.self, FixedPayment.self], inMemory: true)
}
