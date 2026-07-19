import SwiftUI

// Uygulama açılış/karşılama ekranı:
// üstte tanıtıcı görsel + slogan, altta Giriş Yap / Kayıt Ol
struct WelcomeView: View {
    @Binding var loggedInUser: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.36, green: 0.24, blue: 0.90),
                         Color(red: 0.10, green: 0.55, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Tanıtıcı görsel: logo + özellik ikonları
                VStack(spacing: 24) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 150, height: 150)
                        Text("₺")
                            .font(.system(size: 84, weight: .heavy))
                            .foregroundStyle(.white)
                    }

                    HStack(spacing: 22) {
                        featureIcon("chart.pie.fill")
                        featureIcon("banknote.fill")
                        featureIcon("chart.line.uptrend.xyaxis")
                        featureIcon("person.2.fill")
                    }

                    VStack(spacing: 8) {
                        Text("Kasam")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.white)
                        Text("Gelirin, giderin, birikimin — hepsi kasanda")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }

                Spacer()

                // Alt kısım: giriş / kayıt
                VStack(spacing: 12) {
                    NavigationLink {
                        LoginView(loggedInUser: $loggedInUser)
                    } label: {
                        Text("Giriş Yap")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(Color(red: 0.36, green: 0.24, blue: 0.90))

                    NavigationLink {
                        RegisterView(loggedInUser: $loggedInUser)
                    } label: {
                        Text("Kayıt Ol")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 24)
            }
        }
    }

    private func featureIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: 46, height: 46)
            .background(Circle().fill(.white.opacity(0.15)))
    }
}

// Kayıt ekranı: isim + şifre yeterli
struct RegisterView: View {
    @Binding var loggedInUser: String?

    @State private var name = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.36, green: 0.24, blue: 0.90),
                         Color(red: 0.10, green: 0.55, blue: 0.95)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Text("₺")
                    .font(.system(size: 64, weight: .heavy))
                    .foregroundStyle(.white)
                Text("Hesap Oluştur")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("İsim ve şifre belirlemen yeterli")
                    .foregroundStyle(.white.opacity(0.8))

                VStack(spacing: 14) {
                    TextField("", text: $name,
                              prompt: Text("İsim").foregroundColor(.black.opacity(0.55)))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.black)

                    Divider()

                    SecureField("", text: $password,
                                prompt: Text("Şifre").foregroundColor(.black.opacity(0.55)))
                        .foregroundStyle(.black)
                }
                .padding(14)
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
                    register()
                } label: {
                    Text("Kayıt Ol")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundStyle(Color(red: 0.36, green: 0.24, blue: 0.90))
                .disabled(name.isEmpty || password.isEmpty)

                Spacer()
                Spacer()
            }
            .padding(28)
        }
    }

    private func register() {
        if let error = registerUser(name: name, password: password) {
            errorMessage = error
            return
        }
        // Kayıt başarılı: doğrudan giriş yap (tertemiz kişisel depo açılır)
        loggedInUser = name.trimmingCharacters(in: .whitespaces).lowercased()
    }
}

#Preview {
    NavigationStack {
        WelcomeView(loggedInUser: .constant(nil))
    }
}
