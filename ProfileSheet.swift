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
        case .system: return "Sistem"
        case .light:  return "Açık"
        case .dark:   return "Koyu"
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
                        Label("Ayarlar", systemImage: "gearshape.fill")
                    }
                }

                // Çıkış
                Section {
                    Button("Çıkış Yap", role: .destructive) {
                        UserDefaults.standard.removeObject(forKey: "rememberedUser")
                        loggedInUser = nil
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
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
                    Label("Tema", systemImage: "circle.lefthalf.filled")
                }
                .pickerStyle(.menu)
                Picker(selection: $appLanguage) {
                    Text("Türkçe").tag("tr")
                    Text("English").tag("en")
                } label: {
                    Label("Dil", systemImage: "globe")
                }
                .pickerStyle(.menu)
            } header: {
                Text("Görünüm")
            } footer: {
                Text("\"Sistem\" teması telefonun açık/koyu ayarına uyar. Dil seçimi ay adlarını, tarih ve sayı biçimlerini etkiler.")
            }

            Section("Hesap") {
                NavigationLink {
                    ChangePasswordView(user: user)
                } label: {
                    Label("Şifre Değiştir", systemImage: "key.fill")
                }
            }

            Section("Hakkında") {
                HStack {
                    Label("Uygulama Sürümü", systemImage: "info.circle")
                    Spacer()
                    Text("1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Ayarlar")
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
                SecureField("Mevcut şifre", text: $oldPassword)
                SecureField("Yeni şifre", text: $newPassword)
                SecureField("Yeni şifre (tekrar)", text: $newPasswordAgain)
            } footer: {
                if let message {
                    Text(message)
                        .foregroundStyle(isSuccess ? .green : .red)
                }
            }

            Section {
                Button("Şifreyi Değiştir") {
                    changePassword()
                }
                .frame(maxWidth: .infinity)
                .disabled(oldPassword.isEmpty || newPassword.isEmpty || newPasswordAgain.isEmpty)
            }
        }
        .navigationTitle("Şifre Değiştir")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func changePassword() {
        isSuccess = false
        guard currentPassword(for: user) == oldPassword else {
            message = "Mevcut şifre hatalı."
            return
        }
        guard newPassword == newPasswordAgain else {
            message = "Yeni şifreler birbiriyle uyuşmuyor."
            return
        }
        guard newPassword != oldPassword else {
            message = "Yeni şifre eskisiyle aynı olamaz."
            return
        }
        setPassword(newPassword, for: user)
        isSuccess = true
        message = "Şifren değiştirildi. Bir sonraki girişte yeni şifreni kullan."
        oldPassword = ""
        newPassword = ""
        newPasswordAgain = ""
    }
}

#Preview {
    ProfileSheet(loggedInUser: .constant("soray"))
}
