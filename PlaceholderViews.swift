import SwiftUI

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

#Preview("Borçlar") { DebtsView() }
