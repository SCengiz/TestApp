import SwiftUI
import SwiftData
import Charts

struct SummaryView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var payments: [FixedPayment]

    private var calendar: Calendar { .current }

    // Bu ayın günlük harcama toplamı
    private var thisMonthTotal: Double {
        expenses
            .filter { calendar.isDate($0.date, equalTo: .now, toGranularity: .month) }
            .reduce(0) { $0 + $1.amount }
    }

    // Aylık sabit ödemelerin toplamı
    private var fixedTotal: Double {
        payments.reduce(0) { $0 + $1.amount }
    }

    // Son 7 günün gün gün toplamları
    private var last7Days: [(date: Date, total: Double)] {
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            return (day, totalIn(day, unit: .day))
        }
    }

    // Son 6 ayın toplamları
    private var last6Months: [(date: Date, total: Double)] {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        return (0..<6).reversed().map { offset in
            let month = calendar.date(byAdding: .month, value: -offset, to: thisMonth)!
            return (month, totalIn(month, unit: .month))
        }
    }

    // Son 5 yılın toplamları
    private var last5Years: [(date: Date, total: Double)] {
        let thisYear = calendar.dateInterval(of: .year, for: .now)!.start
        return (0..<5).reversed().map { offset in
            let year = calendar.date(byAdding: .year, value: -offset, to: thisYear)!
            return (year, totalIn(year, unit: .year))
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        StatCard(
                            title: "Bu Ay Harcama",
                            amount: thisMonthTotal,
                            icon: "cart.fill",
                            colors: [.pink, .red]
                        )
                        StatCard(
                            title: "Sabit Yük",
                            amount: fixedTotal,
                            icon: "creditcard.fill",
                            colors: [.orange, .yellow]
                        )
                    }

                    StatCard(
                        title: "Bu Ay Toplam Gider",
                        amount: thisMonthTotal + fixedTotal,
                        icon: "chart.pie.fill",
                        colors: [.indigo, .blue]
                    )

                    chartCard(title: "Son 7 Gün", icon: "calendar") {
                        barChart(last7Days, unit: .day, colors: [.blue, .indigo],
                                 axis: .dateTime.weekday(.abbreviated))
                    }

                    chartCard(title: "Aylık Gidişat", icon: "chart.line.uptrend.xyaxis") {
                        barChart(last6Months, unit: .month, colors: [.teal, .green],
                                 axis: .dateTime.month(.abbreviated))
                    }

                    chartCard(title: "Yıllık Gidişat", icon: "calendar.badge.clock") {
                        barChart(last5Years, unit: .year, colors: [.purple, .pink],
                                 axis: .dateTime.year())
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Özet")
        }
    }

    // Belirli bir tarihin ait olduğu gün/ay/yıl içindeki harcama toplamı
    private func totalIn(_ date: Date, unit: Calendar.Component) -> Double {
        expenses
            .filter { calendar.isDate($0.date, equalTo: date, toGranularity: unit) }
            .reduce(0) { $0 + $1.amount }
    }

    // Ortak çubuk grafik
    private func barChart(
        _ data: [(date: Date, total: Double)],
        unit: Calendar.Component,
        colors: [Color],
        axis: Date.FormatStyle
    ) -> some View {
        Chart(data, id: \.date) { item in
            BarMark(
                x: .value("Dönem", item.date, unit: unit),
                y: .value("Tutar", item.total)
            )
            .foregroundStyle(
                LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            )
            .cornerRadius(6)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: unit)) {
                AxisValueLabel(format: axis)
            }
        }
        .frame(height: 180)
    }

    // Grafikleri saran beyaz köşeli kart
    private func chartCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

#Preview {
    SummaryView()
        .modelContainer(for: [Expense.self, FixedPayment.self], inMemory: true)
}
