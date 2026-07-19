import Foundation
import SwiftData

// Günlük harcama kaydı: "Market alışverişi, 500 TL, 17 Temmuz" gibi
@Model
final class Expense {
    var title: String
    var amount: Double // taksitli harcamada AYLIK taksit tutarı
    var date: Date
    var category: String = "Diğer"
    var installmentCount: Int? = nil // toplam taksit (peşinse nil)
    var installmentNumber: Int? = nil // bu kayıt kaçıncı taksit
    var installmentGroupID: UUID? = nil // aynı taksitli alışverişin kayıtlarını bağlar

    init(title: String, amount: Double, date: Date = .now, category: String = "Diğer",
         installmentCount: Int? = nil, installmentNumber: Int? = nil,
         installmentGroupID: UUID? = nil) {
        self.title = title
        self.amount = amount
        self.date = date
        self.category = category
        self.installmentCount = installmentCount
        self.installmentNumber = installmentNumber
        self.installmentGroupID = installmentGroupID
    }
}

// Aylık gelir kaynağı: maaş, kira geliri gibi (çoğu zaman sabit,
// her ay yeniden girilmez; değişince güncellenir)
@Model
final class IncomeSource {
    var name: String
    var amount: Double

    init(name: String, amount: Double) {
        self.name = name
        self.amount = amount
    }
}

// Aylık gelir fotoğrafı: her ayın toplam geliri kaydedilir.
// Böylece gelir silinse/değişse bile geçmiş aylar olduğu gibi kalır,
// sadece bu ay ve gelecek aylar yeni duruma göre güncellenir.
@Model
final class IncomeSnapshot {
    var monthStart: Date
    var total: Double

    init(monthStart: Date, total: Double) {
        self.monthStart = monthStart
        self.total = total
    }
}

// Bu ayın gelir fotoğrafını güncel toplamla eşitle (geçmiş aylara dokunmaz)
@MainActor
func syncIncomeSnapshot(_ context: ModelContext) {
    let calendar = Calendar.current
    guard let monthStart = calendar.dateInterval(of: .month, for: .now)?.start else { return }
    let total = ((try? context.fetch(FetchDescriptor<IncomeSource>())) ?? [])
        .reduce(0) { $0 + $1.amount }
    let snapshots = (try? context.fetch(FetchDescriptor<IncomeSnapshot>())) ?? []
    if let current = snapshots.first(where: {
        calendar.isDate($0.monthStart, equalTo: monthStart, toGranularity: .month)
    }) {
        current.total = total
    } else {
        context.insert(IncomeSnapshot(monthStart: monthStart, total: total))
    }
    try? context.save()
}

// Birikim hesabı: kullanıcı istediği kadar hesap açabilir
// (varsayılan 4: Fon, Hisse, Vadeli, Altın; tür davranışı belirler)
@Model
final class SavingsAccountModel {
    var name: String
    var kind: String // fund | stock | cash | gold
    var createdAt: Date = Date.now
    @Relationship(deleteRule: .cascade, inverse: \Asset.account)
    var assets: [Asset] = []

    init(name: String, kind: String) {
        self.name = name
        self.kind = kind
    }
}

extension SavingsAccountModel {
    var totalValue: Double {
        assets.reduce(0) { $0 + $1.value }
    }

    // Hesap bazlı kar/zarar (tüm varlıkların toplamı)
    var totalProfit: Double {
        assets.reduce(0) { $0 + $1.profit }
    }

    var totalProfitPercent: Double? {
        let invested = assets.reduce(0) { $0 + $1.netInvested }
        guard invested > 0 else { return nil }
        return totalProfit / invested * 100
    }

    // Kar/zarar göstermeye değer mi? (hiç yatırım yoksa gösterme)
    var netInvestedNonZero: Bool {
        assets.contains { $0.netInvested > 0 }
    }
}

// Birikim varlığı: bir hesabın içindeki kalem
// - Fon hesabında fonlar (TP2 gibi), hisse hesabında hisseler
// - Altın ve vadeli hesaplar tek varlıkla çalışır (gram / TL)
@Model
final class Asset {
    var accountKind: String // fund | stock | gold | cash
    var name: String
    var code: String? // fon/hisse kodu
    var unitPrice: Double = 0 // TL birim fiyat (cash: 1, gold: canlı, fon/hisse: elle)
    var priceUpdatedAt: Date? = nil
    var account: SavingsAccountModel? = nil
    @Relationship(deleteRule: .cascade, inverse: \AssetTransaction.asset)
    var transactions: [AssetTransaction] = []

    init(accountKind: String, name: String, code: String? = nil,
         unitPrice: Double = 0, account: SavingsAccountModel? = nil) {
        self.accountKind = accountKind
        self.name = name
        self.code = code
        self.unitPrice = unitPrice
        self.account = account
    }
}

extension Asset {
    // Eldeki miktar: alışlar (+) ve satışlar (-) toplamı
    var holdings: Double {
        transactions.reduce(0) { $0 + $1.quantity }
    }

    // Güncel TL değeri (vadeli hesapta birikmiş günlük faiz dahil)
    var value: Double {
        accountKind == "cash" ? holdings + accruedInterest : holdings * unitPrice
    }

    // Vadeli hesap: günlük işleyen faiz getirisi
    // Bakiye işlem işlem izlenir; her aralıkta bakiye × (yıllık oran/100) × gün/365 eklenir.
    // Oran, para yatırma işlemlerinde girilen son orandır.
    var accruedInterest: Double {
        guard accountKind == "cash" else { return 0 }
        let sorted = transactions.sorted { $0.date < $1.date }
        var balance = 0.0
        var rate = 0.0
        var interest = 0.0
        var lastDate: Date?
        for tx in sorted {
            if let last = lastDate {
                let days = tx.date.timeIntervalSince(last) / 86400
                if days > 0 {
                    interest += balance * (rate / 100) * days / 365
                }
            }
            balance += tx.quantity
            if let newRate = tx.interestRate, newRate > 0 {
                rate = newRate
            }
            lastDate = max(lastDate ?? tx.date, tx.date)
        }
        if let last = lastDate {
            let days = Date.now.timeIntervalSince(last) / 86400
            if days > 0 {
                interest += balance * (rate / 100) * days / 365
            }
        }
        return max(0, interest)
    }

    // Vadeli hesapta geçerli (son girilen) faiz oranı
    var currentInterestRate: Double? {
        transactions
            .sorted { $0.date < $1.date }
            .compactMap(\.interestRate)
            .last
    }

    // Net yatırılan: alış maliyetleri - satış gelirleri
    // (fiyatı kaydedilmemiş işlemler güncel fiyattan sayılır, kar/zararı şişirmez)
    var netInvested: Double {
        transactions.reduce(0) { sum, tx in
            let price = tx.pricePerUnit ?? (accountKind == "cash" ? 1 : unitPrice)
            return sum + tx.quantity * price
        }
    }

    // Kar/Zarar: güncel değer - net yatırılan (satış karları dahil)
    var profit: Double {
        value - netInvested
    }

    var profitPercent: Double? {
        guard netInvested > 0 else { return nil }
        return profit / netInvested * 100
    }
}

// Tarihli alış/satış işlemi (miktar: + alış, - satış; cash'te doğrudan TL)
@Model
final class AssetTransaction {
    var date: Date
    var quantity: Double
    var pricePerUnit: Double? // işlem anındaki birim fiyat (kayıt için)
    var interestRate: Double? // vadeli: para yatırırken geçerli yıllık basit faiz (%)
    var asset: Asset?

    init(date: Date, quantity: Double, pricePerUnit: Double? = nil,
         interestRate: Double? = nil, asset: Asset? = nil) {
        self.date = date
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
        self.interestRate = interestRate
        self.asset = asset
    }
}

// Aylık birikim fotoğrafı: her ayın toplam birikimi kaydedilir,
// geçmiş aylar silme/güncellemeden etkilenmez
@Model
final class SavingsSnapshot {
    var monthStart: Date
    var total: Double

    init(monthStart: Date, total: Double) {
        self.monthStart = monthStart
        self.total = total
    }
}

// Tüm varlıkların (emtia/fon/hisse) fiyatlarını o an kaynaktan çekip değerleri
// yeniden hesaplar. Hata mesajı döndürür (yoksa nil). Her sayfa girişinde ve
// 30 sn'lik döngüde çağrılır.
@MainActor
func refreshAllAssetPrices(_ context: ModelContext) async -> String? {
    let assets = (try? context.fetch(FetchDescriptor<Asset>())) ?? []
    var priceError: String?

    // Emtia: altın + gümüş gram fiyatları
    let goldAssets = assets.filter { $0.accountKind == "gold" }
    if !goldAssets.isEmpty {
        if let market = try? await PriceService.fetchMarketPrices() {
            for asset in goldAssets {
                let price = asset.code == "GRAM_GUMUS" ? market.silverGram : market.goldGram
                if let price {
                    asset.unitPrice = price
                    asset.priceUpdatedAt = .now
                }
            }
        } else {
            priceError = tr("Emtia fiyatları alınamadı; son bilinen fiyatlar kullanılıyor.", "Could not fetch commodity prices; using last known prices.")
        }
    }

    // Fonlar: tanınan portföy şirketlerinin sitelerinden
    let fundAssets = assets.filter { $0.accountKind == "fund" && !($0.code ?? "").isEmpty }
    if !fundAssets.isEmpty {
        let teraHome = try? await PriceService.fetchTeraHomePage()
        for asset in fundAssets {
            guard let code = asset.code else { continue }
            if let price = await PriceService.fetchAnyFundPrice(code: code, teraHomePage: teraHome) {
                asset.unitPrice = price
                asset.priceUpdatedAt = .now
            } else if priceError == nil {
                priceError = tr("\(code.uppercased()) fiyatı otomatik alınamadı; elle girilen fiyat kullanılıyor.", "\(code.uppercased()) price could not be fetched automatically; using the manually entered price.")
            }
        }
    }

    // Hisseler: BIST fiyatları
    let stockAssets = assets.filter { $0.accountKind == "stock" && !($0.code ?? "").isEmpty }
    for asset in stockAssets {
        guard let code = asset.code else { continue }
        if let price = try? await PriceService.fetchBistStockPrice(code: code) {
            asset.unitPrice = price
            asset.priceUpdatedAt = .now
        } else if priceError == nil {
            priceError = tr("\(code.uppercased()) hisse fiyatı alınamadı; son bilinen fiyat kullanılıyor.", "\(code.uppercased()) stock price could not be fetched; using last known price.")
        }
    }

    try? context.save()
    syncSavingsSnapshot(context)
    return priceError
}

// Bu ayın birikim fotoğrafını güncel toplamla eşitle
@MainActor
func syncSavingsSnapshot(_ context: ModelContext) {
    let calendar = Calendar.current
    guard let monthStart = calendar.dateInterval(of: .month, for: .now)?.start else { return }
    let total = ((try? context.fetch(FetchDescriptor<Asset>())) ?? [])
        .reduce(0) { $0 + $1.value }
    let snapshots = (try? context.fetch(FetchDescriptor<SavingsSnapshot>())) ?? []
    if let current = snapshots.first(where: {
        calendar.isDate($0.monthStart, equalTo: monthStart, toGranularity: .month)
    }) {
        current.total = total
    } else {
        context.insert(SavingsSnapshot(monthStart: monthStart, total: total))
    }
    try? context.save()
}

// Elden alınan borç: TL, dolar veya altın cinsinden
// (altın/dolar borçları güncel satış kurundan TL'ye çevrilir)
@Model
final class Debt {
    var name: String // kime / açıklama
    var kind: String // tl | usd | gram | ceyrek
    var quantity: Double // TL tutarı / dolar miktarı / gram / adet
    var date: Date
    var lastKnownRate: Double = 1 // son bilinen birim kur (TL); tl için 1
    var initialRate: Double? = nil // borcun alındığı gündeki birim kur (TL)

    init(name: String, kind: String, quantity: Double, date: Date = .now,
         lastKnownRate: Double = 1, initialRate: Double? = nil) {
        self.name = name
        self.kind = kind
        self.quantity = quantity
        self.date = date
        self.lastKnownRate = lastKnownRate
        self.initialRate = initialRate
    }
}

extension Debt {
    // Güncel TL karşılığı (son bilinen kurla)
    var valueTL: Double {
        kind == "tl" ? quantity : quantity * lastKnownRate
    }

    // Borcun alındığı gündeki TL karşılığı
    var initialValueTL: Double {
        kind == "tl" ? quantity : quantity * (initialRate ?? lastKnownRate)
    }

    // Kur farkından borç artışı (+ arttı, - azaldı)
    var increaseTL: Double {
        valueTL - initialValueTL
    }
}

// Her ay tekrarlayan sabit ödeme: kredi kartı ekstresi, kredi taksidi gibi
@Model
final class FixedPayment {
    var name: String
    var amount: Double
    var dueDay: Int // ayın kaçında ödeniyor (1-28)

    // Taksitli ödemeler için (nil = süresiz, fatura/abonelik gibi)
    var totalInstallments: Int? = nil // toplam taksit sayısı (örn. 12)
    var firstPaymentDate: Date? = nil // ilk taksitin ödendiği ay

    init(name: String, amount: Double, dueDay: Int,
         totalInstallments: Int? = nil, firstPaymentDate: Date? = nil) {
        self.name = name
        self.amount = amount
        self.dueDay = dueDay
        self.totalInstallments = totalInstallments
        self.firstPaymentDate = firstPaymentDate
    }
}

extension FixedPayment {
    // Verilen ay için kaçıncı taksit? (taksit aralığı dışındaysa nil)
    func installmentNumber(inMonth month: Date, calendar: Calendar = .current) -> Int? {
        guard let total = totalInstallments, let first = firstPaymentDate else { return nil }
        let firstMonth = calendar.dateInterval(of: .month, for: first)!.start
        let thatMonth = calendar.dateInterval(of: .month, for: month)!.start
        let diff = calendar.dateComponents([.month], from: firstMonth, to: thatMonth).month ?? 0
        let number = diff + 1
        return (1...total).contains(number) ? number : nil
    }

    // Bu ödeme verilen ayda geçerli mi? (süresizler her zaman geçerli)
    func isActive(inMonth month: Date, calendar: Calendar = .current) -> Bool {
        guard totalInstallments != nil, firstPaymentDate != nil else { return true }
        return installmentNumber(inMonth: month, calendar: calendar) != nil
    }
}
