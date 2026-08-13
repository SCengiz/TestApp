import SwiftUI
import SwiftData

// Harcama kategorileri: ad + ikon + renk
struct ExpenseCategory: Identifiable, Hashable {
    let name: String
    let icon: String
    let color: Color
    var isCustom: Bool = false
    var id: String { name }

    // Uygulamayla gelen hazır kategoriler
    static let builtIn: [ExpenseCategory] = [
        .init(name: "Market", icon: "cart.fill", color: .green),
        .init(name: "Kafe & Restoran", icon: "fork.knife", color: .orange),
        .init(name: "Ulaşım", icon: "bus.fill", color: .blue),
        .init(name: "Akaryakıt", icon: "fuelpump.fill", color: .teal),
        .init(name: "Alışveriş", icon: "bag.fill", color: .purple),
        .init(name: "Giyim", icon: "tshirt.fill", color: .pink),
        .init(name: "Fatura", icon: "doc.text.fill", color: .indigo),
        .init(name: "Sağlık", icon: "cross.case.fill", color: .red),
        .init(name: "Eğlence", icon: "gamecontroller.fill", color: .mint),
        .init(name: "Abonelik", icon: "tv.fill", color: .cyan),
        .init(name: "Eğitim", icon: "graduationcap.fill", color: .brown),
        .init(name: "Nakit Avans", icon: "banknote.fill", color: .yellow),
    ]

    // Hiçbirine uymayan harcamaların kategorisi (listede hep en sonda)
    static let other = ExpenseCategory(name: "Diğer", icon: "ellipsis.circle.fill", color: .gray)

    // Kullanıcının Ayarlar'dan eklediği kategoriler.
    // Satır çizerken (named) her yerde @Query taşımamak için burada tutulur;
    // veritabanı değişince refreshCustom ile tazelenir.
    private(set) static var custom: [ExpenseCategory] = []

    static func refreshCustom(_ context: ModelContext) {
        let descriptor = FetchDescriptor<CustomCategory>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        let saved = (try? context.fetch(descriptor)) ?? []
        custom = saved.map(ExpenseCategory.init(model:))
        rebuildLookup()
    }

    // Ad -> kategori tablosu. named() liste kaydırılırken her satır için
    // çağrılıyor; her seferinde "builtIn + custom + [other]" dizisini kurup
    // içinde aramak kaydırmayı hissedilir şekilde yavaşlatıyordu.
    private static var lookup: [String: ExpenseCategory] = [:]

    private static func rebuildLookup() {
        var table: [String: ExpenseCategory] = [:]
        for category in builtIn + custom + [other] {
            table[category.name] = category
        }
        lookup = table
    }

    init(model: CustomCategory) {
        self.name = model.name
        self.icon = model.icon
        self.color = categoryColor(named: model.colorName)
        self.isCustom = true
    }

    private init(name: String, icon: String, color: Color, isCustom: Bool = false) {
        self.name = name
        self.icon = icon
        self.color = color
        self.isCustom = isCustom
    }

    // Seçim listelerinde görünen sıra: hazırlar, kullanıcınınkiler, en sonda Diğer
    static var all: [ExpenseCategory] {
        builtIn + custom + [other]
    }

    // İngilizce modda ekranda gösterilen ad.
    // Kayıtlardaki ad Türkçe kalır; kullanıcının kendi kategorileri çevrilmez.
    var displayName: String {
        guard isEnglishUI else { return name }
        switch name {
        case "Market":          return "Groceries"
        case "Kafe & Restoran": return "Cafe & Dining"
        case "Ulaşım":          return "Transport"
        case "Akaryakıt":       return "Fuel"
        case "Alışveriş":       return "Shopping"
        case "Giyim":           return "Clothing"
        case "Fatura":          return "Bills"
        case "Sağlık":          return "Health"
        case "Eğlence":         return "Entertainment"
        case "Abonelik":        return "Subscriptions"
        case "Eğitim":          return "Education"
        case "Nakit Avans":     return "Cash Advance"
        case "Diğer":           return "Other"
        default:                return name
        }
    }

    // Eski kayıtlardaki kategori adlarını yenilerine eşle
    private static let legacyNames: [String: String] = [
        "Online Alışveriş": "Alışveriş",
        "Kıyafet": "Giyim",
    ]

    // İsimden kategori bul; bulunamazsa "Diğer"
    // (silinmiş bir kullanıcı kategorisinin eski kayıtları da buraya düşer)
    static func named(_ name: String) -> ExpenseCategory {
        let resolved = legacyNames[name] ?? name
        if lookup.isEmpty { rebuildLookup() }
        return lookup[resolved] ?? other
    }
}

// Kullanıcı kategorisi eklerken seçilebilen renkler
let categoryColorOptions: [(name: String, turkish: String, english: String, color: Color)] = [
    ("mavi", "Mavi", "Blue", .blue),
    ("yesil", "Yeşil", "Green", .green),
    ("turuncu", "Turuncu", "Orange", .orange),
    ("kirmizi", "Kırmızı", "Red", .red),
    ("mor", "Mor", "Purple", .purple),
    ("pembe", "Pembe", "Pink", .pink),
    ("turkuaz", "Turkuaz", "Teal", .teal),
    ("civit", "Çivit", "Indigo", .indigo),
    ("nane", "Nane", "Mint", .mint),
    ("kahve", "Kahve", "Brown", .brown),
    ("sari", "Sarı", "Yellow", .yellow),
    ("gri", "Gri", "Gray", .gray),
]

func categoryColor(named name: String) -> Color {
    categoryColorOptions.first { $0.name == name }?.color ?? .blue
}

// Kullanıcı kategorisi eklerken seçilebilen simgeler
let categoryIconOptions: [String] = [
    "tag.fill", "pencil.and.ruler.fill", "book.fill", "briefcase.fill",
    "house.fill", "car.fill", "airplane", "tram.fill",
    "pawprint.fill", "gift.fill", "scissors", "wrench.and.screwdriver.fill",
    "figure.run", "dumbbell.fill", "cup.and.saucer.fill", "birthday.cake.fill",
    "phone.fill", "wifi", "drop.fill", "flame.fill",
    "heart.fill", "star.fill", "leaf.fill", "hammer.fill",
]
