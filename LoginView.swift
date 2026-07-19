import SwiftUI

// Basit yerel giriş: kullanıcı adı + şifre
// Kullanıcılar burada tanımlı (kişisel uygulama olduğu için yeterli)
let appUsers: [String: String] = [
    "test": "1",
    "soray": "1",
]

// Kullanıcının geçerli şifresi: değiştirilmişse saklanan, yoksa varsayılan
func currentPassword(for user: String) -> String? {
    UserDefaults.standard.string(forKey: "password_\(user)") ?? appUsers[user]
}

// Yeni şifreyi kalıcı olarak kaydet
func setPassword(_ password: String, for user: String) {
    UserDefaults.standard.set(password, forKey: "password_\(user)")
}

// Bu telefonda kayıtlı tüm hesaplar (varsayılanlar + sonradan kayıt olanlar)
func allRegisteredUsers() -> [String] {
    let registered = UserDefaults.standard.stringArray(forKey: "registeredUsers") ?? []
    return Array(appUsers.keys) + registered
}

let maxAccountsPerDevice = 10

// Yeni hesap oluştur; sorun varsa hata mesajı döndürür
func registerUser(name: String, password: String) -> String? {
    let user = name.trimmingCharacters(in: .whitespaces).lowercased()
    guard !user.isEmpty else { return "İsim boş olamaz." }
    guard !password.isEmpty else { return "Şifre boş olamaz." }
    guard !allRegisteredUsers().contains(user) else {
        return "Bu isimde bir hesap zaten var."
    }
    guard allRegisteredUsers().count < maxAccountsPerDevice else {
        return "Bu telefonda en fazla \(maxAccountsPerDevice) hesap oluşturulabilir."
    }
    var registered = UserDefaults.standard.stringArray(forKey: "registeredUsers") ?? []
    registered.append(user)
    UserDefaults.standard.set(registered, forKey: "registeredUsers")
    setPassword(password, for: user)
    return nil
}

struct LoginView: View {
    @Binding var loggedInUser: String?

    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            // Uygulama ikonuyla aynı degrade arka plan
            LinearGradient(
                colors: [Color(red: 0.36, green: 0.24, blue: 0.90),
                         Color(red: 0.10, green: 0.55, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Logo
                AppMark(size: 96)
                Text("İyi Bütçe")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("Devam etmek için giriş yap")
                    .foregroundStyle(.white.opacity(0.8))

                // Giriş formu (beyaz kutu içinde koyu yazılar)
                VStack(spacing: 14) {
                    TextField("", text: $username,
                              prompt: Text("İsim").foregroundColor(.black.opacity(0.55)))
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.black)

                    Divider()

                    SecureField("", text: $password,
                                prompt: Text("Şifre").foregroundColor(.black.opacity(0.55)))
                        .textContentType(.password)
                        .foregroundStyle(.black)
                }
                .padding(14)
                .textFieldStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white)
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.yellow)
                }

                Button {
                    login()
                } label: {
                    Text("Giriş Yap")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(Color(red: 0.36, green: 0.24, blue: 0.90))
                .disabled(username.isEmpty || password.isEmpty)

                Spacer()
                Spacer()
            }
            .padding(28)
        }
    }

    private func login() {
        let name = username.trimmingCharacters(in: .whitespaces).lowercased()
        if let expected = currentPassword(for: name), expected == password {
            loggedInUser = name
        } else {
            errorMessage = "Kullanıcı adı veya şifre hatalı"
            password = ""
        }
    }
}

#Preview {
    LoginView(loggedInUser: .constant(nil))
}
