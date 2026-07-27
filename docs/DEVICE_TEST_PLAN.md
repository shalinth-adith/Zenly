# Zenly — Device-Only Test Plan

| | |
|---|---|
| **Version** | 2.0 — rewritten 2026-07-27 for the current "Quiet" UI |
| **Supersedes** | the `[Device]` cases in `TEST_CASES.md` (v1 navigation is stale throughout) |
| **Scope** | Only what a physical iPhone can verify. Everything runnable on Simulator is already automated in `ZenlyUITests/ZenlyQuietSuite` + `ZenlyTests` and is not repeated here. |
| **Total cases** | 53 across 8 sections |

Every case below has been re-checked against the current source, so the navigation paths and
on-screen wording match what you will actually see.

---

## Why this rewrite exists

The Quiet redesign changed navigation and copy, and features were deleted. v1 sends you to screens
that no longer exist. Concretely:

| v1 said | Reality |
|---|---|
| "Profiles tab" | No such tab. **Settings → Focus profiles**, or **Schedule → New profile** |
| "Schedules" tab | Tab is named **Schedule** (singular) |
| "Start Focus" button | Button reads **Begin focus** |
| Splash: "Zenly / Find your focus", ~2.2s | **"Zen-ly" / "A calm and simple way to stay focused."**, auto-advances at 3.6s (1.6s Reduce Motion), tap to skip |
| Work / Study / Gym seeded | Four profiles — **Work, Study, Gym, Sleep** |
| "delete the app to re-test onboarding" | **Does not work** — see Prerequisites |

---

## Prerequisites

- iPhone running iOS 17+ (iPhone 14 Pro or later for Dynamic Island cases), unlocked, **Trust This
  Computer** accepted. Verify it appears in Xcode → Window → Devices and Simulators.
- Paid Apple Developer account. Family Controls Distribution is **already granted** for team
  `649T62WKAQ` — no request needed.
- Build and run the `Zenly` scheme in **Debug** to the device.

**Resetting to a true first-run state.** Deleting the app is *not* enough: `hasCompletedOnboarding`
and the seeded profiles live in the shared App Group container, which survives app deletion on
Simulator and can survive it on device. To force a genuine first run, delete the app **and** reboot
the phone before reinstalling; if onboarding still doesn't appear, the group state persisted —
note it and move on rather than chasing it.

**Recording results.** Fill in the Result column. Anything not PASS needs a screenshot or screen
recording attached.

---

## A. Screen Time authorization

| ID | v1 | Case | Steps | Expected | Result |
|---|---|---|---|---|---|
| D-A1 | 1.3 | Grant from onboarding | Fresh install → onboarding page 4 "Screen Time Access" → **Grant Screen Time Access** | System prompt appears; approving changes the button to **Access Granted** and advances to "You're all set" | |
| D-A2 | 1.3 | Skip and grant later | On the same page tap **Maybe later** → finish onboarding → Focus tab | Home shows the **"Screen Time access needed"** card with a **Grant Access** button; **Begin focus** is disabled and dimmed until granted | |
| D-A3 | — | Grant from Settings | Settings → Screen Time → **Grant Screen Time Access** | Prompt appears; after approving the row reads **Access granted** with a seal icon | |
| D-A4 | — | Grant from Schedule | Schedule tab (unauthorized) → **Grant access** under "Schedules need Screen Time access to start on their own." | Prompt appears; notice disappears once granted | |
| D-A5 | **1.5** ⚠️ | **No repeated prompt** | Grant once, then force-quit and reopen the app 5+ times; background/foreground it several times | The Screen Time prompt **never** reappears; Home never re-shows the access card | |

> **D-A5 is a flagged regression case.** Do it early — it is nearly free once the app is installed.

---

## B. Blocking — the core of the product

**None of this has ever been executed.** It is the single biggest risk to launch. Set up a profile
first: Settings → Focus profiles → pick one → configure under **Blocking**.

| ID | v1 | Case | Steps | Expected | Result |
|---|---|---|---|---|---|
| D-B1 | 2.1 | Block specific apps | Profile → Blocking → **Block all apps OFF** → **Blocked apps & sites** → pick one app → Save → Begin focus → open that app | Zenly's custom shield appears instead of the app | |
| D-B2 | 2.2 | Block all apps | Profile → Blocking → **Block all apps ON** (default) → Begin focus → try several apps and Safari | All non-system apps shielded. **Phone, Messages, Settings and Zenly stay usable** | |
| D-B3 | 2.3 | Allowed apps escape hatch | Block-all ON → **Allowed apps** → add one app → Save → Begin focus → open it | It opens normally; everything else stays blocked | |
| D-B4 | 2.4 | Research mode allowlist | Profile → **Research mode — allowed websites** = `claude.ai, docs.google.com` → Save → Begin focus → Safari → visit an allowed site, then an entertainment site | Allowed sites load; every other site is blocked. Safari itself still opens | |
| D-B5 | 2.5 | Custom shield message | Settings → **Shield message** = "Future you will thank you" → Begin focus → open a blocked app | Shield shows the custom message. Clearing the field restores the default text | |
| D-B6 | 2.6 | Strict-mode gate | Profile → Session → **Strict** ON → Begin focus → **End early** | Confirmation appears with a streak-loss warning; primary button counts down **"Wait 5s…"** and is disabled until it becomes **End focus**. **Keep focusing** cancels | |
| D-B7 | 2.7 | Unblock on end | End the session (normally or early) → reopen the previously blocked apps and sites | Everything opens normally again; no lingering shield | |
| D-B8 | — | Non-strict end | Strict **OFF** → Begin focus → **End early** | Session ends immediately with no confirmation gate | |
| D-B9 | — | Shield survives relaunch | During a session, force-quit Zenly → open a blocked app | Still shielded (enforcement lives in ManagedSettings, not the app process) | |

---

## C. Sessions & timer

| ID | v1 | Case | Steps | Expected | Result |
|---|---|---|---|---|---|
| D-C1 | 3.1 | Start a session | Focus tab → set duration with −/+ → **Begin focus** | Full-screen session with countdown ring; blocking engages; start haptic fires | |
| D-C2 | 3.3 | Minimize & resume | In session tap **▾** (top-left) → browse other tabs → return via the resume banner | Session keeps running; app is navigable; banner reopens the timer. **Begin focus** stays disabled while active | |
| D-C3 | 3.4 | Natural completion | Start a 5-minute session and wait it out | Celebration summary with confetti + haptic; **"Focus complete"** notification; shields lift | |
| D-C4 | **3.5** ⚠️ | Recorded after app is killed | Start a session, leave Zenly until iOS terminates it, reopen after the end time | Session is recorded — streak / today's minutes update. **Reported PASS on 2026-07-27 — re-confirm on the current build** | |
| D-C5 | 3.5b | Resume mid-session after kill | Start a long session, force-quit, reopen **before** the end time | Timer resumes with the correct remaining time (not restarted, not lost) | |
| D-C6 | 3.6 | End early excluded | Start a session, end early | Logged as ended early; does **not** add to streak or today's minutes | |
| D-C7 | 3.7 | Pomodoro break | Profile with a non-zero Break → complete a focus session → **Take a break** | Break timer runs with **no blocking**; **"Break over"** notification at the end | |
| D-C8 | 3.8 | Post-session review | On the summary, tap a star rating and type a note → Done | Saves against that session (now verifiable via Insights → See all sessions → tap the session, see D-I5) | |

---

## D. Live Activity, Dynamic Island & Widget

**D-D4 is a regression test for a bug fixed on 2026-07-27 — please do it carefully.**

| ID | v1 | Case | Steps | Expected | Result |
|---|---|---|---|---|---|
| D-D1 | 7.2 | Lock Screen activity | Begin focus → lock the phone | Lock Screen banner with profile name and a live countdown, tinted to the profile accent | |
| D-D2 | 7.3 | Dynamic Island | Begin focus (iPhone 14 Pro+) | Compact pill counts down; long-press expands to profile + progress | |
| D-D3 | — | Activity appears at all | Begin focus | The Live Activity **appears** — this is the regression risk from the fix; if it never shows, the sweep in `end()` is tearing down the new activity | |
| D-D4 | **NEW** | **Activity clears after termination** (Finding 6) | Begin focus → leave Zenly until iOS terminates it → reopen → let the session end (or End early) | Dynamic Island **and** Lock Screen timer **disappear**. Previously the countdown was stranded on screen forever | |
| D-D5 | **NEW** | No duplicate activities | Begin focus → force-quit → reopen mid-session | Exactly **one** Live Activity, not two side by side | |
| D-D6 | — | Normal end clears it | Begin focus → **End early** without any termination | Activity disappears immediately | |
| D-D7 | 5.x | Schedule countdown activity | With an upcoming enabled schedule, open the app shortly before its start time | A "starting soon" countdown Live Activity appears and is replaced (not duplicated) by the session activity when the window opens | |
| D-D8 | 7.1 | Home-screen widget | Add the Zenly widget → configure metric (streak / minutes / attempts) | Shows the chosen stat and updates after a session completes | |

---

## E. Schedules

| ID | v1 | Case | Steps | Expected | Result |
|---|---|---|---|---|---|
| D-E1 | 5.2 | Auto-start in window | Schedule → **Add schedule** with a window covering now on today's weekday → Save → keep the app open | A focus session **auto-starts** within ~30s and blocking engages without tapping Begin focus | |
| D-E2 | 5.3 | Weekday filtering | Create a schedule excluding today's weekday | Nothing starts and nothing is blocked today | |
| D-E3 | — | Duration equals remaining window | Create a schedule ending in ~20 minutes → let it auto-start | Session length ≈ **remaining** minutes of the window, and may exceed the 120-minute manual cap (see report Finding 4 — confirm this is intended) | |
| D-E4 | — | Toggle off disables | Toggle a schedule off before its window | No auto-start, no blocking | |
| D-E5 | — | Start notification | Background the app before a schedule window opens | A time-sensitive **schedule-start notification** arrives and opening it starts the session | |
| D-E6 | — | No hijack mid-session | Start a manual session, then let a schedule window open | The running session is **not** interrupted or replaced | |

> **Heads-up:** a saved schedule whose window covers "now" hijacks the UI into a full-screen session
> almost immediately. Create schedules for a *future* window unless you are testing D-E1.

---

## F. System integration

| ID | v1 | Case | Steps | Expected | Result |
|---|---|---|---|---|---|
| D-F1 | 10.1 | Siri / Shortcuts | "Hey Siri, start a focus session in Zenly", and run the action from the Shortcuts app | Zenly opens and starts a session with the active profile | |
| D-F2 | 10.2 | Control Center | Add the **Start Focus** control (iOS 18+) → tap it | Zenly opens and starts a session | |
| D-F3 | 9.5 | Focus filter | iOS Settings → Focus → add the Zenly filter → pick a profile → enable that Focus | Zenly switches to that profile on next open | |
| D-F4 | — | Notification delivery in foreground | Keep Zenly open when a session completes | The completion notification is presented while foregrounded (regression fixed in `47c300f`) | |
| D-F5 | — | Time-sensitive breakthrough | Enable a Focus/Do Not Disturb mode, then let a schedule window open | The schedule-start notification breaks through | |

---

## G. Accessibility & appearance on device

| ID | v1 | Case | Steps | Expected | Result |
|---|---|---|---|---|---|
| D-G1 | 1.6 | Reduce Motion | Settings → Accessibility → Reduce Motion ON → launch | Splash shows the static mark with no looping/breathing animation and advances after ~1.6s | |
| D-G2 | 11.1 | VoiceOver on Home | VoiceOver ON → swipe through Focus tab | Duration announces "Focus duration, N minutes"; −/+ announce "Decrease/Increase focus duration"; profile chips announce their name and selected state | |
| D-G3 | 11.1 | VoiceOver in session | VoiceOver ON during a session | Minimize and End early are labelled and operable; the countdown is readable | |
| D-G4 | 11.2 | Dynamic Type XXXL | Set the largest accessibility text size → walk Focus, Insights, Schedule, Settings | No clipping or overlap. **Settings → "Your name" was fixed on 2026-07-27** — label and field must sit on separate lines | |
| D-G5 | — | Dark / Light | Toggle appearance | Both render correctly; no invisible text | |
| D-G6 | — | Safe areas | Check Focus and the session screen on a Dynamic Island device | No content under the Island or the home indicator | |

---

## I. Insights — newly wired surfaces (added 2026-07-27)

Two of the orphaned surfaces were connected on request. Both need data, so they can only be checked
on device after at least one session has completed.

| ID | v1 | Case | Steps | Expected | Result |
|---|---|---|---|---|---|
| D-I1 | **6.3** | Distraction count shows | Complete a session during which you opened blocked apps a few times → Insights | Under the bar chart: **"N distractions blocked this week"**. N > 0 and roughly matches how many times you hit the shield (deduped ~1 per open) | |
| D-I2 | 6.3 | Count increments | Note the number → run another session → trigger the shield 3 more times → return to Insights | The count rises by ~3 | |
| D-I3 | 6.3 | Zero state reads correctly | With no attempts this week | Shows **"0 distractions blocked this week"** (plural), not blank or "1 distraction" | |
| D-I4 | **6.5** | History reachable | Insights → scroll past the recent sessions → **See all sessions** | Pushes the **History** screen with a back button; shows day-grouped past sessions with duration, outcome, rating and note | |
| D-I5 | 6.5 | History detail | In History, tap a session | Opens the session detail with its rating, note and the timestamped distraction attempts for that session's window | |
| D-I6 | 6.5 | Empty history | Fresh install, no sessions | Insights shows its "Your focus story starts here" empty state; **See all sessions** is not reachable until a session exists (by design) | |

**Automated coverage already in place:** the distraction *data* path is now unit-tested
(`DistractionLogTests`, 6 tests) — recording, the 1.5s dedupe window, per-day bucketing, session-window
attribution, and the fold into `weeklyStats()` that D-I1 displays. What remains for device is purely
"is the right number on screen, and does History open".

---

## H. Cannot be tested — no UI entry point

These were `[Device]` cases in v1. A phone will **not** help: the screens exist in the codebase but
nothing navigates to them. `AnalyticsView` is a flat terminal screen — it contains a
`NavigationStack` but zero `NavigationLink`, `navigationDestination` or `sheet`.

| v1 case | Blocked because |
|---|---|
| 6.4 App usage per-app detail | `AppUsageReportView` (29 lines) has **no entry point** |
| 6.6 Badges & Accountability | `BadgesView` (57) and `LeaderboardView` (72) have no entry point |
| 8.1 Badge awarded on first session | No badge UI to observe it in (award logic itself is unit-tested) |
| 8.2 Daily challenge | `ChallengeDetailView` (189) has no entry point |
| 8.4 Daily goal detail | `GoalsView` (133) has no entry point — goals are only editable in Settings and shown inline on Insights |

**~660 lines across 5 view files remain unreachable** (History and its detail view were wired up on 2026-07-27 — see Section I). This is a second wave of orphaned UI, distinct
from the services deleted earlier. **Decision 2026-07-27 (owner): deferred — leave as-is for this release.** These views stay in the
codebase without entry points, and the cases above stay withdrawn. They are unreachable rather than
broken, so there is no user-visible impact and nothing here blocks submission; the only cost is a
small amount of dead code in the binary. Revisit post-launch.

---

## Run 1 — 2026-07-27 (developer, physical iPhone)

**Sections A, B, C, F, G: passed**, with two defects found in B. Section E partially run
(D-E2, D-E3 equivalents passed). **Section D was not run** — see "still outstanding" below.

### Defects found — both fixed the same day, both need re-test

| ID | Symptom | Root cause | Fix |
|---|---|---|---|
| **D-B5** | Shield-message keyboard could not be dismissed | `TextField(axis: .vertical)` makes Return insert a newline instead of submitting, and the field had no toolbar or focus binding — so the keyboard had no exit | Added `@FocusState` + a keyboard **Done** button (`SettingsView.swift`) |
| **D-B6** | After the 5-second countdown the **End focus** button was invisible — white text on white | `.buttonStyle(.borderedProminent)` fills with the inherited tint, and the Quiet theme sets `.tint(ZTheme.Palette.textPrimary)` = `E7E8EC` in dark mode. White fill + white label | Replaced with an explicit red fill and white label, independent of tint; muted while counting down (`StopBlockingConfirmation.swift`) |

Regression after both fixes: Release build succeeds, 21 unit + 14 UI tests pass, 0 failures.

**Re-test 2026-07-27 (developer, physical iPhone): both confirmed fixed.** The shield-message
keyboard now dismisses via **Done**, and the strict-mode **End focus** button is legible once the
5-second countdown completes. **D-B5 and D-B6 → PASS.**

### Still outstanding

- **Section D in full (8 cases)** — Live Activity, Dynamic Island and Widget. This contains
  **D-D3/D-D4/D-D5**, the regression tests for the stuck-timer fix (report Finding 6), which is
  still unconfirmed on device.
- **D-B5 and D-B6 re-test** on the new build.
- **D-B8** (non-strict end, no confirmation) and **D-B9** (shield survives force-quit).
- **D-E1** (auto-start in window), **D-E4** (toggle off disables), **D-E5** (start notification),
  **D-E6** (no hijack mid-session).

> **Section H cannot pass or fail** — it lists cases with no UI entry point, so there is nothing to
> execute. It is a decision to make, not a test to run.

---

## Sign-off

| Section | Cases | Passed | Failed | Blocked |
|---|---|---|---|---|
| A — Screen Time authorization | 5 | | | |
| B — Blocking | 9 | | | |
| C — Sessions & timer | 8 | | | |
| D — Live Activity & Widget | 8 | | | |
| E — Schedules | 6 | | | |
| F — System integration | 5 | | | |
| G — Accessibility | 6 | | | |
| I — Insights (newly wired) | 6 | | | |
| **Total** | **53** | | | |

**Do not submit to App Review until Section B passes in full.** It is the product's core promise and
has never been executed.

Tester: ______________  Device / iOS: ______________  Build: ______________  Date: ____________
