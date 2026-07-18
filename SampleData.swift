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

    // Kategorilere göre gerçekçi tutar aralıkları ve örnek açıklamalar
    let samples: [(category: String, titles: [String], min: Int, max: Int)] = [
        ("Market", ["Market alışverişi", "Haftalık market", "Manav"], 150, 1200),
        ("Kafe & Restoran", ["Kahve", "Öğle yemeği", "Akşam yemeği"], 60, 1500),
        ("Ulaşım", ["Otobüs", "Taksi", "Metro kart"], 30, 300),
        ("Akaryakıt", ["Benzin", "Motorin"], 500, 2500),
        ("Online Alışveriş", ["Trendyol", "Hepsiburada", "Amazon"], 200, 5000),
        ("Kıyafet", ["Tişört", "Ayakkabı", "Pantolon"], 300, 3000),
        ("Fatura", ["Elektrik", "Su", "İnternet", "Doğalgaz"], 200, 2500),
        ("Sağlık", ["Eczane", "Muayene", "Vitamin"], 80, 2000),
        ("Eğlence", ["Sinema", "Konser", "Oyun"], 100, 1000),
        ("Abonelik", ["Netflix", "Spotify", "YouTube Premium"], 50, 500),
    ]

    func addExpenses(on day: Date, count: Int) {
        let startOfDay = calendar.startOfDay(for: day)
        for _ in 0..<count {
            let s = samples.randomElement()!
            let date = calendar.date(byAdding: .hour, value: Int.random(in: 8...22), to: startOfDay) ?? day
            context.insert(Expense(title: s.titles.randomElement()!,
                                   amount: Double(Int.random(in: s.min...s.max)),
                                   date: date,
                                   category: s.category))
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
