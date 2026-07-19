import SwiftUI
import SwiftData

@main
struct TestAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Expense.self, FixedPayment.self, IncomeSource.self,
                              IncomeSnapshot.self, Asset.self, AssetTransaction.self,
                              SavingsSnapshot.self])
    }
}
