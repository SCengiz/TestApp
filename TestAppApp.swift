import SwiftUI
import SwiftData

@main
struct TestAppApp: App {
    // Ayarlar'daki tema ve dil seçimleri tüm uygulamaya buradan uygulanır
    @AppStorage("appTheme") private var themeRaw = AppTheme.system.rawValue
    @AppStorage("appLanguage") private var appLanguage = "tr"

    var body: some Scene {
        // Veri deposu kullanıcı bazlı olarak UserSessionView içinde kurulur
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
                .environment(\.locale, Locale(identifier: appLanguage == "en" ? "en_US" : "tr_TR"))
        }
    }
}
