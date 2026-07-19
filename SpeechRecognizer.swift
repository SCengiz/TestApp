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
    let rules: [(category: String, keywords: [String])] = [
        ("Market", ["market", "bim", "a101", "şok", "migros", "carrefour", "manav", "bakkal"]),
        ("Akaryakıt", ["benzin", "motorin", "mazot", "akaryakıt", "yakıt", "opet", "shell", "petrol"]),
        ("Kafe & Restoran", ["kafe", "cafe", "kahve", "restoran", "lokanta", "yemek", "starbucks", "burger", "pizza", "döner", "dürüm"]),
        ("Ulaşım", ["otobüs", "metro", "taksi", "dolmuş", "marmaray", "vapur", "ulaşım", "akbil"]),
        ("Giyim", ["giyim", "kıyafet", "ayakkabı", "pantolon", "tişört", "gömlek", "elbise", "mont", "ceket", "zara", "koton", "lcw"]),
        ("Fatura", ["fatura", "elektrik", "doğalgaz", "internet"]),
        ("Sağlık", ["eczane", "ilaç", "doktor", "hastane", "muayene", "diş", "sağlık", "vitamin"]),
        ("Abonelik", ["abonelik", "netflix", "spotify", "youtube"]),
        ("Eğlence", ["sinema", "konser", "tiyatro", "oyun", "eğlence"]),
        ("Eğitim", ["eğitim", "okul", "kurs", "dershane", "üniversite", "kitap", "kırtasiye", "harç"]),
        ("Alışveriş", ["alışveriş", "trendyol", "hepsiburada", "amazon", "n11", "mağaza"]),
    ]
    for rule in rules where rule.keywords.contains(where: { t.contains($0) }) {
        return rule.category
    }
    return nil
}

// "Dün Bim'den 100 TL'lik market alışverişi yaptım"
// → açıklama + tutar (100) + kategori (Market) + tarih (dün)
func parseSpokenExpense(_ spoken: String)
    -> (title: String?, amount: Double?, category: String?, date: Date?) {
    var text = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return (nil, nil, nil, nil) }

    // Kategoriyi orijinal cümleden tahmin et
    let category = guessCategory(from: text)

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

    // Tarih kelimeleri: "dün", "bugün", "evvelsi/önceki gün"
    var date: Date?
    let dayPhrases: [(phrase: String, offset: Int)] = [
        ("evvelsi gün", -2), ("önceki gün", -2), ("dün", -1), ("bugün", 0),
    ]
    for item in dayPhrases where text.range(of: item.phrase, options: .caseInsensitive) != nil {
        date = Calendar.current.date(byAdding: .day, value: item.offset, to: .now)
        text = text.replacingOccurrences(of: item.phrase, with: "", options: .caseInsensitive)
        break
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
    let title = cleaned.isEmpty ? nil : cleaned.prefix(1).uppercased() + cleaned.dropFirst()
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
