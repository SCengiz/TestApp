import Foundation
import SwiftUI
import SwiftData
import Security

// MARK: - API anahtarı saklama (Keychain)
//
// Anahtar koda gömülmez, GitHub'a gitmez. Telefonun şifreli kasasında durur.
enum AIKeyStore {
    private static let service = "com.soraycengiz.TestApp.ai"
    private static let account = "geminiAPIKey"

    static func save(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        delete()
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty
        else { return nil }
        return key
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    static var hasKey: Bool { load() != nil }
}

// MARK: - Finansal özet
//
// UYGULAMA HESAPLAR, YAPAY ZEKA YORUMLAR.
// Dil modelleri aritmetikte güvenilmez; bu yüzden tüm toplamlar, oranlar ve
// karşılaştırmalar burada Swift ile hesaplanır. Modele sadece hazır sayılar
// gider — tek tek harcama kayıtları, mağaza adları ve tarihler gönderilmez.
@MainActor
enum FinancialSummary {

    static func build(_ context: ModelContext) -> String {
        let calendar = Calendar.current
        let now = Date.now
        let thisMonth = calendar.dateInterval(of: .month, for: now)!.start

        let expenses = (try? context.fetch(FetchDescriptor<Expense>())) ?? []
        let payments = (try? context.fetch(FetchDescriptor<FixedPayment>())) ?? []
        let monthAmounts = (try? context.fetch(FetchDescriptor<PaymentMonthAmount>())) ?? []
        let incomes = (try? context.fetch(FetchDescriptor<IncomeSource>())) ?? []
        let accounts = (try? context.fetch(FetchDescriptor<SavingsAccountModel>())) ?? []
        let debts = (try? context.fetch(FetchDescriptor<Debt>())) ?? []
        let savingsSnaps = (try? context.fetch(FetchDescriptor<SavingsSnapshot>())) ?? []

        var lines: [String] = []
        let monthName = thisMonth.formatted(.dateTime.month(.wide).year().locale(appLocale))
        lines.append("İÇİNDE BULUNULAN AY: \(monthName)")

        // --- Gelir ---
        let totalIncome = incomes.reduce(0) { $0 + $1.amount }
        if totalIncome > 0 {
            let detail = incomes.map { "\($0.name) \(tl($0.amount))" }.joined(separator: ", ")
            lines.append("\nAYLIK GELİR: \(tl(totalIncome)) (\(detail))")
        } else {
            lines.append("\nAYLIK GELİR: girilmemiş")
        }

        lines.append("""

        GİDER TANIMI (BU KURALA MUTLAKA UY):
          Bu kullanıcının gideri YALNIZCA "BU AY SABİT ÖDEMELER" listesidir.
          Aşağıdaki "KART HARCAMA DÖKÜMÜ" bir gider kalemi DEĞİLDİR; kredi
          kartıyla yapılan alışverişlerin kategori kategori tutulduğu bir
          nottur ve parasal karşılığı zaten sabit ödemelerdeki kredi kartı
          satırının içindedir.
          Bu iki tutarı ASLA TOPLAMA. "Toplam giderim ne kadar", "ne kadar
          harcadım", "maaşımdan ne kaldı" gibi sorularda yalnızca sabit
          ödemeler toplamını kullan. Kart dökümünü sadece "param hangi
          kategoriye gitti", "nerede kısabilirim" gibi dağılım sorularında
          kullan.
        """)

        // --- Bu ayın kart harcamaları, kategori kategori ---
        let monthExpenses = expenses.filter {
            calendar.isDate($0.date, equalTo: thisMonth, toGranularity: .month)
        }
        let monthTotal = monthExpenses.reduce(0) { $0 + $1.amount }
        lines.append("\nBU AY KART HARCAMA DÖKÜMÜ (gider değil, kategori notu): \(tl(monthTotal))")
        let byCategory = Dictionary(grouping: monthExpenses, by: \.category)
            .map { (name: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
        for item in byCategory {
            let share = monthTotal > 0 ? Int((item.total / monthTotal * 100).rounded()) : 0
            lines.append("  - \(item.name): \(tl(item.total)) (%\(share))")
        }

        // --- Son 6 ayın harcama seyri + kategori kıyası ---
        var trend: [String] = []
        for offset in stride(from: -5, through: 0, by: 1) {
            guard let m = calendar.date(byAdding: .month, value: offset, to: thisMonth) else { continue }
            let total = expenses
                .filter { calendar.isDate($0.date, equalTo: m, toGranularity: .month) }
                .reduce(0) { $0 + $1.amount }
            let label = m.formatted(.dateTime.month(.abbreviated).locale(appLocale))
            trend.append("\(label) \(tl(total))")
        }
        lines.append("\nSON 6 AY KART HARCAMA DÖKÜMÜ (gider değil): " + trend.joined(separator: " | "))

        // Geçen ayla kategori bazlı fark (yorum için en değerli girdi)
        if let lastMonth = calendar.date(byAdding: .month, value: -1, to: thisMonth) {
            let lastExpenses = expenses.filter {
                calendar.isDate($0.date, equalTo: lastMonth, toGranularity: .month)
            }
            let lastByCategory = Dictionary(grouping: lastExpenses, by: \.category)
                .mapValues { $0.reduce(0) { $0 + $1.amount } }
            var diffs: [String] = []
            for item in byCategory {
                let previous = lastByCategory[item.name] ?? 0
                guard previous > 0 else {
                    diffs.append("\(item.name): geçen ay yok, bu ay \(tl(item.total))")
                    continue
                }
                let change = (item.total - previous) / previous * 100
                let sign = change >= 0 ? "+" : ""
                diffs.append("\(item.name): \(tl(previous)) → \(tl(item.total)) (\(sign)%\(Int(change.rounded())))")
            }
            if !diffs.isEmpty {
                lines.append("\nGEÇEN AYA GÖRE KATEGORİ DEĞİŞİMİ:")
                lines.append(contentsOf: diffs.map { "  - " + $0 })
            }
        }

        // --- Sabit ödemeler ---
        let activePayments = payments.filter { $0.isActive(inMonth: thisMonth) }
        let paymentTotal = activePayments.reduce(0) {
            $0 + $1.amount(inMonth: thisMonth, monthlyAmounts: monthAmounts)
        }
        lines.append("\nBU AY SABİT ÖDEMELER: \(tl(paymentTotal))")
        for payment in activePayments.sorted(by: { $0.dueDay < $1.dueDay }) {
            let amount = payment.amount(inMonth: thisMonth, monthlyAmounts: monthAmounts)
            var line = "  - \(payment.name) (\(payment.category)): \(tl(amount)), ayın \(payment.dueDay)'i"
            if let total = payment.totalInstallments,
               let number = payment.installmentNumber(inMonth: thisMonth) {
                line += ", taksit \(number)/\(total), \(total - number) ay kaldı"
            }
            if amount == 0 {
                line += " (tutar henüz girilmemiş)"
            }
            lines.append(line)
        }

        // --- Nakit akışı (hesabı burada yapıyoruz ki model uydurmasın) ---
        if totalIncome > 0 {
            // Tek gider kalemi sabit ödemelerdir; kart dökümü buraya EKLENMEZ,
            // çünkü kredi kartı ödemesi zaten sabit ödemelerin içindedir.
            let remaining = totalIncome - paymentTotal
            let paymentShare = Int((paymentTotal / totalIncome * 100).rounded())
            lines.append("""

            BU AYIN NAKİT AKIŞI (hesap burada yapıldı, aynen kullan):
              Gelir \(tl(totalIncome))
              - Sabit ödemeler \(tl(paymentTotal)) (gelirin %\(paymentShare)'i)
              = Kalan \(tl(remaining))
              Not: kart harcama dökümü bu hesaba dahil DEĞİLDİR ve edilmemelidir.
            """)
        }

        // --- Birikimler ---
        let savingsTotal = accounts.reduce(0) { $0 + $1.totalValue }
        if savingsTotal > 0 {
            let profit = accounts.reduce(0) { $0 + $1.totalProfit }
            lines.append("\nTOPLAM BİRİKİM: \(tl(savingsTotal)) (kar/zarar \(tl(profit)))")
            for account in accounts where account.totalValue > 0 {
                var line = "  - \(account.name): \(tl(account.totalValue))"
                if account.netInvestedNonZero, let pct = account.totalProfitPercent {
                    line += " (kar/zarar \(tl(account.totalProfit)), %\(String(format: "%.1f", pct)))"
                }
                lines.append(line)
            }
            // Birikim seyri (son 6 ay)
            var savingsTrend: [String] = []
            for offset in stride(from: -5, through: -1, by: 1) {
                guard let m = calendar.date(byAdding: .month, value: offset, to: thisMonth),
                      let snap = savingsSnaps.first(where: {
                          calendar.isDate($0.monthStart, equalTo: m, toGranularity: .month)
                      })
                else { continue }
                let label = m.formatted(.dateTime.month(.abbreviated).locale(appLocale))
                savingsTrend.append("\(label) \(tl(snap.total))")
            }
            if !savingsTrend.isEmpty {
                savingsTrend.append("bu ay \(tl(savingsTotal))")
                lines.append("BİRİKİM SEYRİ: " + savingsTrend.joined(separator: " | "))
            }
        } else {
            lines.append("\nTOPLAM BİRİKİM: yok")
        }

        // --- Borçlar ---
        if debts.isEmpty {
            lines.append("\nBORÇ: yok")
        } else {
            let debtTotal = debts.reduce(0) { $0 + $1.valueTL }
            let increase = debts.reduce(0) { $0 + $1.increaseTL }
            lines.append("\nTOPLAM BORÇ: \(tl(debtTotal)) (kur farkından artış \(tl(increase)))")
            for debt in debts {
                let kind = DebtKind(rawValue: debt.kind) ?? .tl
                lines.append("  - \(debt.name): \(debt.quantity.formatted()) \(kind.unitLabel) = \(tl(debt.valueTL))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func tl(_ value: Double) -> String {
        value.formatted(.currency(code: "TRY").precision(.fractionLength(0)))
    }
}

// MARK: - Yapay zeka istemcisi (Google Gemini — ücretsiz katman)

enum AIError: LocalizedError {
    case missingKey
    case badResponse(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return tr("API anahtarı girilmemiş. Ayarlar > Yapay Zeka'dan ekleyebilirsin.",
                      "No API key. Add one in Settings > AI.")
        case .badResponse(let detail):
            return detail
        case .network(let detail):
            return tr("Bağlantı kurulamadı: \(detail)", "Connection failed: \(detail)")
        }
    }
}

struct AIMessage: Identifiable, Equatable {
    enum Role { case user, assistant }
    let id = UUID()
    let role: Role
    var text: String
}

enum AIService {
    // Ayarlar'dan değiştirilebilir; Google model adlarını zaman zaman değiştiriyor
    static var modelName: String {
        UserDefaults.standard.string(forKey: "aiModelName") ?? "gemini-3-flash-preview"
    }

    // Gemini 3 ve sonrası yeni Interactions API'sini kullanıyor;
    // eski modeller hâlâ generateContent (legacy) üzerinden çalışıyor.
    static var usesInteractionsAPI: Bool {
        let name = modelName.lowercased()
        return name.contains("gemini-3") || name.contains("gemini-4")
    }

    // Modele verilen kurallar: kapsamı bütçeyle sınırlar, uydurmayı ve
    // yatırım tavsiyesini engeller
    static func systemPrompt(summary: String) -> String {
        """
        Sen "İyi Bütçe" adlı kişisel finans uygulamasının asistanısın. Kullanıcının \
        kendi finansal verilerinin özeti aşağıda veriliyor.

        KURALLAR:
        1. SADECE kullanıcının bütçesi, harcamaları, gelirleri, sabit ödemeleri, \
        birikimleri, borçları ve tasarruf planlaması hakkında konuş.
        2. Konu dışı sorulara (genel kültür, haber, kod, sohbet, sağlık vb.) kibarca \
        "Ben sadece bütçenle ilgili sorulara yardımcı olabiliyorum." diye cevap ver.
        3. Sayı UYDURMA. Sadece aşağıdaki özette verilen rakamları kullan. Yeni toplam \
        hesaplaman gerekirse dikkatli ol; özette olmayan bir bilgi sorulursa \
        "Bu bilgi uygulamada kayıtlı değil." de.
        4. YATIRIM TAVSİYESİ VERME. Hangi hisse/fon/döviz alınmalı satılmalı deme. \
        Bütçe, tasarruf ve borç yönetimi önerisi verebilirsin.
        5. Türkçe, kısa ve net yaz. Rakamları TL olarak yaz. Gereksiz uzatma; \
        en fazla birkaç kısa paragraf veya madde.
        6. Kullanıcıyla samimi ve destekleyici bir tonda konuş, yargılayıcı olma.
        7. GİDER = SADECE SABİT ÖDEMELER. Özetteki "kart harcama dökümü" bir gider \
        değil, kredi kartı harcamalarının kategori notudur; karşılığı zaten sabit \
        ödemelerdeki kredi kartı satırıdır. Bu ikisini asla toplama, "toplam gider" \
        diye ikisinin toplamını verme. Nakit akışı hesabı özette hazır verilmiştir, \
        aynen kullan.

        KULLANICININ VERİLERİ:
        \(summary)
        """
    }

    static func send(messages: [AIMessage], summary: String) async throws -> String {
        guard let key = AIKeyStore.load() else { throw AIError.missingKey }
        let request = usesInteractionsAPI
            ? try interactionsRequest(messages: messages, summary: summary, key: key)
            : try generateContentRequest(messages: messages, summary: summary, key: key)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIError.network(error.localizedDescription)
        }

        let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Hata durumunda sunucunun mesajını olduğu gibi göster; böylece
        // yanlış model adı / kota gibi sorunlar anlaşılır olur
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let message = ((json?["error"] as? [String: Any])?["message"] as? String)
                ?? tr("Sunucu hatası (\(http.statusCode))", "Server error (\(http.statusCode))")
            throw AIError.badResponse(message)
        }

        let text = usesInteractionsAPI
            ? parseInteractionsAnswer(json)
            : parseGenerateContentAnswer(json)

        guard let text, !text.isEmpty else {
            throw AIError.badResponse(tr("Cevap alınamadı. Model adını Ayarlar'dan kontrol et.",
                                         "No answer received. Check the model name in Settings."))
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Interactions API (Gemini 3+)

    private static func interactionsRequest(messages: [AIMessage], summary: String,
                                            key: String) throws -> URLRequest {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")
        else { throw AIError.badResponse(tr("Geçersiz adres.", "Invalid endpoint.")) }

        let input: [[String: Any]] = messages.map { message in
            [
                "type": message.role == .user ? "user_input" : "model_output",
                "content": [["type": "text", "text": message.text]],
            ]
        }

        // NOT: AI Studio'nun örnek kodundaki google_search aracı bilerek eklenmedi —
        // asistanın internetten değil, yalnızca kullanıcının kendi verisinden
        // cevap vermesi isteniyor. thinking_level de "low": sayılar zaten
        // uygulamada hesaplandığı için derin düşünme gereksiz, cevap daha hızlı gelir.
        let body: [String: Any] = [
            "model": modelName,
            "system_instruction": systemPrompt(summary: summary),
            "input": input,
            "generation_config": [
                "max_output_tokens": 1200,
                "thinking_level": "low",
            ],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 90
        return request
    }

    // Cevap: steps[] içindeki model_output adımlarının metinleri
    private static func parseInteractionsAnswer(_ json: [String: Any]?) -> String? {
        guard let steps = json?["steps"] as? [[String: Any]] else { return nil }
        let texts = steps
            .filter { ($0["type"] as? String) == "model_output" }
            .compactMap { $0["content"] as? [[String: Any]] }
            .flatMap { $0 }
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
        return texts.isEmpty ? nil : texts.joined(separator: "\n")
    }

    // MARK: generateContent (eski modeller)

    private static func generateContentRequest(messages: [AIMessage], summary: String,
                                               key: String) throws -> URLRequest {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/"
            + modelName + ":generateContent"
        guard var components = URLComponents(string: endpoint) else {
            throw AIError.badResponse(tr("Geçersiz model adı.", "Invalid model name."))
        }
        components.queryItems = [URLQueryItem(name: "key", value: key)]
        guard let url = components.url else {
            throw AIError.badResponse(tr("Geçersiz model adı.", "Invalid model name."))
        }

        let contents: [[String: Any]] = messages.map { message in
            [
                "role": message.role == .user ? "user" : "model",
                "parts": [["text": message.text]],
            ]
        }
        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPrompt(summary: summary)]]],
            "contents": contents,
            "generationConfig": ["temperature": 0.4, "maxOutputTokens": 1200],
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 90
        return request
    }

    private static func parseGenerateContentAnswer(_ json: [String: Any]?) -> String? {
        guard let candidates = json?["candidates"] as? [[String: Any]],
              let first = candidates.first,
              let content = first["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]]
        else { return nil }
        let text = parts.compactMap { $0["text"] as? String }.joined()
        return text.isEmpty ? nil : text
    }
}

// MARK: - Ayarlar > Yapay Zeka

struct AISettingsView: View {
    @State private var key = ""
    @State private var hasKey = AIKeyStore.hasKey
    @AppStorage("aiModelName") private var modelName = "gemini-3-flash-preview"
    @State private var saved = false

    var body: some View {
        List {
            Section {
                if hasKey {
                    HStack {
                        Label(tr("Anahtar kayıtlı", "Key saved"), systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                        Spacer()
                    }
                    Button(tr("Anahtarı Sil", "Delete Key"), role: .destructive) {
                        AIKeyStore.delete()
                        hasKey = false
                        saved = false
                    }
                } else {
                    SecureField(tr("API anahtarı (AIza...)", "API key (AIza...)"), text: $key)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    Button(tr("Kaydet", "Save")) {
                        AIKeyStore.save(key)
                        key = ""
                        hasKey = AIKeyStore.hasKey
                        saved = hasKey
                    }
                    .disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text(tr("Google Gemini API Anahtarı", "Google Gemini API Key"))
            } footer: {
                Text(tr("Ücretsiz anahtarı aistudio.google.com adresinden alabilirsin; kredi kartı istemez. Anahtar telefonunun şifreli kasasında saklanır.",
                        "Get a free key at aistudio.google.com; no credit card needed. It is stored in your phone's Keychain."))
            }

            Section {
                TextField(tr("Model adı", "Model name"), text: $modelName)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            } header: {
                Text(tr("Model", "Model"))
            } footer: {
                Text(tr("Gemini 3 ve sonrası yeni Interactions API'siyle, eski modeller generateContent ile çalışır; uygulama model adına bakıp doğru olanı seçer. \"Model bulunamadı\" hatası alırsan buradan güncelleyebilirsin (örn. gemini-3-flash-preview, gemini-2.0-flash).",
                        "Gemini 3+ uses the new Interactions API, older models use generateContent; the app picks the right one from the model name. Update here if you get a \"model not found\" error."))
            }

            Section {
                Text(tr("Asistana tek tek harcama kayıtların, mağaza adların veya tarihler gönderilmez; sadece kategori toplamları ve oranlar gibi özet bilgiler gider. Tüm hesaplamalar telefonunda yapılır.",
                        "Individual records, merchant names and dates are never sent — only summary figures. All math is done on your phone."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text(tr("Gizlilik", "Privacy"))
            }
        }
        .navigationTitle(tr("Yapay Zeka", "AI"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { hasKey = AIKeyStore.hasKey }
    }
}
