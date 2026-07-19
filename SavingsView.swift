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
    @State private var isRefreshing = false
    @State private var priceError: String?

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

    // Bir ayın birikim kalemleri: geçmişte kayıtlı toplam, bu ay kalem kalem
    private func savingsBreakdown(for month: Date) -> [(name: String, amount: Double, color: Color)] {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        if month < thisMonth {
            return [("O ayın kayıtlı birikimi", historicalTotal(for: month), .purple)]
        }
        return items.map { ($0.name, $0.amount, itemColors[$0.name] ?? .purple) }
    }

    // Birikim gidişatı: son 6 ay + bu ay (geleceğe dönük plan yok)
    private var monthlySavings: [(date: Date, total: Double)] {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        return (-6...0).map { offset in
            let month = calendar.date(byAdding: .month, value: offset, to: thisMonth)!
            let value = offset == 0 ? total : historicalTotal(for: month)
            return (month, value)
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
                                RowIcon(systemName: icon(for: item),
                                        color: itemColors[item.name] ?? .purple)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .foregroundStyle(.primary)
                                    Text(subtitle(for: item))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
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
                    HStack {
                        Text("Birikim Kalemleri")
                        Spacer()
                        if isRefreshing {
                            ProgressView()
                                .controlSize(.mini)
                        }
                    }
                } footer: {
                    if let priceError {
                        Text("⚠️ \(priceError)")
                    } else {
                        Text("Altın, döviz ve fon fiyatları otomatik güncellenir; aşağı çekerek yenileyebilirsin.")
                    }
                }

                // Birikim gidişatı grafiği (sadece geçmiş + bugün)
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
                                }
                            }
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
                                AxisValueLabel(format: .dateTime.month(.abbreviated))
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
            .refreshable {
                await refreshPrices()
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
                        description: Text("Sağ üstteki + ile vadeli hesap, altın, fon gibi birikimlerini ekle.")
                    )
                }
            }
            .onAppear {
                syncSavingsSnapshot(modelContext)
            }
            .onChange(of: total) {
                syncSavingsSnapshot(modelContext)
            }
            .task {
                await refreshPrices()
            }
            .onChange(of: items.count) {
                Task { await refreshPrices() }
            }
        }
    }

    // Otomatik türlerin TL karşılığını canlı fiyatlarla yenile
    @MainActor
    private func refreshPrices() async {
        let autoItems = items.filter { $0.kind != "manual" }
        guard !autoItems.isEmpty else { return }
        isRefreshing = true
        priceError = nil

        // Altın/döviz fiyatları (tek istek)
        var market: PriceService.MarketPrices?
        if autoItems.contains(where: { ["gold", "usd", "eur"].contains($0.kind) }) {
            market = try? await PriceService.fetchMarketPrices()
            if market == nil {
                priceError = "Altın/döviz fiyatları alınamadı; son bilinen değerler gösteriliyor."
            }
        }

        for item in autoItems {
            guard let quantity = item.quantity else { continue }
            var unitPrice: Double?
            switch item.kind {
            case "gold": unitPrice = market?.goldGram
            case "usd":  unitPrice = market?.usd
            case "eur":  unitPrice = market?.eur
            case "fund", "stock": unitPrice = item.unitPrice // birim fiyat elle girilir
            default: break
            }
            if let unitPrice {
                item.amount = quantity * unitPrice
                item.priceUpdatedAt = .now
            }
        }

        try? modelContext.save()
        syncSavingsSnapshot(modelContext)
        isRefreshing = false
    }

    private func icon(for item: SavingsItem) -> String {
        switch item.kind {
        case "gold":  return "medal.fill"
        case "usd":   return "dollarsign.circle.fill"
        case "eur":   return "eurosign.circle.fill"
        case "fund":  return "chart.pie.fill"
        case "stock": return "chart.xyaxis.line"
        default:      return "banknote.fill"
        }
    }

    private func subtitle(for item: SavingsItem) -> String {
        let qty = (item.quantity ?? 0).formatted(.number.precision(.fractionLength(0...2)))
        switch item.kind {
        case "gold", "usd", "eur":
            let unit = item.kind == "gold" ? "gram altın" : (item.kind == "usd" ? "dolar" : "euro")
            if let updated = item.priceUpdatedAt {
                return "\(qty) \(unit) · fiyat: \(updated.formatted(date: .omitted, time: .shortened))"
            }
            return "\(qty) \(unit)"
        case "fund", "stock":
            let code = item.code?.uppercased() ?? (item.kind == "fund" ? "fon" : "hisse")
            if let price = item.unitPrice {
                return "\(qty) adet \(code) × \(price.formatted(.currency(code: "TRY")))"
            }
            return "\(qty) adet \(code)"
        default:
            return "Elle girilen tutar"
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

    // Tür seçenekleri
    enum Kind: String, CaseIterable {
        case manual = "Elle"
        case gold = "Altın"
        case usd = "Dolar"
        case eur = "Euro"
        case fund = "Fon"
        case stock = "Hisse"

        var storageKey: String {
            switch self {
            case .manual: return "manual"
            case .gold: return "gold"
            case .usd: return "usd"
            case .eur: return "eur"
            case .fund: return "fund"
            case .stock: return "stock"
            }
        }
    }

    @State private var kind: Kind = .manual
    @State private var name = ""
    @State private var amount: Double?
    @State private var quantity: Double?
    @State private var code = ""
    @State private var unitPrice: Double?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Tür", selection: $kind.animation()) {
                        ForEach(Kind.allCases, id: \.self) { k in
                            Text(k.rawValue).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)

                    TextField("Adı (örn. Vadeli hesap, Altın hesabı)", text: $name)

                    switch kind {
                    case .manual:
                        TextField("Tutar (TL)", value: $amount, format: .number)
                            .keyboardType(.decimalPad)
                    case .gold:
                        TextField("Kaç gram?", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)
                    case .usd, .eur:
                        TextField("Miktar", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)
                    case .fund:
                        TextField("Fon kodu (örn. TP2)", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        TextField("Kaç adet?", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)
                        TextField("Birim fiyat (TL)", value: $unitPrice, format: .number)
                            .keyboardType(.decimalPad)
                        if !code.isEmpty,
                           let url = URL(string: "https://www.tefas.gov.tr/tr/fon-detayli-analiz/\(code.uppercased())") {
                            Link(destination: url) {
                                Label("Güncel fiyatı TEFAS'ta gör", systemImage: "safari")
                            }
                        }
                    case .stock:
                        TextField("Hisse kodu (örn. THYAO)", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                        TextField("Kaç lot/adet?", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)
                        TextField("Birim fiyat (TL)", value: $unitPrice, format: .number)
                            .keyboardType(.decimalPad)
                    }
                } footer: {
                    switch kind {
                    case .manual:
                        Text("Tutarı kendin girersin; değişince güncellersin.")
                    case .gold:
                        Text("Gram sayısını gir; TL karşılığı güncel altın fiyatından otomatik hesaplanır.")
                    case .usd, .eur:
                        Text("Miktarı gir; TL karşılığı güncel kurdan otomatik hesaplanır.")
                    case .fund:
                        Text("Adet × birim fiyat otomatik hesaplanır. TEFAS bağlantısından güncel fiyata bakıp birim fiyatı güncelleyebilirsin.")
                    case .stock:
                        Text("Adet × birim fiyat otomatik hesaplanır. Hisse fiyatı değişince birim fiyatı güncelle.")
                    }
                }

                if item != nil {
                    Section {
                        Button("Birikimi Sil", role: .destructive) {
                            deleteItem()
                        }
                        .frame(maxWidth: .infinity)
                    } footer: {
                        Text("Silince geçmiş ayların birikimi değişmez; sadece bu ay güncellenir.")
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
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let item {
                    kind = Kind.allCases.first { $0.storageKey == item.kind } ?? .manual
                    name = item.name
                    amount = item.amount
                    quantity = item.quantity
                    code = item.code ?? ""
                    unitPrice = item.unitPrice
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var isValid: Bool {
        guard !name.isEmpty else { return false }
        switch kind {
        case .manual:       return (amount ?? 0) > 0
        case .fund, .stock: return (quantity ?? 0) > 0 && !code.isEmpty && (unitPrice ?? 0) > 0
        default:            return (quantity ?? 0) > 0
        }
    }

    private func save() {
        let storageKind = kind.storageKey
        // Başlangıç tutarı: elle → girilen; fon → adet × birim fiyat;
        // altın/döviz → ilk fiyat güncellemesinde hesaplanır
        let initialAmount: Double
        switch kind {
        case .manual:       initialAmount = amount ?? 0
        case .fund, .stock: initialAmount = (quantity ?? 0) * (unitPrice ?? 0)
        default:            initialAmount = item?.amount ?? 0
        }
        let usesCode = kind == .fund || kind == .stock

        if let item {
            item.name = name
            item.kind = storageKind
            item.amount = initialAmount
            item.quantity = kind == .manual ? nil : quantity
            item.code = usesCode ? code.uppercased() : nil
            item.unitPrice = usesCode ? unitPrice : nil
        } else {
            modelContext.insert(SavingsItem(name: name, amount: initialAmount,
                                            kind: storageKind,
                                            quantity: kind == .manual ? nil : quantity,
                                            code: usesCode ? code.uppercased() : nil,
                                            unitPrice: usesCode ? unitPrice : nil))
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
