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
    let titles = ["Market", "Kafe", "Akaryakıt", "Restoran", "Ulaşım", "Fatura", "Giyim", "Eczane"]

    // Son 7 gün
    for d in 0..<7 {
        let day = calendar.date(byAdding: .day, value: -d, to: now)!
        context.insert(Expense(title: titles.randomElement()!,
                               amount: Double(Int.random(in: 80...900)), date: day))
    }
    // Son 12 ay (geçmiş aylar)
    for m in 1..<12 {
        let month = calendar.date(byAdding: .month, value: -m, to: now)!
        for _ in 0..<Int.random(in: 2...4) {
            context.insert(Expense(title: titles.randomElement()!,
                                   amount: Double(Int.random(in: 200...1500)), date: month))
        }
    }
    // Geçmiş yıllar
    for y in 1..<4 {
        let year = calendar.date(byAdding: .year, value: -y, to: now)!
        for _ in 0..<Int.random(in: 3...6) {
            context.insert(Expense(title: titles.randomElement()!,
                                   amount: Double(Int.random(in: 300...2000)), date: year))
        }
    }

    // Örnek sabit ödemeler
    context.insert(FixedPayment(name: "Kredi Kartı Ekstresi", amount: 4500, dueDay: 10))
    context.insert(FixedPayment(name: "Kredi Taksidi", amount: 3200, dueDay: 15))
    context.insert(FixedPayment(name: "Telefon Faturası", amount: 450, dueDay: 20))

    try? context.save()
}
