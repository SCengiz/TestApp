import Foundation
import SwiftData

// Önizleme/deneme kolaylığı için örnek veri.
// Gerçek kullanıma geçerken bunu false yap; uygulama boş başlar.
let useSampleData = true

@MainActor
func seedSampleDataIfNeeded(_ context: ModelContext) {
    guard useSampleData else { return }

    let calendar = Calendar.current
    let now = Date.now

    // Örnek gelirler (harcamalardan bağımsız kontrol edilir)
    let existingIncomes = (try? context.fetchCount(FetchDescriptor<IncomeSource>())) ?? 0
    if existingIncomes == 0 {
        context.insert(IncomeSource(name: "Maaş", amount: 150000))
        context.insert(IncomeSource(name: "Kira Geliri", amount: 30000))
    }

    // Geçmiş ayların gelir fotoğrafları: 3 ay önce zam senaryosu
    // (eski aylar 160b, sonrası 180b — geçmişin donduğunu gösterir)
    let existingSnapshots = (try? context.fetchCount(FetchDescriptor<IncomeSnapshot>())) ?? 0
    if existingSnapshots == 0 {
        let thisMonth = calendar.dateInterval(of: .month, for: now)!.start
        for offset in -6...(-1) {
            let month = calendar.date(byAdding: .month, value: offset, to: thisMonth)!
            let total: Double = offset <= -3 ? 160000 : 180000
            context.insert(IncomeSnapshot(monthStart: month, total: total))
        }
    }

    // Zaten veri varsa dokunma (tekrar tekrar eklemeyi önler)
    let existing = (try? context.fetchCount(FetchDescriptor<Expense>())) ?? 0
    guard existing == 0 else { return }

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
    // Kredi kartları (süresiz)
    context.insert(FixedPayment(name: "ING Kredi Kartı", amount: 10000, dueDay: 10))
    context.insert(FixedPayment(name: "Yapı Kredi Kredi Kartı", amount: 50000, dueDay: 12))

    // Krediler (taksitli)
    // ING Kredi - 1: 12 taksidin 5'i ödendi → 7 ay sonra bitecek
    context.insert(FixedPayment(name: "ING Kredi - 1", amount: 12000, dueDay: 15,
                                totalInstallments: 12,
                                firstPaymentDate: calendar.date(byAdding: .month, value: -4, to: now)))
    // ING Kredi - 2: 24 taksidin 10'u ödendi → 14 ay sonra bitecek
    context.insert(FixedPayment(name: "ING Kredi - 2", amount: 12000, dueDay: 20,
                                totalInstallments: 24,
                                firstPaymentDate: calendar.date(byAdding: .month, value: -9, to: now)))
    // Garanti Kredi: 18 taksidin 15'i ödendi → 3 ay sonra bitecek
    context.insert(FixedPayment(name: "Garanti Kredi", amount: 5000, dueDay: 25,
                                totalInstallments: 18,
                                firstPaymentDate: calendar.date(byAdding: .month, value: -14, to: now)))

    try? context.save()
}
