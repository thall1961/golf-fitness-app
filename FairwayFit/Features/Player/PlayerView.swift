import SwiftData
import SwiftUI

struct PlayerView: View {
    let session: Session
    let enrollment: Enrollment

    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var model: PlayerModel?
    @State private var isResting = false
    @State private var showFinishSheet = false
    @State private var rpe: Double = 6

    var body: some View {
        NavigationStack {
            Group {
                if let model, let step = model.currentStep,
                   let exercise = appState.content.exercise(id: step.exerciseID) {
                    stepBody(model: model, step: step, exercise: exercise)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(model?.currentStep?.blockKind.rawValue.capitalized ?? session.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        model?.abandon()
                        dismiss()
                    }
                }
            }
        }
        .task {
            if model == nil {
                model = PlayerModel(session: session, enrollment: enrollment, context: context)
            }
        }
        .sheet(isPresented: $showFinishSheet) { finishSheet }
    }

    @ViewBuilder
    private func stepBody(model: PlayerModel, step: PlayerStep, exercise: Exercise) -> some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(model.currentIndex + 1), total: Double(model.steps.count))
                .padding(.horizontal)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(exercise.name).font(.title2.bold())
                        Text(step.prescription.summary)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        if let note = step.prescription.note {
                            Text(note).font(.subheadline).foregroundStyle(.tertiary)
                        }
                    }

                    if isResting {
                        RestTimerView(seconds: step.prescription.restSeconds) { isResting = false }
                            .frame(maxWidth: .infinity)
                    }

                    SetEntryList(model: model, step: step, exercise: exercise) {
                        if step.prescription.restSeconds > 0 { isResting = true }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(exercise.cues, id: \.self) { cue in
                            Label(cue, systemImage: "checkmark.circle").font(.callout)
                        }
                        NavigationLink("How to do this") { ExerciseDetailView(exercise: exercise) }
                            .font(.callout)
                    }
                }
                .padding()
            }

            HStack {
                Button("Back") { model.goBack() }
                    .buttonStyle(.bordered)
                    .disabled(model.currentIndex == 0)
                Spacer()
                if model.isOnLastStep {
                    Button("Finish") { showFinishSheet = true }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Next") {
                        isResting = false
                        model.advance()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }

    private var finishSheet: some View {
        NavigationStack {
            Form {
                Section("How hard was that?") {
                    Slider(value: $rpe, in: 1...10, step: 1)
                    Text("RPE \(Int(rpe))").font(.headline)
                }
            }
            .navigationTitle("Finish session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        model?.finish(rpe: Int(rpe))
                        showFinishSheet = false
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") {
                        model?.finish(rpe: nil)
                        showFinishSheet = false
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// One row per prescribed set, tapped to fill in what was actually done.
struct SetEntryList: View {
    let model: PlayerModel
    let step: PlayerStep
    let exercise: Exercise
    let onRecorded: () -> Void

    @State private var editing: Int?
    @State private var entry = ""
    @State private var bandLevel: BandLevel = .medium

    var body: some View {
        VStack(spacing: 8) {
            ForEach(1...step.prescription.sets, id: \.self) { setNumber in
                HStack {
                    Text("Set \(setNumber)").frame(width: 64, alignment: .leading)
                    Spacer()
                    if let value = model.loggedValue(setNumber: setNumber) {
                        Text(step.prescription.target.isTimed ? "\(value)s" : "\(value)")
                            .font(.headline.monospacedDigit())
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Text(step.prescription.target.isTimed
                             ? "\(step.prescription.target.value)s target"
                             : "\(step.prescription.target.value) target")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
                .onTapGesture {
                    entry = String(model.loggedValue(setNumber: setNumber)
                                   ?? step.prescription.target.value)
                    bandLevel = model.recordedBandLevel(for: step, setNumber: setNumber) ?? .medium
                    editing = setNumber
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { editing != nil },
            set: { if !$0 { editing = nil } }
        )) {
            setEntrySheet
        }
    }

    /// A sheet, not an alert — alerts cannot host a Picker, and band exercises need one.
    private var setEntrySheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(step.prescription.target.isTimed ? "Seconds" : "Reps", text: $entry)
                        .keyboardType(.numberPad)
                }
                if exercise.equipment == .band {
                    Section("Band") {
                        Picker("Band", selection: $bandLevel) {
                            ForEach(BandLevel.allCases, id: \.self) { band in
                                Text(band.label).tag(band)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
            .navigationTitle("Set \(editing ?? 0)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { editing = nil }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let setNumber = editing, let value = Int(entry), value > 0 {
                            model.record(setNumber: setNumber, value: value,
                                         bandLevel: exercise.equipment == .band ? bandLevel : nil)
                            onRecorded()
                        }
                        editing = nil
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
