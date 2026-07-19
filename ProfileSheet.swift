import SwiftUI
import SwiftData

// Uygulama teması (Ayarlar'dan seçilir, tüm uygulamaya uygulanır)
enum AppTheme: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return tr("Sistem", "System")
        case .light:  return tr("Açık", "Light")
        case .dark:   return tr("Koyu", "Dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// Sol üstteki kullanıcı simgesi: dokununca profil penceresi açılır
struct ProfileButton: View {
    @Binding var loggedInUser: String?
    @State private var showingSheet = false

    var body: some View {
        Button {
            showingSheet = true
        } label: {
            Image(systemName: "person.crop.circle.fill")
                .font(.title3)
        }
        .sheet(isPresented: $showingSheet) {
            ProfileSheet(loggedInUser: $loggedInUser)
        }
    }
}

// Profil penceresi: ad, ayarlar ve çıkış
struct ProfileSheet: View {
    @Binding var loggedInUser: String?

    @Environment(\.dismiss) private var dismiss

    private var displayName: String {
        (loggedInUser ?? "").capitalized
    }

    var body: some View {
        NavigationStack {
            List {
                // En üstte kullanıcı adı
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.tint)
                        Text(displayName)
                            .font(.title2.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // Ayarlar ekranına giriş
                Section {
                    NavigationLink {
                        SettingsView(user: loggedInUser ?? "")
                    } label: {
                        Label(tr("Ayarlar", "Settings"), systemImage: "gearshape.fill")
                    }
                }

                // Çıkış
                Section {
                    Button(tr("Çıkış Yap", "Log Out"), role: .destructive) {
                        UserDefaults.standard.removeObject(forKey: "rememberedUser")
                        loggedInUser = nil
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(tr("Profil", "Profile"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Kapat", "Close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// Ayarlar ekranı (yeni ayarlar buraya eklenecek)
struct SettingsView: View {
    let user: String
    @AppStorage("appTheme") private var themeRaw = AppTheme.system.rawValue
    @AppStorage("appLanguage") private var appLanguage = "tr"

    var body: some View {
        List {
            Section {
                Picker(selection: $themeRaw) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.title).tag(theme.rawValue)
                    }
                } label: {
                    Label(tr("Tema", "Theme"), systemImage: "circle.lefthalf.filled")
                }
                .pickerStyle(.menu)
                Picker(selection: $appLanguage) {
                    Text(tr("Türkçe", "Türkçe")).tag("tr")
                    Text(tr("English", "English")).tag("en")
                } label: {
                    Label(tr("Dil", "Language"), systemImage: "globe")
                }
                .pickerStyle(.menu)
            } header: {
                Text(tr("Görünüm", "Appearance"))
            } footer: {
                Text(tr("\"Sistem\" teması telefonun açık/koyu ayarına uyar. Dil seçimi tüm uygulama metinlerini değiştirir.", "\"System\" theme follows your phone. Language changes all app texts."))
            }

            Section(tr("Hesap", "Account")) {
                NavigationLink {
                    ChangePasswordView(user: user)
                } label: {
                    Label(tr("Şifre Değiştir", "Change Password"), systemImage: "key.fill")
                }
            }

            Section(tr("Hakkında", "About")) {
                HStack {
                    Label(tr("Uygulama Sürümü", "App Version"), systemImage: "info.circle")
                    Spacer()
                    Text("1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(tr("Ayarlar", "Settings"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Şifre değiştirme ekranı
struct ChangePasswordView: View {
    let user: String

    @Environment(\.dismiss) private var dismiss
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var newPasswordAgain = ""
    @State private var message: String?
    @State private var isSuccess = false

    var body: some View {
        Form {
            Section {
                SecureField(tr("Mevcut şifre", "Current password"), text: $oldPassword)
                SecureField(tr("Yeni şifre", "New password"), text: $newPassword)
                SecureField(tr("Yeni şifre (tekrar)", "New password (again)"), text: $newPasswordAgain)
            } footer: {
                if let message {
                    Text(message)
                        .foregroundStyle(isSuccess ? .green : .red)
                }
            }

            Section {
                Button(tr("Şifreyi Değiştir", "Change Password")) {
                    changePassword()
                }
                .frame(maxWidth: .infinity)
                .disabled(oldPassword.isEmpty || newPassword.isEmpty || newPasswordAgain.isEmpty)
            }
        }
        .navigationTitle(tr("Şifre Değiştir", "Change Password"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func changePassword() {
        isSuccess = false
        guard currentPassword(for: user) == oldPassword else {
            message = tr("Mevcut şifre hatalı.", "Current password is wrong.")
            return
        }
        guard newPassword == newPasswordAgain else {
            message = tr("Yeni şifreler birbiriyle uyuşmuyor.", "New passwords do not match.")
            return
        }
        guard newPassword != oldPassword else {
            message = tr("Yeni şifre eskisiyle aynı olamaz.", "New password cannot be the same as the old one.")
            return
        }
        setPassword(newPassword, for: user)
        isSuccess = true
        message = tr("Şifren değiştirildi. Bir sonraki girişte yeni şifreni kullan.", "Password changed. Use the new password next time you log in.")
        oldPassword = ""
        newPassword = ""
        newPasswordAgain = ""
    }
}

#Preview {
    ProfileSheet(loggedInUser: .constant("soray"))
}
