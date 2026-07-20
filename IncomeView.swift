import SwiftUI
import SwiftData
import Charts

struct IncomeView: View {
    @Binding var loggedInUser: String?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IncomeSource.amount, order: .reverse) private var incomes: [IncomeSource]
    @Query(sort: \IncomeSnapshot.monthStart) private var snapshots: [IncomeSnapshot]
    @State private var showingAddSheet = false
    @State private var editingIncome: IncomeSource?
    @State private var selectedMonth: Date? // grafikte dokunulan ay
    @State private var detailMonth: MonthSelection? // dökümü açılan ay
    @AppStorage("hideIncomeAmounts") private var amountsHidden = false // gizlilik modu

    private var calendar: Calendar { .current }

    // Her gelir kaynağına sırasına göre renk ata
    private var incomeColors: [String: Color] {
        Dictionary(incomes.enumerated().map {
            ($0.element.name, incomePalette[$0.offset % incomePalette.count])
        }, uniquingKeysWith: { first, _ in first })
    }

    // Bir ayın gelir kalemleri: geçmişte kayıtlı toplam, bugünden itibaren kaynak kaynak
    private func incomeBreakdown(for month: Date) -> [(name: String, amount: Double, color: Color)] {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        if month < thisMonth {
            return [(tr("O ayın kayıtlı geliri", "Recorded income for that month"), historicalTotal(for: month), .green)]
        }
        return incomes.map { ($0.name, $0.amount, incomeColors[$0.name] ?? .green) }
    }

    private var monthlyTotal: Double {
        incomes.reduce(0) { $0 + $1.amount }
    }

    // Gelir planı: 3 ay geri + bu ay + 3 ay ileri
    // Geçmiş aylar: o ayın kayıtlı fotoğrafı (silme/ekleme geçmişi DEĞİŞTİRMEZ)
    // Bu ay ve gelecek: güncel kaynakların toplamı (adaptif)
    private var monthlyIncome: [(date: Date, total: Double, isFuture: Bool)] {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        return (-3...3).map { offset in
            let month = calendar.date(byAdding: .month, value: offset, to: thisMonth)!
            let total = offset >= 0 ? monthlyTotal : historicalTotal(for: month)
            return (month, total, offset > 0)
        }
    }

    // Geçmiş bir ayın geliri: o ayın fotoğrafı; yoksa en yakın önceki fotoğraf
    private func historicalTotal(for month: Date) -> Double {
        if let exact = snapshots.first(where: {
            calendar.isDate($0.monthStart, equalTo: month, toGranularity: .month)
        }) {
            return exact.total
        }
        if let earlier = snapshots.last(where: { $0.monthStart < month }) {
            return earlier.total
        }
        return monthlyTotal
    }


    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatCard(
                        title: tr("Aylık Gelirim", "Monthly Income"),
                        amount: monthlyTotal,
                        icon: "banknote.fill",
                        colors: [.green, .mint],
                        masked: amountsHidden
                    )
                    // Gizlilik: kartın sağındaki gözle tutarları sakla/göster
                    .overlay(alignment: .trailing) {
                        Button {
                            amountsHidden.toggle()
                        } label: {
                            Image(systemName: amountsHidden ? "eye.slash.fill" : "eye.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Circle().fill(.white.opacity(0.18)))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 14)
                    }
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
                                Text(amountsHidden ? "₺***.***,**" : income.amount.formatted(.currency(code: "TRY")))
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
                    Text(tr("Gelir Kaynakları", "Income Sources"))
                } footer: {
                    Text(tr("Gelirlerin çoğu zaman sabittir: her ay yeniden girmek yerine, değiştiğinde üzerine dokunup güncelle.", "Income is usually fixed: instead of re-entering monthly, tap to update when it changes."))
                }

                // Gelir planı grafiği (Ödeme Planı ile aynı tarz)
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Label(tr("Gelir Planı", "Income Plan"), systemImage: "chart.bar.fill")
                            .font(.headline)

                        Chart {
                            // Her ay: gelir kalemleri farklı renklerde üst üste biner
                            ForEach(monthlyIncome, id: \.date) { item in
                                ForEach(incomeBreakdown(for: item.date), id: \.name) { seg in
                                    BarMark(
                                        x: .value("Ay", item.date, unit: .month),
                                        y: .value("Tutar", seg.amount)
                                    )
                                    .foregroundStyle(seg.color.gradient)
                                    .cornerRadius(2)
                                    .opacity(item.isFuture ? 0.45 : 1)
                                }
                            }

                            // Bugünü işaretle (kesikli çizgi)
                            RuleMark(x: .value("Bugün", Date.now, unit: .month))
                                .foregroundStyle(.secondary.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                        .chartOverlay { proxy in
                            GeometryReader { geo in
                                Rectangle()
                                    .fill(Color.clear)
                                    .contentShape(Rectangle())
                                    .onTapGesture { location in
                                        // Tek dokunuşla o ayın dökümünü aç
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let x = location.x - geo[plotFrame].origin.x
                                        if let date: Date = proxy.value(atX: x) {
                                            if !amountsHidden {
                                                detailMonth = MonthSelection(date: date)
                                            }
                                        }
                                    }
                            }
                        }
                        .chartYAxis(amountsHidden ? .hidden : .automatic)
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) {
                                AxisValueLabel(format: .dateTime.month(.abbreviated).locale(appLocale))
                            }
                        }
                        .frame(height: 200)
                    }
                }
            }
            .navigationTitle(tr("Gelirler", "Income"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileButton(loggedInUser: $loggedInUser)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label(tr("Gelir Ekle", "Add Income"), systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                IncomeFormView(income: nil)
            }
            .sheet(item: $editingIncome) { income in
                IncomeFormView(income: income)
            }
            // Gelir Planı çubuğuna dokununca ayın kalem dökümü
            .sheet(item: $detailMonth) { selection in
                MonthBreakdownSheet(
                    heading: tr("Gelirler", "Income"),
                    month: selection.date,
                    items: incomeBreakdown(for: selection.date)
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .overlay {
                if incomes.isEmpty {
                    ContentUnavailableView(
                        tr("Henüz gelir yok", "No income yet"),
                        systemImage: "banknote",
                        description: Text(tr("Sağ üstteki + ile maaş, kira geliri gibi gelir kaynaklarını ekle.", "Add income sources like salary or rent with + at the top right."))
                    )
                }
            }
            .onAppear {
                syncIncomeSnapshot(modelContext)
            }
            .onChange(of: monthlyTotal) {
                // Ekleme/silme/güncelleme sonrası bu ayın fotoğrafını tazele
                syncIncomeSnapshot(modelContext)
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
                    TextField(tr("Gelir kaynağı (örn. Maaş, Kira geliri)", "Income source (e.g. Salary, Rent)"), text: $name)
                        .textInputAutocapitalization(.words)

                    TextField(tr("Aylık tutar (TL)", "Monthly amount (TL)"), value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                } footer: {
                    Text(tr("Bu tutar her ay için geçerli sayılır. Zam veya değişiklik olunca buradan güncelle.", "This amount applies every month. Update it here when it changes."))
                }

                // Var olan geliri silme (geçmiş aylar etkilenmez, gelecek plan güncellenir)
                if income != nil {
                    Section {
                        Button(tr("Geliri Sil", "Delete Income"), role: .destructive) {
                            deleteIncome()
                        }
                        .frame(maxWidth: .infinity)
                    } footer: {
                        Text(tr("Silince geçmiş ayların geliri değişmez; sadece bu ay ve gelecek plan güncellenir.", "Deleting does not change past months; only this month and the future plan update."))
                    }
                }
            }
            .navigationTitle(income == nil ? tr("Gelir Ekle", "Add Income") : tr("Geliri Güncelle", "Update Income"))
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
        syncIncomeSnapshot(modelContext)
        dismiss()
    }

    private func deleteIncome() {
        if let income {
            modelContext.delete(income)
        }
        syncIncomeSnapshot(modelContext)
        dismiss()
    }
}

#Preview {
    IncomeView(loggedInUser: .constant("soray"))
        .modelContainer(for: [Expense.self, FixedPayment.self, IncomeSource.self], inMemory: true)
}
