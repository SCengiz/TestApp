import SwiftUI
import SwiftData

@main
struct TestAppApp: App {
    // Ayarlar'daki tema seçimi tüm uygulamaya buradan uygulanır
    @AppStorage("appTheme") private var themeRaw = AppTheme.system.rawValue

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
        }
        .modelContainer(for: [Expense.self, FixedPayment.self, IncomeSource.self,
                              IncomeSnapshot.self, SavingsAccountModel.self,
                              Asset.self, AssetTransaction.self, SavingsSnapshot.self,
                              Debt.self])
    }
}
