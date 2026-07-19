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
    guard !user.isEmpty else { return tr("İsim boş olamaz.", "Name cannot be empty.") }
    guard !password.isEmpty else { return tr("Şifre boş olamaz.", "Password cannot be empty.") }
    guard !allRegisteredUsers().contains(user) else {
        return tr("Bu isimde bir hesap zaten var.", "An account with this name already exists.")
    }
    guard allRegisteredUsers().count < maxAccountsPerDevice else {
        return tr("Bu telefonda en fazla \(maxAccountsPerDevice) hesap oluşturulabilir.", "At most \(maxAccountsPerDevice) accounts can be created on this phone.")
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
    @State private var rememberMe = true
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
                Text(tr("Devam etmek için giriş yap", "Log in to continue"))
                    .foregroundStyle(.white.opacity(0.8))

                // Giriş formu (beyaz kutu içinde koyu yazılar)
                VStack(spacing: 14) {
                    TextField("", text: $username,
                              prompt: Text(tr("İsim", "Name")).foregroundColor(.black.opacity(0.55)))
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.black)

                    Divider()

                    SecureField("", text: $password,
                                prompt: Text(tr("Şifre", "Password")).foregroundColor(.black.opacity(0.55)))
                        .textContentType(.password)
                        .foregroundStyle(.black)
                }
                .padding(14)
                .textFieldStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white)
                )

                Toggle(isOn: $rememberMe) {
                    Text(tr("Oturumum açık kalsın", "Keep me logged in"))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .tint(.green)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.yellow)
                }

                Button {
                    login()
                } label: {
                    Text(tr("Giriş Yap", "Log In"))
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
            // tr("Oturumum açık kalsın", "Keep me logged in") seçiliyse bir sonraki açılışta sormaz
            if rememberMe {
                UserDefaults.standard.set(name, forKey: "rememberedUser")
            } else {
                UserDefaults.standard.removeObject(forKey: "rememberedUser")
            }
            loggedInUser = name
        } else {
            errorMessage = tr("Kullanıcı adı veya şifre hatalı", "Wrong name or password")
            password = ""
        }
    }
}

#Preview {
    LoginView(loggedInUser: .constant(nil))
}
