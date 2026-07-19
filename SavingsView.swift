import SwiftUI
import SwiftData
import Charts

// 4 sabit birikim hesabı
enum SavingsAccount: String, CaseIterable, Identifiable {
    case fund = "fund"
    case stock = "stock"
    case cash = "cash"
    case gold = "gold"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fund:  return "Fon Hesabı"
        case .stock: return "Hisse Hesabı"
        case .cash:  return "Vadeli Hesap"
        case .gold:  return "Altın Hesabı"
        }
    }

    var icon: String {
        switch self {
        case .fund:  return "chart.pie.fill"
        case .stock: return "chart.xyaxis.line"
        case .cash:  return "banknote.fill"
        case .gold:  return "medal.fill"
        }
    }

    var color: Color {
        switch self {
        case .fund:  return .purple
        case .stock: return .orange
        case .cash:  return .indigo
        case .gold:  return .yellow
        }
    }

    // Alış/satış düğme başlıkları ve miktar birimi
    var buyLabel: String {
        switch self {
        case .cash: return "Para Yatır"
        default:    return "Alış Ekle"
        }
    }
    var sellLabel: String {
        switch self {
        case .cash: return "Para Çek"
        default:    return "Satış Ekle"
        }
    }
    var unitLabel: String {
        switch self {
        case .gold: return "gram"
        case .cash: return "TL"
        default:    return "adet"
        }
    }
}

// MARK: - Ana Birikimler ekranı (4 hesap + grafik)

struct SavingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavingsAccountModel.createdAt) private var accounts: [SavingsAccountModel]
    @Query private var assets: [Asset]
    @Query(sort: \SavingsSnapshot.monthStart) private var snapshots: [SavingsSnapshot]
    @State private var selectedMonth: Date?
    @State private var detailMonth: MonthSelection?
    @State private var showingAccountForm = false
    @State private var priceError: String?

    private var calendar: Calendar { .current }

    private var total: Double {
        assets.reduce(0) { $0 + $1.value }
    }

    // Tüm hesapların kümülatif kar/zararı
    private var cumulativeProfit: Double {
        accounts.reduce(0) { $0 + $1.totalProfit }
    }

    private var cumulativeProfitPercent: Double? {
        let invested = assets.reduce(0) { $0 + $1.netInvested }
        guard invested > 0 else { return nil }
        return cumulativeProfit / invested * 100
    }

    private var hasAnyInvestment: Bool {
        accounts.contains { $0.netInvestedNonZero }
    }

    // Bir ayın dökümü: geçmişte kayıtlı toplam, bu ay hesap hesap
    private func breakdown(for month: Date) -> [(name: String, amount: Double, color: Color)] {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        if month < thisMonth {
            return [("O ayın kayıtlı birikimi", historicalTotal(for: month), .purple)]
        }
        return accounts.map { account in
            let kind = SavingsAccount(rawValue: account.kind) ?? .cash
            return (account.name, account.totalValue, kind.color)
        }
    }

    // Son 6 ay + bu ay
    private var monthlySavings: [(date: Date, total: Double)] {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        return (-6...0).map { offset in
            let month = calendar.date(byAdding: .month, value: offset, to: thisMonth)!
            let value = offset == 0 ? total : historicalTotal(for: month)
            return (month, value)
        }
    }

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
                        colors: [.purple, .indigo],
                        profit: hasAnyInvestment ? cumulativeProfit : nil,
                        profitPercent: cumulativeProfitPercent
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(accounts) { account in
                        let kind = SavingsAccount(rawValue: account.kind) ?? .cash
                        NavigationLink {
                            AccountDetailView(accountModel: account)
                        } label: {
                            HStack(spacing: 12) {
                                RowIcon(systemName: kind.icon, color: kind.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(account.name)
                                    if kind != .cash, account.netInvestedNonZero {
                                        ProfitText(profit: account.totalProfit,
                                                   percent: account.totalProfitPercent)
                                    }
                                }
                                Spacer()
                                Text(account.totalValue, format: .currency(code: "TRY"))
                                    .font(.callout.weight(.semibold))
                            }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(accounts[index])
                        }
                        syncSavingsSnapshot(modelContext)
                    }
                } header: {
                    Text("Hesaplarım")
                } footer: {
                    if let priceError {
                        Text("⚠️ \(priceError)")
                    } else {
                        Text("Hesaba dokunup alış/satış işlemlerini gir; + ile yeni hesap ekleyebilirsin.")
                    }
                }

                // Birikim gidişatı (son 6 ay + bugün)
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Birikim Gidişatı", systemImage: "chart.bar.fill")
                            .font(.headline)

                        Chart {
                            ForEach(monthlySavings, id: \.date) { item in
                                ForEach(breakdown(for: item.date), id: \.name) { seg in
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
                    showingAccountForm = true
                } label: {
                    Label("Hesap Ekle", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAccountForm) {
                AccountFormView()
            }
            .refreshable {
                await refreshPrices()
            }
            .sheet(item: $detailMonth) { selection in
                MonthBreakdownSheet(
                    heading: "Birikimler",
                    month: selection.date,
                    items: breakdown(for: selection.date)
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onAppear {
                ensureDefaultAccounts()
                syncSavingsSnapshot(modelContext)
            }
            .onChange(of: total) {
                syncSavingsSnapshot(modelContext)
            }
            .task {
                await refreshPrices()
            }
        }
    }

    // İlk açılışta varsayılan 4 hesabı oluştur
    private func ensureDefaultAccounts() {
        guard accounts.isEmpty else { return }
        for account in SavingsAccount.allCases {
            modelContext.insert(SavingsAccountModel(name: account.title, kind: account.rawValue))
        }
        try? modelContext.save()
    }

    // Canlı fiyatları yenile: altın (kur) + fonlar (Tera Portföy sitesi)
    @MainActor
    private func refreshPrices() async {
        priceError = nil

        // Altın: canlı gram fiyatı
        let goldAssets = assets.filter { $0.accountKind == "gold" }
        if !goldAssets.isEmpty {
            if let market = try? await PriceService.fetchMarketPrices(),
               let goldPrice = market.goldGram {
                for asset in goldAssets {
                    asset.unitPrice = goldPrice
                    asset.priceUpdatedAt = .now
                }
            } else {
                priceError = "Altın fiyatı alınamadı; son bilinen fiyat kullanılıyor."
            }
        }

        // Fonlar: Tera Portföy sitesinden otomatik
        let fundAssets = assets.filter {
            $0.accountKind == "fund" && !($0.code ?? "").isEmpty
        }
        if !fundAssets.isEmpty {
            let homePage = try? await PriceService.fetchTeraHomePage()
            for asset in fundAssets {
                guard let code = asset.code else { continue }
                if let price = try? await PriceService.fetchTeraFundPrice(code: code, homePage: homePage) {
                    asset.unitPrice = price
                    asset.priceUpdatedAt = .now
                } else if priceError == nil {
                    priceError = "\(code.uppercased()) fiyatı otomatik alınamadı; elle girilen fiyat kullanılıyor."
                }
            }
        }

        try? modelContext.save()
        syncSavingsSnapshot(modelContext)
    }
}

// MARK: - Hesap detayı

struct AccountDetailView: View {
    @Bindable var accountModel: SavingsAccountModel

    @Environment(\.modelContext) private var modelContext
    @State private var showingAssetForm = false

    private var account: SavingsAccount {
        SavingsAccount(rawValue: accountModel.kind) ?? .cash
    }

    private var assets: [Asset] {
        accountModel.assets.sorted { $0.value > $1.value }
    }

    private var accountTotal: Double {
        accountModel.totalValue
    }

    var body: some View {
        Group {
            if account == .fund || account == .stock {
                // Fon/Hisse: içinde birden çok varlık olabilir
                List {
                    summaryCard

                    Section {
                        ForEach(assets) { asset in
                            NavigationLink {
                                AssetDetailView(asset: asset, account: account)
                            } label: {
                                HStack(spacing: 12) {
                                    RowIcon(systemName: account.icon, color: account.color)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(asset.name)
                                        Text(assetSubtitle(asset))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        if asset.netInvested > 0 {
                                            ProfitText(profit: asset.profit,
                                                       percent: asset.profitPercent)
                                        }
                                    }
                                    Spacer()
                                    Text(asset.value, format: .currency(code: "TRY"))
                                        .font(.callout.weight(.semibold))
                                }
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                modelContext.delete(assets[index])
                            }
                            syncSavingsSnapshot(modelContext)
                        }
                    } header: {
                        Text(account == .fund ? "Fonlarım" : "Hisselerim")
                    } footer: {
                        Text("Varlığa dokunup alış/satış işlemlerini ve güncel fiyatını gir.")
                    }
                }
                .toolbar {
                    Button {
                        showingAssetForm = true
                    } label: {
                        Label(account == .fund ? "Fon Ekle" : "Hisse Ekle", systemImage: "plus")
                    }
                }
                .sheet(isPresented: $showingAssetForm) {
                    AssetFormView(account: account, accountModel: accountModel)
                }
                .overlay {
                    if assets.isEmpty {
                        ContentUnavailableView(
                            account == .fund ? "Henüz fon yok" : "Henüz hisse yok",
                            systemImage: account.icon,
                            description: Text("Sağ üstteki + ile ekle, sonra alış/satış işlemlerini gir.")
                        )
                    }
                }
            } else {
                // Altın/Vadeli: tek varlık, doğrudan işlem listesi
                if let asset = assets.first {
                    AssetDetailView(asset: asset, account: account, embedded: true)
                } else {
                    Color.clear
                }
            }
        }
        .navigationTitle(accountModel.name)
        .onAppear {
            // Altın/Vadeli hesabın tekil varlığını ilk girişte oluştur
            if (account == .gold || account == .cash) && assets.isEmpty {
                let name = account == .gold ? "Altın" : "Vadeli Mevduat"
                modelContext.insert(Asset(accountKind: account.rawValue, name: name,
                                          unitPrice: account == .cash ? 1 : 0,
                                          account: accountModel))
                try? modelContext.save()
            }
        }
    }

    private var summaryCard: some View {
        Section {
            StatCard(
                title: accountModel.name,
                amount: accountTotal,
                icon: account.icon,
                colors: [account.color, account.color.opacity(0.6)],
                profit: (account != .cash && accountModel.netInvestedNonZero)
                    ? accountModel.totalProfit : nil,
                profitPercent: accountModel.totalProfitPercent
            )
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
        }
    }

    private func assetSubtitle(_ asset: Asset) -> String {
        let qty = asset.holdings.formatted(.number.precision(.fractionLength(0...2)))
        let price = asset.unitPrice.formatted(.currency(code: "TRY"))
        return "\(qty) adet × \(price)"
    }
}

// MARK: - Varlık detayı (işlem geçmişi + fiyat)

struct AssetDetailView: View {
    @Bindable var asset: Asset
    let account: SavingsAccount
    var embedded = false // Altın/Vadeli: hesap sayfasının kendisi

    @Environment(\.modelContext) private var modelContext
    @State private var showingBuy = false
    @State private var showingSell = false
    @State private var priceText: Double?

    private var sortedTransactions: [AssetTransaction] {
        asset.transactions.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                StatCard(
                    title: asset.name,
                    amount: asset.value,
                    icon: account.icon,
                    colors: [account.color, account.color.opacity(0.6)]
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Miktar + kar/zarar + birim fiyat
            Section {
                HStack {
                    Text("Eldeki miktar")
                    Spacer()
                    Text("\(asset.holdings.formatted(.number.precision(.fractionLength(0...2)))) \(account.unitLabel)")
                        .fontWeight(.semibold)
                }

                if account != .cash, asset.netInvested > 0 {
                    HStack {
                        Text("Net yatırılan")
                        Spacer()
                        Text(asset.netInvested, format: .currency(code: "TRY"))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Kar/Zarar")
                        Spacer()
                        ProfitText(profit: asset.profit, percent: asset.profitPercent)
                            .font(.callout.weight(.bold))
                    }
                }

                if account == .fund || account == .stock {
                    HStack {
                        Text("Birim fiyat")
                        Spacer()
                        TextField("₺", value: $priceText, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 110)
                            .onSubmit { savePrice() }
                        Button {
                            savePrice()
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(account.color)
                        }
                        .buttonStyle(.plain)
                    }

                    if account == .fund, let updated = asset.priceUpdatedAt {
                        HStack {
                            Text("Son otomatik güncelleme")
                            Spacer()
                            Text(updated.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                }

                if account == .gold {
                    HStack {
                        Text("Gram fiyatı (canlı)")
                        Spacer()
                        Text(asset.unitPrice, format: .currency(code: "TRY"))
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                if account == .fund {
                    Text("Tera Portföy fonlarının fiyatı otomatik güncellenir (Birikimler'i aşağı çekerek yenile). Diğer fonlarda fiyatı buradan elle girebilirsin.")
                } else if account == .stock {
                    Text("Fiyat değişince buradan güncelle; değer otomatik yeniden hesaplanır.")
                }
            }

            // Alış / Satış düğmeleri
            Section {
                HStack(spacing: 12) {
                    Button {
                        showingBuy = true
                    } label: {
                        Label(account.buyLabel, systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                    Button {
                        showingSell = true
                    } label: {
                        Label(account.sellLabel, systemImage: "minus.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // İşlem geçmişi
            Section("İşlem Geçmişi") {
                if sortedTransactions.isEmpty {
                    Text("Henüz işlem yok.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sortedTransactions) { tx in
                        transactionRow(tx)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            modelContext.delete(sortedTransactions[index])
                        }
                        syncSavingsSnapshot(modelContext)
                    }
                }
            }
        }
        .navigationTitle(embedded ? account.title : asset.name)
        .sheet(isPresented: $showingBuy) {
            TransactionFormView(asset: asset, account: account, isBuy: true)
        }
        .sheet(isPresented: $showingSell) {
            TransactionFormView(asset: asset, account: account, isBuy: false)
        }
        .onAppear {
            priceText = asset.unitPrice > 0 ? asset.unitPrice : nil
        }
        .onChange(of: asset.unitPrice) {
            priceText = asset.unitPrice > 0 ? asset.unitPrice : nil
        }
    }

    private func savePrice() {
        guard let priceText, priceText > 0 else { return }
        asset.unitPrice = priceText
        asset.priceUpdatedAt = .now
        try? modelContext.save()
        syncSavingsSnapshot(modelContext)
    }

    private func transactionRow(_ tx: AssetTransaction) -> some View {
        let isBuy = tx.quantity >= 0
        return HStack(spacing: 12) {
            RowIcon(systemName: isBuy ? "arrow.down.circle.fill" : "arrow.up.circle.fill",
                    color: isBuy ? .green : .red)
            VStack(alignment: .leading, spacing: 2) {
                Text(transactionTitle(tx))
                Text(tx.date, format: .dateTime.day().month(.wide).year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let total = transactionTotal(tx) {
                Text(total, format: .currency(code: "TRY"))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(isBuy ? Color.primary : Color.red)
            }
        }
    }

    private func transactionTitle(_ tx: AssetTransaction) -> String {
        let qty = abs(tx.quantity).formatted(.number.precision(.fractionLength(0...2)))
        let action = tx.quantity >= 0
            ? (account == .cash ? "Yatırılan" : "Alış")
            : (account == .cash ? "Çekilen" : "Satış")
        if account == .cash {
            return action
        }
        if let price = tx.pricePerUnit {
            return "\(action) · \(qty) \(account.unitLabel) × \(price.formatted(.currency(code: "TRY")))"
        }
        return "\(action) · \(qty) \(account.unitLabel)"
    }

    private func transactionTotal(_ tx: AssetTransaction) -> Double? {
        if account == .cash { return tx.quantity }
        if let price = tx.pricePerUnit { return tx.quantity * price }
        return nil
    }
}

// MARK: - Yeni hesap ekleme formu

struct AccountFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var kind: SavingsAccount = .fund

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Hesap adı (örn. Midas Hisse, Ziraat Vadeli)", text: $name)

                    Picker("Hesap türü", selection: $kind) {
                        ForEach(SavingsAccount.allCases) { k in
                            Label(k.title, systemImage: k.icon).tag(k)
                        }
                    }
                } footer: {
                    Text("Tür, hesabın nasıl çalışacağını belirler: Fon/Hisse içine varlık eklenir; Vadeli para yatır/çek, Altın gram al/sat ile çalışır.")
                }
            }
            .navigationTitle("Hesap Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        modelContext.insert(SavingsAccountModel(name: name, kind: kind.rawValue))
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Yeni fon/hisse ekleme formu

struct AssetFormView: View {
    let account: SavingsAccount
    let accountModel: SavingsAccountModel

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var code = ""
    @State private var unitPrice: Double?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(account == .fund ? "Fon adı (örn. TP2 Fonu)" : "Hisse adı (örn. THY)",
                              text: $name)
                    TextField(account == .fund ? "Fon kodu (örn. TP2)" : "Hisse kodu (örn. THYAO)",
                              text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    TextField("Güncel birim fiyat (TL)", value: $unitPrice, format: .number)
                        .keyboardType(.decimalPad)
                } footer: {
                    Text("Ekledikten sonra varlığa dokunup alış işlemlerini gir.")
                }
            }
            .navigationTitle(account == .fund ? "Fon Ekle" : "Hisse Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        modelContext.insert(Asset(accountKind: account.rawValue,
                                                  name: name,
                                                  code: code.uppercased(),
                                                  unitPrice: unitPrice ?? 0,
                                                  account: accountModel))
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(name.isEmpty || code.isEmpty || (unitPrice ?? 0) <= 0)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Alış/Satış işlemi formu

struct TransactionFormView: View {
    let asset: Asset
    let account: SavingsAccount
    let isBuy: Bool

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var quantity: Double?
    @State private var price: Double?
    @State private var date = Date.now
    @State private var useCurrentPrice = true

    private var title: String { isBuy ? account.buyLabel : account.sellLabel }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if account == .cash {
                        TextField("Tutar (TL)", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)
                    } else {
                        TextField("Miktar (\(account.unitLabel))", value: $quantity, format: .number)
                            .keyboardType(.decimalPad)

                        // Güncel fiyattan mı, elle mi?
                        if asset.unitPrice > 0 {
                            Toggle(isOn: $useCurrentPrice.animation()) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Güncel fiyattan")
                                    Text(asset.unitPrice, format: .currency(code: "TRY"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        if !useCurrentPrice || asset.unitPrice <= 0 {
                            TextField("Birim fiyat (TL)", value: $price, format: .number)
                                .keyboardType(.decimalPad)
                        }
                    }

                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                } footer: {
                    if account == .cash {
                        EmptyView()
                    } else if useCurrentPrice && asset.unitPrice > 0 {
                        Text("İşlem, güncel fiyat (\(asset.unitPrice.formatted(.currency(code: "TRY")))) üzerinden kaydedilir. Farklı fiyattan işlem yaptıysan kapatıp elle gir.")
                    } else {
                        Text("İşlemi yaptığın birim fiyatı gir; kar/zarar hesabında kullanılır.")
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        save()
                    }
                    .disabled((quantity ?? 0) <= 0)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard let quantity, quantity > 0 else { return }
        let signed = isBuy ? quantity : -quantity

        // İşlem fiyatı: güncel fiyattan ya da elle girilen
        let effectivePrice: Double?
        if account == .cash {
            effectivePrice = nil
        } else if useCurrentPrice && asset.unitPrice > 0 {
            effectivePrice = asset.unitPrice
        } else {
            effectivePrice = price
        }

        let tx = AssetTransaction(date: date, quantity: signed,
                                  pricePerUnit: effectivePrice,
                                  asset: asset)
        modelContext.insert(tx)
        // Elle girilen fiyat, fiyatı olmayan varlığın güncel fiyatı olarak da kullanılabilir
        if let effectivePrice, effectivePrice > 0, asset.unitPrice == 0 {
            asset.unitPrice = effectivePrice
        }
        try? modelContext.save()
        syncSavingsSnapshot(modelContext)
        dismiss()
    }
}

#Preview {
    SavingsView()
        .modelContainer(for: [Asset.self, AssetTransaction.self, SavingsSnapshot.self], inMemory: true)
}
