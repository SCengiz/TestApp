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
            SummaryView(loggedInUser: $loggedInUser)
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
