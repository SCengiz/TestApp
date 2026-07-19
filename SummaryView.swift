import SwiftUI
import SwiftData
import Charts

struct SummaryView: View {
    @Binding var loggedInUser: String?
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var payments: [FixedPayment]
    @State private var selectedMonth: Date? // grafikte dokunulan ay
    @State private var selectedCategory: ExpenseCategory? // detayı açılan kategori

    private var calendar: Calendar { .current }

    // Dokunulan ayın verileri
    private var selectedStatus: (date: Date, fixed: Double, isFuture: Bool)? {
        guard let selectedMonth else { return nil }
        return monthlyStatus.first {
            calendar.isDate($0.date, equalTo: selectedMonth, toGranularity: .month)
        }
    }

    // Bu ayın günlük harcama toplamı
    private var thisMonthTotal: Double {
        expenses
            .filter { calendar.isDate($0.date, equalTo: .now, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    // Bu ay geçerli olan sabit ödemelerin toplamı
    private var fixedTotal: Double {
        payments
            .filter { $0.isActive(inMonth: .now, calendar: calendar) }
            .reduce(0) { $0 + $1.amount }
    }

    // Aylık durum: 6 ay geri + bu ay + 6 ay ileri, sadece sabit giderler
    // (Günlük harcamalar kredi kartıyla yapılıp ekstre olarak sabitlerde ödendiği
    //  için toplam gider = sabit giderler; ayrıca toplamak çift sayma olur.)
    private var monthlyStatus: [(date: Date, fixed: Double, isFuture: Bool)] {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        return (-6...6).map { offset in
            let month = calendar.date(byAdding: .month, value: offset, to: thisMonth)!
            let fixed = payments
                .filter { $0.isActive(inMonth: month, calendar: calendar) }
                .reduce(0) { $0 + $1.amount }
            return (month, fixed, offset > 0)
        }
    }

    // Bu ay kategori kategori toplamlar (büyükten küçüğe)
    private var categoryTotals: [(category: ExpenseCategory, total: Double)] {
        let monthExpenses = expenses.filter {
            calendar.isDate($0.date, equalTo: .now, toGranularity: .month)
        }
        let groups = Dictionary(grouping: monthExpenses) { $0.category }
        return groups
            .map { (ExpenseCategory.named($0.key), $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // Kutulara dokununca ilgili sayfa açılır
                    HStack(spacing: 12) {
                        NavigationLink {
                            DailyExpensesView()
                        } label: {
                            StatCard(
                                title: "Harcamalarım",
                                amount: thisMonthTotal,
                                icon: "creditcard.fill",
                                colors: [.pink, .red]
                            )
                        }

                        NavigationLink {
                            FixedPaymentsView()
                        } label: {
                            StatCard(
                                title: "Ödemelerim",
                                amount: fixedTotal,
                                icon: "building.columns.fill",
                                colors: [.blue, .cyan]
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: false, vertical: true)

                    // Bu ay kategori dağılımı: halka grafik + liste
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Harcama Dağılımı", systemImage: "chart.pie.fill")
                            .font(.headline)

                        if categoryTotals.isEmpty {
                            Text("Bu ay henüz harcama yok.")
                                .foregroundStyle(.secondary)
                        } else {
                            Chart(categoryTotals, id: \.category) { item in
                                SectorMark(
                                    angle: .value("Tutar", item.total),
                                    innerRadius: .ratio(0.62),
                                    angularInset: 2
                                )
                                .foregroundStyle(item.category.color.gradient)
                                .cornerRadius(4)
                            }
                            .frame(height: 210)
                            .chartBackground { _ in
                                VStack(spacing: 2) {
                                    Text("Toplam")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(thisMonthTotal, format: .currency(code: "TRY"))
                                        .font(.headline)
                                }
                            }

                            ForEach(categoryTotals, id: \.category) { item in
                                Button {
                                    selectedCategory = item.category
                                } label: {
                                    HStack(spacing: 12) {
                                        RowIcon(systemName: item.category.icon, color: item.category.color)
                                        Text(item.category.name)
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(item.total, format: .currency(code: "TRY"))
                                                .font(.callout.weight(.semibold))
                                            Text(thisMonthTotal > 0
                                                 ? "%\(Int((item.total / thisMonthTotal * 100).rounded()))"
                                                 : "%0")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Image(systemName: "chevron.right")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )

                    // Aylık durum: 6 ay geri + bu ay + 6 ay ileri, sabit giderler (gelecek = plan)
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Ödeme Planı", systemImage: "chart.bar.fill")
                            .font(.headline)

                        Chart {
                            ForEach(monthlyStatus, id: \.date) { item in
                                BarMark(
                                    x: .value("Ay", item.date, unit: .month),
                                    y: .value("Tutar", item.fixed)
                                )
                                .foregroundStyle(
                                    LinearGradient(colors: [.blue, .cyan],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                                .cornerRadius(4)
                                .opacity(item.isFuture ? 0.45 : 1)
                            }

                            // Bugünü işaretle (yazısız, sadece kesikli çizgi)
                            RuleMark(x: .value("Bugün", Date.now, unit: .month))
                                .foregroundStyle(.secondary.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))

                            // Dokunulan ayı ince çizgiyle vurgula
                            if let sel = selectedStatus {
                                RuleMark(x: .value("Seçili", sel.date, unit: .month))
                                    .foregroundStyle(.secondary.opacity(0.35))
                            }
                        }
                        .chartXSelection(value: $selectedMonth)
                        // Baloncuk yüzen katmanda çizilir: yerleşimi etkilemez, grafik kaymaz
                        .chartOverlay { proxy in
                            GeometryReader { geo in
                                if let sel = selectedStatus,
                                   let plotAnchor = proxy.plotFrame,
                                   let center = calendar.date(byAdding: .day, value: 15, to: sel.date),
                                   let xInPlot = proxy.position(forX: center) {
                                    let plotFrame = geo[plotAnchor]
                                    let bubbleWidth: CGFloat = 190
                                    let rawX = plotFrame.minX + xInPlot
                                    let x = min(max(rawX, bubbleWidth / 2 + 2),
                                                geo.size.width - bubbleWidth / 2 - 2)
                                    tooltip(for: sel)
                                        .frame(width: bubbleWidth)
                                        .position(x: x, y: 52)
                                        .allowsHitTesting(false)
                                }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) {
                                AxisValueLabel(format: .dateTime.month(.narrow))
                            }
                        }
                        .frame(height: 220)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )



                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Giderler")
            // Kategoriye dokununca alttan açılan yarım ekran detay paneli
            .sheet(item: $selectedCategory) { category in
                CategoryDetailSheet(
                    category: category,
                    expenses: monthExpenses(for: category)
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let user = loggedInUser {
                            Text("Giriş: \(user)")
                        }
                        Button(role: .destructive) {
                            loggedInUser = nil
                        } label: {
                            Label("Çıkış Yap", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "person.crop.circle.fill")
                    }
                }
            }
        }
    }

    // Belirli bir tarihin ait olduğu gün/ay/yıl içindeki harcama toplamı
    private func totalIn(_ date: Date, unit: Calendar.Component) -> Double {
        expenses
            .filter { calendar.isDate($0.date, equalTo: date, toGranularity: unit) }
            .reduce(0) { $0 + $1.amount }
    }

    // Bu ay, seçilen kategorideki harcamalar (yeniden eskiye)
    private func monthExpenses(for category: ExpenseCategory) -> [Expense] {
        expenses
            .filter {
                $0.category == category.name &&
                calendar.isDate($0.date, equalTo: .now, toGranularity: .month)
            }
            .sorted { $0.date > $1.date }
    }

    // Dokunulan ayın detay baloncuğu
    private func tooltip(for sel: (date: Date, fixed: Double, isFuture: Bool)) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(sel.date, format: .dateTime.month(.wide).year())
                .font(.subheadline.bold())
            tooltipRow(sel.isFuture ? "Plan" : "Sabit Gider", sel.fixed, bold: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        )
    }

    private func tooltipRow(_ label: String, _ amount: Double, bold: Bool = false) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(amount, format: .currency(code: "TRY"))
                .fontWeight(bold ? .bold : .regular)
        }
        .font(.footnote)
    }
}

// Kategoriye dokununca açılan yarım ekran detay paneli
struct CategoryDetailSheet: View {
    let category: ExpenseCategory
    let expenses: [Expense]

    private var total: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        RowIcon(systemName: category.icon, color: category.color)
                        Text("Bu Ay Toplam")
                            .font(.headline)
                        Spacer()
                        Text(total, format: .currency(code: "TRY"))
                            .font(.title3.bold())
                            .foregroundStyle(category.color)
                    }
                }

                Section {
                    ForEach(expenses) { expense in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(expense.title)
                                Text(expense.date, format: .dateTime.day().month(.wide).weekday(.wide))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(expense.amount, format: .currency(code: "TRY"))
                                .font(.callout.weight(.semibold))
                        }
                    }
                }
            }
            .navigationTitle(category.name)
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if expenses.isEmpty {
                    ContentUnavailableView(
                        "Bu ay harcama yok",
                        systemImage: category.icon,
                        description: Text("\(category.name) kategorisinde bu ay kayıt bulunmuyor.")
                    )
                }
            }
        }
    }
}

#Preview {
    SummaryView(loggedInUser: .constant("soray"))
        .modelContainer(for: [Expense.self, FixedPayment.self], inMemory: true)
}
