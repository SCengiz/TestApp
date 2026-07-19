import SwiftUI
import SwiftData

struct DailyExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var showingAddSheet = false

    // Bu ayın harcamaları
    private var thisMonthExpenses: [Expense] {
        let calendar = Calendar.current
        return expenses.filter {
            calendar.isDate($0.date, equalTo: .now, toGranularity: .month)
        }
    }

    private var thisMonthTotal: Double {
        thisMonthExpenses.reduce(0) { $0 + $1.amount }
    }

    // Harcamaları günlere göre grupla (en yeni gün en üstte)
    private var groupedByDay: [(day: Date, items: [Expense])] {
        let groups = Dictionary(grouping: expenses) {
            Calendar.current.startOfDay(for: $0.date)
        }
        return groups
            .map { (day: $0.key, items: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        List {
            Section {
                StatCard(
                    title: "Bu Ay Toplam",
                    amount: thisMonthTotal,
                    icon: "cart.fill",
                    colors: [.pink, .red]
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            ForEach(groupedByDay, id: \.day) { group in
                Section {
                    ForEach(group.items) { expense in
                        let cat = ExpenseCategory.named(expense.category)
                        HStack(spacing: 12) {
                            RowIcon(systemName: cat.icon, color: cat.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(expense.title)
                                Text(cat.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(expense.amount, format: .currency(code: "TRY"))
                                .font(.callout.weight(.semibold))
                        }
                    }
                    .onDelete { offsets in
                        deleteExpenses(group.items, at: offsets)
                    }
                } header: {
                    HStack {
                        Text(group.day, format: .dateTime.day().month(.wide).weekday(.wide))
                        Spacer()
                        Text(dayTotal(group.items), format: .currency(code: "TRY"))
                    }
                }
            }
        }
        .navigationTitle("Günlük Harcamalar")
        .toolbar {
            Button {
                showingAddSheet = true
            } label: {
                Label("Harcama Ekle", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddExpenseView()
        }
        .overlay {
            if expenses.isEmpty {
                ContentUnavailableView(
                    "Henüz harcama yok",
                    systemImage: "cart",
                    description: Text("Sağ üstteki + ile ilk harcamanı ekle.")
                )
            }
        }
    }

    private func dayTotal(_ items: [Expense]) -> Double {
        items.reduce(0) { $0 + $1.amount }
    }

    private func deleteExpenses(_ items: [Expense], at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}

// Yeni harcama ekleme formu
struct AddExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var amount: Double?
    @State private var date = Date.now
    @State private var category = "Market"

    var body: some View {
        NavigationStack {
            Form {
                VoiceEntrySection(hint: "Sesle söyle") { spoken in
                    // "Dün Bim'den 100 TL'lik market alışverişi yaptım"
                    // → 4 alan birden dolar
                    let parsed = parseSpokenExpense(spoken)
                    if let spokenTitle = parsed.title { title = spokenTitle }
                    if let spokenAmount = parsed.amount { amount = spokenAmount }
                    if let spokenCategory = parsed.category { category = spokenCategory }
                    if let spokenDate = parsed.date { date = spokenDate }
                }

                Section("Elle Gir") {
                    TextField("Ne aldın? (örn. Market alışverişi)", text: $title)
                        .onChange(of: title) {
                            // Yazdıkça kategoriyi otomatik tahmin et
                            if let guessed = guessCategory(from: title) {
                                category = guessed
                            }
                        }

                    TextField("Tutar (TL)", value: $amount, format: .number)
                        .keyboardType(.decimalPad)

                    Picker("Kategori", selection: $category) {
                        ForEach(ExpenseCategory.all) { cat in
                            Label(cat.name, systemImage: cat.icon).tag(cat.name)
                        }
                    }

                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("Harcama Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        save()
                    }
                    .disabled(title.isEmpty || (amount ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        guard let amount else { return }
        modelContext.insert(Expense(title: title, amount: amount, date: date, category: category))
        dismiss()
    }
}

#Preview {
    DailyExpensesView()
        .modelContainer(for: [Expense.self, FixedPayment.self], inMemory: true)
}
