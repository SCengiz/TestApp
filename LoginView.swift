import SwiftUI

// Basit yerel giriş: kullanıcı adı + şifre
// Kullanıcılar burada tanımlı (kişisel uygulama olduğu için yeterli)
let appUsers: [String: String] = [
    "test": "1",
    "soray": "1",
]

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
                Text("₺")
                    .font(.system(size: 80, weight: .heavy))
                    .foregroundStyle(.white)
                Text("Bütçem")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("Devam etmek için giriş yap")
                    .foregroundStyle(.white.opacity(0.8))

                // Giriş formu
                VStack(spacing: 14) {
                    TextField("Kullanıcı adı", text: $username)
                        .textContentType(.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Şifre", text: $password)
                        .textContentType(.password)
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
        if appUsers[name] == password {
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
