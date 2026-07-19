import SwiftUI

// Renkli özet kartı: başlık + tutar, degrade arka plan
struct StatCard: View {
    let title: String
    let amount: Double
    let icon: String
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(amount, format: .currency(code: "TRY"))
                .font(.title2.bold())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
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
                            Text("Toplam")
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
            .navigationTitle(month.formatted(.dateTime.month(.wide).year()))
            .navigationBarTitleDisplayMode(.inline)
        }
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
