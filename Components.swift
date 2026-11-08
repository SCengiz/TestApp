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
                // "Kredi Kartı Harcamalarım" gibi uzun başlıklar tek satıra
                // sığmayıp kırpılıyordu; iki satıra kadar sarsın
                .lineLimit(2)
                .multilineTextAlignment(.leading)
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

// Ekranların baktığı dönem: tek bir ay ya da ay aralığı.
// Her iki uç da bugünün ayına göre "kaç ay" olarak tutulur, böylece
// ekranlar arasında taşınabiliyor ve takvim ilerleyince kendiliğinden kayıyor.
struct PeriodSelection: Equatable {
    var startOffset: Int = 0
    var endOffset: Int = 0 // tek ay seçiliyken startOffset ile aynı

    var isRange: Bool { endOffset != startOffset }

    static func thisMonth() -> PeriodSelection { PeriodSelection() }

    private static var calendar: Calendar { .current }

    private static var currentMonth: Date {
        calendar.dateInterval(of: .month, for: .now)!.start
    }

    func month(at offset: Int) -> Date {
        Self.calendar.date(byAdding: .month, value: offset, to: Self.currentMonth)!
    }

    var startMonth: Date { month(at: min(startOffset, endOffset)) }
    var endMonth: Date { month(at: max(startOffset, endOffset)) }

    // Sorgularda kullanılan zaman aralığı: başlangıç ayının ilkinden
    // bitiş ayının sonuna kadar
    var interval: DateInterval {
        let cal = Self.calendar
        let start = cal.dateInterval(of: .month, for: startMonth)?.start ?? startMonth
        let end = cal.dateInterval(of: .month, for: endMonth)?.end ?? endMonth
        return DateInterval(start: start, end: max(end, start))
    }

    // Aralıktaki ayların tamamı (tek ay seçiliyse tek elemanlı)
    var months: [Date] {
        let cal = Self.calendar
        var result: [Date] = []
        var cursor = startMonth
        while cursor < interval.end {
            result.append(cursor)
            guard let next = cal.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result.isEmpty ? [startMonth] : result
    }

    var title: String {
        if !isRange {
            return startMonth.formatted(.dateTime.month(.wide).year().locale(appLocale))
        }
        let from = startMonth.formatted(.dateTime.month(.abbreviated).year().locale(appLocale))
        let to = endMonth.formatted(.dateTime.month(.abbreviated).year().locale(appLocale))
        return "\(from) – \(to)"
    }

    // Grafiklerde gösterilecek aylar.
    //
    // Tek ay seçiliyken ekranın kendi penceresi kullanılır (Gelirler seçili ayın
    // etrafında, Birikimler seçili ayla biten). Aralık seçiliyse aralığın
    // kendisi gösterilir; çok uzun aralıklarda son `maxCount` ay alınır, yoksa
    // hem okunmaz hem de ay başına hesap yapan grafiklerde yavaşlar.
    func chartMonths(radius: Int? = nil, trailing: Int? = nil, maxCount: Int = 24) -> [Date] {
        if isRange {
            let all = months
            return all.count <= maxCount ? all : Array(all.suffix(maxCount))
        }
        let cal = Calendar.current
        if let radius {
            return (-radius...radius).compactMap {
                cal.date(byAdding: .month, value: $0, to: startMonth)
            }
        }
        let count = trailing ?? 7
        return (-(count - 1)...0).compactMap {
            cal.date(byAdding: .month, value: $0, to: startMonth)
        }
    }

    // Oklarla kaydırma: aralık seçiliyken pencere bütün olarak kayar
    mutating func shift(by months: Int) {
        startOffset += months
        endOffset += months
    }
}

// Dönem seçici: istenen aya atlama ve ay aralığı seçme.
//
// Oklar komşu aylarda gezinmek için; bu düğme "beş yıl önceki şubatı aç" ya da
// "2025'in tamamını göster" içindir. Hiçbir kayıt silinmediği için eski aylar
// her zaman erişilebilir.
struct PeriodPickerButton: View {
    @Binding var period: PeriodSelection
    var tint: Color = .accentColor

    @State private var showing = false
    @State private var rangeMode = false
    @State private var fromYear = Calendar.current.component(.year, from: .now)
    @State private var fromMonth = Calendar.current.component(.month, from: .now)
    @State private var toYear = Calendar.current.component(.year, from: .now)
    @State private var toMonth = Calendar.current.component(.month, from: .now)

    private var calendar: Calendar { .current }

    private var yearRange: [Int] {
        let thisYear = calendar.component(.year, from: .now)
        return Array((thisYear - 20)...(thisYear + 5))
    }

    var body: some View {
        Button {
            prepare()
            showing = true
        } label: {
            Image(systemName: period.isRange ? "calendar.badge.clock" : "calendar")
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tr("Dönem seç", "Choose period"))
        .sheet(isPresented: $showing) { sheet }
    }

    private var sheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("", selection: $rangeMode.animation()) {
                    Text(tr("Tek Ay", "Single Month")).tag(false)
                    Text(tr("Aralık", "Range")).tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                monthWheels(title: rangeMode ? tr("Başlangıç", "From") : nil,
                            year: $fromYear, month: $fromMonth)

                if rangeMode {
                    monthWheels(title: tr("Bitiş", "To"), year: $toYear, month: $toMonth)
                }

                Text(tr("Hiçbir kayıt silinmez; istediğin kadar geriye gidebilirsin.",
                        "Nothing is ever deleted; you can go as far back as you like."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer(minLength: 0)
            }
            .padding(.top, 8)
            .navigationTitle(tr("Dönem Seç", "Choose Period"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Vazgeç", "Cancel")) { showing = false }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(tr("Bu Ay", "Today")) {
                        period = .thisMonth()
                        showing = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Göster", "Show")) {
                        apply()
                        showing = false
                    }
                }
            }
        }
        .presentationDetents([.height(rangeMode ? 520 : 340)])
    }

    @ViewBuilder
    private func monthWheels(title: String?, year: Binding<Int>, month: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
            HStack(spacing: 0) {
                Picker(tr("Ay", "Month"), selection: month) {
                    ForEach(1...12, id: \.self) { m in Text(monthName(m)).tag(m) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)

                Picker(tr("Yıl", "Year"), selection: year) {
                    ForEach(yearRange, id: \.self) { y in Text(String(y)).tag(y) }
                }
                .pickerStyle(.wheel)
                .frame(maxWidth: .infinity)
            }
            .frame(height: 150)
        }
    }

    private func monthName(_ month: Int) -> String {
        guard let date = calendar.date(from: DateComponents(year: 2000, month: month, day: 1))
        else { return String(month) }
        return date.formatted(.dateTime.month(.wide).locale(appLocale))
    }

    private func prepare() {
        rangeMode = period.isRange
        fromYear = calendar.component(.year, from: period.startMonth)
        fromMonth = calendar.component(.month, from: period.startMonth)
        toYear = calendar.component(.year, from: period.endMonth)
        toMonth = calendar.component(.month, from: period.endMonth)
    }

    private func offset(year: Int, month: Int) -> Int? {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        guard let target = calendar.date(from: DateComponents(year: year, month: month, day: 1))
        else { return nil }
        return calendar.dateComponents([.month], from: thisMonth, to: target).month
    }

    private func apply() {
        guard let start = offset(year: fromYear, month: fromMonth) else { return }
        if rangeMode, let end = offset(year: toYear, month: toMonth) {
            // Ters seçilse bile düzgün çalışsın
            period = PeriodSelection(startOffset: min(start, end), endOffset: max(start, end))
        } else {
            period = PeriodSelection(startOffset: start, endOffset: start)
        }
    }
}
