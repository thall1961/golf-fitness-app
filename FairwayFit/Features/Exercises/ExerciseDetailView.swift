import SwiftUI

struct ExerciseDetailView: View {
    let exercise: Exercise
    @Environment(\.openURL) private var openURL

    var body: some View {
        List {
            Section("Why it matters") {
                Text(exercise.swingRationale)
                    .font(.callout)
            }
            Section("Setup") {
                Text(exercise.setup)
            }
            Section("Cues") {
                ForEach(exercise.cues, id: \.self) { cue in
                    Label(cue, systemImage: "checkmark.circle")
                }
            }
            Section {
                Button {
                    openURL(exercise.demoURL)
                } label: {
                    Label("Watch demo", systemImage: "play.rectangle")
                }
            } footer: {
                Text("Opens YouTube. The cues above are enough on their own if the video will not load.")
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
