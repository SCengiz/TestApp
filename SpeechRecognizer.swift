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
                    self.errorMessage = "Konuşma tanıma izni verilmedi. Ayarlar > Bütçem'den açabilirsin."
                    return
                }
                AVAudioApplication.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        guard granted else {
                            self.errorMessage = "Mikrofon izni verilmedi. Ayarlar > Bütçem'den açabilirsin."
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
            errorMessage = "Konuşma tanıma şu an kullanılamıyor."
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

// "Market alışverişi 500 lira" → (açıklama: "Market alışverişi", tutar: 500)
func parseSpokenExpense(_ spoken: String) -> (title: String?, amount: Double?) {
    var text = spoken.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return (nil, nil) }

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

    // Para birimi kelimelerini açıklamadan temizle
    for word in ["türk lirası", "lira", "tl", "₺"] {
        text = text.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
    }
    let cleaned = text.split(separator: " ").joined(separator: " ")
    let title = cleaned.isEmpty ? nil : cleaned.prefix(1).uppercased() + cleaned.dropFirst()
    return (title, amount)
}

// Formlarda kullanılan "Sesle Gir" bölümü
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
                    Text(speech.isRecording ? "Dinliyorum... bitince dokun" : hint)
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
            Text("Sesle Gir")
        } footer: {
            Text("Örn. \"Market alışverişi 500 lira\" — tutarı ve açıklamayı otomatik doldurur.")
        }
        .onDisappear { speech.stop() }
    }
}
