import SwiftUI
import SwiftData
import Charts

struct IncomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \IncomeSource.amount, order: .reverse) private var incomes: [IncomeSource]
    @Query(sort: \IncomeSnapshot.monthStart) private var snapshots: [IncomeSnapshot]
    @State private var showingAddSheet = false
    @State private var editingIncome: IncomeSource?
    @State private var selectedMonth: Date? // grafikte dokunulan ay

    private var calendar: Calendar { .current }

    private var monthlyTotal: Double {
        incomes.reduce(0) { $0 + $1.amount }
    }

    // Gelir planı: 6 ay geri + bu ay + 6 ay ileri
    // Geçmiş aylar: o ayın kayıtlı fotoğrafı (silme/ekleme geçmişi DEĞİŞTİRMEZ)
    // Bu ay ve gelecek: güncel kaynakların toplamı (adaptif)
    private var monthlyIncome: [(date: Date, total: Double, isFuture: Bool)] {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        return (-6...6).map { offset in
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

    // Dokunulan ayın verisi
    private var selectedStatus: (date: Date, total: Double, isFuture: Bool)? {
        guard let selectedMonth else { return nil }
        return monthlyIncome.first {
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
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

                // Gelir planı grafiği (Ödeme Planı ile aynı tarz)
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Gelir Planı", systemImage: "chart.bar.fill")
                            .font(.headline)

                        Chart {
                            ForEach(monthlyIncome, id: \.date) { item in
                                BarMark(
                                    x: .value("Ay", item.date, unit: .month),
                                    y: .value("Tutar", item.total)
                                )
                                .foregroundStyle(
                                    LinearGradient(colors: [.green, .mint],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                                .cornerRadius(4)
                                .opacity(item.isFuture ? 0.45 : 1)
                            }

                            // Bugünü işaretle (kesikli çizgi)
                            RuleMark(x: .value("Bugün", Date.now, unit: .month))
                                .foregroundStyle(.secondary.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                            // Dokunulan ayı vurgula
                            if let sel = selectedStatus {
                                RuleMark(x: .value("Seçili", sel.date, unit: .month))
                                    .foregroundStyle(.secondary.opacity(0.35))
                            }
                        }
                        .chartXSelection(value: $selectedMonth)
                        // Baloncuk yüzen katmanda: grafik kaymaz
                        .chartOverlay { proxy in
                            GeometryReader { geo in
                                if let sel = selectedStatus,
                                   let plotAnchor = proxy.plotFrame,
                                   let center = calendar.date(byAdding: .day, value: 15, to: sel.date),
                                   let xInPlot = proxy.position(forX: center) {
                                    let plotFrame = geo[plotAnchor]
                                    let bubbleWidth: CGFloat = 190
                                    let rawX = plotFrame.minX + xInPlot
                                    let x = min(max(rawX, bubbleWidth / 2 + 2),
                                                geo.size.width - bubbleWidth / 2 - 2)
                                    incomeTooltip(for: sel)
                                        .frame(width: bubbleWidth)
                                        .position(x: x, y: 46)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) {
                                AxisValueLabel(format: .dateTime.month(.narrow))
                            }
                        }
                        .frame(height: 200)
                    }
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

    // Dokunulan ayın gelir baloncuğu
    private func incomeTooltip(for sel: (date: Date, total: Double, isFuture: Bool)) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(sel.date, format: .dateTime.month(.wide).year())
                .font(.subheadline.bold())
            HStack {
                Text(sel.isFuture ? "Plan" : "Gelir")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(sel.total, format: .currency(code: "TRY"))
                    .fontWeight(.bold)
            }
            .font(.footnote)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        )
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

                // Var olan geliri silme (geçmiş aylar etkilenmez, gelecek plan güncellenir)
                if income != nil {
                    Section {
                        Button("Geliri Sil", role: .destructive) {
                            deleteIncome()
                        }
                        .frame(maxWidth: .infinity)
                    } footer: {
                        Text("Silince geçmiş ayların geliri değişmez; sadece bu ay ve gelecek plan güncellenir.")
                    }
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
    IncomeView()
        .modelContainer(for: [Expense.self, FixedPayment.self, IncomeSource.self], inMemory: true)
}
