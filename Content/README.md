# Content

`content.json` is the whole of Fairway Fit's content: every exercise, session
and program. It is bundled into the app as a baseline **and** served from this
repository (`https://github.com/thall1961/golf-fitness-app`), so it can be
updated on installed phones without an App Store release.

> **The repository is public and the endpoint is live** — but it resolves only
> once `Content/content.json` exists on `main`. The app fetches
> `https://raw.githubusercontent.com/thall1961/golf-fitness-app/main/Content/content.json`
> with no credentials, by design; today that path 404s because this file
> currently lives on the `fairway-fit-v1` branch, not `main`, so every
> background refresh fails silently — installed phones simply keep running on
> their bundled content, which is a fully supported state. Nothing in the app
> changes when this branch merges to `main`; remote updates simply begin
> working.

## Updating content

1. Edit `content.json`.
2. **Bump `version`.** A document that is not strictly newer than what a phone
   already has is ignored. This is the single most common mistake.
3. Run the tests: `xcodebuild test -project FairwayFit.xcodeproj -scheme FairwayFit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -quiet`
   The `BundledContentTests` suite runs the exact validation the app runs
   against anything it fetches. Nothing reaches a phone that fails it.
4. Commit and push to `main`.

Phones download it in the background and start using it the next time the app
launches — never mid-session.

## Rules that will bite you

- **Never rename or remove an id.** Session and exercise ids are how logged
  history attaches to content. A renamed id reads as a deletion plus an
  addition, and the user's history for it silently stops counting.
- **`schemaVersion` stays 1** unless the app's `Content.supportedSchemaVersion`
  changes too. Bumping it alone makes every installed app reject the document.
- **Rejection is wholesale.** One bad `demoURL` invalidates the entire file for
  every user, not just that exercise. Run the tests.
- Adding sessions to the end of a program is safe. Reordering them is safe too,
  now that completions key off session id rather than position — but it changes
  what "Session 9 of 24" means to someone mid-program.

## Demo URLs are deliberately search links

Every `demoURL` in `content.json` points at a YouTube **search** URL (a query
for the exercise name) rather than a specific video id. Search URLs don't rot
the way a single video id does — the linked video can't be deleted, made
private, or region-blocked out from under the app. Swapping in curated,
hand-picked video links later is a content-only change: edit `content.json`,
bump `version`, and push, same as any other update.
