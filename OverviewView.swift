import SwiftUI
import SwiftData

// MARK: - Özet sekmesi
// O ayki maaşımı nelere dağıttım? Gelir soldan; ödemelere, birikime ve
// kalana doğru akar (appeconomyinsights tarzı Sankey akış grafiği).

struct OverviewView: View {
    @Binding var loggedInUser: String?
    @Environment(\.modelContext) private var modelContext
    @Query private var incomes: [IncomeSource]
    @Query(sort: \IncomeSnapshot.monthStart) private var incomeSnapshots: [IncomeSnapshot]
    @Query private var payments: [FixedPayment]
    @Query private var assets: [Asset]

    @State private var monthOffset = 0 // -3 (3 ay geri) ... +3 (3 ay ileri)

    private var calendar: Calendar { .current }

    private var selectedMonth: Date {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        return calendar.date(byAdding: .month, value: monthOffset, to: thisMonth)!
    }

    // MARK: Aylık veriler

    // Gelir: bu ay ve gelecek = güncel kaynaklar; geçmiş = o ayın fotoğrafı
    private var income: Double {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        if selectedMonth >= thisMonth {
            return incomes.reduce(0) { $0 + $1.amount }
        }
        if let exact = incomeSnapshots.first(where: {
            calendar.isDate($0.monthStart, equalTo: selectedMonth, toGranularity: .month)
        }) {
            return exact.total
        }
        if let earlier = incomeSnapshots.last(where: { $0.monthStart < selectedMonth }) {
            return earlier.total
        }
        return incomes.reduce(0) { $0 + $1.amount }
    }

    // Ödemeler: o ay geçerli sabit ödemeler, parça parça
    private var paymentItems: [(name: String, amount: Double, color: Color)] {
        payments
            .filter { $0.isActive(inMonth: selectedMonth) }
            .enumerated()
            .map { (idx, p) in
                (p.name, p.amount, paymentPalette[idx % paymentPalette.count])
            }
    }

    // Birikime ayrılan para: o ay yapılan alışlar (para girişi), hesap bazında
    private var savingsItems: [(name: String, amount: Double, color: Color)] {
        var byAccount: [String: (amount: Double, color: Color)] = [:]
        for asset in assets {
            let kind = SavingsAccount(rawValue: asset.account?.kind ?? "cash") ?? .cash
            let accountName = asset.account?.name ?? asset.name
            for tx in asset.transactions where tx.quantity > 0 {
                guard calendar.isDate(tx.date, equalTo: selectedMonth, toGranularity: .month) else { continue }
                let price = tx.pricePerUnit ?? (asset.accountKind == "cash" ? 1 : asset.unitPrice)
                let put = tx.quantity * price
                byAccount[accountName, default: (0, kind.color)].amount += put
            }
        }
        return byAccount
            .map { (localizedDataName($0.key), $0.value.amount, $0.value.color) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
    }

    private var paymentsTotal: Double { paymentItems.reduce(0) { $0 + $1.amount } }
    private var savingsTotal: Double { savingsItems.reduce(0) { $0 + $1.amount } }
    private var remaining: Double { income - paymentsTotal - savingsTotal }

    // Akış grafiğinin sağ tarafındaki düğümler (ödemeler + birikim + kalan)
    private var flowNodes: [FlowNode] {
        var nodes: [FlowNode] = []
        for item in paymentItems {
            nodes.append(FlowNode(name: item.name, amount: item.amount, color: item.color, group: .payment))
        }
        for item in savingsItems {
            nodes.append(FlowNode(name: item.name, amount: item.amount, color: item.color, group: .savings))
        }
        if remaining > 0 {
            nodes.append(FlowNode(name: tr("Kalan", "Remaining"), amount: remaining, color: .green, group: .remaining))
        }
        return nodes
    }

    private var hasData: Bool { income > 0 || !flowNodes.isEmpty }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    monthHeader
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if hasData {
                    Section {
                        summaryChips
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }

                    Section {
                        VStack(alignment: .leading, spacing: 14) {
                            Label(tr("Para Akışı", "Money Flow"), systemImage: "arrow.left.arrow.right")
                                .font(.headline)
                            Text(tr("Bu ayki gelirini nelere dağıttığını gösterir.", "Shows how you spread this month's income."))
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            SankeyFlowView(income: income, nodes: flowNodes)
                                .frame(height: sankeyHeight)
                                .padding(.vertical, 4)
                        }
                        .padding(.vertical, 6)
                    }

                    Section {
                        ForEach(flowNodes) { node in
                            HStack(spacing: 12) {
                                RowIcon(systemName: node.group.icon, color: node.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(node.name)
                                    Text(node.group.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(node.amount, format: .currency(code: "TRY"))
                                        .font(.callout.weight(.semibold))
                                    if income > 0 {
                                        Text("%\(Int((node.amount / income * 100).rounded()))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    } header: {
                        Text(tr("Dağılım", "Breakdown"))
                    } footer: {
                        if remaining < 0 {
                            Text(tr("Bu ay ödeme ve birikimlerin gelirini \(abs(remaining).formatted(.currency(code: "TRY"))) aştı.", "This month payments and savings exceeded your income by \(abs(remaining).formatted(.currency(code: "TRY")))."))
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(tr("Özet", "Overview"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileButton(loggedInUser: $loggedInUser)
                }
            }
            .overlay {
                if !hasData {
                    ContentUnavailableView(
                        tr("Bu ay için veri yok", "No data for this month"),
                        systemImage: "chart.bar.doc.horizontal",
                        description: Text(tr("Gelir, ödeme veya birikim ekledikçe maaşının dağılımı burada görünür.", "As you add income, payments or savings, your salary breakdown shows up here."))
                    )
                }
            }
            .onAppear { syncIncomeSnapshot(modelContext) }
        }
    }

    // Düğüm sayısına göre grafik yüksekliği
    private var sankeyHeight: CGFloat {
        max(280, CGFloat(max(flowNodes.count, 1)) * 56)
    }

    private var monthHeader: some View {
        HStack {
            monthArrow("chevron.left", enabled: monthOffset > -3) { monthOffset -= 1 }
            Spacer()
            VStack(spacing: 2) {
                Text(selectedMonth.formatted(.dateTime.month(.wide).year().locale(appLocale)))
                    .font(.title3.weight(.semibold))
                if monthOffset == 0 {
                    Text(tr("Bu ay", "This month"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            monthArrow("chevron.right", enabled: monthOffset < 3) { monthOffset += 1 }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var summaryChips: some View {
        HStack(spacing: 10) {
            overviewChip(tr("Gelir", "Income"), income, .green)
            overviewChip(tr("Ödeme", "Payments"), paymentsTotal, .blue)
            overviewChip(tr("Birikim", "Savings"), savingsTotal, .purple)
            overviewChip(tr("Kalan", "Remaining"), remaining, remaining >= 0 ? .teal : .red)
        }
    }

    private func overviewChip(_ title: String, _ amount: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(amount, format: .currency(code: "TRY"))
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(color.opacity(0.12)))
    }

    private func monthArrow(_ icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .foregroundStyle(enabled ? Color.accentColor : .gray.opacity(0.4))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color.accentColor.opacity(enabled ? 0.12 : 0.05)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

// MARK: - Akış düğümü modeli

struct FlowNode: Identifiable {
    let id = UUID()
    let name: String
    let amount: Double
    let color: Color
    let group: FlowGroup
}

enum FlowGroup {
    case payment, savings, remaining

    var label: String {
        switch self {
        case .payment:   return tr("Ödeme", "Payment")
        case .savings:   return tr("Birikim", "Savings")
        case .remaining: return tr("Maaştan kalan", "Left from income")
        }
    }

    var icon: String {
        switch self {
        case .payment:   return "building.columns.fill"
        case .savings:   return "chart.line.uptrend.xyaxis"
        case .remaining: return "wallet.pass.fill"
        }
    }
}

// MARK: - Sankey akış grafiği
// Solda tek "Gelir" düğümü; sağda ödeme/birikim/kalan düğümleri.
// Her düğüme geliri değerine göre kavisli bir şerit akar.

struct SankeyFlowView: View {
    let income: Double
    let nodes: [FlowNode]

    private let nodeWidth: CGFloat = 12
    private let gap: CGFloat = 6 // sağ düğümler arası boşluk

    var body: some View {
        GeometryReader { geo in
            let W = geo.size.width
            let H = geo.size.height
            // Ölçek: soldaki gelir çubuğu + sağdaki şeritler aynı toplam yüksekliği paylaşır
            let outflow = nodes.reduce(0) { $0 + $1.amount }
            let total = max(income, outflow, 1)
            let gapsTotal = gap * CGFloat(max(nodes.count - 1, 0))
            let usableH = max(H - gapsTotal, 1)
            let scale = usableH / total

            // Sağ düğüm konumları (boşluklu)
            let rightLayout = rightNodeLayout(scale: scale)
            // Sol tarafta şeritlerin başlangıç yığını (boşluksuz, düğüm sırasıyla)
            let leftHeights = nodes.map { $0.amount * scale }

            ZStack(alignment: .topLeading) {
                // Şeritler
                Canvas { ctx, size in
                    let xL = nodeWidth
                    let xR = size.width - nodeWidth
                    var cumL: CGFloat = 0
                    for (i, node) in nodes.enumerated() {
                        let h = leftHeights[i]
                        let topL = cumL
                        let topR = rightLayout[i].y
                        var path = Path()
                        path.move(to: CGPoint(x: xL, y: topL))
                        path.addCurve(
                            to: CGPoint(x: xR, y: topR),
                            control1: CGPoint(x: (xL + xR) / 2, y: topL),
                            control2: CGPoint(x: (xL + xR) / 2, y: topR)
                        )
                        path.addLine(to: CGPoint(x: xR, y: topR + h))
                        path.addCurve(
                            to: CGPoint(x: xL, y: topL + h),
                            control1: CGPoint(x: (xL + xR) / 2, y: topR + h),
                            control2: CGPoint(x: (xL + xR) / 2, y: topL + h)
                        )
                        path.closeSubpath()
                        ctx.fill(path, with: .color(node.color.opacity(0.28)))
                        cumL += h
                    }
                }

                // Sol "Gelir" düğümü
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.green.gradient)
                    .frame(width: nodeWidth, height: income * scale)
                    .position(x: nodeWidth / 2, y: income * scale / 2)

                // Sağ düğümler + etiketleri
                ForEach(Array(nodes.enumerated()), id: \.element.id) { i, node in
                    let layout = rightLayout[i]
                    RoundedRectangle(cornerRadius: 3)
                        .fill(node.color.gradient)
                        .frame(width: nodeWidth, height: layout.height)
                        .position(x: W - nodeWidth / 2, y: layout.y + layout.height / 2)

                    Text(node.name)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(.primary)
                        .frame(width: W * 0.42, alignment: .trailing)
                        .position(x: W - nodeWidth - 4 - (W * 0.42) / 2,
                                  y: layout.y + layout.height / 2)
                }

                // Sol düğüm etiketi
                Text(tr("Gelir", "Income"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .fixedSize()
                    .position(x: nodeWidth + 4 + 22, y: income * scale / 2)
            }
        }
    }

    // Sağ düğümlerin dikey yerleşimi (yukarıdan aşağı, aralarında boşlukla)
    private func rightNodeLayout(scale: CGFloat) -> [(y: CGFloat, height: CGFloat)] {
        var result: [(CGFloat, CGFloat)] = []
        var cursor: CGFloat = 0
        for node in nodes {
            let h = node.amount * scale
            result.append((cursor, h))
            cursor += h + gap
        }
        return result
    }
}
