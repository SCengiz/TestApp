import SwiftUI
import SwiftData

struct DailyExpensesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @State private var showingAddSheet = false
    @State private var monthOffset = 0 // -3 (3 ay geri) ... +3 (3 ay ileri)

    private var calendar: Calendar { .current }

    // Görüntülenen ay
    private var selectedMonth: Date {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        return calendar.date(byAdding: .month, value: monthOffset, to: thisMonth)!
    }

    // Seçili ayın harcamaları (kronolojik: en yeni en üstte)
    private var monthExpenses: [Expense] {
        expenses
            .filter { calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month) }
            .sorted { $0.date > $1.date }
    }

    private var monthTotal: Double {
        monthExpenses.reduce(0) { $0 + $1.amount }
    }

    private var cardTitle: String {
        monthOffset == 0
            ? "Bu Ay Toplam"
            : selectedMonth.formatted(.dateTime.month(.wide).year())
    }

    // Harcamaları günlere göre grupla (günler ve gün içi kayıtlar kronolojik)
    private var groupedByDay: [(day: Date, items: [Expense])] {
        let groups = Dictionary(grouping: monthExpenses) {
            calendar.startOfDay(for: $0.date)
        }
        return groups
            .map { (day: $0.key, items: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        List {
            Section {
                StatCard(
                    title: cardTitle,
                    amount: monthTotal,
                    icon: "cart.fill",
                    colors: [.pink, .red]
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

            ForEach(groupedByDay, id: \.day) { group in
                Section {
                    ForEach(group.items) { expense in
                        let cat = ExpenseCategory.named(expense.category)
                        HStack(spacing: 12) {
                            RowIcon(systemName: cat.icon, color: cat.color)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(expense.title)
                                Text(rowSubtitle(expense, category: cat))
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
            if monthExpenses.isEmpty {
                ContentUnavailableView(
                    monthOffset > 0 ? "Bu aya planlanmış harcama yok" : "Bu ayda harcama yok",
                    systemImage: "cart",
                    description: Text(monthOffset == 0
                                      ? "Sağ üstteki + ile ilk harcamanı ekle."
                                      : "Karttaki oklarla aylar arasında gezinebilirsin.")
                )
            }
        }
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

    // "Market · Taksit 2/6" gibi alt satır
    private func rowSubtitle(_ expense: Expense, category: ExpenseCategory) -> String {
        if let number = expense.installmentNumber, let count = expense.installmentCount {
            return "\(category.name) · Taksit \(number)/\(count)"
        }
        return category.name
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
    @State private var isInstallment = false
    @State private var installmentCount = 2
    @State private var currentInstallment = 1

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

                    TextField(isInstallment ? "Aylık taksit tutarı (TL)" : "Tutar (TL)",
                              value: $amount, format: .number)
                        .keyboardType(.decimalPad)

                    Picker("Kategori", selection: $category) {
                        ForEach(ExpenseCategory.all) { cat in
                            Label(cat.name, systemImage: cat.icon).tag(cat.name)
                        }
                    }

                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                }

                // Peşin / Taksitli seçimi
                Section {
                    Picker("Ödeme şekli", selection: $isInstallment.animation()) {
                        Text("Peşin").tag(false)
                        Text("Taksitli").tag(true)
                    }
                    .pickerStyle(.segmented)

                    if isInstallment {
                        Picker("Toplam taksit", selection: $installmentCount) {
                            ForEach(2...36, id: \.self) { n in
                                Text("\(n) taksit").tag(n)
                            }
                        }
                        Picker("Şu an kaçıncı taksit", selection: $currentInstallment) {
                            ForEach(1...installmentCount, id: \.self) { n in
                                Text("\(n). taksit").tag(n)
                            }
                        }
                    }
                } footer: {
                    if isInstallment {
                        Text("Tutar, AYLIK taksit tutarıdır. Kalan taksitler sonraki ayların harcamalarına otomatik eklenir; ileri aylara gidince görürsün.")
                    }
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
        if isInstallment {
            // Bu taksit + kalan taksitler sonraki aylara otomatik yazılır
            let groupID = UUID()
            for number in currentInstallment...installmentCount {
                guard let installmentDate = Calendar.current.date(
                    byAdding: .month, value: number - currentInstallment, to: date
                ) else { continue }
                modelContext.insert(Expense(title: title, amount: amount,
                                            date: installmentDate, category: category,
                                            installmentCount: installmentCount,
                                            installmentNumber: number,
                                            installmentGroupID: groupID))
            }
        } else {
            modelContext.insert(Expense(title: title, amount: amount,
                                        date: date, category: category))
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        DailyExpensesView()
    }
    .modelContainer(for: [Expense.self, FixedPayment.self], inMemory: true)
}
