import SwiftUI

// Uygulama dili (Ayarlar'dan seçilir; varsayılan Türkçe).
// Ay adları, tarih ve sayı biçimleri bu yerel ayara göre gösterilir.
var appLocale: Locale {
    let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "tr"
    return Locale(identifier: lang == "en" ? "en_US" : "tr_TR")
}

// Seçili dile göre metin: tr("Türkçe", "English")
var isEnglishUI: Bool {
    UserDefaults.standard.string(forKey: "appLanguage") == "en"
}

func tr(_ turkish: String, _ english: String) -> String {
    isEnglishUI ? english : turkish
}

// Renkli özet kartı: başlık + tutar (+ isteğe bağlı kar/zarar rozeti)
struct StatCard: View {
    let title: String
    let amount: Double
    let icon: String
    let colors: [Color]
    var profit: Double? = nil
    var profitPercent: Double? = nil
    var invertProfitColors = false // borç gibi: artış kötü (kırmızı), azalış iyi (yeşil)
    var masked = false // gizlilik: tutar yerine ***.***,** gösterilir

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(masked ? "₺***.***,**" : amount.formatted(.currency(code: "TRY")))
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            // Kar/zarar rozeti (verilmişse)
            if let profit {
                let isPositive = profit >= 0
                let isGain = invertProfitColors ? !isPositive : isPositive
                let sign = isPositive ? "+" : "-"
                let amountText = abs(profit).formatted(.currency(code: "TRY").precision(.fractionLength(0)))
                let pctText = profitPercent.map {
                    " · \(sign)%" + abs($0).formatted(.number.precision(.fractionLength(1)))
                } ?? ""
                HStack(spacing: 4) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                    Text("\(sign)\(amountText)\(pctText)")
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Capsule().fill((isGain ? Color.green : Color.red).opacity(0.85))
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .shadow(color: (colors.last ?? .clear).opacity(0.35), radius: 8, y: 4)
    }
}

// Grafik kalemleri için renk paletleri (kalem sırasına göre atanır)
let paymentPalette: [Color] = [.blue, .cyan, .indigo, .purple, .teal, .mint, .orange, .pink]
let incomePalette: [Color] = [.green, .mint, .teal, .cyan, .yellow, .orange]
let savingsPalette: [Color] = [.purple, .indigo, .pink, .orange, .teal, .mint]

// Grafikte dokunulan ayı sheet'e taşımak için
struct MonthSelection: Identifiable {
    let date: Date
    var id: Date { date }
}

// Bir ayın kalem kalem dökümünü gösteren küçük ekran:
// üstte renkli parçalı bar, altında kalem listesi
struct MonthBreakdownSheet: View {
    let heading: String // "Ödemeler" / "Gelirler"
    let month: Date
    let items: [(name: String, amount: Double, color: Color)]

    private var total: Double { items.reduce(0) { $0 + $1.amount } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 14) {
                        // Kalemlerin üst üste bindiği parçalı bar
                        GeometryReader { geo in
                            HStack(spacing: 2) {
                                ForEach(items, id: \.name) { seg in
                                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                                        .fill(seg.color.gradient)
                                        .frame(width: total > 0
                                               ? max(5, (geo.size.width - CGFloat(items.count - 1) * 2) * seg.amount / total)
                                               : 0)
                                }
                            }
                        }
                        .frame(height: 26)

                        HStack {
                            Text(tr("Toplam", "Total"))
                                .font(.headline)
                            Spacer()
                            Text(total, format: .currency(code: "TRY"))
                                .font(.title3.bold())
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(heading) {
                    ForEach(items, id: \.name) { seg in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(seg.color.gradient)
                                .frame(width: 14, height: 14)
                            Text(seg.name)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(seg.amount, format: .currency(code: "TRY"))
                                    .font(.callout.weight(.semibold))
                                Text(total > 0
                                     ? "%\(Int((seg.amount / total * 100).rounded()))"
                                     : "%0")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(month.formatted(.dateTime.month(.wide).year().locale(appLocale)))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// Yeşil/kırmızı kar-zarar etiketi: "+₺18.800 · %13,3"
struct ProfitText: View {
    let profit: Double
    let percent: Double?

    var body: some View {
        let isGain = profit >= 0
        let sign = isGain ? "+" : "-"
        let amount = abs(profit).formatted(.currency(code: "TRY").precision(.fractionLength(0)))
        let pct = percent.map {
            " · \(sign)%" + abs($0).formatted(.number.precision(.fractionLength(1)))
        } ?? ""
        Text("\(sign)\(amount)\(pct)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(isGain ? Color.green : Color.red)
    }
}

// Liste satırlarının solundaki yuvarlak ikon
struct RowIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(Circle().fill(color.gradient))
    }
}

// Varsayılan hesap/varlık adlarını İngilizce modda çevir (kayıt Türkçe kalır)
func localizedDataName(_ name: String) -> String {
    guard isEnglishUI else { return name }
    let map: [String: String] = [
        "Fon Hesabı": "Fund Account",
        "Hisse Hesabı": "Stock Account",
        "Vadeli Hesap": "Deposit Account",
        "Emtia Hesabı": "Commodity Account",
        "Vadeli Mevduat": "Time Deposit",
        "Altın": "Gold",
        "Gümüş": "Silver",
    ]
    return map[name] ?? name
}
