import Foundation
import SwiftData

struct PlayerStep: Identifiable, Hashable {
    let id = UUID()
    let exerciseID: String
    let prescription: Prescription
    let blockKind: BlockKind
}

/// Runs one session: flattens it into steps, writes a SetLog per recorded set,
/// and stamps the SessionCompletion at the end.
@Observable
@MainActor
final class PlayerModel {
    let session: Session
    let steps: [PlayerStep]
    private(set) var currentIndex = 0

    private let context: ModelContext
    private let completion: SessionCompletion

    init(session: Session, enrollment: Enrollment, context: ModelContext) {
        self.session = session
        self.context = context
        self.steps = session.blocks.flatMap { block in
            block.prescriptions.map {
                PlayerStep(exerciseID: $0.exerciseID, prescription: $0, blockKind: block.kind)
            }
        }

        // Resume an unfinished attempt rather than starting a second one.
        if let existing = enrollment.completions.first(where: {
            $0.sessionID == session.id && !$0.isFinished
        }) {
            self.completion = existing
        } else {
            let fresh = SessionCompletion(sessionID: session.id, startedAt: .now)
            fresh.enrollment = enrollment
            context.insert(fresh)
            self.completion = fresh
            try? context.save()
        }
    }

    var currentStep: PlayerStep? {
        steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
    }

    var isOnLastStep: Bool { currentIndex >= steps.count - 1 }

    func advance() {
        guard currentIndex < steps.count - 1 else { return }
        currentIndex += 1
    }

    func goBack() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    /// Existing logs for the current exercise, so the UI can show what is filled in.
    func loggedValue(setNumber: Int) -> Int? {
        guard let step = currentStep else { return nil }
        return log(for: step, setNumber: setNumber)?.achievedValue
    }

    /// The band level to default a set-entry sheet to: whatever was already logged
    /// for this exact set, else the most recent one logged for this exercise this
    /// session (nobody changes bands between sets of the same movement), else nil.
    func recordedBandLevel(for step: PlayerStep, setNumber: Int) -> BandLevel? {
        let logsForExercise = completion.setLogs.filter { $0.exerciseID == step.exerciseID }
        if let exact = logsForExercise.first(where: { $0.setNumber == setNumber })?.bandLevel {
            return exact
        }
        return logsForExercise.sorted { $0.setNumber < $1.setNumber }.compactMap(\.bandLevel).last
    }

    func record(setNumber: Int, value: Int, bandLevel: BandLevel?) {
        guard let step = currentStep else { return }
        let isTimed = step.prescription.target.isTimed

        if let existing = log(for: step, setNumber: setNumber) {
            existing.actualReps = isTimed ? nil : value
            existing.actualSeconds = isTimed ? value : nil
            existing.bandLevel = bandLevel
        } else {
            let entry = SetLog(exerciseID: step.exerciseID,
                               setNumber: setNumber,
                               actualReps: isTimed ? nil : value,
                               actualSeconds: isTimed ? value : nil,
                               bandLevel: bandLevel)
            entry.completion = completion
            context.insert(entry)
        }
        try? context.save()
    }

    func finish(rpe: Int?) {
        completion.finishedAt = .now
        completion.rpe = rpe
        try? context.save()
    }

    /// Bailing out keeps everything logged and leaves the session resumable.
    func abandon() {
        try? context.save()
    }

    private func log(for step: PlayerStep, setNumber: Int) -> SetLog? {
        completion.setLogs.first { $0.exerciseID == step.exerciseID && $0.setNumber == setNumber }
    }
}
