import SwiftUI
import SwiftData

@main
struct TestAppApp: App {
    // Ayarlar'daki tema seçimi tüm uygulamaya buradan uygulanır
    @AppStorage("appTheme") private var themeRaw = AppTheme.system.rawValue

    var body: some Scene {
        // Veri deposu kullanıcı bazlı olarak UserSessionView içinde kurulur
        WindowGroup {
            ContentView()
                .preferredColorScheme(AppTheme(rawValue: themeRaw)?.colorScheme)
        }
    }
}
