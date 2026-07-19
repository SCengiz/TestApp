import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    // -skipLogin: geliştirme/test kestirmesi (simülatör otomasyonu için)
    @State private var loggedInUser: String? =
        CommandLine.arguments.contains("-skipLogin") ? "soray" : nil

    var body: some View {
        if loggedInUser == nil {
            LoginView(loggedInUser: $loggedInUser)
        } else {
            TabView {
                SummaryView(loggedInUser: $loggedInUser)
                    .tabItem {
                        Label("Giderler", systemImage: "chart.pie.fill")
                    }

                IncomeView()
                    .tabItem {
                        Label("Gelirler", systemImage: "banknote.fill")
                    }

                SavingsView()
                    .tabItem {
                        Label("Birikimler", systemImage: "chart.line.uptrend.xyaxis")
                    }

                DebtsView()
                    .tabItem {
                        Label("Borçlar", systemImage: "person.2.fill")
                    }
            }
            .onAppear {
                seedSampleDataIfNeeded(modelContext)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Expense.self, FixedPayment.self], inMemory: true)
}
