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
        case .tl:     return tr("Türk Lirası", "Turkish Lira")
        case .usd:    return tr("Dolar", "US Dollar")
        case .gram:   return tr("Gram Altın", "Gold (grams)")
        case .ceyrek: return tr("Çeyrek Altın", "Quarter Gold")
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
        case .tl:     return tr("Tutar (TL)", "Amount (TL)")
        case .usd:    return tr("Miktar (dolar)", "Amount (USD)")
        case .gram:   return tr("Kaç gram?", "How many grams?")
        case .ceyrek: return tr("Kaç adet?", "How many pieces?")
        }
    }

    var unitLabel: String {
        switch self {
        case .tl:     return "TL"
        case .usd:    return tr("dolar", "USD")
        case .gram:   return tr("gram", "grams")
        case .ceyrek: return tr("adet çeyrek", "quarter coins")
        }
    }
}

struct DebtsView: View {
    @Binding var loggedInUser: String?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Debt.date, order: .reverse) private var debts: [Debt]
    @State private var showingAddSheet = false
    @State private var editingDebt: Debt?
    @State private var priceError: String?
    @State private var isRefreshing = false
    @State private var lastUpdate: Date?
    @State private var isVisible = false
    private let autoRefresh = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

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
                        title: tr("Toplam Borcum", "Total Debt"),
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
                    HStack {
                        Text(tr("Borçlarım", "My Debts"))
                        Spacer()
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.mini)
                        }
                    }
                } footer: {
                    if let priceError {
                        Text("⚠️ \(priceError)")
                    } else if let lastUpdate {
                        Text(tr("Kurlar güncel · son güncelleme \(lastUpdate.formatted(date: .omitted, time: .shortened)). Aşağı çekerek yenileyebilirsin; ödediğin borca dokunup silebilirsin.", "Rates up to date · last update \(lastUpdate.formatted(date: .omitted, time: .shortened)). Pull to refresh; tap a paid debt to delete."))
                    } else {
                        Text(tr("Altın ve dolar borçları güncel satış kurundan TL'ye çevrilir; aşağı çekerek kurları yenile. Ödediğin borca dokunup silebilirsin.", "Gold and dollar debts convert to TL at the current sell rate; pull to refresh. Tap a paid debt to delete."))
                    }
                }
            }
            .navigationTitle(tr("Borçlar", "Debts"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileButton(loggedInUser: $loggedInUser)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label(tr("Borç Ekle", "Add Debt"), systemImage: "plus")
                    }
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
                        tr("Henüz borç yok", "No debts yet"),
                        systemImage: "person.2",
                        description: Text(tr("Sağ üstteki + ile elden aldığın borçları ekle: TL, dolar veya altın.", "Add debts with + at the top right: TL, dollars or gold."))
                    )
                }
            }
            .onAppear {
                isVisible = true
                Task { await refreshRates() }
            }
            .onDisappear {
                isVisible = false
            }
            .onReceive(autoRefresh) { _ in
                // Sekme açıkken kurlar 30 sn'de bir otomatik tazelenir
                guard isVisible else { return }
                Task { await refreshRates() }
            }
            .onChange(of: debts.count) {
                Task { await refreshRates() }
            }
        }
    }

    private func subtitle(for debt: Debt, kind: DebtKind) -> String {
        let qty = debt.quantity.formatted(.number.precision(.fractionLength(0...2)))
        let date = debt.date.formatted(.dateTime.day().month(.abbreviated).year().locale(appLocale))
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
        isRefreshing = true
        defer { isRefreshing = false }
        priceError = nil
        guard let market = try? await PriceService.fetchMarketPrices() else {
            priceError = tr("Kurlar alınamadı; son bilinen kurlar kullanılıyor.", "Could not fetch rates; using last known.")
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
        lastUpdate = .now
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
                    TextField(tr("Kimden / açıklama (örn. Ahmet)", "From whom / note (e.g. Ahmet)"), text: $name)
                        .textInputAutocapitalization(.words)

                    Picker(tr("Borç türü", "Debt kind"), selection: $kind.animation()) {
                        ForEach(DebtKind.allCases) { k in
                            Label(k.title, systemImage: k.icon).tag(k)
                        }
                    }

                    TextField(kind.quantityLabel, value: $quantity, format: .number)
                        .keyboardType(.decimalPad)

                    if kind != .tl {
                        TextField(tr("Aldığın gündeki birim fiyat (TL)", "Unit price on the borrow date (TL)"), value: $initialRate, format: .number)
                            .keyboardType(.decimalPad)
                    }

                    DatePicker(tr("Borç tarihi", "Borrow date"), selection: $date, displayedComponents: .date)
                        .id(date)
                } footer: {
                    if kind == .tl {
                        Text(tr("TL borcu olduğu gibi toplama eklenir.", "TL debts are added as-is."))
                    } else {
                        Text(tr("Güncel satış kurundan TL karşılığı gösterilir. Aldığın gündeki fiyatı girersen, kur farkından borcun ne kadar arttığı da kırmızı kutuda görünür (boş bırakırsan bugün baz alınır).", "Shown in TL at the current sell rate. Enter the borrow-day price to also track how much the debt grew."))
                    }
                }

                if debt != nil {
                    Section {
                        Button(tr("Borcu Sil (Ödendi)", "Delete Debt (Paid)"), role: .destructive) {
                            deleteDebt()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(debt == nil ? tr("Borç Ekle", "Add Debt") : tr("Borcu Düzenle", "Edit Debt"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Vazgeç", "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Kaydet", "Save")) {
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
    DebtsView(loggedInUser: .constant("soray"))
        .modelContainer(for: [Debt.self], inMemory: true)
}
