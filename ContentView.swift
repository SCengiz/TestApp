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
                        Label("Özet", systemImage: "chart.bar.fill")
                    }

                DailyExpensesView()
                    .tabItem {
                        Label("Günlük", systemImage: "cart")
                    }

                FixedPaymentsView()
                    .tabItem {
                        Label("Sabit Ödemeler", systemImage: "creditcard")
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
