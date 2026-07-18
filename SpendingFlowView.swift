import SwiftUI

// Sankey tarzı akış grafiği: soldaki toplam, sağdaki kategorilere dallanır.
// Şerit kalınlığı = o kategorinin payı.
struct SpendingFlowView: View {
    struct Item: Identifiable {
        let category: ExpenseCategory
        let amount: Double
        var id: String { category.id }
    }

    let items: [Item] // büyükten küçüğe sıralı
    let onSelect: (ExpenseCategory) -> Void

    private let rowGap: CGFloat = 6      // sağdaki dallar arası boşluk
    private let minRowHeight: CGFloat = 30 // etiketin sığması için en az dal kalınlığı
    private let leftBarWidth: CGFloat = 16
    private let nodeWidth: CGFloat = 5
    private let labelWidth: CGFloat = 148

    private var total: Double { items.reduce(0) { $0 + $1.amount } }

    var body: some View {
        let height = max(280, CGFloat(items.count) * 36)
        GeometryReader { geo in
            let rows = layoutRows(width: geo.size.width, height: geo.size.height)
            let nodeX = geo.size.width - labelWidth

            ZStack(alignment: .topLeading) {
                // Akış şeritleri
                ForEach(Array(zip(items, rows)), id: \.0.id) { item, row in
                    FlowRibbon(
                        x0: leftBarWidth, y0a: row.leftY0, y0b: row.leftY1,
                        x1: nodeX, y1a: row.rightY0, y1b: row.rightY1
                    )
                    .fill(
                        LinearGradient(
                            colors: [item.category.color.opacity(0.35),
                                     item.category.color.opacity(0.75)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                }

                // Soldaki kök bar (kategori renkleriyle dilimli)
                VStack(spacing: 0) {
                    ForEach(Array(zip(items, rows)), id: \.0.id) { item, row in
                        Rectangle()
                            .fill(item.category.color)
                            .frame(height: row.leftY1 - row.leftY0)
                    }
                }
                .frame(width: leftBarWidth)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .position(x: leftBarWidth / 2,
                          y: (rows.first?.leftY0 ?? 0) + leftTotalHeight(rows) / 2)

                // Sağdaki dal uçları ve etiketler
                ForEach(Array(zip(items, rows)), id: \.0.id) { item, row in
                    let midY = (row.rightY0 + row.rightY1) / 2

                    Capsule()
                        .fill(item.category.color)
                        .frame(width: nodeWidth, height: row.rightY1 - row.rightY0)
                        .position(x: nodeX + nodeWidth / 2, y: midY)

                    Button {
                        onSelect(item.category)
                    } label: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.category.name)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                            Text("\(item.amount, format: .currency(code: "TRY").precision(.fractionLength(0))) · %\(total > 0 ? Int((item.amount / total * 100).rounded()) : 0)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        .frame(width: labelWidth - nodeWidth - 10, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .position(x: nodeX + nodeWidth + 6 + (labelWidth - nodeWidth - 10) / 2,
                              y: midY)
                }
            }
        }
        .frame(height: height)
    }

    // Her satırın sol ve sağ dikey aralıklarını hesapla
    private struct RowLayout {
        var leftY0: CGFloat = 0, leftY1: CGFloat = 0
        var rightY0: CGFloat = 0, rightY1: CGFloat = 0
    }

    private func leftTotalHeight(_ rows: [RowLayout]) -> CGFloat {
        guard let first = rows.first, let last = rows.last else { return 0 }
        return last.leftY1 - first.leftY0
    }

    private func layoutRows(width: CGFloat, height: CGFloat) -> [RowLayout] {
        let count = items.count
        guard count > 0, total > 0 else { return [] }

        let available = height - rowGap * CGFloat(count - 1)

        // Sağ dallar: paya göre, ama etiket sığsın diye alt sınırlı
        var rightHeights = items.map { max(minRowHeight, available * $0.amount / total) }
        // Alt sınır yüzünden taşan miktarı büyük dallardan kırp
        let excess = rightHeights.reduce(0, +) - available
        if excess > 0 {
            let flexible = rightHeights.enumerated().filter { $0.element > minRowHeight }
            let flexTotal = flexible.reduce(0) { $0 + ($1.element - minRowHeight) }
            if flexTotal > 0 {
                for (i, h) in flexible {
                    rightHeights[i] = h - excess * (h - minRowHeight) / flexTotal
                }
            }
        }

        // Sol dilimler: saf paya göre (kök bar), dikeyde ortalı
        let leftHeights = items.map { available * $0.amount / total }
        let leftStart = (height - leftHeights.reduce(0, +)) / 2

        var rows: [RowLayout] = []
        var ly = leftStart
        var ry: CGFloat = 0
        for i in 0..<count {
            var row = RowLayout()
            row.leftY0 = ly
            row.leftY1 = ly + leftHeights[i]
            ly = row.leftY1
            row.rightY0 = ry
            row.rightY1 = ry + rightHeights[i]
            ry = row.rightY1 + rowGap
            rows.append(row)
        }
        return rows
    }
}

// İki dikey aralığı birbirine bağlayan kavisli şerit
private struct FlowRibbon: Shape {
    let x0: CGFloat, y0a: CGFloat, y0b: CGFloat
    let x1: CGFloat, y1a: CGFloat, y1b: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let mx = (x0 + x1) / 2
        p.move(to: CGPoint(x: x0, y: y0a))
        p.addCurve(to: CGPoint(x: x1, y: y1a),
                   control1: CGPoint(x: mx, y: y0a),
                   control2: CGPoint(x: mx, y: y1a))
        p.addLine(to: CGPoint(x: x1, y: y1b))
        p.addCurve(to: CGPoint(x: x0, y: y0b),
                   control1: CGPoint(x: mx, y: y1b),
                   control2: CGPoint(x: mx, y: y0b))
        p.closeSubpath()
        return p
    }
}
