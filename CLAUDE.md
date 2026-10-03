# Swaybles — working rules

Swaybles is a **free, open-source, native** Mac app (Swift, in `mac/`): charms hang from the top of the screen, swing with rope
physics, and act as a gentle focus companion "made for ADHD brains". Growth comes from the daily
video series ("Make the most of the last 90 days", 1 Oct to NYE). Read `docs/PRD.md` before planning and `docs/ART.md` before
touching art.

## Decisions already made (ask before reopening)
- **Art comes only from Imagine Art**, per `docs/ART.md`. Never hand-draw charms in SVG/code.
- **No text in generated images.** Timers, quotes, banners and task names are drawn by the app on a blank surface.
- **Packs and charms are data** (`tools/packs.json` + `npm run charms`). No engine code per charm.
- **The 90-day counter is a calendar, not a streak.** Nothing resets, nothing is "missed".
- **Never shame the user.** Celebrate finishes, doze quietly when idle, "welcome back" after gaps.
  No guilt copy, no failure counters, no red. Roast mode is opt-in and joking.
- **Privacy:** only user-started timers, system idle time, time of day and local streaks.
  Never window titles, keystrokes, screenshots, or network calls with user data. No new macOS
  permission prompts. Frontmost-app name only behind an off-by-default opt-in.
- **Respect Reduce Motion** in every animation.
- **Native Swift, macOS 14+.** The Electron app in `src/` is legacy: keep it only for the art pipeline
  (`npm run charms`) and promo recorder; don't add features there.
- **No license, no network, no accounts.** Free download, tips optional.
- Code is MIT; charm images under `ART-LICENSE`.

## Commands
| Task | Command |
|---|---|
| Run the app | `cd mac && swift run Swaybles` (or `open mac/Package.swift` → Xcode → ⌘R) |
| Tests | `cd mac && swift test` (Xcode: ⌘U) |
| Package for download | `mac/scripts/make-app.sh` → `mac/dist/Swaybles-<version>.zip` |
| Import charm art | `npm install` once, then `npm run charms [pack]` (writes `src/charms/` and `mac/Resources/Charms/`) |
| Review a pack | `npm run charms:review <pack>` → `art/review/<pack>.png` |

**Definition of done:** `swift build` has no errors, `swift test` passes, you ran the app and watched
the change on screen, the contact sheet was looked at for new art, and every new line of copy is in
`Copy.swift` and passes the never-shame test.

## Code map (`mac/`)
- `Package.swift` — Swift package, macOS 14+. Open it in Xcode.
- `Sources/SwayblesCore/` — pure logic, no AppKit, fully tested:
  `Physics.swift` (rope), `NinetyDays.swift` (counter + wins jar), `FocusClock.swift`,
  `Catalog.swift` (reads `charms.json`), `Settings.swift`, `Copy.swift` (every word the charms say)
- `Sources/Swaybles/` — the app:
  `SwayblesApp.swift` (menu bar + Studio scene), `AppModel.swift` (state, focus, idle, what each charm says),
  `Overlay.swift` (transparent click-through panel, animation loop, mouse), `OverlayView.swift` (drawing),
  `Ropes.swift` (rope styles), `MenuContent.swift`, `StudioView.swift`
- `Resources/Charms/` — charm PNGs + `charms.json` (generated; don't edit by hand)
- `Tests/SwayblesCoreTests/` — Swift Testing, pure logic
- `Tests/SwayblesAppTests/` — Swift Testing, the app layer: `AppModel` (injected defaults, catalog, clock, idle source) and `OverlayGeometry.swift` (hit-testing, drag clamp). The panel, display link and drawing are covered by `docs/QA.md`, not unit tests
- `scripts/make-app.sh` — universal .app, icon, ad-hoc signature, zip

Legacy: `src/` (Electron app, don't add features), `tools/` (art importer, contact sheet, promo recorder),
`docs/` (PRD, ART spec, 90-day calendar).

## Guardrails
- Never commit secrets. The repo will be public.
- Never commit `dist/`, `node_modules/`, `art/review/`.
- Imagine Art credits cost money: generate only what the PRD's art budget lists; regenerate a failed charm at most once; ask before more.
- Posting to social accounts always needs the owner's OK in chat.

## Releasing
1. Bump `version` in `package.json` (the script reads it).
2. `cd mac && swift test` passes.
3. `mac/scripts/make-app.sh`, then run through `docs/QA.md` on the packaged app (not `swift run`).
4. Upload the zip to GitHub Releases. Download note: "first time: right-click → Open".
