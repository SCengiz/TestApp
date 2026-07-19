import SwiftUI

// Birikimler sayfası (henüz boş)
struct SavingsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Birikimler",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Birikimlerini burada takip edeceksin. Yakında!")
            )
            .navigationTitle("Birikimler")
        }
    }
}

// Borçlar sayfası: elden alınan borçlar (henüz boş)
struct DebtsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Borçlar",
                systemImage: "person.2.fill",
                description: Text("Elden aldığın borçları burada takip edeceksin. Yakında!")
            )
            .navigationTitle("Borçlar")
        }
    }
}

#Preview("Birikimler") { SavingsView() }
#Preview("Borçlar") { DebtsView() }
