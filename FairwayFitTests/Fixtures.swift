import Foundation
@testable import FairwayFit

func makeExercise(
    id: String = "push-up",
    name: String = "Push-Up",
    category: ExerciseCategory = .strength,
    equipment: Equipment = .none,
    setup: String = "Hands under the shoulders, body in one line.",
    cues: [String] = ["Ribs down", "Elbows at 45 degrees"],
    swingRationale: String = "Pressing strength stabilises the lead side through impact.",
    demoURL: URL = URL(string: "https://www.youtube.com/watch?v=example")!,
    isBenchmark: Bool = false
) -> Exercise {
    Exercise(id: id, name: name, category: category, equipment: equipment,
             setup: setup, cues: cues, swingRationale: swingRationale,
             demoURL: demoURL, isBenchmark: isBenchmark)
}

func makePrescription(
    exerciseID: String = "push-up",
    sets: Int = 3,
    target: Target = Target(kind: .reps, value: 10),
    restSeconds: Int = 45,
    note: String? = nil
) -> Prescription {
    Prescription(exerciseID: exerciseID, sets: sets, target: target,
                 restSeconds: restSeconds, note: note)
}

func makeSession(
    id: String = "s1",
    name: String = "Session",
    estimatedMinutes: Int = 30,
    blocks: [Block] = [Block(kind: .main, prescriptions: [makePrescription()])]
) -> Session {
    Session(id: id, name: name, estimatedMinutes: estimatedMinutes, blocks: blocks)
}

func makeProgram(
    id: String = "program",
    title: String = "Program",
    subtitle: String = "Subtitle",
    weeks: Int = 4,
    sessionsPerWeek: Int = 3,
    whoThisIsFor: String = "Anyone.",
    isRepeatable: Bool = false,
    sessions: [Session] = [makeSession()]
) -> Program {
    Program(id: id, title: title, subtitle: subtitle, weeks: weeks,
            sessionsPerWeek: sessionsPerWeek, whoThisIsFor: whoThisIsFor,
            isRepeatable: isRepeatable, sessions: sessions)
}

func makeContent(
    schemaVersion: Int = Content.supportedSchemaVersion,
    version: Int = 1,
    exercises: [Exercise] = [makeExercise()],
    programs: [Program] = [makeProgram()]
) -> Content {
    Content(schemaVersion: schemaVersion, version: version,
            exercises: exercises, programs: programs)
}
