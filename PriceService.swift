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

        // Anahtar adları sürüme göre değişebiliyor; esnek ara
        func price(forKeys keys: [String]) -> Double? {
            for key in keys {
                if let entry = json[key] as? [String: Any] {
                    for valueKey in ["Satış", "Satis", "Selling", "satis", "satış"] {
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
