# Fairway Fit — Design

**Date:** 2026-09-05 (revised 2026-09-06 — content moved out of the binary)
**Status:** Approved design, ready for implementation planning
**Location:** `~/solo/golf-workout-app`

## What this is

A native iOS app that runs a golfer through a structured strength, power and
mobility program built around the swing. Open it, see the next session, train,
log it, watch the numbers move. No golf-practice features — no drills, rounds,
courses or swing video. This is the gym half of getting better at golf.

Built fresh. It is not a fork of `~/solo/coach` (Everyday Trainer) or
`~/solo/golf-trainer` (Break 100).

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
| Content storage | Versioned JSON document: bundled baseline + remote override, decoded to in-memory value types | Swift values in code; JSON seeded into SwiftData; a real backend with an editing UI |
| Content host | `content.json` in a GitHub repo, fetched over HTTPS | S3/R2 + CDN, CloudKit public database |
| Content authoring | Hand-written JSON | Spreadsheet + export script, generated draft |
| Name / target | Fairway Fit, iOS 26 | — |

## Architecture

Three layers that do not leak into each other.

**Content** is a single versioned JSON document describing every exercise,
session and program. It is decoded into immutable value types held in memory.
It is never written to SwiftData.

**User state** is SwiftData, and only SwiftData: enrollment, completions,
logged sets, profile. It references content by stable string id, never by
position.

**Logic** is `ProgramEngine`, a pure function over content values and
completion records. No store, no clock, no network.

Keeping content out of the database is the load-bearing decision. Most of the
complexity in a seeding layer — upsert by id, "delete only if it carries no
user data", version gates in `UserDefaults`, content migrations — exists only
because content and user data share a store. Here they do not, so none of it
is needed. Content is replaced wholesale; user rows are untouched because they
were never in the same place.

Shipping content separately from the app buys the thing that motivated it: a
dead YouTube link, a wrong rep count or a new program is fixed by editing and
pushing one file, not by an App Store release.

The cost, stated plainly: content errors stop being compile errors. The
validation suite is now the only thing between a bad edit and every user's
phone, so it runs both in CI against the repo's `content.json` and at runtime
against whatever was fetched.

## The content document

One file, `content.json`:

```json
{
  "schemaVersion": 1,
  "version": 7,
  "exercises": [ ... ],
  "programs": [ ... ]
}
```

`schemaVersion` is the shape of the document; `version` is the edition of the
content. The app understands exactly one `schemaVersion` and **rejects any
document whose `schemaVersion` it does not recognise**, which is what stops a
future content format from breaking older installs. `version` is a
monotonically increasing integer and is the only thing compared to decide
whether a fetched document is newer.

### Exercise

Roughly 45 of them.

```swift
struct Exercise: Codable, Identifiable, Hashable {
    let id: String              // stable, e.g. "band-pull-apart"
    let name: String
    let category: Category      // mobility, power, strength, core, balance
    let equipment: Equipment    // none, band, club
    let setup: String           // one or two sentences
    let cues: [String]          // three or four short coaching cues
    let swingRationale: String  // why a golfer cares
    let demoURL: URL            // YouTube, https
    let isBenchmark: Bool       // gets its own Progress chart
}
```

`swingRationale` is a first-class field, not a nicety. It is the difference
between a generic fitness app and one a golfer keeps using: every exercise
states the swing fault or the yardage it is aimed at.

`isBenchmark` marks the handful of exercises that recur often enough across a
program for a trend line to mean something. It is a property of the exercise,
not something the Progress screen infers by counting occurrences.

### Prescription

How an exercise appears in one specific session. This is what progresses; the
exercise itself never changes.

```swift
struct Prescription: Codable, Hashable {
    let exerciseID: String
    let sets: Int
    let target: Target          // .reps(Int), .repsPerSide(Int),
                                // .seconds(Int), .secondsPerSide(Int)
    let restSeconds: Int
    let note: String?           // day-specific instruction, e.g. "slow eccentric"
}
```

`Target` is encoded as `{"kind": "reps", "value": 12}` — a flat, obvious shape
rather than Swift's default enum encoding, since this JSON is written by hand.

### Block and Session

```swift
enum BlockKind: String, Codable { case warmup, main, finisher }

struct Block: Codable, Hashable {
    let kind: BlockKind
    let prescriptions: [Prescription]
}

struct Session: Codable, Identifiable, Hashable {
    let id: String              // stable and globally unique, e.g. "osp-w1d1"
    let name: String            // "Rotational Power B"
    let estimatedMinutes: Int
    let blocks: [Block]         // warmup -> main -> optional finisher
}
```

The block is the unit the player groups by and the header the user sees, so
they always know whether they are warming up or working.

Session ids are globally unique across all programs, not merely unique within
one, because completions are recorded against the session id.

### Program

```swift
struct Program: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let weeks: Int              // descriptive only
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
stick. Every session is doable at home or in a hotel room. One exercise
library is shared across all programs — no equipment variants.

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

## ContentStore

Resolves which content document to use, and fetches newer ones.

```swift
actor ContentStore {
    private(set) var content: Content

    func loadAtLaunch() throws      // synchronous-ish, blocks first render
    func refreshInBackground() async // never blocks anything
}
```

**At launch:** read the cached document from Application Support and the
bundled document from the app bundle, decode and validate both, and use
whichever has the higher `version`. A cached document that fails to decode or
validate is deleted and the bundled one is used. The bundled document is
therefore always a working floor: first launch works with no network, and no
sequence of bad fetches can leave the app without content.

**In the background, after launch:** GET the content URL. If the response
decodes, has a recognised `schemaVersion`, passes full validation, and has a
higher `version` than what is loaded, write it to the cache atomically.

**Promotion happens at the next launch, not immediately.** Swapping content
underneath a running app could change a session while someone is halfway
through it. The fetch only ever updates the cache; the in-memory content for
this run never changes.

Failure at any step — offline, timeout, non-200, malformed JSON, unknown
`schemaVersion`, failed validation, oversized response — is not an error the
user sees. The fetch is abandoned and the cache is left as it was. Rejection
is wholesale: a document is used in full or not at all, never partially
merged.

Constraints: HTTPS only, no credentials (the content is public), a 10-second
timeout, and a 5 MB response cap.

## Persistence

SwiftData, four models, all of them user-owned.

```swift
@Model final class Profile          // one row
  var name: String
  var reminderWeekdays: [Int]       // 1...7
  var reminderTime: DateComponents
  var remindersEnabled: Bool

@Model final class Enrollment
  var programID: String             // content id
  var startedAt: Date
  var finishedAt: Date?
  var isActive: Bool                // exactly one active at a time
  var completions: [SessionCompletion]

@Model final class SessionCompletion
  var enrollment: Enrollment?
  var sessionID: String             // content id — NOT a position
  var startedAt: Date
  var finishedAt: Date?             // nil = bailed out mid-session
  var rpe: Int?                     // optional 1...10, asked once at the end
  var setLogs: [SetLog]

@Model final class SetLog
  var completion: SessionCompletion?
  var exerciseID: String            // content id
  var setNumber: Int
  var actualReps: Int?              // exactly one of reps/seconds is set,
  var actualSeconds: Int?           // matching the prescription's target
  var bandLevel: BandLevel?         // light, medium, heavy — band exercises only
```

Every reference from user state into content is a **stable string id**. This
is mandatory rather than stylistic: content is now mutable between releases,
and an integer index into a reorderable array would silently misattribute
someone's history the first time a session moved.

### Content that changes underneath existing history

Because content ships independently, user rows can outlive what they point at.
The rules:

- **A session id disappears from a program.** Completions for unknown ids are
  ignored by the engine and by progress counts, but are never deleted. If the
  id returns, the history reattaches on its own.
- **A program id disappears.** An enrollment pointing at it is kept and shown
  as archived and unavailable. Its logged history stays readable; it cannot be
  resumed.
- **An exercise id disappears.** Its `SetLog` rows persist and are shown by id
  in history; it simply stops appearing in charts.
- **Prescriptions change within a session someone already finished.** Nothing
  is rewritten. The logs record what was actually done, which is the only
  claim they ever made.

Deleting content ids is therefore safe but lossy from the user's point of
view, and is worth avoiding. Renaming an id is equivalent to deleting one and
adding another.

### Logging shape

There is no weight to log on this equipment, so "full logging" means actual
reps or actual seconds per set, plus band level where relevant, plus one
optional session RPE. Week 7's set of 14 against week 1's set of 8 tells the
same progression story a heavier bar would.

## ProgramEngine

Pure, no store, no clock, no network. It does not take SwiftData models — it
takes a value type mapped from them at the call site, which is what keeps the
suites constructible from array literals with no container.

```swift
struct CompletionRecord: Hashable {   // mapped from SessionCompletion
    let sessionID: String
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

- The next session is the first in program order whose id has no *finished*
  completion. A bailed session (`isFinished == false`) is offered again, and
  resuming reuses that same completion row rather than creating a second one.
- Completion records whose `sessionID` is not in the program are ignored
  everywhere, including `progress` denominators.
- `isComplete` is true when every session in the program has a finished
  completion.
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

**Programs.** The programs in the current content document, each with
`whoThisIsFor`, the full session list, and enrol / switch. Switching archives
the current enrollment rather than deleting it — history always survives.

**Progress.** Streak, sessions completed, completion percentage, benchmark
charts, session history.

**Settings.** Reminder weekdays and time, profile, the full exercise library
for reading outside a session, and the loaded content `version` (so a content
problem can be diagnosed without a debugger).

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
- `Content/content.json` lives in this repo, is committed, is copied into the
  app bundle as the baseline, and is the same file served over HTTPS. One
  source of truth, edited by hand.
- The content URL is a single constant in one file, pointing at the raw
  GitHub URL for `Content/content.json`.
- **Prerequisite:** this repo is currently local-only. Remote content updates
  do not work until it is pushed to GitHub and the file is reachable
  unauthenticated over HTTPS. Until then the app runs on bundled content and
  every fetch fails silently, which is a supported state, not a broken one.

```sh
brew install xcodegen
xcodegen generate
open FairwayFit.xcodeproj
```

## Testing

1. **ProgramEngine** — next session, progress, completion, bailed-session
   resumption, unknown-session-id records ignored, repeatable re-enrollment.
   Array literals only.
2. **Content validation** — one rule set, used in two places: a test that runs
   it against the repo's `content.json` in CI, and `ContentStore` running the
   identical rules against any fetched document. Rules: `schemaVersion` is
   supported; `version` is a positive integer; exercise ids are unique and
   non-empty; every `exerciseID` in a prescription resolves; every exercise
   has a name, setup, at least two cues, a swing rationale and an `https`
   demo URL; session ids are globally unique; no session has zero blocks and
   no block has zero prescriptions; blocks appear in warmup → main →
   finisher order; program ids are unique; no program has zero sessions;
   `weeks` and `sessionsPerWeek` are positive; at least one exercise is
   flagged `isBenchmark`; every `sets` and target value is positive.
3. **ContentStore** — bundled-only first launch; cached-newer wins;
   bundled-newer wins after an app update; corrupt cache falls back to bundled
   and is deleted; unknown `schemaVersion` rejected; failed validation
   rejected wholesale; oversized and non-200 responses ignored; a successful
   fetch does not change in-memory content until relaunch.
4. **Progress and streak** — week-boundary behaviour, gaps, the two-sessions
   threshold, timezone stability.
5. **Reminder scheduling** — clock-injected, correct next-fire dates for a
   given weekday set, rescheduling after completion.

## Failure modes

| Situation | Behaviour |
|---|---|
| No network, ever | App works entirely on bundled content. Only demo videos need the network. |
| Remote content unreachable, malformed, oversized, or invalid | Silently ignored; cache untouched; last good content stays loaded |
| Cached content corrupt | Deleted, bundled content used |
| Bundled content invalid | Fatal at launch. This is a build defect, not a runtime condition — the CI content test exists to make it impossible to ship. |
| Content newer than the app understands (`schemaVersion`) | Rejected; app keeps working on what it has |
| Notification permission denied | Settings explains it; app otherwise unaffected |
| YouTube link cannot open, or the video is gone | Cues and rationale stand alone; fix is a content push, not a release |
| Bail out mid-session | Partial logs persist; session stays unfinished; engine offers it again and resumes the same row |
| Switch programs mid-way | Old enrollment archived, not deleted; history intact |
| Content ids removed underneath existing history | See "Content that changes underneath existing history" |
| SwiftData container fails to load | Fatal at launch with a clear message; there is no remote copy of user data to fall back to |

## Out of scope for v1

Pre-round warmup routines, HealthKit and Apple Watch, bundled demo media,
profile-generated or adaptive programming, movement screens, dumbbell or
barbell variants, iPad, sync of user data across devices, a content editing
UI, and any server component beyond a static file over HTTPS.
