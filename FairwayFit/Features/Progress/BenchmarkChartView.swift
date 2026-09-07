import Charts
import SwiftUI

struct BenchmarkChartView: View {
    let exercise: Exercise
    let points: [BenchmarkPoint]
    let isTimed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(exercise.name).font(.headline)
            if points.count < 2 {
                Text("Log this at least twice and the trend shows up here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Chart(points) { point in
                    LineMark(x: .value("Date", point.date), y: .value("Best", point.best))
                    PointMark(x: .value("Date", point.date), y: .value("Best", point.best))
                }
                .chartYAxisLabel(isTimed ? "seconds" : "reps")
                .frame(height: 160)
            }
        }
    }
}
