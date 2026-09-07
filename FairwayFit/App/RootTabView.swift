import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Today", systemImage: "figure.strengthtraining.functional") {
                TodayView()
            }
            Tab("Programs", systemImage: "list.bullet.rectangle") {
                ProgramListView()
            }
            Tab("Progress", systemImage: "chart.xyaxis.line") {
                ProgressTabView()
            }
            Tab("Settings", systemImage: "gearshape") {
                Text("Settings")
            }
        }
    }
}
