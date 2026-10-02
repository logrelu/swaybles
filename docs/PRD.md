# PRD — Swaybles: Make the Most of the Last 90 Days

**Status:** v4 (replaces v3 "31 Nights") · **Owner:** logrelu · **Date:** 1 Oct 2026

## 1. The bet
Desktop hanging-charm apps are a crowded trend: a dozen open-source clones, **all with 0 GitHub
stars**, some well built. Code is not scarce; attention and a reason to keep the app open are.

Swaybles wins on three things:
1. **A fidget toy for your screen.** Flicking a swinging charm is a small, harmless stim, especially
   loved by ADHD brains.
2. **A focus companion that celebrates you.** Charms cheer when you finish a focus session and
   doze when you step away. Never shames.
3. **A daily content series:** "Make the most of the last 90 days": Day 1 = 1 Oct, Day 90 = 29 Dec,
   New Year's Eve finale. Rides the "October Theory" trend (1 Oct as a fresh start for the last
   quarter). Seasonal skins: Halloween (Oct), cozy autumn + Thanksgiving / Bonfire Night (Nov),
   winter holidays (Dec).

Free and open source (MIT). The daily series and the art are the moat, not the code.

## 2. Goals (by 31 Dec)
| Metric | Target |
|---|---|
| Days posted | 90 / 90 (+ NYE finale) |
| Instagram + TikTok followers | 3,000 |
| App downloads | 3,000 |
| People who finished ≥1 focus session (opt-in local count, shown only to them) | n/a, no tracking; proxy = video comments mentioning focus |
| Tips + custom pet charms | $100 |
| GitHub stars | 100 (from one Show HN / r/macapps launch, not from videos) |

## 3. Who it's for
- **Primary:** 16–30, ADHD and neurodivergent folks on #adhdtok / #studytok, desk-setup and cozy-aesthetic fans.
- Message: "**made for ADHD brains**". Never a medical or treatment claim.

## 4. Features
### 4.1 Already built
Swinging charms with rope physics, 8 rope styles, Studio window, photo-to-charm, packs as data, tests.

### 4.2 Focus Crew (new — the reveal on Day 8)
Five charms with **blank surfaces the app writes on** (see `docs/ART.md` §Functional charms):

| Charm | Blank surface | The app shows |
|---|---|---|
| Timer Ghost | Round clock face, no hands or numbers | Focus countdown ring + minutes left |
| Chalkboard Cat | Small chalkboard sign | Kind words: "you showed up", "one step counts" |
| Banner Bat | Ribbon banner | "Day 12 / 90", "5 focus sessions this week" |
| Task Lantern | Paper tag on a string | The one thing you're doing now ("reply to Sam") |
| Cocoa Buddy | (none) | Swings in on breaks: "sip, stretch, back in 5" |

### 4.3 Focus behaviour (rules, not suggestions)
- **Start:** user starts a focus session (menu bar, hotkey, or flick Timer Ghost). Default 25 min; 15/25/45 presets.
- **Done:** every charm does a happy wiggle, a burst of hearts/sparkles drawn by the app, Chalkboard Cat cheers.
- **Away:** after 5 min of no mouse/keyboard (system idle time), charms droop and doze. They wake with a stretch when you return. **No message, no guilt.**
- **Breaks:** Cocoa Buddy swings in. The timer never auto-restarts.
- **Never shame.** No "you were unproductive", no red, no counters of failure. A missed day doesn't reset a streak to zero in a scolding way; it says "welcome back".
- **Roast mode:** opt-in only, joke lines, off by default.
- **Reduce motion** respected everywhere.

### 4.4 Permissions (hard requirement)
| Sense | macOS permission | Allowed |
|---|---|---|
| Timer started by the user, hotkey | None | ✅ |
| System idle time | None | ✅ |
| Time of day, streaks (stored locally) | None | ✅ |
| Frontmost app name | None | ⚠️ opt-in only, off by default |
| Window titles / websites | Screen Recording | ❌ never |
| Keystrokes | Input Monitoring / Accessibility | ❌ never |
| Screenshots or anything sent to a server | — | ❌ never |
Nothing leaves the Mac. No accounts, no analytics.

### 4.5 My 90 Days (the counter and the goal)
- **One goal.** On first launch (or any time) the user types one goal for their 90 days. Task Lantern shows it.
- **The counter is a calendar, not a streak.** "Day 12 / 90" counts days since *they* started, so
  people who download in November get their own Day 1. Missing a day changes nothing; there is no
  streak to break and no "you missed" message.
- **Wins jar.** Each finished focus session drops a small sparkle into a jar charm. Weekly line on
  Chalkboard Cat: "look what you did this week: 7 sessions". Only ever counts up.
- **Optional "days left in the year"** mode for people who'd rather follow the series count.
- **Season skins** switch by date: Halloween glow in October, cozy autumn in November, snow and
  ornaments in December. All optional.
- Day 90 for the user: confetti, every charm swings, "you did 90 days". Then offer a new 90.

## 5. Art budget (Imagine Art credits)
A new charm about **3 times a week**, not daily. The other days show a feature, a goal check-in, a
viewer's desk, or a charm reacting.
| Use | Images |
|---|---|
| Spooky Crew (done) | 5 |
| Cat Crew (generated) | 5 |
| Focus Crew (generated 1 Oct) | 5 |
| October (Halloween) | ~8 |
| November (cozy autumn, Thanksgiving, Bonfire Night, gratitude) | ~12 |
| December (winter, holiday ornaments, NYE) | ~13 |
| **Total new from today** | **~33**, generated a week ahead |
Rules: text and numbers are **never** generated into images (the app draws them); reactions use
physics + app-drawn effects, **not** extra pose images; regenerate a failed charm at most once.

## 6. Constraints found
- **Imagine Art commercial use requires a paid subscription.** Tips and custom pet charms count as commercial. Confirm the plan is paid before launch.
- **AI-generated images can't be copyrighted** (US). The art license is a polite request, not a strong protection. Our moat is the daily channel.
- Cloud sessions can't download from Imagine Art or compile Mac apps. **Build in Claude Code on the Mac** (§8).
- Without the $99/yr Apple Developer account the app can't be notarized: first launch needs right-click → Open. Say so on the download page.

## 7. Non-goals
Accounts, cloud sync, analytics, Windows, Etsy, licence keys, any surveillance-style sensing.

## 8. How it's built (decided 1 Oct: native rewrite)
- **Native Swift app in `mac/`** (Swift package; open `mac/Package.swift` in Xcode). Target: macOS 14+,
  universal (Apple Silicon + Intel), download under 10 MB, idle CPU ~0 (the loop sleeps when charms are still).
- `SwayblesCore` = pure logic (rope physics, day counter, catalog, settings, copy), covered by Swift Testing.
  `Swaybles` = the app: menu bar, transparent click-through overlay, Studio window.
- No license, no network, no new permission prompts.
- The Electron app in `src/` stays only as the art/manifest pipeline and the promo recorder until the
  native app reaches parity, then `src/` app code is deleted.
- Work in **Claude Code in the Mac Terminal, inside the repo**: it builds with `swift build`, runs the
  tests, saves Imagine Art images to `art/raw/`, and packages the app with `mac/scripts/make-app.sh`.

## 9. Timeline
| When | What |
|---|---|
| Day 1 (1 Oct) | "October Theory: 90 days left. Here's my desk buddy." Spooky Crew; no download yet. |
| 1–7 Oct | Native app in Xcode: charms swing, menu bar, Studio. |
| **Day 8** | **Free download + reveal: "your charms cheer when you finish focusing"** |
| Oct | Halloween charms, Focus Crew spread through the month, goal + counter ships |
| Nov | Cozy autumn, gratitude week (Chalkboard Cat), Thanksgiving (US) and Bonfire Night (UK) |
| Dec | Holiday ornaments, wins-jar recap videos, custom pet charm giveaway |
| Day 90 (29 Dec) + NYE | Finale: everything swings, "you did 90 days", invite to the next 90 |
| ~Day 45 | Repo public; Show HN / r/macapps |
