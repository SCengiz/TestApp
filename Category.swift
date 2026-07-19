import SwiftUI

// Harcama kategorileri: ad + ikon + renk
struct ExpenseCategory: Identifiable, Hashable {
    let name: String
    let icon: String
    let color: Color
    var id: String { name }

    static let all: [ExpenseCategory] = [
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
        .init(name: "Diğer", icon: "ellipsis.circle.fill", color: .gray),
    ]

    // İngilizce modda ekranda gösterilen ad (kayıtlardaki ad Türkçe kalır)
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
    static func named(_ name: String) -> ExpenseCategory {
        let resolved = legacyNames[name] ?? name
        return all.first { $0.name == resolved } ?? all.last!
    }
}
