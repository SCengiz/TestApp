import SwiftUI
import SwiftData
import Charts

struct SummaryView: View {
    @Binding var loggedInUser: String?
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var payments: [FixedPayment]
    @Query private var monthlyAmounts: [PaymentMonthAmount]
    @Query private var paidRecords: [PaidPayment]
    @State private var selectedMonth: Date? // grafikte dokunulan ay
    @State private var detailMonth: MonthSelection? // dökümü açılan ay
    @State private var selectedCategory: ExpenseCategory? // detayı açılan kategori
    @State private var categoryMonthOffset = 0 // Harcama Dağılımı: -3...+3 ay

    private var calendar: Calendar { .current }

    // Her sabit ödemeye sırasına göre renk ata
    private var paymentColors: [String: Color] {
        Dictionary(payments.enumerated().map {
            ($0.element.name, paymentPalette[$0.offset % paymentPalette.count])
        }, uniquingKeysWith: { first, _ in first })
    }

    // Bir ayın ödeme kalemleri (ad, tutar, renk)
    private func paymentBreakdown(for month: Date) -> [(name: String, amount: Double, color: Color)] {
        // Renk tablosu hesaplanan bir özellik: doğrudan map içinde kullanılırsa
        // her ödeme için baştan kuruluyordu. Ödeme planı grafiği bu işlevi 7 ay
        // için çağırdığından maliyet ödeme sayısının karesiyle büyüyordu.
        let colors = paymentColors
        return payments
            .filter { $0.isActive(inMonth: month, calendar: calendar) }
            .map { ($0.name, $0.amount(inMonth: month, monthlyAmounts: monthlyAmounts),
                    colors[$0.name] ?? .blue) }
    }

    // Seçili ayın günlük harcama toplamı
    private var thisMonthTotal: Double {
        expenses
            .filter { calendar.isDate($0.date, equalTo: categoryMonth, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    // Bu ay geçerli olan sabit ödemelerin toplamı.
    // Ham "amount" alanı DEĞİL, o ayın tutarı kullanılır: kredi kartı gibi tutarı
    // her ay değişen ödemelerde ekstre girilmemişse o ay 0 sayılır.
    private var fixedTotal: Double {
        payments
            .filter { $0.isActive(inMonth: categoryMonth, calendar: calendar) }
            .reduce(0) { $0 + $1.amount(inMonth: categoryMonth, monthlyAmounts: monthlyAmounts,
                                        calendar: calendar) }
    }

    // Aylık durum: 3 ay geri + bu ay + 3 ay ileri, sadece sabit giderler
    // (Günlük harcamalar kredi kartıyla yapılıp ekstre olarak sabitlerde ödendiği
    //  için toplam gider = sabit giderler; ayrıca toplamak çift sayma olur.)
    private var monthlyStatus: [(date: Date, fixed: Double, isFuture: Bool)] {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        return (-3...3).map { offset in
            let month = calendar.date(byAdding: .month, value: offset, to: thisMonth)!
            let fixed = payments
                .filter { $0.isActive(inMonth: month, calendar: calendar) }
                .reduce(0) { $0 + $1.amount(inMonth: month, monthlyAmounts: monthlyAmounts,
                                            calendar: calendar) }
            return (month, fixed, offset > 0)
        }
    }

    // Harcama Dağılımı'nda görüntülenen ay (oklarla -3...+3 gezilir)
    private var categoryMonth: Date {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        return calendar.date(byAdding: .month, value: categoryMonthOffset, to: thisMonth)!
    }

    private var categoryMonthTotal: Double {
        expenses
            .filter { calendar.isDate($0.date, equalTo: categoryMonth, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    // Seçili ayın kategori kategori toplamları (büyükten küçüğe)
    private var categoryTotals: [(category: ExpenseCategory, total: Double)] {
        let monthExpenses = expenses.filter {
            calendar.isDate($0.date, equalTo: categoryMonth, toGranularity: .month)
        }
        let groups = Dictionary(grouping: monthExpenses) { $0.category }
        return groups
            .map { (ExpenseCategory.named($0.key), $0.value.reduce(0) { $0 + $1.amount }) }
            .filter { $0.1 > 0 } // o ay harcaması olmayan kategori listede görünmez
            .sorted { $0.total > $1.total }
    }

    // Sayfanın tepesindeki ay seçici: hem iki kutuyu hem de dağılımı yönetir
    private var monthPicker: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation { categoryMonthOffset -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.bold))
                    .foregroundStyle(categoryMonthOffset > -3 ? Color.accentColor : .gray.opacity(0.35))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
            }
            .buttonStyle(.plain)
            .disabled(categoryMonthOffset <= -3)

            Text(categoryMonth, format: .dateTime.month(.wide).year().locale(appLocale))
                .font(.headline)
                .frame(maxWidth: .infinity)

            Button {
                withAnimation { categoryMonthOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.bold))
                    .foregroundStyle(categoryMonthOffset < 3 ? Color.accentColor : .gray.opacity(0.35))
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color(.secondarySystemGroupedBackground)))
            }
            .buttonStyle(.plain)
            .disabled(categoryMonthOffset >= 3)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    monthPicker

                    // Kutulara dokununca ilgili sayfa açılır
                    HStack(spacing: 12) {
                        NavigationLink {
                            DailyExpensesView(startMonthOffset: categoryMonthOffset)
                        } label: {
                            StatCard(
                                title: tr("Harcamalarım", "My Spending"),
                                amount: thisMonthTotal,
                                icon: "creditcard.fill",
                                colors: [.pink, .red]
                            )
                        }

                        NavigationLink {
                            FixedPaymentsView(startMonthOffset: categoryMonthOffset)
                        } label: {
                            StatCard(
                                title: tr("Ödemelerim", "My Payments"),
                                amount: fixedTotal,
                                icon: "building.columns.fill",
                                colors: [.blue, .cyan]
                            )
                        }
                    }
                    .buttonStyle(.plain)
                    .fixedSize(horizontal: false, vertical: true)

                    // Kategori dağılımı: halka grafik + liste (ay tepeden seçilir)
                    VStack(alignment: .leading, spacing: 14) {
                        Label(tr("Harcama Dağılımı", "Spending Breakdown"),
                              systemImage: "chart.pie.fill")
                            .font(.headline)

                        if categoryTotals.isEmpty {
                            Text(categoryMonthOffset > 0
                                 ? tr("Bu aya planlanmış harcama yok (taksitli alışverişler burada görünür).", "No planned spending for this month (installments show up here).")
                                 : tr("Bu ayda harcama yok.", "No spending this month."))
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
                                    Text(tr("Toplam", "Total"))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(categoryMonthTotal, format: .currency(code: "TRY"))
                                        .font(.headline)
                                }
                            }

                            ForEach(categoryTotals, id: \.category) { item in
                                Button {
                                    selectedCategory = item.category
                                } label: {
                                    HStack(spacing: 12) {
                                        RowIcon(systemName: item.category.icon, color: item.category.color)
                                        Text(item.category.displayName)
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(item.total, format: .currency(code: "TRY"))
                                                .font(.callout.weight(.semibold))
                                            Text(categoryMonthTotal > 0
                                                 ? "%\(Int((item.total / categoryMonthTotal * 100).rounded()))"
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
                        Label(tr("Ödeme Planı", "Payment Plan"), systemImage: "chart.bar.fill")
                            .font(.headline)

                        Chart {
                            // Her ay: kalemler farklı renklerde üst üste biner
                            ForEach(monthlyStatus, id: \.date) { item in
                                ForEach(paymentBreakdown(for: item.date), id: \.name) { seg in
                                    BarMark(
                                        x: .value("Ay", item.date, unit: .month),
                                        y: .value("Tutar", seg.amount)
                                    )
                                    .foregroundStyle(seg.color.gradient)
                                    .cornerRadius(2)
                                    .opacity(item.isFuture ? 0.45 : 1)
                                }
                            }

                            // Bugünü işaretle (yazısız, sadece kesikli çizgi)
                            RuleMark(x: .value("Bugün", Date.now, unit: .month))
                                .foregroundStyle(.secondary.opacity(0.5))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        }
                        .chartOverlay { proxy in
                            GeometryReader { geo in
                                Rectangle()
                                    .fill(Color.clear)
                                    .contentShape(Rectangle())
                                    .onTapGesture { location in
                                        // Tek dokunuşla o ayın dökümünü aç
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let x = location.x - geo[plotFrame].origin.x
                                        if let date: Date = proxy.value(atX: x) {
                                            detailMonth = MonthSelection(date: date)
                                        }
                                    }
                            }
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) {
                                AxisValueLabel(format: .dateTime.month(.abbreviated).locale(appLocale))
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
            .navigationTitle(tr("Giderler", "Expenses"))
            // Kategoriye dokununca alttan açılan yarım ekran detay paneli
            .sheet(item: $selectedCategory) { category in
                CategoryDetailSheet(
                    category: category,
                    expenses: monthExpenses(for: category)
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            // Ödeme Planı çubuğuna dokununca ayın kalem dökümü
            .sheet(item: $detailMonth) { selection in
                MonthBreakdownSheet(
                    heading: tr("Ödemeler", "Payments"),
                    month: selection.date,
                    items: paymentBreakdown(for: selection.date)
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ProfileButton(loggedInUser: $loggedInUser)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    RemindersButton(payments: payments, paidRecords: paidRecords,
                                    monthlyAmounts: monthlyAmounts)
                }
            }
            .onAppear {
                // Ödeme hatırlatmaları: izin iste ve planı tazele
                PaymentReminders.requestAuthorization()
                PaymentReminders.reschedule(payments: payments, paidRecords: paidRecords,
                                            monthlyAmounts: monthlyAmounts)
            }
        }
    }

    // Belirli bir tarihin ait olduğu gün/ay/yıl içindeki harcama toplamı
    private func totalIn(_ date: Date, unit: Calendar.Component) -> Double {
        expenses
            .filter { calendar.isDate($0.date, equalTo: date, toGranularity: unit) }
            .reduce(0) { $0 + $1.amount }
    }

    // Seçili ayda, seçilen kategorideki harcamalar (yeniden eskiye)
    private func monthExpenses(for category: ExpenseCategory) -> [Expense] {
        expenses
            .filter {
                $0.category == category.name &&
                calendar.isDate($0.date, equalTo: categoryMonth, toGranularity: .month)
            }
            .sorted { $0.date > $1.date }
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
                        Text(tr("Bu Ay Toplam", "This Month Total"))
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
            .navigationTitle(category.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .overlay {
                if expenses.isEmpty {
                    ContentUnavailableView(
                        tr("Bu ay harcama yok", "No spending this month"),
                        systemImage: category.icon,
                        description: Text(tr("\(category.name) kategorisinde bu ay kayıt bulunmuyor.", "No records in \(category.displayName) this month."))
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
