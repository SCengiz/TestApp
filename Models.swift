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
                if let price { asset.applyPrice(price) }
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
                asset.applyPrice(price)
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
            asset.applyPrice(price)
        } else if priceError == nil {
            priceError = tr("\(code.uppercased()) hisse fiyatı alınamadı; son bilinen fiyat kullanılıyor.", "\(code.uppercased()) stock price could not be fetched; using last known price.")
        }
    }

    if context.hasChanges { try? context.save() }
    syncSavingsSnapshot(context)
    return priceError
}

extension Asset {
    // Fiyat DEĞİŞMEDİYSE hiçbir şey yazılmaz.
    //
    // Eskiden her tazelemede unitPrice ve priceUpdatedAt koşulsuz yazılıyordu.
    // Her yazma bütün ekranlardaki sorguları geçersiz kılıyor; Birikimler ya da
    // Borçlar bir kez açıldıktan sonra 30 sn'lik tazeleme döngüsü diğer
    // ekranları saniyede onlarca kez yeniden çizdiriyordu (ölçüm: Giderler
    // görünür değilken 8 saniyede 185 çizim).
    func applyPrice(_ price: Double) {
        guard price > 0, abs(unitPrice - price) > 0.0001 else { return }
        unitPrice = price
        priceUpdatedAt = .now
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
        // Aynı toplamı yeniden yazmak da her ekranı yeniden çizdiriyordu
        // Faiz sürekli işlediği için kuruş altı oynamalar kayda değmez
        guard abs(current.total - total) > 0.5 else { return }
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

    var category: String = "Diğer" // Kredi Kartı, Kira, Kredi...

    // Taksitli ödemeler için (nil = süresiz, fatura/abonelik gibi)
    var totalInstallments: Int? = nil // toplam taksit sayısı (örn. 12)
    var firstPaymentDate: Date? = nil // ilk taksitin ödendiği ay


    init(name: String, amount: Double, dueDay: Int, category: String = "Diğer",
         totalInstallments: Int? = nil, firstPaymentDate: Date? = nil) {
        self.name = name
        self.amount = amount
        self.dueDay = dueDay
        self.category = category
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

    // Verilen ayda gösterilecek tutar.
    // Kredi kartı ekstresi / fatura gibi tutarı her ay değişen ödemelerde
    // gelecek ayların tutarı henüz belli değildir; satır 0 TL gösterilir.
    func amount(inMonth month: Date, monthlyAmounts: [PaymentMonthAmount] = [],
                calendar: Calendar = .current) -> Double {
        // Sabit tutarlı ödemeler (kira, kredi taksidi) her ay aynıdır
        guard PaymentCategory.named(category).amountVaries else { return amount }

        // Tutarı değişen ödemelerde o aya girilmiş tutar varsa o kullanılır
        if let record = monthlyAmounts.first(where: {
            $0.paymentName == name
                && calendar.isDate($0.monthStart, equalTo: month, toGranularity: .month)
        }) {
            return record.amount
        }

        // Kaydı yoksa 0: o ayın tutarı bilinmiyor demektir.
        //
        // Buraya "içinde bulunduğumuz ay `amount` alanını göstersin" diye bir kural
        // KONMAZ. Öyle yapılınca tutar takvimle birlikte kayıyordu: temmuzda girilen
        // ekstre ağustos gelince ağustosun tutarı gibi görünüyor, temmuz sıfırlanıyordu.
        // Her ayın tutarı yalnızca o aya yazılmış kayıttan gelir.
        return 0
    }

    // Bu ödeme verilen ayda geçerli mi? (süresizler her zaman geçerli)
    func isActive(inMonth month: Date, calendar: Calendar = .current) -> Bool {
        guard totalInstallments != nil, firstPaymentDate != nil else { return true }
        return installmentNumber(inMonth: month, calendar: calendar) != nil
    }

    // Verilen ayda son ödeme günü (ödeme günü 1-28 olduğu için hep geçerli bir tarih)
    func dueDate(inMonth month: Date, calendar: Calendar = .current) -> Date? {
        let monthStart = calendar.dateInterval(of: .month, for: month)!.start
        var components = calendar.dateComponents([.year, .month], from: monthStart)
        components.day = dueDay
        return calendar.date(from: components)
    }

}

// Kullanıcının Ayarlar'dan eklediği kendi harcama kategorisi.
// Hazır kategoriler koda gömülüdür; bunlar kullanıcıya özeldir ve
// diğer veriler gibi kullanıcının kendi deposunda saklanır.
@Model
final class CustomCategory {
    var name: String = ""
    var icon: String = "tag.fill"
    var colorName: String = "mavi"
    var createdAt: Date = Date.now

    init(name: String, icon: String, colorName: String, createdAt: Date = .now) {
        self.name = name
        self.icon = icon
        self.colorName = colorName
        self.createdAt = createdAt
    }
}

// "Ödedim" işaretlenen ödemeler. Ayrı tabloda tutulur: mevcut bir tabloya
// yeni kolon eklemek eski kayıtlarda beklenmedik değerler oluşturabiliyor,
// yeni tablo ise her zaman boş başlar.
@Model
final class PaidPayment {
    var paymentName: String = ""
    var monthStart: Date = Date.now // işaretlenen ayın başı
    var paidAt: Date = Date.now

    init(paymentName: String, monthStart: Date, paidAt: Date = .now) {
        self.paymentName = paymentName
        self.monthStart = monthStart
        self.paidAt = paidAt
    }
}

// Tutarı her ay değişen ödemelerin (kredi kartı ekstresi, fatura) aya özel tutarı.
// Ayrı tabloda tutulur: her ayın kendi ekstresi vardır, tek bir "tutar" alanı
// bütün aylara yayılamaz.
@Model
final class PaymentMonthAmount {
    var paymentName: String = ""
    var monthStart: Date = Date.now
    var amount: Double = 0

    init(paymentName: String, monthStart: Date, amount: Double) {
        self.paymentName = paymentName
        self.monthStart = monthStart
        self.amount = amount
    }
}

// TEK SEFERLİK GÖÇ.
//
// Eski kuralda, tutarı her ay değişen ödemelerin (kredi kartı, fatura) tutarı
// hiçbir aya bağlı değildi: "içinde bulunulan ay" hangisiyse orada görünürdü.
// Ay değişince tutar da onunla birlikte kayıyordu — temmuzda girilen ekstre
// ağustos gelince ağustosun tutarı gibi görünüyor, temmuz sıfırlanıyordu.
//
// Artık her ayın tutarı yalnızca o aya yazılmış kayıttan geliyor. Aya özel hiç
// kaydı olmayan eski ödemelerin tutarı, eski kuralın en son doğru gösterdiği
// aya — yani bir önceki aya — yazılır ki veri kaybolmasın.
@MainActor
func migrateFloatingPaymentAmounts(_ context: ModelContext,
                                   calendar: Calendar = .current,
                                   now: Date = .now) {
    let payments = (try? context.fetch(FetchDescriptor<FixedPayment>())) ?? []
    let records = (try? context.fetch(FetchDescriptor<PaymentMonthAmount>())) ?? []
    let thisMonth = calendar.dateInterval(of: .month, for: now)!.start
    guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: thisMonth) else {
        return
    }

    var didInsert = false
    for payment in payments where PaymentCategory.named(payment.category).amountVaries {
        guard payment.amount > 0 else { continue }
        // Aya özel kaydı olan ödemeler zaten doğru; onlara dokunulmaz
        guard !records.contains(where: { $0.paymentName == payment.name }) else { continue }
        context.insert(PaymentMonthAmount(paymentName: payment.name,
                                          monthStart: previousMonth,
                                          amount: payment.amount))
        didInsert = true
    }
    if didInsert { try? context.save() }
}

// TAKSİT TARİHİ KURALI — her açılışta uygulanır.
//
// Kural: yalnızca 1. taksit alışveriş tarihinde durur; 2. taksitten sonrakilerin
// hepsi kendi ayının 1'ine yazılır. Böylece gelecek taksitler ay listesinin en
// altında kalır, o ay yeni girilen harcamaların arasına karışmaz.
//
// Gruplama YAPILMAZ, sadece taksit numarasına bakılır. Önceki sürümde grup
// kimliğine (sonradan bazı kayıtlarda boş) ve ada göre gruplanıyor, grubun en
// küçük numaralı taksidi korunuyordu; "şu an 4. taksitteyim" denerek girilmiş
// bir alışverişte 4/6 grubun en küçüğü olduğu için yerinden oynamıyordu.
//
// Taksitin hangi AYA ait olduğu DEĞİŞMEZ, yalnızca ay içindeki günü değişir;
// bu yüzden aylık toplamlar, grafikler ve kategori dağılımları etkilenmez.
@MainActor
func normalizeInstallmentDates(_ context: ModelContext,
                               calendar: Calendar = .current) {
    let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
    var didChange = false
    for expense in expenses {
        guard let number = expense.installmentNumber, number > 1,
              let monthStart = calendar.dateInterval(of: .month, for: expense.date)?.start,
              expense.date != monthStart
        else { continue }
        expense.date = monthStart
        didChange = true
    }
    if didChange { try? context.save() }
}
