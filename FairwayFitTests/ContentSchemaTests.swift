import Foundation
import Testing
@testable import FairwayFit

@Suite struct ContentSchemaTests {

    @Test func decodesAFullDocument() throws {
        let json = """
        {
          "schemaVersion": 1,
          "version": 4,
          "exercises": [
            {
              "id": "band-pull-apart",
              "name": "Band Pull-Apart",
              "category": "strength",
              "equipment": "band",
              "setup": "Stand tall holding a band at shoulder height, arms straight.",
              "cues": ["Ribs down", "Lead with the knuckles", "Pause at the end"],
              "swingRationale": "Upper-back strength keeps the trail arm from collapsing at the top.",
              "demoURL": "https://www.youtube.com/watch?v=abc123",
              "isBenchmark": true
            }
          ],
          "programs": [
            {
              "id": "mobility-foundations",
              "title": "Mobility Foundations",
              "subtitle": "Turn further without forcing it",
              "weeks": 4,
              "sessionsPerWeek": 3,
              "whoThisIsFor": "Start here if you cannot make a full backswing.",
              "isRepeatable": false,
              "sessions": [
                {
                  "id": "mf-w1d1",
                  "name": "Hips and T-Spine A",
                  "estimatedMinutes": 22,
                  "blocks": [
                    {
                      "kind": "warmup",
                      "prescriptions": [
                        {
                          "exerciseID": "band-pull-apart",
                          "sets": 2,
                          "target": { "kind": "reps", "value": 12 },
                          "restSeconds": 30,
                          "note": null
                        }
                      ]
                    }
                  ]
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let content = try JSONDecoder().decode(Content.self, from: json)

        #expect(content.schemaVersion == 1)
        #expect(content.version == 4)
        #expect(content.exercises.count == 1)
        #expect(content.exercises[0].category == .strength)
        #expect(content.exercises[0].equipment == .band)
        #expect(content.exercises[0].isBenchmark)
        #expect(content.programs[0].sessions[0].blocks[0].kind == .warmup)
        #expect(content.programs[0].sessions[0].blocks[0].prescriptions[0].target
                == Target(kind: .reps, value: 12))
    }

    @Test func looksUpByID() {
        let content = makeContent(
            exercises: [makeExercise(id: "push-up")],
            programs: [makeProgram(id: "off-season-power")]
        )
        #expect(content.exercise(id: "push-up")?.id == "push-up")
        #expect(content.exercise(id: "missing") == nil)
        #expect(content.program(id: "off-season-power")?.id == "off-season-power")
        #expect(content.program(id: "missing") == nil)
    }

    @Test func supportedSchemaVersionIsOne() {
        #expect(Content.supportedSchemaVersion == 1)
    }
}
