import Foundation
import Speech
import AVFoundation
import SwiftUI

// Mikrofon ile konuşmayı yazıya çevirir (Türkçe)
@Observable
final class SpeechRecognizer {
    var transcript = ""
    var isRecording = false
    var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "tr-TR"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    func start() {
        errorMessage = nil
        transcript = ""

        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    self.errorMessage = "Konuşma tanıma izni verilmedi. Ayarlar > İyi Bütçe'den açabilirsin."
                    return
                }
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        guard granted else {
                            self.errorMessage = "Mikrofon izni verilmedi. Ayarlar > İyi Bütçe'den açabilirsin."
                            return
                        }
                        self.beginRecording()
                    }
                }
            }
        }
    }

    private func beginRecording() {
        guard let recognizer, recognizer.isAvailable else {
            #if targetEnvironment(simulator)
            errorMessage = "Konuşma tanıma simülatörde kullanılamıyor. Mac'te: Sistem Ayarları > Gizlilik > Mikrofon'dan Simulator'a izin ver ve Simulator menüsünden I/O > Audio Input'u kontrol et. En sağlıklı test gerçek iPhone'da."
            #else
            errorMessage = "Konuşma tanıma şu an kullanılamıyor. İnternet bağlantını ve Ayarlar > Genel > Klavye > Dikte'nin açık olduğunu kontrol et."
            #endif
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)

            // Mikrofon hattı gerçekten var mı? (simülatörde sık görülen sorun)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                errorMessage = "Mikrofon girişi bulunamadı. Simulator menüsünden I/O > Audio Input > Internal Microphone'u seç, olmazsa simülatörü yeniden başlat. En sağlıklısı gerçek iPhone'da denemek."
                return
            }

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                request.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true

            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                    }
                    if error != nil || (result?.isFinal ?? false) {
                        // Hiçbir şey tanınmadan hata geldiyse sebebini göster
                        if let error, self.isRecording, self.transcript.isEmpty {
                            self.errorMessage = "Ses tanınamadı: \(error.localizedDescription)"
                        }
                        self.stop()
                    }
                }
            }
        } catch {
            errorMessage = "Kayıt başlatılamadı: \(error.localizedDescription)"
            stop()
        }
    }

    func stop() {
        guard isRecording || audioEngine.isRunning else { return }
        isRecording = false
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        let currentTask = task
        task = nil
        request = nil
        currentTask?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// Metinden kategori tahmini: "bim", "benzin", "eczane" gibi anahtar kelimelerden
// (sıra önemli: "market alışverişi" önce Market'e yakalanır, Alışveriş'e değil)
func guessCategory(from text: String) -> String? {
    let t = text.lowercased(with: Locale(identifier: "tr_TR"))

    // Önce kullanıcının kendi eklediği kategoriler: adı geçiyorsa o seçilir
    for category in ExpenseCategory.custom
    where t.contains(category.name.lowercased(with: Locale(identifier: "tr_TR"))) {
        return category.name
    }

    // Sıra önemli: yukarıdaki kural önce yakalar
    // ("market alışverişi" → Market, "kırtasiye alışverişi" → Eğitim)
    let rules: [(category: String, keywords: [String])] = [
        ("Nakit Avans", ["nakit avans", "avans", "nakit çekim", "nakit çektim", "atm'den çektim"]),

        ("Market", ["market", "bim", "a101", "şok market", "şok", "migros", "carrefour", "carrefoursa",
                    "macrocenter", "metro market", "tarım kredi", "manav", "bakkal", "kasap",
                    "fırın", "ekmek", "süt", "meyve", "sebze", "et aldım", "balıkçı", "kuruyemiş",
                    "banabi", "istegelsin"]),

        ("Akaryakıt", ["benzin", "motorin", "mazot", "akaryakıt", "yakıt", "opet", "shell", "petrol",
                       "petrol ofisi", "total", "aytemiz", "lukoil", "lpg", "otogaz",
                       "depo doldur", "yakıt aldım", "elektrikli şarj", "araç şarj"]),

        ("Kafe & Restoran", ["kafe", "cafe", "kahve", "restoran", "lokanta", "yemek", "starbucks",
                             "burger", "pizza", "döner", "dürüm", "kebap", "lahmacun", "pide",
                             "mcdonald", "burger king", "kfc", "popeyes", "domino", "sbarro",
                             "yemeksepeti", "trendyol yemek", "getir yemek", "migros yemek",
                             "kahvaltı", "öğle yemeği", "akşam yemeği", "çay", "tatlı", "baklava",
                             "dondurma", "pastane", "simit", "gazoz", "meyhane"]),

        ("Ulaşım", ["otobüs", "metro", "taksi", "dolmuş", "minibüs", "marmaray", "vapur", "ulaşım",
                    "akbil", "istanbulkart", "kentkart", "uber", "bitaksi", "martı",
                    "scooter", "otopark", "park ücreti", "köprü", "otoyol", "hgs", "ogs",
                    "trene", "trenle", "trenden", "tren bileti", "yht", "uçak", "havayolu",
                    "thy", "pegasus", "ajet"]),

        ("Giyim", ["giyim", "kıyafet", "ayakkabı", "çizme", "sneaker", "pantolon", "kot",
                   "jean", "tişört", "sweat", "kazak", "hırka", "gömlek", "elbise", "etek",
                   "mont", "kaban", "ceket", "atkı", "eldiven", "çorap", "iç çamaşırı",
                   "zara", "koton", "lcw", "lc waikiki", "defacto", "mavi jeans", "bershka",
                   "pull and bear", "stradivarius", "h&m", "mango", "hummel", "nike", "adidas",
                   "puma", "new balance", "flo", "deichmann", "vakko", "beymen", "boyner",
                   "terzi", "kuru temizleme"]),

        ("Fatura", ["fatura", "elektrik", "doğalgaz", "gaz faturası", "su faturası", "internet",
                    "telefon faturası", "cep telefonu faturası", "turkcell", "vodafone",
                    "türk telekom", "superonline", "aidat", "site aidatı", "apartman",
                    "kira ödemesi", "kira verdim", "vergi", "mtv", "emlak vergisi", "sigorta",
                    "kasko", "trafik sigortası", "dask", "bağkur", "sgk"]),

        ("Sağlık", ["eczane", "ilaç", "doktor", "hastane", "muayene", "diş", "dişçi", "sağlık",
                    "vitamin", "tahlil", "röntgen", "mr ", "tomografi", "ameliyat", "fizik tedavi",
                    "gözlük", "lens", "optik", "psikolog", "terapi", "aşı", "check up", "checkup"]),

        ("Abonelik", ["abonelik", "üyelik", "netflix", "spotify", "youtube", "disney", "blutv",
                      "exxen", "amazon prime", "apple music", "icloud", "google one", "dropbox",
                      "chatgpt", "adobe", "office 365", "steam abonelik", "spor salonu",
                      "gym üyelik", "dergi aboneliği"]),

        ("Eğlence", ["sinema", "film bileti", "konser", "tiyatro", "festival", "maç bileti",
                     "stadyum", "playstation", "xbox", "steam", "epic games", "lunapark",
                     "eğlence", "bowling", "bilardo", "paintball", "müze", "sergi", "tatil",
                     "otel", "konaklama", "airbnb", "booking", "hediye", "doğum günü"]),

        ("Eğitim", ["eğitim", "okul", "kurs", "dershane", "etüt", "üniversite", "harç", "yurt",
                    "kitap", "kırtasiye", "defter", "kalem", "fotokopi", "ders", "özel ders",
                    "udemy", "online kurs", "sertifika", "sınav ücreti", "yds", "ales", "kpss",
                    "anaokulu", "kreş", "servis ücreti"]),

        ("Alışveriş", ["alışveriş", "trendyol", "hepsiburada", "amazon", "n11", "çiçeksepeti",
                       "gittigidiyor", "morhipo", "mağaza", "avm", "ikea", "koçtaş", "bauhaus",
                       "teknosa", "vatan bilgisayar", "media markt", "apple store", "telefon aldım",
                       "bilgisayar", "kulaklık", "şarj aleti", "kablo", "beyaz eşya", "mobilya",
                       "ev eşyası", "süpürge", "ütü", "buzdolabı", "çamaşır makinesi",
                       "bulaşık makinesi", "televizyon", "klima", "mikrodalga",
                       "deterjan", "temizlik malzemesi", "kozmetik", "gratis",
                       "watsons", "rossmann", "sephora", "parfüm", "kuaför", "berber", "petshop",
                       "mama", "kedi", "köpek", "çiçek", "oyuncak"]),
    ]
    for rule in rules where rule.keywords.contains(where: { t.contains($0) }) {
        return rule.category
    }
    return nil
}

// Türkçe ay adları (sesli girişteki "3 temmuz" gibi tarihler için)
private let turkishMonths: [(names: [String], number: Int)] = [
    (["ocak"], 1), (["şubat", "subat"], 2), (["mart"], 3), (["nisan"], 4),
    (["mayıs", "mayis"], 5), (["haziran"], 6), (["temmuz"], 7),
    (["ağustos", "agustos"], 8), (["eylül", "eylul"], 9), (["ekim"], 10),
    (["kasım", "kasim"], 11), (["aralık", "aralik"], 12),
]

// "3 temmuz" / "3 temmuzda" / "3 temmuz 2026" → tarih.
// Bulunca ifadeyi metinden siler (tutar ararken gün sayısına takılmasın diye).
private func parseSpokenMonthDate(in text: inout String) -> Date? {
    let monthPattern = turkishMonths.flatMap(\.names).joined(separator: "|")
    let pattern = "(\\d{1,2})\\s*(" + monthPattern + ")\\w*(?:\\s+(\\d{4}))?"
    guard let match = text.range(of: pattern, options: [.regularExpression, .caseInsensitive])
    else { return nil }

    let trLocale = Locale(identifier: "tr_TR")
    let matched = String(text[match]).lowercased(with: trLocale)

    guard let dayRange = matched.range(of: #"\d{1,2}"#, options: .regularExpression),
          let day = Int(matched[dayRange]),
          let month = turkishMonths.first(where: { entry in
              entry.names.contains { matched.contains($0) }
          })?.number
    else { return nil }

    let calendar = Calendar.current
    var components = DateComponents()
    components.day = day
    components.month = month

    // Yıl söylendiyse onu kullan
    if let yearRange = matched.range(of: #"\d{4}"#, options: .regularExpression),
       let spokenYear = Int(matched[yearRange]) {
        components.year = spokenYear
        guard let parsed = calendar.date(from: components) else { return nil }
        text.removeSubrange(match)
        return parsed
    }

    // Yıl söylenmediyse bu yıl; tarih ileride kalıyorsa geçen yıl kastedilmiştir
    components.year = calendar.component(.year, from: .now)
    guard var parsed = calendar.date(from: components) else { return nil }
    if let limit = calendar.date(byAdding: .day, value: 30, to: .now), parsed > limit {
        components.year = (components.year ?? 0) - 1
        guard let previousYear = calendar.date(from: components) else { return nil }
        parsed = previousYear
    }
    text.removeSubrange(match)
    return parsed
}

// Her kelimeyi büyük harfle başlat ("market alışverişi" → "Market Alışverişi")
private func capitalizedWords(_ text: String) -> String {
    let trLocale = Locale(identifier: "tr_TR")
    return text
        .split(separator: " ")
        .map { $0.prefix(1).uppercased(with: trLocale) + $0.dropFirst() }
        .joined(separator: " ")
}

// "Dün Bim'den 100 TL'lik market alışverişi yaptım"
// → açıklama + tutar (100) + kategori (Market) + tarih (dün)
func parseSpokenExpense(_ spoken: String)
    -> (title: String?, amount: Double?, category: String?, date: Date?) {
    var text = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return (nil, nil, nil, nil) }

    // Kategoriyi orijinal cümleden tahmin et
    let category = guessCategory(from: text)

    // Tarih: önce "3 temmuz" gibi açık tarihler, sonra "dün/bugün" gibi ifadeler.
    // Tutardan ÖNCE ayıklanır; yoksa gün sayısı tutar sanılır.
    var date: Date? = parseSpokenMonthDate(in: &text)

    if date == nil {
        let dayPhrases: [(phrase: String, offset: Int)] = [
            ("evvelsi gün", -2), ("önceki gün", -2), ("dün", -1), ("bugün", 0),
        ]
        for item in dayPhrases where text.range(of: item.phrase, options: .caseInsensitive) != nil {
            date = Calendar.current.date(byAdding: .day, value: item.offset, to: .now)
            text = text.replacingOccurrences(of: item.phrase, with: "", options: .caseInsensitive)
            break
        }
    }

    // Tutarı yakala
    var amount: Double?
    if let match = text.range(of: #"\d+(?:[.,]\d+)?"#, options: .regularExpression) {
        var numText = String(text[match])
        // "1.250,50" gibi Türkçe biçimi düz sayıya çevir
        if numText.contains(",") {
            numText = numText
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
        }
        amount = Double(numText)
        text.removeSubrange(match)
    }

    // Çok kelimeli para ifadelerini temizle
    text = text.replacingOccurrences(of: "türk lirası", with: "", options: .caseInsensitive)

    // Gereksiz kelimeleri (para birimi, ekler, fiiller) kelime bazında ayıkla
    let junkWords: Set<String> = ["tl", "lira", "liralık", "lik", "lık", "₺",
                                  "yaptım", "aldım", "ödedim", "harcadım", "verdim"]
    let words = text
        .split(separator: " ")
        .map(String.init)
        .filter { !junkWords.contains($0.lowercased(with: Locale(identifier: "tr_TR"))) }

    let cleaned = words.joined(separator: " ")
    // Elle yazarkenki gibi her kelime büyük harfle başlasın
    let title = cleaned.isEmpty ? nil : capitalizedWords(cleaned)
    return (title, amount, category, date)
}

// Formlarda kullanılan tr("Sesle Gir", "Voice Entry") bölümü
struct VoiceEntrySection: View {
    let hint: String
    let onResult: (String) -> Void

    @State private var speech = SpeechRecognizer()

    var body: some View {
        Section {
            Button {
                if speech.isRecording {
                    let spoken = speech.transcript
                    speech.stop()
                    onResult(spoken)
                } else {
                    speech.start()
                }
            } label: {
                HStack {
                    Image(systemName: speech.isRecording ? "mic.fill" : "mic")
                        .symbolEffect(.pulse, isActive: speech.isRecording)
                    Text(speech.isRecording ? tr("Dinliyorum... bitince dokun", "Listening... tap when done") : hint)
                }
                .foregroundStyle(speech.isRecording ? .red : Color.accentColor)
            }

            if speech.isRecording && !speech.transcript.isEmpty {
                Text(speech.transcript)
                    .foregroundStyle(.secondary)
            }

            if let message = speech.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text(tr("Sesle Gir", "Voice Entry"))
        } footer: {
            Text(tr("Örn. \"Market alışverişi 500 lira\" — tutarı ve açıklamayı otomatik doldurur.", "E.g. \"Groceries 500 lira\" — fills amount and note automatically."))
        }
        .onDisappear { speech.stop() }
    }
}
