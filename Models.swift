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
