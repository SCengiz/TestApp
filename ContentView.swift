import SwiftUI
import SwiftData

struct ContentView: View {
    // -skipLogin / -openTab N: geliştirme/test kestirmeleri (simülatör otomasyonu için)
    @State private var loggedInUser: String? =
        CommandLine.arguments.contains("-skipLogin") ? "test" : nil
    @State private var selectedTab: Int = {
        if let i = CommandLine.arguments.firstIndex(of: "-openTab"),
           i + 1 < CommandLine.arguments.count,
           let tab = Int(CommandLine.arguments[i + 1]) {
            return tab
        }
        return 0
    }()

    var body: some View {
        if let user = loggedInUser {
            UserSessionView(user: user, loggedInUser: $loggedInUser, selectedTab: $selectedTab)
                .id(user) // farklı kullanıcı girişinde oturum baştan kurulur
        } else {
            LoginView(loggedInUser: $loggedInUser)
        }
    }
}

// Kullanıcıya özel veri deposuyla ana sekmeler.
// HER KULLANICININ VERİSİ AYRI DOSYADA tutulur (butcem-soray.store gibi);
// bu dosyalar uygulamanın Application Support klasöründedir ve Xcode'dan
// yeniden yükleme / güncelleme ile SİLİNMEZ. Sadece uygulama telefondan
// tamamen silinirse kaybolur.
struct UserSessionView: View {
    let user: String
    @Binding var loggedInUser: String?
    @Binding var selectedTab: Int
    @State private var container: ModelContainer

    init(user: String, loggedInUser: Binding<String?>, selectedTab: Binding<Int>) {
        self.user = user
        self._loggedInUser = loggedInUser
        self._selectedTab = selectedTab

        let schema = Schema([Expense.self, FixedPayment.self, IncomeSource.self,
                             IncomeSnapshot.self, SavingsAccountModel.self,
                             Asset.self, AssetTransaction.self, SavingsSnapshot.self,
                             Debt.self])
        let supportDir = URL.applicationSupportDirectory
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        let storeURL = supportDir.appending(path: "butcem-\(user).store")
        let config = ModelConfiguration(url: storeURL)

        let container: ModelContainer
        if let fileContainer = try? ModelContainer(for: schema, configurations: [config]) {
            container = fileContainer
        } else {
            // Beklenmedik durumda uygulama açılabilsin (geçici bellek deposu)
            container = try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
            )
        }
        self._container = State(initialValue: container)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SummaryView(loggedInUser: $loggedInUser)
                .tabItem {
                    Label("Giderler", systemImage: "chart.pie.fill")
                }
                .tag(0)

            IncomeView(loggedInUser: $loggedInUser)
                .tabItem {
                    Label("Gelirler", systemImage: "banknote.fill")
                }
                .tag(1)

            SavingsView(loggedInUser: $loggedInUser)
                .tabItem {
                    Label("Birikimler", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)

            DebtsView(loggedInUser: $loggedInUser)
                .tabItem {
                    Label("Borçlar", systemImage: "person.2.fill")
                }
                .tag(3)
        }
        .modelContainer(container)
        .onAppear {
            // Örnek veriler SADECE test kullanıcısına yüklenir;
            // soray (gerçek kullanım) tertemiz başlar
            if user == "test" {
                seedSampleDataIfNeeded(container.mainContext)
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Expense.self, FixedPayment.self], inMemory: true)
}
