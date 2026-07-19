import Foundation

// Güncel fiyatları internetten çeker:
// - Altın (gram) ve döviz kurları: truncgil finans API
// - Yatırım fonu fiyatları: TEFAS
enum PriceService {

    // Önbelleksiz oturum: "yenile" her zaman o anın verisini getirir
    static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.timeoutIntervalForRequest = 15
        config.urlCache = nil
        return URLSession(configuration: config)
    }()


    struct MarketPrices {
        var goldGram: Double?     // gram altın alış (varlık değerlemesi)
        var goldGramSell: Double? // gram altın satış (borç değerlemesi)
        var silverGram: Double?   // gram gümüş alış
        var ceyrekSell: Double?   // çeyrek altın satış
        var usd: Double?          // dolar alış
        var usdSell: Double?      // dolar satış
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
        let (data, _) = try await session.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        // Anahtar adları sürüme göre değişebiliyor; esnek ara.
        // Varlıklarda ALIŞ (bozdurunca eline geçen), borçlarda SATIŞ (kapatmak
        // için ödeyeceğin) kuru kullanılır.
        let buyKeys = ["Alış", "Alis", "Buying", "alis", "alış"]
        let sellKeys = ["Satış", "Satis", "Selling", "satis", "satış"]
        func price(forKeys keys: [String], valueKeys: [String]) -> Double? {
            for key in keys {
                if let entry = json[key] as? [String: Any] {
                    for valueKey in valueKeys {
                        if let value = parseNumber(entry[valueKey]) { return value }
                    }
                }
            }
            return nil
        }

        let goldKeys = ["gram-altin", "gram-altın", "GRA", "Gram Altın"]
        let ceyrekKeys = ["ceyrek-altin", "ceyrek-altın", "CEYREK", "Çeyrek Altın"]
        return MarketPrices(
            goldGram: price(forKeys: goldKeys, valueKeys: buyKeys),
            goldGramSell: price(forKeys: goldKeys, valueKeys: sellKeys),
            silverGram: price(forKeys: ["gumus", "gümüş", "GUMUS", "Gümüş"], valueKeys: buyKeys),
            ceyrekSell: price(forKeys: ceyrekKeys, valueKeys: sellKeys),
            usd: price(forKeys: ["USD", "usd"], valueKeys: buyKeys),
            usdSell: price(forKeys: ["USD", "usd"], valueKeys: sellKeys),
            eur: price(forKeys: ["EUR", "eur"], valueKeys: buyKeys)
        )
    }

    // Tera Portföy sitesinden fon fiyatı çek (TP2 gibi Tera fonları için)
    // 1) Ana sayfadaki menüden fonun kendi sayfa linki bulunur
    // 2) Fon sayfasındaki "product-price" değeri okunur
    static func fetchTeraHomePage() async throws -> String {
        let (data, _) = try await session.data(from: URL(string: "https://www.teraportfoy.com")!)
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

        let (fundData, _) = try await session.data(from: fundURL)
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

    // İş Portföy sitesinden fon fiyatı (TI1, TIL gibi İş Portföy fonları)
    // 1) Fon getirileri sayfasındaki listeden fonun sayfa linki bulunur
    // 2) Fon sayfasındaki "Fon Birim Fiyatı (TL)" değeri okunur
    static func fetchIsPortfoyFundPrice(code: String) async throws -> Double {
        func get(_ urlString: String) async throws -> String {
            var request = URLRequest(url: URL(string: urlString)!)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            let (data, _) = try await session.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else {
                throw URLError(.cannotParseResponse)
            }
            return html
        }

        let list = try await get("https://www.isportfoy.com.tr/fon-getirileri")

        // &quot;TI1 - ...&quot;,&quot;url&quot;:&quot;/is-portfoy-...&quot;
        let linkPattern = "&quot;\(code.uppercased()) - [^&]*&quot;,&quot;url&quot;:&quot;([^&]+)&quot;"
        let linkRegex = try NSRegularExpression(pattern: linkPattern)
        let listRange = NSRange(list.startIndex..., in: list)
        guard let match = linkRegex.firstMatch(in: list, range: listRange),
              let pathRange = Range(match.range(at: 1), in: list) else {
            throw URLError(.resourceUnavailable)
        }

        let page = try await get("https://www.isportfoy.com.tr\(String(list[pathRange]))")

        // "Fon Birim Fiyatı (TL)" etiketinden sonraki content değeri
        let pricePattern = #"Fon Birim Fiyatı.{0,400}?class="content">\s*([0-9][0-9.,]*)"#
        let priceRegex = try NSRegularExpression(pattern: pricePattern,
                                                 options: [.dotMatchesLineSeparators])
        let pageRange = NSRange(page.startIndex..., in: page)
        guard let priceMatch = priceRegex.firstMatch(in: page, range: pageRange),
              let priceRange = Range(priceMatch.range(at: 1), in: page) else {
            throw URLError(.cannotParseResponse)
        }

        // "1.604,814613" → 1604.814613
        let priceText = String(page[priceRange])
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        guard let price = Double(priceText), price > 0 else {
            throw URLError(.cannotParseResponse)
        }
        return price
    }

    // BIST hisse fiyatı (Yahoo Finance, "THYAO" → THYAO.IS)
    static func fetchBistStockPrice(code: String) async throws -> Double {
        let symbol = code.uppercased()
        // query2 ana, query1 yedek
        for host in ["query2", "query1"] {
            guard let url = URL(string: "https://\(host).finance.yahoo.com/v8/finance/chart/\(symbol).IS?interval=1d&range=1d") else { continue }
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            guard let (data, _) = try? await session.data(for: request),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let chart = json["chart"] as? [String: Any],
                  let results = chart["result"] as? [[String: Any]],
                  let meta = results.first?["meta"] as? [String: Any],
                  let price = parseNumber(meta["regularMarketPrice"]),
                  price > 0 else { continue }
            return price
        }
        throw URLError(.resourceUnavailable)
    }

    // Fonu tanıyan ilk sağlayıcıdan fiyatı getir (yeni şirketler buraya eklenir)
    static func fetchAnyFundPrice(code: String, teraHomePage: String? = nil) async -> Double? {
        if let price = try? await fetchTeraFundPrice(code: code, homePage: teraHomePage) {
            return price
        }
        if let price = try? await fetchIsPortfoyFundPrice(code: code) {
            return price
        }
        return nil
    }
}
