import SwiftUI
import SwiftData

// 3x3 ızgarada hazır sorular. Kullanıcı serbest soru yazarak başlayamaz;
// önce bunlardan birini seçer, sonra karşılıklı sohbet açılır.
struct AIQuestion: Identifiable {
    let id: Int
    let icon: String
    let colors: [Color]
    let shortTR: String
    let shortEN: String
    let fullTR: String
    let fullEN: String

    var short: String { tr(shortTR, shortEN) }
    var full: String { tr(fullTR, fullEN) }
}

let aiQuestions: [AIQuestion] = [
    .init(id: 1, icon: "chart.pie.fill", colors: [.pink, .red],
          shortTR: "Bu Ay Nereye Gitti?", shortEN: "Where Did It Go?",
          fullTR: "Bu ay paramı nereye harcadım? En büyük kalemler neler?",
          fullEN: "Where did my money go this month? What are the biggest items?"),
    .init(id: 2, icon: "arrow.up.arrow.down", colors: [.orange, .yellow],
          shortTR: "Geçen Aya Göre", shortEN: "vs. Last Month",
          fullTR: "Harcamalarım geçen aya göre nasıl değişti? Hangi kategoride arttı, hangisinde azaldı?",
          fullEN: "How did my spending change versus last month? Which categories went up or down?"),
    .init(id: 3, icon: "banknote.fill", colors: [.green, .mint],
          shortTR: "Maaşımdan Kalan", shortEN: "What's Left",
          fullTR: "Bu ay gelirimin ne kadarı ödemelere ve harcamalara gitti, elimde ne kaldı?",
          fullEN: "How much of my income went to payments and spending this month, and what's left?"),
    .init(id: 4, icon: "scissors", colors: [.purple, .indigo],
          shortTR: "Nerede Kısabilirim?", shortEN: "Where to Cut",
          fullTR: "Hangi kategorilerde tasarruf edebilirim? Bana somut öneriler ver.",
          fullEN: "Which categories could I cut back on? Give me concrete suggestions."),
    .init(id: 5, icon: "building.columns.fill", colors: [.blue, .cyan],
          shortTR: "Ödeme Yüküm", shortEN: "Payment Load",
          fullTR: "Sabit ödemelerim gelirimin yüzde kaçını alıyor? Bu oran sağlıklı mı?",
          fullEN: "What share of my income goes to fixed payments? Is that ratio healthy?"),
    .init(id: 6, icon: "calendar", colors: [.teal, .blue],
          shortTR: "Taksitlerim", shortEN: "My Installments",
          fullTR: "Taksitlerim ne zaman bitiyor? Bittiklerinde ayda ne kadar rahatlayacağım?",
          fullEN: "When do my installments end? How much monthly relief will that bring?"),
    .init(id: 7, icon: "chart.line.uptrend.xyaxis", colors: [.purple, .pink],
          shortTR: "Birikimim", shortEN: "My Savings",
          fullTR: "Birikimim nasıl gidiyor? Getirisi ne durumda, aylık ne kadar biriktiriyorum?",
          fullEN: "How are my savings doing? What's the return, and how much am I saving monthly?"),
    .init(id: 8, icon: "person.2.fill", colors: [.red, .orange],
          shortTR: "Borç Durumum", shortEN: "My Debts",
          fullTR: "Borçlarım ne durumda? Hangisini önce kapatmam mantıklı olur?",
          fullEN: "How are my debts? Which one makes sense to pay off first?"),
    .init(id: 9, icon: "sparkles", colors: [.indigo, .blue],
          shortTR: "Yıl Sonu Tahmini", shortEN: "Year-End Outlook",
          fullTR: "Bu tempoyla gidersem yıl sonunda ne kadar biriktirmiş olurum?",
          fullEN: "At this pace, how much will I have saved by year end?"),
]

// MARK: - Ana sekme

struct AskAIView: View {
    @Binding var loggedInUser: String?
    @Environment(\.modelContext) private var modelContext

    @State private var messages: [AIMessage] = []
    @State private var followUp = ""
    @State private var isThinking = false
    @State private var errorMessage: String?
    @State private var hasKey = AIKeyStore.hasKey
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            Group {
                if !hasKey {
                    AISetupView(hasKey: $hasKey)
                } else if messages.isEmpty {
                    questionGrid
                } else {
                    chatView
                }
            }
            .navigationTitle(tr("Finans Asistanı", "Finance Assistant"))
            .navigationBarTitleDisplayMode(hasKey ? .large : .inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileButton(loggedInUser: $loggedInUser)
                }
                if !messages.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            messages = []
                            errorMessage = nil
                            followUp = ""
                        } label: {
                            Label(tr("Yeni Soru", "New Question"),
                                  systemImage: "square.grid.2x2")
                        }
                    }
                }
            }
            .onAppear { hasKey = AIKeyStore.hasKey }
        }
    }

    // MARK: 3x3 soru ızgarası

    private var questionGrid: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(tr("Bütçenle ilgili bir soru seç",
                        "Pick a question about your budget"))
                    .font(.headline)
                Text(tr("Verilerin telefonunda hesaplanır; asistana yalnızca özet gider.",
                        "Your numbers are computed on your phone; only a summary is sent."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                          spacing: 12) {
                    ForEach(aiQuestions) { question in
                        Button {
                            ask(question.full)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: question.icon)
                                    .font(.title2)
                                    .foregroundStyle(.white)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        Circle().fill(
                                            LinearGradient(colors: question.colors,
                                                           startPoint: .topLeading,
                                                           endPoint: .bottomTrailing)
                                        )
                                    )
                                Text(question.short)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 118)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color(.secondarySystemGroupedBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: Sohbet

    private var chatView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(messages) { message in
                            bubble(for: message)
                                .id(message.id)
                        }
                        if isThinking {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text(tr("Düşünüyor...", "Thinking..."))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("thinking")
                        }
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { scrollToEnd(proxy) }
                .onChange(of: isThinking) { scrollToEnd(proxy) }
            }

            Divider()

            HStack(spacing: 10) {
                TextField(tr("Bütçenle ilgili bir şey sor...", "Ask about your budget..."),
                          text: $followUp, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .onSubmit(sendFollowUp)

                Button(action: sendFollowUp) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(followUp.trimmingCharacters(in: .whitespaces).isEmpty || isThinking)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemGroupedBackground))
        }
    }

    private func bubble(for message: AIMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(message.role == .user
                              ? AnyShapeStyle(Color.accentColor)
                              : AnyShapeStyle(Color(.secondarySystemGroupedBackground)))
                )
                .foregroundStyle(message.role == .user ? .white : .primary)
                .textSelection(.enabled)
            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation {
            if isThinking {
                proxy.scrollTo("thinking", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: Gönderme

    private func sendFollowUp() {
        let text = followUp.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, !isThinking else { return }
        followUp = ""
        inputFocused = false
        ask(text)
    }

    private func ask(_ text: String) {
        errorMessage = nil
        messages.append(AIMessage(role: .user, text: text))
        isThinking = true

        // Özet her soruda yeniden hesaplanır: veriler değişmiş olabilir
        let summary = FinancialSummary.build(modelContext)
        let history = messages

        Task {
            do {
                let answer = try await AIService.send(messages: history, summary: summary)
                messages.append(AIMessage(role: .assistant, text: answer))
            } catch {
                errorMessage = error.localizedDescription
            }
            isThinking = false
        }
    }
}

// Asistan ekranlarının ortak renk kimliği
let aiBrandColors: [Color] = [
    Color(red: 0.42, green: 0.36, blue: 0.95),
    Color(red: 0.62, green: 0.34, blue: 0.92),
    Color(red: 0.30, green: 0.55, blue: 0.98),
]

// MARK: - Anahtar yoksa gösterilen kurulum ekranı
//
// Sade tutuldu: sadece anahtar alanı. Adımlar ve gizlilik notu, yanındaki
// "?" düğmesine dokununca açılır.
struct AISetupView: View {
    @Binding var hasKey: Bool
    @State private var key = ""
    @State private var showingHelp = false
    @State private var appeared = false
    @FocusState private var focused: Bool

    private var brand: [Color] { aiBrandColors }

    private var canSave: Bool {
        !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                emblem
                    .padding(.bottom, 26)

                titleBlock
                    .padding(.bottom, 30)

                keyField
                    .padding(.horizontal, 24)

                saveButton
                    .padding(.horizontal, 24)
                    .padding(.top, 14)

                Spacer(minLength: 0)
                Spacer(minLength: 0)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
        }
        .sheet(isPresented: $showingHelp) {
            AISetupHelpView()
        }
    }

    // Yumuşak renk bulutlarıyla derinlik
    private var background: some View {
        ZStack {
            Color(.systemGroupedBackground)
            Circle()
                .fill(brand[0].opacity(0.28))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: -110, y: -190)
            Circle()
                .fill(brand[2].opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 100)
                .offset(x: 130, y: 150)
        }
        .ignoresSafeArea()
    }

    private var emblem: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: brand,
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 92, height: 92)
                .shadow(color: brand[1].opacity(0.45), radius: 22, y: 10)
            Circle()
                .fill(
                    RadialGradient(colors: [.white.opacity(0.45), .clear],
                                   center: UnitPoint(x: 0.3, y: 0.24),
                                   startRadius: 0, endRadius: 58)
                )
                .frame(width: 92, height: 92)
            Image(systemName: "sparkles")
                .font(.system(size: 38, weight: .medium))
                .foregroundStyle(.white)
        }
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
    }

    private var titleBlock: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Text(tr("Sormak için anahtarı gir", "Enter your key to ask"))
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Button {
                    showingHelp = true
                } label: {
                    Image(systemName: "questionmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(brand[1])
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(brand[1].opacity(0.14)))
                }
                .buttonStyle(.plain)
            }

            Text(tr("Ücretsiz Google Gemini anahtarı · kredi kartı istemez",
                    "Free Google Gemini key · no credit card"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
    }

    // Kart görünümlü giriş alanı + panodan yapıştırma kısayolu
    private var keyField: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 15))
                .foregroundStyle(focused ? brand[1] : .secondary)
                .frame(width: 20)

            SecureField("", text: $key,
                        prompt: Text(verbatim: "AIza…")
                            .foregroundColor(.secondary.opacity(0.7)))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused)
                .font(.system(.body, design: .monospaced))

            if canSave {
                Button {
                    key = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    if let pasted = UIPasteboard.general.string {
                        key = pasted.trimmingCharacters(in: .whitespacesAndNewlines)
                        focused = false
                    }
                } label: {
                    Text(tr("Yapıştır", "Paste"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(brand[1])
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(brand[1].opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(focused ? brand[1].opacity(0.55) : Color.primary.opacity(0.06),
                              lineWidth: focused ? 1.6 : 1)
        )
        .animation(.easeOut(duration: 0.18), value: focused)
    }

    private var saveButton: some View {
        Button {
            AIKeyStore.save(key)
            key = ""
            focused = false
            hasKey = AIKeyStore.hasKey
        } label: {
            HStack(spacing: 8) {
                Text(tr("Kaydet ve Başla", "Save and Start"))
                    .font(.system(.body, design: .rounded, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(colors: brand,
                                       startPoint: .leading, endPoint: .trailing)
                    )
            )
            .shadow(color: canSave ? brand[1].opacity(0.4) : .clear, radius: 14, y: 7)
            .opacity(canSave ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!canSave)
        .animation(.easeOut(duration: 0.2), value: canSave)
    }
}


// "?" düğmesiyle açılan yardım ekranı
struct AISetupHelpView: View {
    @Environment(\.dismiss) private var dismiss
    private var brand: [Color] { aiBrandColors }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    stepsCard
                    privacyCard
                    scopeCard
                }
                .padding(20)
            }
            .background(background)
            .navigationTitle(tr("Nasıl Çalışır?", "How It Works"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(Color.primary.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var background: some View {
        ZStack {
            Color(.systemGroupedBackground)
            Circle()
                .fill(brand[0].opacity(0.20))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: -120, y: -240)
        }
        .ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LinearGradient(colors: brand,
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 64, height: 64)
                    .shadow(color: brand[1].opacity(0.4), radius: 16, y: 8)
                Image(systemName: "key.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.white)
            }
            Text(tr("Ücretsiz anahtarını 2 dakikada al",
                    "Get your free key in 2 minutes"))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            Text(tr("Google hesabın yeterli. Kredi kartı istemez, günlük sınırı kişisel kullanım için fazlasıyla yeter.",
                    "Your Google account is enough. No credit card; the daily limit is plenty for personal use."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 6)
    }

    // Numaralı adımlar, aralarında bağlantı çizgisiyle
    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            stepRow(1, tr("aistudio.google.com adresine gir", "Go to aistudio.google.com"),
                    tr("Google hesabınla oturum aç.", "Sign in with your Google account."),
                    isLast: false)
            stepRow(2, tr("\"Get API key\" düğmesine bas", "Tap \"Get API key\""),
                    tr("Açılan anahtarı kopyala.", "Copy the key it shows."),
                    isLast: false)
            stepRow(3, tr("Uygulamaya yapıştır", "Paste it into the app"),
                    tr("\"Yapıştır\" düğmesi panondaki anahtarı tek dokunuşla koyar.",
                       "The \"Paste\" button fills it from your clipboard."),
                    isLast: true)

            Link(destination: URL(string: "https://aistudio.google.com/apikey")!) {
                HStack(spacing: 8) {
                    Text(tr("AI Studio'yu Aç", "Open AI Studio"))
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: brand,
                                             startPoint: .leading, endPoint: .trailing))
                )
            }
            .padding(.top, 6)
        }
        .padding(18)
        .background(cardBackground)
    }

    private func stepRow(_ number: Int, _ title: String, _ detail: String,
                         isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Text("\(number)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(LinearGradient(colors: brand,
                                                     startPoint: .top, endPoint: .bottom))
                    )
                if !isLast {
                    Rectangle()
                        .fill(brand[1].opacity(0.22))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(minHeight: isLast ? 28 : 62)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 3)
            Spacer(minLength: 0)
        }
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle(tr("Verilerin ne oluyor?", "What happens to your data?"),
                      icon: "lock.shield.fill")
            infoRow("iphone", tr("Hesaplar telefonunda yapılır",
                                 "Math happens on your phone"),
                    tr("Toplamlar ve oranlar uygulamada hesaplanır; asistan sadece hazır sayıları yorumlar.",
                       "Totals are computed in the app; the assistant only interprets them."))
            infoRow("eye.slash.fill", tr("Kayıtların gönderilmez",
                                         "Your records are not sent"),
                    tr("Tek tek harcamalar, mağaza adları ve tarihler paylaşılmaz — yalnızca kategori toplamları gider.",
                       "Individual purchases, merchant names and dates are never shared."))
            infoRow("key.fill", tr("Anahtar Keychain'de", "Key stays in Keychain"),
                    tr("Telefonunun şifreli kasasında saklanır, koda gömülmez.",
                       "Stored in your phone's encrypted store, never in the code."))
            infoRow("exclamationmark.circle.fill",
                    tr("Ücretsiz katman notu", "Free tier note"),
                    tr("Google, ücretsiz katmanda gönderilen verileri hizmetini geliştirmek için kullanabilir.",
                       "On the free tier Google may use submitted data to improve its services."))
        }
        .padding(18)
        .background(cardBackground)
    }

    private var scopeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            cardTitle(tr("Neler sorabilirim?", "What can I ask?"), icon: "bubble.left.and.text.bubble.right.fill")
            Text(tr("Asistan yalnızca senin bütçenle ilgili konuşur: harcamalar, gelir, sabit ödemeler, birikim, borç ve tasarruf planı.",
                    "The assistant only discusses your budget: spending, income, payments, savings, debt and planning."))
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.orange)
                Text(tr("Konu dışı sorulara ve yatırım tavsiyesine yanıt vermez.",
                        "It declines off-topic questions and investment advice."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.orange.opacity(0.10))
            )
        }
        .padding(18)
        .background(cardBackground)
    }

    private func cardTitle(_ text: String, icon: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(brand[1])
            Text(text)
                .font(.system(.headline, design: .rounded))
            Spacer(minLength: 0)
        }
    }

    private func infoRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(brand[1])
                .frame(width: 30, height: 30)
                .background(Circle().fill(brand[1].opacity(0.12)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
            .shadow(color: .black.opacity(0.05), radius: 12, y: 4)
    }
}
