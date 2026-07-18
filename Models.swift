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

// Her ay tekrarlayan sabit ödeme: kredi kartı ekstresi, kredi taksidi gibi
@Model
final class FixedPayment {
    var name: String
    var amount: Double
    var dueDay: Int // ayın kaçında ödeniyor (1-28)

    init(name: String, amount: Double, dueDay: Int) {
        self.name = name
        self.amount = amount
        self.dueDay = dueDay
    }
}
