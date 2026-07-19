import SwiftUI
import SwiftData
import Charts

struct SavingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavingsItem.amount, order: .reverse) private var items: [SavingsItem]
    @Query(sort: \SavingsSnapshot.monthStart) private var snapshots: [SavingsSnapshot]
    @State private var showingAddSheet = false
    @State private var editingItem: SavingsItem?
    @State private var selectedMonth: Date? // grafikte dokunulan ay
    @State private var detailMonth: MonthSelection? // dökümü açılan ay

    private var calendar: Calendar { .current }

    private var total: Double {
        items.reduce(0) { $0 + $1.amount }
    }

    // Her birikim kalemine sırasına göre renk ata
    private var itemColors: [String: Color] {
        Dictionary(items.enumerated().map {
            ($0.element.name, savingsPalette[$0.offset % savingsPalette.count])
        }, uniquingKeysWith: { first, _ in first })
    }

    // Bir ayın birikim kalemleri: geçmişte kayıtlı toplam, bugünden itibaren kalem kalem
    private func savingsBreakdown(for month: Date) -> [(name: String, amount: Double, color: Color)] {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        if month < thisMonth {
            return [("O ayın kayıtlı birikimi", historicalTotal(for: month), .purple)]
        }
        return items.map { ($0.name, $0.amount, itemColors[$0.name] ?? .purple) }
    }

    // Birikim gidişatı: 6 ay geri + bu ay + 6 ay ileri
    private var monthlySavings: [(date: Date, total: Double, isFuture: Bool)] {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        return (-6...6).map { offset in
            let month = calendar.date(byAdding: .month, value: offset, to: thisMonth)!
            let value = offset >= 0 ? total : historicalTotal(for: month)
            return (month, value, offset > 0)
        }
    }

    // Geçmiş bir ayın birikimi: o ayın fotoğrafı; yoksa en yakın önceki fotoğraf
    private func historicalTotal(for month: Date) -> Double {
        if let exact = snapshots.first(where: {
            calendar.isDate($0.monthStart, equalTo: month, toGranularity: .month)
        }) {
            return exact.total
        }
        if let earlier = snapshots.last(where: { $0.monthStart < month }) {
            return earlier.total
        }
        return total
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatCard(
                        title: "Toplam Birikimim",
                        amount: total,
                        icon: "chart.line.uptrend.xyaxis",
                        colors: [.purple, .indigo]
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(items) { item in
                        Button {
                            editingItem = item
                        } label: {
                            HStack(spacing: 12) {
                                RowIcon(systemName: "banknote.fill",
                                        color: itemColors[item.name] ?? .purple)
                                Text(item.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text(item.amount, format: .currency(code: "TRY"))
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteItems)
                } header: {
                    Text("Birikim Kalemleri")
                } footer: {
                    Text("Vadeli hesap, altın, yastık altı gibi birikimlerini gir; tutar değişince üzerine dokunup güncelle.")
                }

                // Birikim gidişatı grafiği
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Birikim Gidişatı", systemImage: "chart.bar.fill")
                            .font(.headline)

                        Chart {
                            ForEach(monthlySavings, id: \.date) { item in
                                ForEach(savingsBreakdown(for: item.date), id: \.name) { seg in
                                    BarMark(
                                        x: .value("Ay", item.date, unit: .month),
                                        y: .value("Tutar", seg.amount)
                                    )
                                    .foregroundStyle(seg.color.gradient)
                                    .cornerRadius(2)
                                    .opacity(item.isFuture ? 0.45 : 1)
                                }
                            }

                            RuleMark(x: .value("Bugün", Date.now, unit: .month))
                                .foregroundStyle(.secondary.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                        .chartXSelection(value: $selectedMonth)
                        .onChange(of: selectedMonth) {
                            if let month = selectedMonth {
                                detailMonth = MonthSelection(date: month)
                                selectedMonth = nil
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
            .navigationTitle("Birikimler")
            .toolbar {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Birikim Ekle", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                SavingsFormView(item: nil)
            }
            .sheet(item: $editingItem) { item in
                SavingsFormView(item: item)
            }
            .sheet(item: $detailMonth) { selection in
                MonthBreakdownSheet(
                    heading: "Birikimler",
                    month: selection.date,
                    items: savingsBreakdown(for: selection.date)
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Henüz birikim yok",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("Sağ üstteki + ile vadeli hesap, altın gibi birikim kalemlerini ekle.")
                    )
                }
            }
            .onAppear {
                syncSavingsSnapshot(modelContext)
            }
            .onChange(of: total) {
                syncSavingsSnapshot(modelContext)
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(items[index])
        }
    }
}

// Birikim ekleme / güncelleme formu (item nil ise yeni kayıt)
struct SavingsFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let item: SavingsItem?

    @State private var name = ""
    @State private var amount: Double?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Birikim adı (örn. Vadeli hesap, Altın)", text: $name)

                    TextField("Tutar (TL)", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                } footer: {
                    Text("Birikimin büyüyünce veya bozdurunca buradan güncelle; geçmiş ayların kaydı değişmez.")
                }

                if item != nil {
                    Section {
                        Button("Birikimi Sil", role: .destructive) {
                            deleteItem()
                        }
                        .frame(maxWidth: .infinity)
                    } footer: {
                        Text("Silince geçmiş ayların birikimi değişmez; sadece bu ay ve gelecek güncellenir.")
                    }
                }
            }
            .navigationTitle(item == nil ? "Birikim Ekle" : "Birikimi Güncelle")
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
                if let item {
                    name = item.name
                    amount = item.amount
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let amount else { return }
        if let item {
            item.name = name
            item.amount = amount
        } else {
            modelContext.insert(SavingsItem(name: name, amount: amount))
        }
        syncSavingsSnapshot(modelContext)
        dismiss()
    }

    private func deleteItem() {
        if let item {
            modelContext.delete(item)
        }
        syncSavingsSnapshot(modelContext)
        dismiss()
    }
}

#Preview {
    SavingsView()
        .modelContainer(for: [SavingsItem.self, SavingsSnapshot.self], inMemory: true)
}
