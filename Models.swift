import Foundation
import SwiftData

// Günlük harcama kaydı: "Market alışverişi, 500 TL, 17 Temmuz" gibi
@Model
final class Expense {
    var title: String
    var amount: Double
    var date: Date
    var category: String = "Diğer"

    init(title: String, amount: Double, date: Date = .now, category: String = "Diğer") {
        self.title = title
        self.amount = amount
        self.date = date
        self.category = category
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

    // Güncel TL değeri
    var value: Double {
        accountKind == "cash" ? holdings : holdings * unitPrice
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
    var asset: Asset?

    init(date: Date, quantity: Double, pricePerUnit: Double? = nil, asset: Asset? = nil) {
        self.date = date
        self.quantity = quantity
        self.pricePerUnit = pricePerUnit
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
