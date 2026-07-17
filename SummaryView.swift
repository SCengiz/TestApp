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

    // Son 7 günün gün gün toplamları (harcama olmayan günler 0)
    private var last7Days: [(day: Date, total: Double)] {
        let today = calendar.startOfDay(for: .now)
        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!
            let total = expenses
                .filter { calendar.isDate($0.date, inSameDayAs: day) }
                .reduce(0) { $0 + $1.amount }
            return (day, total)
        }
    }

    // Son 6 ayın toplamları
    private var last6Months: [(month: Date, total: Double)] {
        let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
        return (0..<6).reversed().map { offset in
            let month = calendar.date(byAdding: .month, value: -offset, to: thisMonth)!
            let total = expenses
                .filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
                .reduce(0) { $0 + $1.amount }
            return (month, total)
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
                        Chart(last7Days, id: \.day) { item in
                            BarMark(
                                x: .value("Gün", item.day, unit: .day),
                                y: .value("Tutar", item.total)
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [.blue, .indigo], startPoint: .top, endPoint: .bottom)
                            )
                            .cornerRadius(6)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) {
                                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            }
                        }
                        .frame(height: 180)
                    }

                    chartCard(title: "Aylık Gidişat", icon: "chart.line.uptrend.xyaxis") {
                        Chart(last6Months, id: \.month) { item in
                            BarMark(
                                x: .value("Ay", item.month, unit: .month),
                                y: .value("Tutar", item.total)
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [.teal, .green], startPoint: .top, endPoint: .bottom)
                            )
                            .cornerRadius(6)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .month)) {
                                AxisValueLabel(format: .dateTime.month(.abbreviated))
                            }
                        }
                        .frame(height: 180)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Özet")
        }
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
