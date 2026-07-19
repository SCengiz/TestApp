import SwiftUI

// Uygulama logosu (ikonla aynı tasarım): degrade kare üzerinde
// yükselen çubuklar + trend oku — her boyutta çizilebilir
struct AppMark: View {
    var size: CGFloat = 120

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.31, green: 0.27, blue: 0.90),
                                 Color(red: 0.02, green: 0.71, blue: 0.83)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.25), radius: size * 0.09, y: size * 0.05)

            // Yükselen çubuklar
            HStack(alignment: .bottom, spacing: size * 0.06) {
                bar(height: 0.22, opacity: 0.75)
                bar(height: 0.34, opacity: 0.85)
                bar(height: 0.46, opacity: 1.0)
            }
            .offset(y: size * 0.14)

            // Trend oku
            TrendArrow()
                .stroke(.white, style: StrokeStyle(lineWidth: size * 0.055,
                                                   lineCap: .round, lineJoin: .round))
                .frame(width: size * 0.62, height: size * 0.3)
                .offset(y: -size * 0.17)

            ArrowHead()
                .fill(.white)
                .frame(width: size * 0.17, height: size * 0.17)
                .offset(x: size * 0.31, y: -size * 0.31)
        }
        .frame(width: size, height: size)
    }

    private func bar(height: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: size * 0.045, style: .continuous)
            .fill(.white.opacity(opacity))
            .frame(width: size * 0.13, height: size * height)
    }
}

// Yükselen kırık çizgi
struct TrendArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.width * 0.4, y: rect.height * 0.35))
        p.addLine(to: CGPoint(x: rect.width * 0.6, y: rect.height * 0.6))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return p
    }
}

// Ok başı (sağ yukarı bakan üçgen)
struct ArrowHead: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.35))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.65, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// Uygulama açılış/karşılama ekranı:
// üstte profesyonel logo + slogan, altta Giriş Yap / Kayıt Ol
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

            // Arka plandaki yumuşak ışık daireleri (derinlik)
            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 420, height: 420)
                .offset(x: -150, y: -320)
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 300, height: 300)
                .offset(x: 170, y: 100)

            VStack(spacing: 0) {
                Spacer()

                // Logo + isim + slogan
                VStack(spacing: 28) {
                    AppMark(size: 148)

                    VStack(spacing: 10) {
                        Text("İyi Bütçe")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(.white)
                        Text(tr("Gelirinizi bilin, giderinizi yönetin.", "Know your income, manage your spending."))
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                    }

                    // Özellik rozetleri
                    HStack(spacing: 10) {
                        featureChip("chart.pie.fill", tr("Gider", "Spend"))
                        featureChip("banknote.fill", tr("Gelir", "Income"))
                        featureChip("chart.line.uptrend.xyaxis", tr("Birikim", "Savings"))
                        featureChip("person.2.fill", tr("Borç", "Debt"))
                    }
                }

                Spacer()

                // Alt kısım: giriş / kayıt
                VStack(spacing: 12) {
                    NavigationLink {
                        LoginView(loggedInUser: $loggedInUser)
                    } label: {
                        Text(tr("Giriş Yap", "Log In"))
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
                        Text(tr("Kayıt Ol", "Sign Up"))
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

    private func featureChip(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.body)
            Text(title)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(width: 74, height: 64)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.14))
        )
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

                AppMark(size: 88)
                Text(tr("Hesap Oluştur", "Create Account"))
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text(tr("İsim ve şifre belirlemen yeterli", "Just pick a name and password"))
                    .foregroundStyle(.white.opacity(0.8))

                VStack(spacing: 14) {
                    TextField("", text: $name,
                              prompt: Text(tr("İsim", "Name")).foregroundColor(.black.opacity(0.55)))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .foregroundStyle(.black)

                    Divider()

                    SecureField("", text: $password,
                                prompt: Text(tr("Şifre", "Password")).foregroundColor(.black.opacity(0.55)))
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
                    Text(tr("Kayıt Ol", "Sign Up"))
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
        let user = name.trimmingCharacters(in: .whitespaces).lowercased()
        UserDefaults.standard.set(user, forKey: "rememberedUser")
        loggedInUser = user
    }
}

#Preview {
    NavigationStack {
        WelcomeView(loggedInUser: .constant(nil))
    }
}
