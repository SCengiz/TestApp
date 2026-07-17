import SwiftUI
import SwiftData
import Charts

// Grafik dönemi seçimi
enum SummaryPeriod: String, CaseIterable, Identifiable {
    case week = "Haftalık"
    case month = "Aylık"
    case year = "Yıllık"
    var id: String { rawValue }
}

struct SummaryView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var payments: [FixedPayment]
    @State private var period: SummaryPeriod = .month

    private var calendar: Calendar { .current }

    // Aylık sabit ödemelerin toplamı
    private var fixedTotal: Double {
        payments.reduce(0) { $0 + $1.amount }
    }

    // Seçili döneme göre grafik verisi: (etiket tarihi, o dönemin toplamı)
    private var buckets: [(date: Date, total: Double)] {
        switch period {
        case .week:
            // Son 7 gün, gün gün
            let today = calendar.startOfDay(for: .now)
            return (0..<7).reversed().map { offset in
                let day = calendar.date(byAdding: .day, value: -offset, to: today)!
                return (day, totalIn(day, unit: .day))
            }
        case .month:
            // Son 12 ay, ay ay
            let thisMonth = calendar.dateInterval(of: .month, for: .now)!.start
            return (0..<12).reversed().map { offset in
                let month = calendar.date(byAdding: .month, value: -offset, to: thisMonth)!
                return (month, totalIn(month, unit: .month))
            }
        case .year:
            // Son 5 yıl, yıl yıl
            let thisYear = calendar.dateInterval(of: .year, for: .now)!.start
            return (0..<5).reversed().map { offset in
                let year = calendar.date(byAdding: .year, value: -offset, to: thisYear)!
                return (year, totalIn(year, unit: .year))
            }
        }
    }

    // İçinde bulunulan dönemin (bu hafta / bu ay / bu yıl) toplamı
    private var currentPeriodTotal: Double {
        switch period {
        case .week:  return totalIn(.now, unit: .weekOfYear)
        case .month: return totalIn(.now, unit: .month)
        case .year:  return totalIn(.now, unit: .year)
        }
    }

    private var currentPeriodLabel: String {
        switch period {
        case .week:  return "Bu Hafta Harcama"
        case .month: return "Bu Ay Harcama"
        case .year:  return "Bu Yıl Harcama"
        }
    }

    private var chartUnit: Calendar.Component {
        switch period {
        case .week:  return .day
        case .month: return .month
        case .year:  return .year
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Dönem seçici
                    Picker("Dönem", selection: $period) {
                        ForEach(SummaryPeriod.allCases) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 12) {
                        StatCard(
                            title: currentPeriodLabel,
                            amount: currentPeriodTotal,
                            icon: "cart.fill",
                            colors: [.pink, .red]
                        )
                        StatCard(
                            title: "Aylık Sabit Yük",
                            amount: fixedTotal,
                            icon: "creditcard.fill",
                            colors: [.orange, .yellow]
                        )
                    }

                    chartCard(title: "\(period.rawValue) Gidişat", icon: "chart.bar.fill") {
                        Chart(buckets, id: \.date) { item in
                            BarMark(
                                x: .value("Dönem", item.date, unit: chartUnit),
                                y: .value("Tutar", item.total)
                            )
                            .foregroundStyle(
                                LinearGradient(colors: [.blue, .indigo], startPoint: .top, endPoint: .bottom)
                            )
                            .cornerRadius(6)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: chartUnit)) {
                                AxisValueLabel(format: axisFormat)
                            }
                        }
                        .frame(height: 220)
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

    // X eksenindeki tarih etiketinin biçimi
    private var axisFormat: Date.FormatStyle {
        switch period {
        case .week:  return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.month(.narrow)
        case .year:  return .dateTime.year()
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
