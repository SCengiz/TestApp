import SwiftUI
import SwiftData
import Charts

// Grafik dönemi
enum ChartRange: String, CaseIterable, Identifiable {
    case month = "Bu Ay"
    case yearly = "Aylık"
    case allYears = "Yıllık"
    var id: String { rawValue }
}

struct SummaryView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var payments: [FixedPayment]
    @State private var range: ChartRange = .month

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

    // Seçili döneme göre grafik verisi
    private var chartData: [(date: Date, total: Double)] {
        switch range {
        case .month:
            // Ayın 1'inden bugüne, gün gün
            let start = calendar.dateInterval(of: .month, for: .now)!.start
            let today = calendar.startOfDay(for: .now)
            let dayCount = (calendar.dateComponents([.day], from: start, to: today).day ?? 0) + 1
            return (0..<dayCount).map { offset in
                let day = calendar.date(byAdding: .day, value: offset, to: start)!
                return (day, totalIn(day, unit: .day))
            }
        case .yearly:
            // Son 12 ay, ay ay
            let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
            return (0..<12).reversed().map { offset in
                let month = calendar.date(byAdding: .month, value: -offset, to: thisMonth)!
                return (month, totalIn(month, unit: .month))
            }
        case .allYears:
            // Son 5 yıl, yıl yıl
            let thisYear = calendar.dateInterval(of: .year, for: .now)!.start
            return (0..<5).reversed().map { offset in
                let year = calendar.date(byAdding: .year, value: -offset, to: thisYear)!
                return (year, totalIn(year, unit: .year))
            }
        }
    }

    private var chartUnit: Calendar.Component {
        switch range {
        case .month:    return .day
        case .yearly:   return .month
        case .allYears: return .year
        }
    }

    private var axisFormat: Date.FormatStyle {
        switch range {
        case .month:    return .dateTime.day()
        case .yearly:   return .dateTime.month(.narrow)
        case .allYears: return .dateTime.year()
        }
    }

    private var chartColors: [Color] {
        switch range {
        case .month:    return [.blue, .indigo]
        case .yearly:   return [.teal, .green]
        case .allYears: return [.purple, .pink]
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

                    // Seçimli grafik kartı
                    VStack(alignment: .leading, spacing: 14) {
                        Label("Harcama Grafiği", systemImage: "chart.bar.fill")
                            .font(.headline)

                        Picker("Dönem", selection: $range) {
                            ForEach(ChartRange.allCases) { r in
                                Text(r.rawValue).tag(r)
                            }
                        }
                        .pickerStyle(.segmented)

                        Chart(chartData, id: \.date) { item in
                            BarMark(
                                x: .value("Dönem", item.date, unit: chartUnit),
                                y: .value("Tutar", item.total)
                            )
                            .foregroundStyle(
                                LinearGradient(colors: chartColors, startPoint: .top, endPoint: .bottom)
                            )
                            .cornerRadius(5)
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: 6)) {
                                AxisValueLabel(format: axisFormat)
                            }
                        }
                        .frame(height: 220)
                        .animation(.easeInOut, value: range)
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
            .navigationTitle("Özet")
        }
    }

    // Belirli bir tarihin ait olduğu gün/ay/yıl içindeki harcama toplamı
    private func totalIn(_ date: Date, unit: Calendar.Component) -> Double {
        expenses
            .filter { calendar.isDate($0.date, equalTo: date, toGranularity: unit) }
            .reduce(0) { $0 + $1.amount }
    }
}

#Preview {
    SummaryView()
        .modelContainer(for: [Expense.self, FixedPayment.self], inMemory: true)
}
