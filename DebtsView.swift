import SwiftUI
import SwiftData

// Borç türleri
enum DebtKind: String, CaseIterable, Identifiable {
    case tl = "tl"
    case usd = "usd"
    case gram = "gram"
    case ceyrek = "ceyrek"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tl:     return "Türk Lirası"
        case .usd:    return "Dolar"
        case .gram:   return "Gram Altın"
        case .ceyrek: return "Çeyrek Altın"
        }
    }

    var icon: String {
        switch self {
        case .tl:     return "turkishlirasign.circle.fill"
        case .usd:    return "dollarsign.circle.fill"
        case .gram:   return "medal.fill"
        case .ceyrek: return "circle.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .tl:     return .red
        case .usd:    return .green
        case .gram:   return .yellow
        case .ceyrek: return .orange
        }
    }

    var quantityLabel: String {
        switch self {
        case .tl:     return "Tutar (TL)"
        case .usd:    return "Miktar (dolar)"
        case .gram:   return "Kaç gram?"
        case .ceyrek: return "Kaç adet?"
        }
    }

    var unitLabel: String {
        switch self {
        case .tl:     return "TL"
        case .usd:    return "dolar"
        case .gram:   return "gram"
        case .ceyrek: return "adet çeyrek"
        }
    }
}

struct DebtsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Debt.date, order: .reverse) private var debts: [Debt]
    @State private var showingAddSheet = false
    @State private var editingDebt: Debt?
    @State private var priceError: String?

    private var totalTL: Double {
        debts.reduce(0) { $0 + $1.valueTL }
    }

    // Kur farkından toplam borç artışı (emtia borçları)
    private var totalIncrease: Double {
        debts.reduce(0) { $0 + $1.increaseTL }
    }

    private var totalIncreasePercent: Double? {
        let initial = debts.reduce(0) { $0 + $1.initialValueTL }
        guard initial > 0 else { return nil }
        return totalIncrease / initial * 100
    }

    private var hasCommodityDebt: Bool {
        debts.contains { $0.kind != "tl" && $0.initialRate != nil }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    StatCard(
                        title: "Toplam Borcum",
                        amount: totalTL,
                        icon: "person.2.fill",
                        colors: [.red, .orange],
                        profit: hasCommodityDebt ? totalIncrease : nil,
                        profitPercent: totalIncreasePercent,
                        invertProfitColors: true
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(debts) { debt in
                        let kind = DebtKind(rawValue: debt.kind) ?? .tl
                        Button {
                            editingDebt = debt
                        } label: {
                            HStack(spacing: 12) {
                                RowIcon(systemName: kind.icon, color: kind.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(debt.name)
                                        .foregroundStyle(.primary)
                                    Text(subtitle(for: debt, kind: kind))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(debt.valueTL, format: .currency(code: "TRY"))
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteDebts)
                } header: {
                    Text("Borçlarım")
                } footer: {
                    if let priceError {
                        Text("⚠️ \(priceError)")
                    } else {
                        Text("Altın ve dolar borçları güncel satış kurundan TL'ye çevrilir; aşağı çekerek kurları yenile. Ödediğin borca dokunup silebilirsin.")
                    }
                }
            }
            .navigationTitle("Borçlar")
            .toolbar {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("Borç Ekle", systemImage: "plus")
                }
            }
            .refreshable {
                await refreshRates()
            }
            .sheet(isPresented: $showingAddSheet) {
                DebtFormView(debt: nil)
            }
            .sheet(item: $editingDebt) { debt in
                DebtFormView(debt: debt)
            }
            .overlay {
                if debts.isEmpty {
                    ContentUnavailableView(
                        "Henüz borç yok",
                        systemImage: "person.2",
                        description: Text("Sağ üstteki + ile elden aldığın borçları ekle: TL, dolar veya altın.")
                    )
                }
            }
            .task {
                await refreshRates()
            }
            .onChange(of: debts.count) {
                Task { await refreshRates() }
            }
        }
    }

    private func subtitle(for debt: Debt, kind: DebtKind) -> String {
        let qty = debt.quantity.formatted(.number.precision(.fractionLength(0...2)))
        let date = debt.date.formatted(.dateTime.day().month(.abbreviated).year())
        if kind == .tl {
            return "\(kind.title) · \(date)"
        }
        let rate = debt.lastKnownRate.formatted(.currency(code: "TRY"))
        return "\(qty) \(kind.unitLabel) × \(rate) · \(date)"
    }

    private func deleteDebts(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(debts[index])
        }
    }

    // Altın/dolar borçlarının kurunu güncelle (satış kuru)
    @MainActor
    private func refreshRates() async {
        let fxDebts = debts.filter { $0.kind != "tl" }
        guard !fxDebts.isEmpty else { return }
        priceError = nil
        guard let market = try? await PriceService.fetchMarketPrices() else {
            priceError = "Kurlar alınamadı; son bilinen kurlar kullanılıyor."
            return
        }
        for debt in fxDebts {
            let rate: Double?
            switch debt.kind {
            case "usd":    rate = market.usdSell
            case "gram":   rate = market.goldGramSell
            case "ceyrek": rate = market.ceyrekSell
            default:       rate = nil
            }
            if let rate {
                debt.lastKnownRate = rate
                // İlk kur girilmemişse bugünü baz al (artış 0'dan başlar)
                if debt.initialRate == nil { debt.initialRate = rate }
            }
        }
        try? modelContext.save()
    }
}

// Borç ekleme / düzenleme formu (debt nil ise yeni kayıt)
struct DebtFormView: View {
    let debt: Debt?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var kind: DebtKind = .tl
    @State private var quantity: Double?
    @State private var initialRate: Double?
    @State private var date = Date.now

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Kimden / açıklama (örn. Ahmet)", text: $name)

                    Picker("Borç türü", selection: $kind.animation()) {
                        ForEach(DebtKind.allCases) { k in
                            Label(k.title, systemImage: k.icon).tag(k)
                        }
                    }

                    TextField(kind.quantityLabel, value: $quantity, format: .number)
                        .keyboardType(.decimalPad)

                    if kind != .tl {
                        TextField("Aldığın gündeki birim fiyat (TL)", value: $initialRate, format: .number)
                            .keyboardType(.decimalPad)
                    }

                    DatePicker("Borç tarihi", selection: $date, displayedComponents: .date)
                } footer: {
                    if kind == .tl {
                        Text("TL borcu olduğu gibi toplama eklenir.")
                    } else {
                        Text("Güncel satış kurundan TL karşılığı gösterilir. Aldığın gündeki fiyatı girersen, kur farkından borcun ne kadar arttığı da kırmızı kutuda görünür (boş bırakırsan bugün baz alınır).")
                    }
                }

                if debt != nil {
                    Section {
                        Button("Borcu Sil (Ödendi)", role: .destructive) {
                            deleteDebt()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(debt == nil ? "Borç Ekle" : "Borcu Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        save()
                    }
                    .disabled(name.isEmpty || (quantity ?? 0) <= 0)
                }
            }
            .onAppear {
                if let debt {
                    name = debt.name
                    kind = DebtKind(rawValue: debt.kind) ?? .tl
                    quantity = debt.quantity
                    initialRate = debt.initialRate
                    date = debt.date
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard let quantity else { return }
        if let debt {
            debt.name = name
            debt.kind = kind.rawValue
            debt.quantity = quantity
            debt.date = date
            debt.initialRate = kind == .tl ? nil : initialRate
            if kind == .tl { debt.lastKnownRate = 1 }
        } else {
            modelContext.insert(Debt(name: name, kind: kind.rawValue,
                                     quantity: quantity, date: date,
                                     initialRate: kind == .tl ? nil : initialRate))
        }
        try? modelContext.save()
        dismiss()
    }

    private func deleteDebt() {
        if let debt {
            modelContext.delete(debt)
        }
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    DebtsView()
        .modelContainer(for: [Debt.self], inMemory: true)
}
