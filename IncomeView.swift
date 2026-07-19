import SwiftUI
import SwiftData

struct IncomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IncomeSource.amount, order: .reverse) private var incomes: [IncomeSource]
    @State private var showingAddSheet = false
    @State private var editingIncome: IncomeSource?

    private var monthlyTotal: Double {
        incomes.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatCard(
                        title: "Aylık Gelirim",
                        amount: monthlyTotal,
                        icon: "banknote.fill",
                        colors: [.green, .mint]
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(incomes) { income in
                        Button {
                            editingIncome = income
                        } label: {
                            HStack(spacing: 12) {
                                RowIcon(systemName: "banknote.fill", color: .green)
                                Text(income.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(income.amount, format: .currency(code: "TRY"))
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteIncomes)
                } header: {
                    Text("Gelir Kaynakları")
                } footer: {
                    Text("Gelirlerin çoğu zaman sabittir: her ay yeniden girmek yerine, değiştiğinde üzerine dokunup güncelle.")
                }
            }
            .navigationTitle("Gelirler")
            .toolbar {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Gelir Ekle", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                IncomeFormView(income: nil)
            }
            .sheet(item: $editingIncome) { income in
                IncomeFormView(income: income)
            }
            .overlay {
                if incomes.isEmpty {
                    ContentUnavailableView(
                        "Henüz gelir yok",
                        systemImage: "banknote",
                        description: Text("Sağ üstteki + ile maaş, kira geliri gibi gelir kaynaklarını ekle.")
                    )
                }
            }
        }
    }

    private func deleteIncomes(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(incomes[index])
        }
    }
}

// Gelir ekleme / güncelleme formu (income nil ise yeni kayıt)
struct IncomeFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let income: IncomeSource?

    @State private var name = ""
    @State private var amount: Double?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Gelir kaynağı (örn. Maaş, Kira geliri)", text: $name)

                    TextField("Aylık tutar (TL)", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                } footer: {
                    Text("Bu tutar her ay için geçerli sayılır. Zam veya değişiklik olunca buradan güncelle.")
                }
            }
            .navigationTitle(income == nil ? "Gelir Ekle" : "Geliri Güncelle")
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
                if let income {
                    name = income.name
                    amount = income.amount
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let amount else { return }
        if let income {
            income.name = name
            income.amount = amount
        } else {
            modelContext.insert(IncomeSource(name: name, amount: amount))
        }
        dismiss()
    }
}

#Preview {
    IncomeView()
        .modelContainer(for: [Expense.self, FixedPayment.self, IncomeSource.self], inMemory: true)
}
