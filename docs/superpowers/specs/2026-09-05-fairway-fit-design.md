# Fairway Fit — Design

**Date:** 2026-09-05
**Status:** Approved design, ready for implementation planning
**Location:** `~/solo/golf-workout-app`

## What this is

A native iOS app that runs a golfer through a structured strength, power and
mobility program built around the swing. Open it, see the next session, train,
log it, watch the numbers move. No golf-practice features — no drills, rounds,
courses or swing video. This is the gym half of getting better at golf.

Built fresh. It is not a fork of `~/solo/coach` (Everyday Trainer) or
`~/solo/golf-trainer` (Break 100), though it borrows the "static content as
code, SwiftData for user state only" architecture from the former.

## Decisions made during brainstorming

| Decision | Choice | Rejected |
|---|---|---|
| Core promise | A training program you follow | Warmup-only, exercise library, movement-screen app |
| Plan source | Hand-authored prebuilt programs you pick | Profile-generated, screen-driven, week-to-week adaptive |
| Session execution | Guided player with per-set logging | Checklist, tap-to-complete, lifts-only logging |
| Exercise demos | Written cues + link out to YouTube | Bundled images, bundled video, text only |
| Equipment | Bodyweight + resistance band + a club | Full gym, dumbbells, home/gym variants |
| Scheduling | Sequential — next session up | Fixed weekly days, fixed-but-forgiving |
| v1 extras | Progress & history, daily notifications | Pre-round warmup, HealthKit, Apple Watch |
| Content storage | Swift values; SwiftData for user state only | Bundled JSON seeded into the store, all-in-SwiftData |
| Name / target | Fairway Fit, iOS 26 | — |

## Architecture

Static content as code. The exercise library, every session and all three
programs are Swift values compiled into the binary. SwiftData persists only
what belongs to the user. The rule that decides what to train next is a pure
function over content plus completion history.

Three consequences worth stating plainly:

1. A content typo is a compile error or a failing content test, never a data
   repair task on an installed device.
2. Rewriting a program in v1.1 requires no schema migration, because no
   program data was ever persisted.
3. The engine is testable with array literals — no store, no clock, no dates.

The cost: content changes ship with an app release. For three hand-authored
programs that is the correct trade. If programs ever need to come from a
server, that is a different design and should be revisited then, not
pre-built for now.

## Content model

### Exercise

The atom of the library. Roughly 45 of them.

```swift
struct Exercise: Identifiable, Hashable {
    let id: ExerciseID          // typed string id, e.g. "band-pull-apart"
    let name: String
    let category: Category      // mobility, power, strength, core, balance
    let equipment: Equipment    // none, band, club
    let setup: String           // one or two sentences
    let cues: [String]          // three or four short coaching cues
    let swingRationale: String  // why a golfer cares
    let demoURL: URL            // YouTube
    let isBenchmark: Bool       // gets its own Progress chart
}
```

`isBenchmark` marks the handful of exercises that recur often enough across a
program for a trend line to mean something. It is a property of the exercise,
not something Progress infers by counting occurrences.

`swingRationale` is a first-class field, not a nicety. It is the difference
between a generic fitness app and one a golfer keeps using: every exercise
states the swing fault or the yardage it is aimed at.

### Prescription

How an exercise appears in one specific session. This is what progresses; the
exercise itself never changes.

```swift
struct Prescription: Hashable {
    let exercise: ExerciseID
    let sets: Int
    let target: Target          // .reps(Int), .repsPerSide(Int),
                                // .seconds(Int), .secondsPerSide(Int)
    let restSeconds: Int
    let note: String?           // day-specific instruction, e.g. "slow eccentric"
}
```

### Block and Session

```swift
enum BlockKind { case warmup, main, finisher }

struct Block: Hashable {
    let kind: BlockKind
    let prescriptions: [Prescription]
}

struct Session: Identifiable, Hashable {
    let id: SessionID
    let name: String            // "Rotational Power B"
    let estimatedMinutes: Int
    let blocks: [Block]         // always warmup -> main -> optional finisher
}
```

The block is the unit the player groups by and the header the user sees, so
they always know whether they are warming up or working.

### Program

```swift
struct Program: Identifiable, Hashable {
    let id: ProgramID
    let title: String
    let subtitle: String
    let weeks: Int              // descriptive only — nothing is calendar-bound
    let sessionsPerWeek: Int    // descriptive only
    let whoThisIsFor: String    // a paragraph shown before enrolling
    let isRepeatable: Bool
    let sessions: [Session]     // ordered; this IS the program
}
```

Because progression is sequential, a program is literally an ordered array.
`weeks` and `sessionsPerWeek` describe the intended pace to the user; no code
branches on them.

### The three programs

| Program | Sessions | Intended pace | Repeatable | Purpose |
|---|---|---|---|---|
| Off-Season Power | 24 | ~8 weeks at 3/week | No | The flagship. Rotational power, single-leg strength, anti-rotation core. Builds clubhead speed. |
| In-Season Maintenance | 8 | ~4 weeks at 2/week | Yes | Shorter and lower fatigue. Holds what was built without leaving you sore on Saturday. Re-enrolls on completion. |
| Mobility Foundations | 12 | ~4 weeks at 3/week | No | The entry point. Hips, T-spine, ankles, shoulder turn. Run this first if you cannot make a full backswing. |

All three assume bodyweight, one resistance band, and a golf club or alignment
stick. Every session is doable at home or in a hotel room. There is one
exercise library shared across all programs — no equipment variants.

## Progression model

With no external load, progression comes from the prescription, not the
weight. Across a program's sessions, difficulty advances by:

- more reps or longer holds at the same tempo
- shorter rest between sets
- tempo changes (slow eccentric, pause at end range)
- harder variants of the same pattern, as distinct exercises with their own
  cues (push-up -> tempo push-up -> single-arm-biased push-up)
- heavier band level, recorded but not prescribed

The variant requirement is why the library is ~45 exercises rather than ~25.
Authoring the content is the single largest piece of work in this project.

## Persistence

SwiftData, four models, all of them user-owned.

```swift
@Model final class Profile          // one row
  var name: String
  var reminderWeekdays: [Int]       // 1...7
  var reminderTime: DateComponents
  var remindersEnabled: Bool

@Model final class Enrollment
  var programID: String
  var startedAt: Date
  var finishedAt: Date?
  var isActive: Bool                // exactly one active at a time
  var completions: [SessionCompletion]

@Model final class SessionCompletion
  var enrollment: Enrollment?
  var sessionIndex: Int             // index into the program's sessions array
  var startedAt: Date
  var finishedAt: Date?             // nil = bailed out mid-session
  var rpe: Int?                     // optional 1...10, asked once at the end
  var setLogs: [SetLog]

@Model final class SetLog
  var completion: SessionCompletion?
  var exerciseID: String
  var setNumber: Int
  var actualReps: Int?              // exactly one of reps/seconds is set,
  var actualSeconds: Int?           // matching the prescription's target
  var bandLevel: BandLevel?         // light, medium, heavy — band exercises only
```

Not stored: exercises, prescriptions, sessions, programs, or any schedule.

`sessionIndex` referencing a position in a compiled array is the one place
content and state touch. Programs are therefore **append-only across
releases**: adding sessions to the end is safe, reordering or removing them
would misalign existing history. If a program ever needs reordering, migrate
completions by session id at launch rather than reindexing silently.

### Logging shape

There is no weight to log on this equipment, so "full logging" means actual
reps or actual seconds per set, plus band level where relevant, plus one
optional session RPE. Week 7's set of 14 against week 1's set of 8 tells the
same progression story a heavier bar would.

## ProgramEngine

Pure, no store, no clock. The engine does **not** take SwiftData models — it
takes a value type mapped from them at the call site, which is what keeps the
suites constructible from array literals with no container.

```swift
struct CompletionRecord: Hashable {   // mapped from SessionCompletion
    let sessionIndex: Int
    let isFinished: Bool
}

enum ProgramEngine {
    static func nextSession(program: Program,
                            completions: [CompletionRecord])
        -> (index: Int, session: Session)?

    static func progress(program: Program,
                         completions: [CompletionRecord])
        -> (completed: Int, total: Int)

    static func isComplete(program: Program,
                           completions: [CompletionRecord]) -> Bool
}
```

Rules:

- The next session is the lowest index with no *finished* completion. A bailed
  session (`finishedAt == nil`) is offered again, and resuming reuses that
  same completion row rather than creating a second one.
- `isComplete` is true when every index has a finished completion.
- Completing a repeatable program archives the enrollment and creates a fresh
  active one for the same program, so history stays separated per cycle.

## Progress and streak

- Sessions completed, all-time and within the current enrollment.
- Program completion percentage.
- **Streak: consecutive weeks with at least two finished sessions.** Days
  cannot anchor a streak when the schedule floats, and weeks can. The
  threshold is a fixed two regardless of the program's intended pace — it is
  the floor for "trained this week", not a target derived from the program,
  and deriving it would make the streak mean different things in different
  programs. Weeks start Monday, in the user's current timezone.
- Swift Charts, one chart per exercise flagged `isBenchmark`, plotting
  achieved reps or seconds over time.
- Session history list, tappable through to what was logged that day.

## Notifications

Sequential progression has no calendar, so there is no "you have a session
today" to fire. Reminders are therefore a **pure preference**, deliberately
not a schedule the program is bound to: the user picks weekdays and a time in
onboarding or Settings, and a local notification fires then, naming whatever
session is next.

> Session 9 of 24: Rotational Power B — 38 min

Skipping three days changes nothing about that text, because nothing was
missed. Rescheduled on app foreground and after any session completes.

Permission denied is not an error state: Settings shows that reminders are off
at the system level with a link to Settings.app, and the rest of the app is
unaffected.

## Screens

Four tabs.

**Today.** The point of the app. Next-session card (name, block summary,
estimated minutes), program progress ring, one large Start button. With no
active enrollment this tab is the program picker instead. With the program
finished it is the congratulations and what-next state.

**Programs.** The three programs, each with `whoThisIsFor`, the full session
list, and enrol / switch. Switching archives the current enrollment rather
than deleting it — history always survives.

**Progress.** Streak, sessions completed, completion percentage, benchmark
charts, session history.

**Settings.** Reminder weekdays and time, profile, and access to the full
exercise library for reading outside a session.

**The player** (presented full-screen from Today, not a tab). One exercise at
a time with cues visible, set rows tapped to fill in as you go, a rest timer
with haptics between sets, block name in the header. Back and next between
exercises. A bail-out that saves everything logged so far and leaves the
session unfinished.

**Exercise detail** is reachable from the player, the program session list and
Settings: setup, cues, swing rationale, and a Watch demo button that opens
YouTube in Safari.

## Project setup

- XcodeGen `project.yml` generating `FairwayFit.xcodeproj` (gitignored),
  matching the convention in `~/solo/coach` and `~/solo/golf-trainer`.
- SwiftUI, SwiftData, Swift Charts. No third-party dependencies.
- Bundle id `com.thomashall.FairwayFit`, display name "Fairway Fit",
  iOS 26 deployment target, iPhone only, portrait.
- Swift Testing for all suites.

```sh
brew install xcodegen
xcodegen generate
open FairwayFit.xcodeproj
```

## Testing

1. **ProgramEngine** — next session, progress, completion, bailed-session
   resumption, repeatable re-enrollment. Array literals only.
2. **Content validation** — every prescription references an exercise that
   exists; every exercise has non-empty cues, a swing rationale and a demo
   URL; no session has an empty block; no program has zero sessions; session
   counts are consistent with the stated weeks and pace; exercise ids are
   unique. This catches content typos in CI instead of on a phone.
3. **Progress and streak** — week-boundary behaviour, gaps, the two-sessions
   threshold, timezone stability.
4. **Reminder scheduling** — clock-injected, correct next-fire dates for a
   given weekday set, rescheduling after completion.

## Failure modes

| Situation | Behaviour |
|---|---|
| Notification permission denied | Settings explains it; app otherwise unaffected |
| YouTube link cannot open | Cues and rationale remain — the video is never the only source of truth |
| Bail out mid-session | Partial logs persist; session stays unfinished; engine offers it again and resumes the same row |
| Switch programs mid-way | Old enrollment archived, not deleted; history intact |
| SwiftData container fails to load | Fatal at launch with a clear message; there is no remote copy to fall back to |
| No network | Everything works except opening a demo video. There is no backend. |

## Out of scope for v1

Pre-round warmup routines, HealthKit and Apple Watch, bundled demo media,
profile-generated or adaptive programming, movement screens, dumbbell or
barbell variants, iPad, sync across devices, and any server component.
