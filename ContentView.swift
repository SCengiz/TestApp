import SwiftUI
import SwiftData

struct ContentView: View {
    // -skipLogin / -openTab N: geliştirme/test kestirmeleri (simülatör otomasyonu için)
    // Normal açılışta: "oturumum açık kalsın" denmişse o kullanıcıyla doğrudan girilir
    @State private var loggedInUser: String? = {
        if CommandLine.arguments.contains("-skipLogin") { return "test" }
        return UserDefaults.standard.string(forKey: "rememberedUser")
    }()
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
            NavigationStack {
                WelcomeView(loggedInUser: $loggedInUser)
            }
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
    // Sekmeden ayrılınca o sekme kök sayfasına döner (kimlik değişince baştan kurulur)
    @State private var tabResetTokens: [UUID] = [UUID(), UUID(), UUID(), UUID()]

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
                .id(tabResetTokens[0])
                .tabItem {
                    Label(tr("Giderler", "Expenses"), systemImage: "chart.pie.fill")
                }
                .tag(0)

            IncomeView(loggedInUser: $loggedInUser)
                .id(tabResetTokens[1])
                .tabItem {
                    Label(tr("Gelirler", "Income"), systemImage: "banknote.fill")
                }
                .tag(1)

            SavingsView(loggedInUser: $loggedInUser)
                .id(tabResetTokens[2])
                .tabItem {
                    Label(tr("Birikimler", "Savings"), systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)

            DebtsView(loggedInUser: $loggedInUser)
                .id(tabResetTokens[3])
                .tabItem {
                    Label(tr("Borçlar", "Debts"), systemImage: "person.2.fill")
                }
                .tag(3)
        }
        .modelContainer(container)
        .onChange(of: selectedTab) { oldValue, _ in
            // Terk edilen sekme bir sonraki girişte kök sayfasıyla açılır
            if (0..<tabResetTokens.count).contains(oldValue) {
                tabResetTokens[oldValue] = UUID()
            }
        }
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
