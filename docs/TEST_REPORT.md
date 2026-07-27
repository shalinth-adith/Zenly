# Zenly — Test Execution Report

## Launch-readiness at a glance

**Verdict: not yet submittable — one substantive gap remains.** The app's core blocking behaviour
has still never been executed. Everything else that was blocking is now closed.

| Item | Status |
|---|---|
| Family Controls **Distribution** entitlement | **Already granted** — App Store profiles carry `family-controls = true` (team `649T62WKAQ`) |
| Privacy manifests (`PrivacyInfo.xcprivacy`) | **Done** — app + 5 extensions, verified shipping in a Release build |
| Dead features & their purpose strings | **Removed** — ~736 lines; strings absent from built `Info.plist` |
| Release build for device | **Succeeds** |
| Automated tests | **21 unit + 14 UI, 0 failures** |
| TC-3.5 — session survives app termination | **PASS** (developer, on device) |
| Finding 6 — stuck Dynamic Island timer | **Fixed in code — needs device re-confirmation** |
| Finding 3 — Settings overlap at XXXL | **Fixed and visually verified** |
| **§2 Blocking (7 cases)** | **NOT TESTED — blocks submission** |
| TC-1.5 — no repeated Screen Time prompt | **NOT TESTED** |
| Archive + upload to App Store Connect | **NOT YET RUN** |

Cases **TC-8.3, 9.1, 9.2, 9.3, 9.4** are **withdrawn** rather than blocked — those features were
deleted, so there is nothing left to test.


**Date:** 2026-07-27
**Commit:** `136d47b` (main, clean tree at start)
**Toolchain:** Xcode 26.4.1 (17E202)
**Target under test:** iPhone 16e Simulator, iOS 26.4 (app-group state wiped before the final run)
**Plan executed:** `TEST_CASES.md` / `TEST_CASES.pdf` — 54 numbered cases + 7 signing checklist items

---

## 1. Scope — what could and could not be executed

The plan is explicit that most of Zenly depends on Apple's Screen Time stack, which does not run on
the Simulator. That constraint dominated this run.

| Bucket | Cases | Status |
|---|---|---|
| Executed automatically (Simulator) | 21 | Ran, with real assertions |
| Verified by code inspection only | 12 | Implementation confirmed, **not executed** |
| Needs a physical iPhone | 16 | Not run (TC-3.5 since passed — see §7) |
| Withdrawn — feature deleted | 6 | Nothing left to test (see Finding 1) |

**No physical device was available during this run.** `xcrun devicectl list devices` reported
`Shalinth's iPhone … unavailable`, so every `[Device]` case (all of §2 Blocking, §7 Widget/Live
Activity, §10 Siri/Control Center, and most of §3 and §9) is reported as **BLOCKED**, never as
passed. Even with the phone attached, cases like "open a blocked app and confirm the shield" are
inherently manual — I cannot drive a physical iPhone's Springboard.

---

## 2. Test results

### 2.1 Unit tests — `ZenlyTests`

```
xcodebuild test-without-building -scheme Zenly -only-testing:ZenlyTests
→ Executed 21 tests, 0 failures
```

**21/21 passed.** Covers streak rules, today/weekly aggregation, previous-week window,
productivity score bounds, achievement idempotency, daily-challenge titles, selection codec,
badge-catalog integrity.

These are the authority for the `[Sim logic]` cases: **TC-6.2** (score is 0 with no data, and
0–100 with data), the accounting behind **TC-3.6** (ended-early sessions excluded from streak and
today's minutes), **TC-5.1** weekday mask/summary, and **TC-8.2** challenge titles.

### 2.2 UI tests — `ZenlyQuietSuite` (new, written for this run)

```
xcodebuild test-without-building -scheme Zenly -only-testing:ZenlyUITests/ZenlyQuietSuite
→ Executed 14 tests, 2 skipped, 0 failures
```

| Case | Test | Result |
|---|---|---|
| TC-1.1 / 1.4 | `testLaunchReachesHome` | **PASS** — splash plays, crossfades to Home, no white flash |
| TC-1.2 | onboarding walked by `completeOnboardingIfPresent` on wiped state | **PASS** — all 5 pages advance |
| — | `testFourTabsPresent` | **PASS** — exactly Focus · Insights · Schedule · Settings |
| TC-3.2 | `testDurationStepperStepsAndClamps` | **PASS** — ±5 steps, clamps at 5 and 120 |
| TC-4.1 | `testDefaultProfilesSeeded` | **PASS** — Work / Study / Gym present |
| TC-4.2 | `testCreateProfile` | **PASS** — saves, sheet dismisses, row appears |
| TC-4.3 | `testDeleteProfileAsksForConfirmation` | **PASS** — confirmation shown; Cancel keeps profile |
| TC-4.5 (sim part) | `testSelectingProfileResetsDuration` | **PASS** — switching resets to profile default |
| TC-5.1 | `testCreateSchedule` | **PASS** — Save enabled without a title; row appears |
| TC-5.1 | `testScheduleToggleFlips` | **PASS** — toggle changes state |
| TC-6.1 / 6.2 | `testInsightsRenders` | **PASS** — renders (first-run empty state) |
| TC-11.1 | `testHomeControlsHaveAccessibilityLabels` | **PASS** — duration orb and ± labelled |
| TC-11.2 | `testDynamicTypeAccessibilityXXXL` | **PASS as written**, but see Finding 5 — visual review found a real overlap |
| TC-5.4 | `testSuggestedScheduleOpensEditor` | **SKIPPED** — no "Suggested" section rendered |
| TC-6.5 / 6.6 | `testHistoryAndBadgesReachable` | **SKIPPED** — see below |

**Why TC-6.5 / 6.6 are genuinely blocked, not failing:** Insights shows a first-run empty state
("Your focus story starts here") until at least one session completes. `Begin focus` is
`.disabled(… || !authorization.isAuthorized || …)`, and FamilyControls authorization cannot be
granted on Simulator — so no session can ever complete there, and History/Badges have no entry
point to reach. These need a device.

Screenshot evidence: `docs/test-evidence/` (11 images, extracted from the result bundle).

---

## 3. Blocker found and fixed before any test could run

**The project did not build from a clean checkout.**

```
error: Build input file cannot be found:
  …/Zenly/Resources/Fonts/.claude/logs/commands.log
** TEST BUILD FAILED **   (CpResource + Ld __preview.dylib)
```

`project.yml` declares `sources: - path: Zenly`, which makes XcodeGen sweep **everything** under
that folder — including the hidden `.claude/logs/` directory Claude Code writes. A stray
`commands.log` was captured into the app's **Resources** build phase. Because `.claude/logs/` is
`.gitignore`d, the file is absent on a fresh checkout while the committed-in-place
`project.pbxproj` still referenced it → unbuildable.

**Fix applied:** `xcodegen generate` (the `.pbxproj` is untracked and generated, so this is the
normal workflow). Build then succeeded and all testing proceeded.

**Recommended permanent fix** — stop the sweep at the source, in `project.yml`:

```yaml
sources:
  - path: Zenly
    excludes:
      - "**/.claude/**"
```

---

## 4. Findings

### Finding 1 — Five features are wired up but have no reachable UI (**High — RESOLVED**)

`TasksView` is never presented anywhere in the app, and `AmbientSoundService`, `MusicController`
and `CalendarService` are instantiated and injected in `ZenlyApp.swift` but **no view consumes
them**:

```
TasksView          → only its own definition; zero call sites
AmbientSoundService→ only ZenlyApp.swift:22
MusicController    → only ZenlyApp.swift:26
CalendarService    → only ZenlyApp.swift:24
AccountabilityService → ZenlyApp.swift:23 + LeaderboardView  ✅ (this one is fine)
```

`HomeView` declares only four environment dependencies (profiles, session, authorization,
analytics) and hides its nav bar — there is no toolbar, no music row, no sound picker, no
free-time card.

This makes **6 planned cases untestable in this build**, not merely device-blocked:

- **TC-8.3** Ambient sounds — no UI to select a sound
- **TC-9.1** Calendar free-time card — never rendered
- **TC-9.2** Tasks + Reminders import/export — `TasksView` unreachable
- **TC-9.3** Apple Music transport — no music row
- **TC-9.4** Spotify transport — no music row (the `onOpenURL` callback is still wired)
- **TC-11.1** (partial) — the plan expects the music transport to announce Previous/Play-Pause/Next; there is no transport

This is consistent with the recent Quiet redesign (`6a5d0ff`, `136d47b`) rebuilding Home and
Insights without re-attaching these surfaces. **Decide per feature:** re-attach the entry point, or
delete the service and its test cases so the plan stops describing a product that isn't shipping.

### Finding 2 — The committed UI test suite is stale and fails 3/3 (**Medium**)

`ZenlyUITests.swift` navigates to tabs that no longer exist:

```
testCreateProfileSaveWorks  → XCTAssertTrue failed - Profiles tab missing
testCreateScheduleSaveWorks → XCTAssertTrue failed - Schedules tab missing
testScheduleToggleWorks     → XCTAssertTrue failed - Schedules tab missing
```

The tabs are now `Focus · Insights · Schedule · Settings`. "Profiles" is no longer a tab at all
(it moved to Settings → Focus profiles, and a "New profile" row on Schedule), and "Schedules" was
renamed singular. **The app is fine — the tests are out of date.** All three cases are correctly
covered by the new `ZenlyQuietSuite`. Recommend deleting the three stale tests (I left them
untouched rather than edit tests I wasn't asked to change).

### Finding 3 — TC-11.2: label/placeholder overlap at accessibility text sizes (**FIXED**)

At `UICTContentSizeCategoryAccessibilityXXXL`, Settings → **"Your name"** wraps to two lines and
the `Add your name` placeholder is drawn **on top of** the wrapped label — text over text.
See `docs/test-evidence/…2-Settings-XXXL.png`.

Schedule and the splash render cleanly at XXXL. Home was not captured at XXXL (the screenshot
fired during the splash crossfade) — worth a manual re-check.

**Fixed** (`Zenly/Views/Settings/SettingsView.swift`): the row is now `nameRow`, which switches
from `HStack` to a stacked `VStack` when `dynamicTypeSize.isAccessibilitySize`. An `HStack` with
`label / Spacer / TextField` leaves neither child enough width at accessibility sizes, so the
field drew over the wrapped label. Re-captured at XXXL: label and placeholder now sit on separate
lines with no overlap.

### Finding 4 — Schedule-driven sessions bypass the 120-minute cap (**Observation, likely by design**)

Creating a schedule with defaults (9:00 AM, Weekdays, **8h**) whose window covers "now"
immediately auto-started a focus session of **~196 minutes** (`184:18` remaining, 6% complete).

```swift
let minutes = schedules.remainingMinutes(for: schedule)   // uncapped
session.startFocus(… focusMinutes: minutes …)             // ScheduleStore.swift:356,371
```

The manual stepper clamps to `max(5, min(120, …))`, so schedule sessions can be far longer than a
user can set by hand. That is coherent with TC-5.2 ("apps shielded during the window"), so I'm
reporting it as an observation rather than a defect — but confirm it's intended.

Practical side effect: it makes the app hard to test, because saving a schedule instantly hijacks
the UI into a full-screen session. This poisoned an intermediate test run until the suite was
taught to end any running session on launch.

### Finding 5 — Stale copy: "Profiles tab" no longer exists (**Low**)

`HomeView.swift:147` (empty-profile guard, TC-4.4) reads:

> "Create a profile in the **Profiles tab** to start a focus session."

There is no Profiles tab. Should point at Settings → Focus profiles, or Schedule → New profile.

---

### Finding 6 — Live Activity survives the session it belongs to (**High — FIXED**)

Reported from device: after a session ends, the Dynamic Island / Lock Screen countdown keeps
running.

**Root cause.** `LiveActivityManager.end()` began with
`guard let current = activity else { return }`, but `activity` is an in-memory reference while
ActivityKit activities outlive the process. After iOS terminates the app mid-session — the exact
TC-3.5 path — the relaunched process has `activity == nil` while the system is still showing the
timer, so every `end()` silently no-opped and the countdown was stranded. `start()` calls `end()`
first, so a resumed session could also add a *second* activity alongside the orphan.

**Fix** (`Zenly/Services/LiveActivityManager.swift`): `end()` now snapshots
`Activity<FocusActivityAttributes>.activities` synchronously and ends every one, making it
authoritative and idempotent regardless of process lifetime. The snapshot is taken before the
`Task` on purpose — reading the list inside the task would let the sweep tear down the new
activity that `start()` requests immediately afterwards.

**Verification status:** code-verified and builds clean; Live Activity behaviour across app
termination **must be re-confirmed on device** — it cannot be reproduced on Simulator.

---

## 5. Corrections to the test plan itself

The plan has drifted from the Quiet redesign. These are plan bugs, not app bugs:

1. **Prerequisite "Clean install (delete app first) to test onboarding" does not work.**
   `hasCompletedOnboarding` lives in `AppGroup.defaults`, whose plist sits in the **shared App
   Group container** — not the app sandbox. `simctl uninstall` leaves it behind, so reinstalling
   goes straight to Home. This cost real time during this run: onboarding appeared "missing" on a
   supposedly clean device until the group plist was inspected and found already set to `true`
   from a 23 Jun session.
   **Use `xcrun simctl erase <udid>`**, or delete
   `…/data/Library/Preferences/group.me.adithyan.shalinth.Zenly.plist` plus the matching
   `Containers/Shared/AppGroup/<uuid>` directory.

2. **TC-1.1 copy is wrong.** The splash shows **"Zen-ly" / "A calm and simple way to stay
   focused."** with a periwinkle ring + focus dot and a "TAP TO BEGIN" hint — not
   "Zenly / Find your focus". It also auto-advances at **3.6s** (1.6s under Reduce Motion), not
   ~2.2s.

3. **TC-4.1 seeds four profiles**, not three: Work, Study, Gym **and Sleep**
   (`didAddSleepProfileV3`).

4. **Navigation is wrong throughout.** TC-4.x/5.x say "Profiles tab" / "Schedules"; the real paths
   are Settings → Focus profiles (sheet), Schedule → New profile, and the tab is "Schedule".

5. **The primary button is "Begin focus"**, not "Start Focus".

---

## 6. Section 12 — signing / App Store checklist

Verified statically against the **built bundle** (stronger than config inspection). Archive-time
items still need a real archive.

| Item | Result | Evidence |
|---|---|---|
| No `91179` (ZenlyReport is ExtensionKit in `Extensions/`) | **PASS** | `Zenly.app/Extensions/ZenlyReport.appex`, `EXExtensionPointIdentifier = com.apple.deviceactivityui.report-extension` |
| No `90349` (shield-action id) | **PASS** | `NSExtensionPointIdentifier = com.apple.ManagedSettings.shield-action-service` |
| Export compliance not prompted | **PASS** | `ITSAppUsesNonExemptEncryption = false` in built `Info.plist` |
| App icon 1024² light + dark | **PASS** | `AppIconLight.png` + `AppIconDark.png` (luminosity/dark) |
| App Groups on all App IDs | **PASS** | `group.me.adithyan.shalinth.Zenly` on all 6 targets incl. ZenlyShield + ZenlyShieldAction |
| Family Controls capability | **PASS** (config) | Zenly, ZenlyMonitor, ZenlyReport |
| Family Controls **Distribution** entitlement granted | **PASS** | `iOS Team Store Provisioning Profile` for `…Zenly`, `…ZenlyMonitor`, `…ZenlyReport` all contain `com.apple.developer.family-controls = true` (team `649T62WKAQ`, valid to 2027-06-11). Apple only issues App Store profiles with this entitlement after approving the distribution request — so it is already granted; no request needs filing. |
| Archive uploads without entitlement errors | **NOT YET RUN** | Entitlement is in place (row above); still needs an actual `xcodebuild archive` + upload to confirm |
| Privacy policy URL + App Privacy labels | **NOT VERIFIED** | App Store Connect, not in-repo |
| TestFlight build installs; blocking works E2E | **BLOCKED** | Device required |

Also confirmed present: `NSSupportsLiveActivities`, `zenly` URL scheme, `spotify` in
`LSApplicationQueriesSchemes`, calendar/reminders/music usage strings, and the
`time-sensitive` notification entitlement.

---

## 7. Cases requiring a physical iPhone (not run)

All of **§2 Blocking** (2.1–2.7), **§7 Widget / Live Activity / Dynamic Island** (7.1–7.3),
**§10 Siri & Control Center** (10.1–10.2), plus **1.3, 1.5, 3.1, 3.3–3.5, 3.7, 5.2, 5.3, 6.3, 6.4,
9.5, 9.6**.

Two of these are flagged `⚠️ regression` in the plan and deserve priority on-device attention:
- **TC-1.5** — Screen Time must not re-prompt on later launches — **still untested**
- **TC-3.5** — a session must still be recorded after iOS terminates the app — **PASS**

### TC-3.5 — PASS (verified on device by the developer, 2026-07-27)

Reported working on a physical iPhone: the session is still recorded after iOS terminates the app.
Mechanism confirmed by inspection, so this is structural rather than incidental:

- `FocusSessionStore` persists the session outside the process; `restoreIfNeeded()` runs on
  scene-phase `.active` (`FocusSessionController.swift:115`).
- Elapsed time is recomputed from **wall clock**
  (`Date().timeIntervalSince(saved.startedAt)`), not from an in-memory ticker — termination costs
  no time.
- `elapsed >= totalSeconds` → `finishFocus(completed: true)` records it; otherwise the session
  resumes with the correct remainder and the Live Activity restarts.
- `finishFocus` records `startedAt: focusStartedAt` — the **original** start, not the reopen
  time — so a session finished on one day but reopened later is credited to the correct day and
  the streak does not skew. `ZenlyTests` covers this bucketing.

Residual (inherent to iOS, not a defect): the write happens on next app open, so a completed
session is not in the store until the user reopens Zenly.

---

## 8. Changes made to the repo

**Application source**
- `Zenly/Services/LiveActivityManager.swift` — `end()` now sweeps all system activities (Finding 6).
- `Zenly/Views/Settings/SettingsView.swift` — `nameRow` stacks at accessibility text sizes (Finding 3).
- `Zenly/App/ZenlyApp.swift` — dropped 5 dead `@State` services, their injections, and the
  Spotify `onOpenURL` callback.
- **Deleted** (~736 lines): `MusicController`, `Music/SpotifyController`, `Music/SpotifyConfig`,
  `AmbientSoundService`, `CalendarService`, `TaskService`, `Views/Tasks/TasksView`.

**Configuration**
- `project.yml` — removed the `SpotifyiOS` package + dependency, `LSApplicationQueriesSchemes:
  [spotify]`, and the `NSAppleMusicUsageDescription` /
  `NSCalendarsFullAccessUsageDescription` / `NSRemindersFullAccessUsageDescription` purpose strings.
- **Added** `PrivacyInfo.xcprivacy` to the app and all five extensions.
- **Regenerated** `Zenly.xcodeproj` via `xcodegen` (untracked, generated) — also clears the stale
  `commands.log` resource reference from §3.

**Tests & docs**
- **Added** `ZenlyUITests/ZenlyQuietSuite.swift` — 14 UI tests against the current Quiet UI.
- **Added** `docs/test-evidence/` (11 screenshots) and this report.
- **Not touched:** the three stale tests in `ZenlyUITests.swift` (Finding 2) — left for the owner
  to delete.

---

## 9. Recommended next steps

**Blocking before submission**
1. **Run the seven §2 blocking cases on a physical iPhone.** This is the app's core value
   proposition and has never been executed. Add **TC-1.5** (no repeated Screen Time prompt) — it
   is nearly free once the phone is in hand.
2. **Re-confirm Finding 6 on device**: after the app is terminated mid-session and reopened, the
   Dynamic Island / Lock Screen timer must clear when the session ends. Also verify a normal
   "End early" still dismisses it, and that starting a session still *shows* it — that is the
   regression risk from the fix.
3. **Run a real `xcodebuild archive` + upload.** The Family Controls Distribution entitlement is
   already granted and the privacy manifests ship correctly, so this should pass — but it is the
   only way to clear the last checklist rows.

**Worth doing, not blocking**
4. Add `excludes: ["**/.claude/**"]` to the `Zenly` target in `project.yml` so a clean clone
   cannot hit the §3 build failure again.
5. Delete the three stale tests in `ZenlyUITests.swift` (Finding 2).
6. Fix the stale "Profiles tab" copy in `HomeView.swift` (Finding 5).
7. Correct `TEST_CASES.md` per §5 — especially the clean-install prerequisite, which will keep
   producing false "onboarding is broken" reports.
8. Confirm Finding 4 (schedule sessions exceeding the 120-minute manual cap) is intended.
