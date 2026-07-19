import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    // -skipLogin / -openTab N: geliştirme/test kestirmeleri (simülatör otomasyonu için)
    @State private var loggedInUser: String? =
        CommandLine.arguments.contains("-skipLogin") ? "soray" : nil
    @State private var selectedTab: Int = {
        if let i = CommandLine.arguments.firstIndex(of: "-openTab"),
           i + 1 < CommandLine.arguments.count,
           let tab = Int(CommandLine.arguments[i + 1]) {
            return tab
        }
        return 0
    }()

    var body: some View {
        if loggedInUser == nil {
            LoginView(loggedInUser: $loggedInUser)
        } else {
            TabView(selection: $selectedTab) {
                SummaryView(loggedInUser: $loggedInUser)
                    .tabItem {
                        Label("Giderler", systemImage: "chart.pie.fill")
                    }
                    .tag(0)

                IncomeView()
                    .tabItem {
                        Label("Gelirler", systemImage: "banknote.fill")
                    }
                    .tag(1)

                SavingsView()
                    .tabItem {
                        Label("Birikimler", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(2)

                DebtsView()
                    .tabItem {
                        Label("Borçlar", systemImage: "person.2.fill")
                    }
                    .tag(3)
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
