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

// MARK: - Anahtar yoksa gösterilen kurulum ekranı

struct AISetupView: View {
    @Binding var hasKey: Bool
    @State private var key = ""
    @FocusState private var focused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                    Text(tr("Finans asistanını aç", "Turn on the finance assistant"))
                        .font(.title2.bold())
                    Text(tr("Bütçenle ilgili soruları cevaplaması için ücretsiz bir Google Gemini anahtarı gerekiyor. Kredi kartı istemez.",
                            "A free Google Gemini key is needed. No credit card required."))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    step(1, tr("aistudio.google.com adresine gir ve Google hesabınla oturum aç.",
                               "Go to aistudio.google.com and sign in with your Google account."))
                    step(2, tr("\"Get API key\" düğmesine bas ve anahtarı kopyala.",
                               "Tap \"Get API key\" and copy the key."))
                    step(3, tr("Anahtarı aşağıya yapıştır ve kaydet.",
                               "Paste the key below and save."))
                }

                SecureField(tr("API anahtarı (AIza...)", "API key (AIza...)"), text: $key)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .focused($focused)

                Button {
                    AIKeyStore.save(key)
                    key = ""
                    focused = false
                    hasKey = AIKeyStore.hasKey
                } label: {
                    Text(tr("Kaydet ve Başla", "Save and Start"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)

                Text(tr("Anahtar telefonunun şifreli kasasında (Keychain) saklanır. Asistana harcama kayıtların tek tek değil, kategori toplamları gibi özet bilgiler gönderilir. Ücretsiz katmanda Google, gönderilen verileri hizmetini geliştirmek için kullanabilir.",
                        "The key is stored in your phone's Keychain. Only summary figures are sent, not individual records. On the free tier Google may use submitted data to improve its services."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .font(.callout)
            Spacer(minLength: 0)
        }
    }
}
