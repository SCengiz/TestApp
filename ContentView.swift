import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            SummaryView()
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

#Preview {
    ContentView()
        .modelContainer(for: [Expense.self, FixedPayment.self], inMemory: true)
}
