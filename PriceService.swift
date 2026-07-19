import Foundation

// Güncel fiyatları internetten çeker:
// - Altın (gram) ve döviz kurları: truncgil finans API
// - Yatırım fonu fiyatları: TEFAS
enum PriceService {

    struct MarketPrices {
        var goldGram: Double? // 1 gram altın (TL, satış)
        var usd: Double?
        var eur: Double?
    }

    // "4.379,42" / "33,94" / 4379.42 gibi farklı biçimleri sayıya çevir
    private static func parseNumber(_ raw: Any?) -> Double? {
        if let d = raw as? Double { return d }
        if let s = raw as? String {
            let cleaned = s
                .replacingOccurrences(of: "%", with: "")
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
            return Double(cleaned)
        }
        return nil
    }

    static func fetchMarketPrices() async throws -> MarketPrices {
        let url = URL(string: "https://finans.truncgil.com/today.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        // Anahtar adları sürüme göre değişebiliyor; esnek ara.
        // Değerleme için ALIŞ kuru kullanılır (bozdurduğunda eline geçecek tutar).
        func price(forKeys keys: [String]) -> Double? {
            for key in keys {
                if let entry = json[key] as? [String: Any] {
                    for valueKey in ["Alış", "Alis", "Buying", "alis", "alış",
                                     "Satış", "Satis", "Selling"] {
                        if let value = parseNumber(entry[valueKey]) { return value }
                    }
                }
            }
            return nil
        }

        return MarketPrices(
            goldGram: price(forKeys: ["gram-altin", "gram-altın", "GRA", "Gram Altın"]),
            usd: price(forKeys: ["USD", "usd"]),
            eur: price(forKeys: ["EUR", "eur"])
        )
    }

    // Tera Portföy sitesinden fon fiyatı çek (TP2 gibi Tera fonları için)
    // 1) Ana sayfadaki menüden fonun kendi sayfa linki bulunur
    // 2) Fon sayfasındaki "product-price" değeri okunur
    static func fetchTeraHomePage() async throws -> String {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://www.teraportfoy.com")!)
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        return html
    }

    static func fetchTeraFundPrice(code: String, homePage: String? = nil) async throws -> Double {
        let home: String
        if let homePage {
            home = homePage
        } else {
            home = try await fetchTeraHomePage()
        }

        // Menüde: href="/fonlarimiz/..."> <div class="product-code">TP2</div>
        let linkPattern = #"href="([^"]+)">\s*<div class="product-code">\#(code.uppercased())</div>"#
        let linkRegex = try NSRegularExpression(pattern: linkPattern)
        let homeRange = NSRange(home.startIndex..., in: home)
        guard let match = linkRegex.firstMatch(in: home, range: homeRange),
              let pathRange = Range(match.range(at: 1), in: home) else {
            throw URLError(.resourceUnavailable)
        }
        let path = String(home[pathRange])
        guard let fundURL = URL(string: "https://www.teraportfoy.com\(path)") else {
            throw URLError(.badURL)
        }

        let (fundData, _) = try await URLSession.shared.data(from: fundURL)
        guard let fundHTML = String(data: fundData, encoding: .utf8) else {
            throw URLError(.cannotParseResponse)
        }

        // <div class="product-price"> <strong>2,07413 </strong>
        let pricePattern = #"product-price"[^>]*>\s*<strong>\s*([0-9]+[.,][0-9]+)"#
        let priceRegex = try NSRegularExpression(pattern: pricePattern)
        let fundRange = NSRange(fundHTML.startIndex..., in: fundHTML)
        guard let priceMatch = priceRegex.firstMatch(in: fundHTML, range: fundRange),
              let priceRange = Range(priceMatch.range(at: 1), in: fundHTML) else {
            throw URLError(.cannotParseResponse)
        }
        let priceText = String(fundHTML[priceRange]).replacingOccurrences(of: ",", with: ".")
        guard let price = Double(priceText), price > 0 else {
            throw URLError(.cannotParseResponse)
        }
        return price
    }

    // TEFAS'tan fonun son fiyatını çek (örn. "TP2")
    static func fetchFundPrice(code: String) async throws -> Double {
        var request = URLRequest(url: URL(string: "https://www.tefas.gov.tr/api/DB/BindHistoryInfo")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=UTF-8",
                         forHTTPHeaderField: "Content-Type")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        let end = formatter.string(from: .now)
        let start = formatter.string(from: Calendar.current.date(byAdding: .day, value: -10, to: .now)!)

        let body = "fontip=YAT&fonkod=\(code.uppercased())&bastarih=\(start)&bittarih=\(end)"
        request.httpBody = body.data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = json["data"] as? [[String: Any]], !rows.isEmpty else {
            throw URLError(.cannotParseResponse)
        }

        // En güncel kaydın fiyatını al (TARIH alanı milisaniye cinsinden gelir)
        let sorted = rows.sorted {
            (parseNumber($0["TARIH"]) ?? 0) < (parseNumber($1["TARIH"]) ?? 0)
        }
        if let last = sorted.last, let price = parseNumber(last["FIYAT"]) {
            return price
        }
        throw URLError(.cannotParseResponse)
    }
}
