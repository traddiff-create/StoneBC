import SwiftUI
import Charts

struct RideStatsView: View {
    @State private var history = RideHistoryService.shared

    var body: some View {
        if history.rides.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: BCSpacing.lg) {
                    allTimeCard
                    prGrid
                    monthlyChart
                    categoryBreakdown
                }
                .padding(BCSpacing.md)
            }
        }
    }

    // MARK: - All-Time Card

    private var allTimeCard: some View {
        VStack(alignment: .leading, spacing: BCSpacing.sm) {
            BCSectionHeader("ALL TIME", icon: "gauge.with.dots.needle.bottom.50percent")

            BCMetricStrip(metrics: [
                BCMetric(value: String(format: "%.0f", history.allTimeMiles), label: "Miles", icon: "road.lanes"),
                BCMetric(value: "\(history.rides.count)", label: "Rides", icon: "figure.outdoor.cycle"),
                BCMetric(value: elevationFormatted(history.allTimeElevationFeet), label: "Elevation", icon: "arrow.up")
            ])
        }
    }

    // MARK: - Personal Records

    private var prGrid: some View {
        let pr = history.personalRecords
        return VStack(alignment: .leading, spacing: BCSpacing.sm) {
            BCSectionHeader("PERSONAL RECORDS", icon: "medal")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: BCSpacing.sm) {
                prCard(
                    icon: "arrow.right.to.line",
                    label: "Longest Ride",
                    value: String(format: "%.1f mi", pr.longestMiles)
                )
                prCard(
                    icon: "speedometer",
                    label: "Fastest Avg",
                    value: String(format: "%.1f mph", pr.fastestAvgMPH)
                )
                prCard(
                    icon: "mountain.2",
                    label: "Most Elevation",
                    value: elevationFormatted(pr.mostElevationFeet)
                )
                prCard(
                    icon: "flame",
                    label: "Best Streak",
                    value: "\(pr.longestStreakDays) day\(pr.longestStreakDays == 1 ? "" : "s")"
                )
            }
        }
    }

    private func prCard(icon: String, label: String, value: String) -> some View {
        VStack(spacing: BCSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(BCColors.brandBlue)
            Text(value)
                .font(.bcInstrumentValue)
            Text(label)
                .font(.bcInstrumentLabel)
                .tracking(0.6)
                .foregroundColor(BCColors.cockpitMutedText)
        }
        .frame(maxWidth: .infinity)
        .bcInstrumentCard()
    }

    // MARK: - Monthly Chart

    private var monthlyChart: some View {
        let data = history.monthlyMiles()
        let hasData = data.contains { $0.miles > 0 }
        return VStack(alignment: .leading, spacing: BCSpacing.sm) {
            BCSectionHeader("MONTHLY MILES", icon: "chart.bar")

            VStack {
                if hasData {
                    Chart {
                        ForEach(data, id: \.month) { entry in
                            BarMark(
                                x: .value("Month", entry.month, unit: .month),
                                y: .value("Miles", entry.miles)
                            )
                            .foregroundStyle(BCColors.brandBlue)
                            .cornerRadius(4)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .month)) { value in
                            if let date = value.as(Date.self) {
                                AxisValueLabel {
                                    Text(date, format: .dateTime.month(.narrow))
                                        .font(.system(size: 9))
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let v = value.as(Double.self) {
                                    Text("\(Int(v))")
                                        .font(.system(size: 9))
                                }
                            }
                        }
                    }
                    .frame(height: 140)
                } else {
                    Text("Record more rides to see your monthly trend")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 30)
                }
            }
            .bcInstrumentCard()
        }
    }

    // MARK: - Category Breakdown

    private var categoryBreakdown: some View {
        let byCategory = history.milesByCategory
        let total = byCategory.values.reduce(0, +)
        let sorted = byCategory.sorted { $0.value > $1.value }

        return VStack(alignment: .leading, spacing: BCSpacing.sm) {
            BCSectionHeader("BY CATEGORY", icon: "square.grid.2x2")

            if sorted.isEmpty {
                Text("No category data yet")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
                    .bcInstrumentCard()
            } else {
                VStack(spacing: BCSpacing.sm) {
                    ForEach(sorted, id: \.key) { cat, miles in
                        categoryBar(category: cat, miles: miles, total: total)
                    }
                }
                .bcInstrumentCard()
            }
        }
    }

    private func categoryBar(category: String, miles: Double, total: Double) -> some View {
        let pct = total > 0 ? miles / total : 0
        return VStack(spacing: 4) {
            HStack {
                Text(category.capitalized)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
                Text(String(format: "%.1f mi  ·  %.0f%%", miles, pct * 100))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(BCColors.fill)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(BCColors.categoryColor(category))
                        .frame(width: geo.size.width * pct, height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Helpers

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar")
                .font(.system(size: 36))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No stats yet")
                .font(.system(size: 15, weight: .medium))
            Text("Complete rides to see your progress here")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 60)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .bold))
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func elevationFormatted(_ feet: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return (formatter.string(from: NSNumber(value: Int(feet))) ?? "\(Int(feet))") + " ft"
    }
}

#Preview {
    RideStatsView()
}
