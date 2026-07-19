import SwiftUI
import SwiftData
import WebKit

// TEFAS fon sayfasını uygulama içinde açar; sayfa yüklenince
// "Güncel fiyat" değerini okuyup tek dokunuşla kullanmayı önerir.
// (Sayfa, kullanıcının kendi internetiyle normal bir tarayıcı gibi yüklenir.)
struct TefasPriceSheet: View {
    @Bindable var asset: Asset

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var foundPrice: Double?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TefasWebView(code: asset.code ?? "") { price in
                    if foundPrice == nil {
                        foundPrice = price
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    if let price = foundPrice {
                        Label("Güncel fiyat: \(price.formatted(.currency(code: "TRY")))",
                              systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.callout.weight(.semibold))
                        Spacer()
                        Button("Bu fiyatı kullan") {
                            asset.unitPrice = price
                            asset.priceUpdatedAt = .now
                            try? modelContext.save()
                            syncSavingsSnapshot(modelContext)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        ProgressView()
                        Text("Sayfadaki güncel fiyat aranıyor...")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .padding()
            }
            .navigationTitle(asset.code?.uppercased() ?? "TEFAS")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

// TEFAS sayfasını yükleyen web görünümü; yüklendikçe sayfa metninde
// "Güncel Fiyat" etiketinin yanındaki sayıyı arar
private struct TefasWebView: UIViewRepresentable {
    let code: String
    let onPrice: (Double) -> Void

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.onPrice = onPrice
        if let url = URL(string: "https://www.tefas.gov.tr/tr/fon-detayli-analiz/\(code.uppercased())") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        weak var webView: WKWebView?
        var onPrice: ((Double) -> Void)?
        private var timer: Timer?
        private var attempts = 0

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            startPolling()
        }

        private func startPolling() {
            timer?.invalidate()
            attempts = 0
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
                guard let self else { t.invalidate(); return }
                self.attempts += 1
                if self.attempts > 30 { t.invalidate() }
                self.extractPrice()
            }
        }

        private func extractPrice() {
            webView?.evaluateJavaScript("document.body.innerText") { [weak self] result, _ in
                guard let self, let text = result as? String else { return }
                // "Güncel Fiyat" etiketinin yakınındaki ilk sayıyı bul
                guard let labelRange = text.range(
                    of: #"(?i)g[uü]ncel\s*fiyat[^0-9]{0,40}[0-9]+[.,][0-9]+"#,
                    options: .regularExpression
                ) else { return }
                let snippet = String(text[labelRange])
                guard let numberRange = snippet.range(
                    of: #"[0-9]+[.,][0-9]+"#,
                    options: .regularExpression
                ) else { return }
                let numberText = String(snippet[numberRange])
                    .replacingOccurrences(of: ",", with: ".")
                if let price = Double(numberText), price > 0 {
                    self.timer?.invalidate()
                    DispatchQueue.main.async {
                        self.onPrice?(price)
                    }
                }
            }
        }

        deinit { timer?.invalidate() }
    }
}
