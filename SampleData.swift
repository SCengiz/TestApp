import Foundation
import SwiftData

// Önizleme/deneme kolaylığı için örnek veri.
// Gerçek kullanıma geçerken bunu false yap; uygulama boş başlar.
let useSampleData = true

@MainActor
func seedSampleDataIfNeeded(_ context: ModelContext) {
    guard useSampleData else { return }

    // Zaten veri varsa dokunma (tekrar tekrar eklemeyi önler)
    let existing = (try? context.fetchCount(FetchDescriptor<Expense>())) ?? 0
    guard existing == 0 else { return }

    let calendar = Calendar.current
    let now = Date.now

    // Farklı kategoriler ve gerçekçi tutar aralıkları (min, max TL)
    let categories: [(name: String, min: Int, max: Int)] = [
        ("Market", 150, 1200),
        ("Kafe", 60, 400),
        ("Restoran", 200, 1500),
        ("Akaryakıt", 500, 2500),
        ("Ulaşım", 30, 300),
        ("Giyim", 300, 3000),
        ("Eczane", 80, 800),
        ("Elektronik", 500, 8000),
        ("Eğlence", 100, 1000),
        ("Spor", 100, 1500),
        ("Sağlık", 150, 2000),
        ("Kozmetik", 100, 900),
        ("Kitap", 80, 600),
        ("Hediye", 150, 2000),
        ("Abonelik", 50, 500),
        ("Fatura", 200, 2500),
    ]

    func addExpenses(on day: Date, count: Int) {
        let startOfDay = calendar.startOfDay(for: day)
        for _ in 0..<count {
            let c = categories.randomElement()!
            let date = calendar.date(byAdding: .hour, value: Int.random(in: 8...22), to: startOfDay) ?? day
            context.insert(Expense(title: c.name,
                                   amount: Double(Int.random(in: c.min...c.max)),
                                   date: date))
        }
    }

    // Son ~13 ay: HER güne 1-4 harcama, farklı kategorilerde
    // (bu ayın her günü + geçmiş aylar dolu görünür)
    for offset in 0..<400 {
        let day = calendar.date(byAdding: .day, value: -offset, to: now)!
        addExpenses(on: day, count: Int.random(in: 1...4))
    }

    // Daha eski yıllar (2-4 yıl önce): yıllık grafiği doldurmak için
    for yearsAgo in 2...4 {
        let base = calendar.date(byAdding: .year, value: -yearsAgo, to: now)!
        for _ in 0..<70 {
            let day = calendar.date(byAdding: .day, value: -Int.random(in: 0...360), to: base)!
            addExpenses(on: day, count: 1)
        }
    }

    // Örnek sabit ödemeler
    context.insert(FixedPayment(name: "Kredi Kartı Ekstresi", amount: 4500, dueDay: 10))
    context.insert(FixedPayment(name: "Kredi Taksidi", amount: 3200, dueDay: 15))
    context.insert(FixedPayment(name: "Telefon Faturası", amount: 450, dueDay: 20))
    context.insert(FixedPayment(name: "Abonelikler (Netflix vb.)", amount: 350, dueDay: 5))

    try? context.save()
}
