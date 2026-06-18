# Zenly — Manual Test Plan

Most of Zenly depends on Apple's Screen Time stack, which **does not run on the
iOS Simulator**. This plan is written for **on-device** testing, with each case
tagged:

- **[Device]** — requires a physical iPhone (FamilyControls / ManagedSettings / DeviceActivity).
- **[Sim OK]** — works in the Simulator too (pure SwiftUI / Core Data logic).

## Prerequisites

- Physical iPhone, paid Apple Developer account.
- Family Controls capability enabled on App IDs: `…Zenly`, `…ZenlyMonitor`, `…ZenlyReport`.
- App Groups enabled on **all** App IDs (`group.me.adithyan.shalinth.Zenly`).
- For Spotify cases: Spotify app installed, **Premium** account, redirect URI
  `zenly://spotify-callback` registered in the Spotify dashboard.
- A clean install (delete the app first) to test onboarding / first-run.

Legend: **Pre** = preconditions, **Steps**, **Expected**.

---

## 1. Onboarding & Permissions

### TC-1.1 First-run onboarding [Sim OK]
- **Pre:** Fresh install.
- **Steps:** Launch the app.
- **Expected:** Onboarding appears (Welcome → Focus → Habit → Screen Time → Done).
  Swiping and the buttons advance through pages; page dots update.

### TC-1.2 Screen Time permission primed [Device]
- **Steps:** On the "Screen Time Access" page, tap **Grant Screen Time Access**.
- **Expected:** The iOS system Screen Time prompt appears; approving it shows
  "Access Granted" and advances to the final page. "Maybe later" skips it.

### TC-1.3 Onboarding shows once [Sim OK]
- **Steps:** Complete onboarding, then force-quit and relaunch.
- **Expected:** App launches straight into the Home tab (no onboarding).
  (Reinstall to see onboarding again.)

### TC-1.4 Permission denied recovery [Device]
- **Pre:** Screen Time previously denied.
- **Steps:** Open Home / Settings.
- **Expected:** A "Grant Screen Time Access" prompt is shown; tapping it re-requests
  or routes appropriately. Start Focus is disabled until authorized.

---

## 2. Core Blocking (Phase 1)

### TC-2.1 Block selected apps [Device]
- **Pre:** Authorized. Profile with "Block all apps" OFF and a specific app chosen.
- **Steps:** Start Focus → press Home → open the blocked app.
- **Expected:** Zenly's custom shield (calm, "Stay in your focus") appears instead
  of the app.

### TC-2.2 Block all apps [Device]
- **Pre:** Profile with "Block all apps" ON (default).
- **Steps:** Start Focus → try to open several apps + Safari.
- **Expected:** All non-system apps are shielded. **Phone, Messages, Settings, and
  Zenly itself remain usable.**

### TC-2.3 Allowlist exception [Device]
- **Pre:** Block-all ON, with one app added to "Always allow".
- **Steps:** Start Focus → open the allowed app.
- **Expected:** The allowed app opens normally; others are blocked.

### TC-2.4 Website blocking [Device]
- **Pre:** A website domain in the blocklist (block-all OFF) or block-all ON.
- **Steps:** Start Focus → open that site in Safari.
- **Expected:** The site is shielded.

### TC-2.5 Stop blocking [Device]
- **Steps:** End the session.
- **Expected:** Previously-blocked apps open normally again.

### TC-2.6 Strict mode override [Device]
- **Pre:** Profile with Strict mode ON, session running.
- **Steps:** Tap "Stop Blocking" / "End early".
- **Expected:** A confirmation sheet with a **5-second countdown** + streak-loss
  warning; the confirm button is disabled until the countdown ends.

---

## 3. Sessions & Timer (Phase 2)

### TC-3.1 Start a focus session [Device]
- **Steps:** Home → adjust duration with −/+ → Start Focus.
- **Expected:** Full-screen Session view with a countdown ring; blocking engages.

### TC-3.2 Editable duration [Sim OK]
- **Steps:** On Home, tap −/+.
- **Expected:** The ring's minutes update (5–120, 5-min steps); the profile name
  shows below. Switching profiles resets to that profile's default.

### TC-3.3 Session completes naturally [Device]
- **Steps:** Start a short session (e.g. 5 min), wait for it to finish.
- **Expected:** Celebration summary (confetti + haptic); "Focus complete"
  notification fires; shields lift.

### TC-3.4 Session recorded after app is killed [Device] ⚠️ regression-critical
- **Steps:** Start a session, leave Zenly (use other apps / lock the phone) for
  the full duration so iOS suspends/terminates Zenly, then reopen Zenly.
- **Expected:** The session is **recorded** — Home shows updated focus minutes /
  streak (or the summary appears). It is NOT silently lost.

### TC-3.5 End early does not count [Sim OK logic / Device flow]
- **Steps:** Start a session, end it early.
- **Expected:** Logged as "ended early"; **does not** add to streak or today's minutes.

### TC-3.6 Pomodoro break [Device]
- **Pre:** Profile with a non-zero break.
- **Steps:** Complete focus → from the summary tap "Take a break".
- **Expected:** Break timer runs (no blocking during break); "Break over"
  notification at the end.

---

## 4. Profiles

### TC-4.1 Default profiles seeded [Sim OK]
- **Pre:** Fresh install.
- **Expected:** Work / Study / Gym profiles exist with sensible lengths.

### TC-4.2 Create / edit / delete profile [Sim OK]
- **Steps:** Profiles tab → +; set name/icon/accent/pickers/lengths/strict/block-all;
  Save. Swipe to edit and delete.
- **Expected:** Changes persist; deleting removes it; active profile falls back.

### TC-4.3 Active profile drives session [Device]
- **Steps:** Set a profile active → Home → Start Focus.
- **Expected:** The session uses that profile's selection, strict, and block-all.

---

## 5. Schedules

### TC-5.1 Create recurring schedule [Device]
- **Steps:** Schedules tab → +; set title, time window, weekdays, blocking; Save.
- **Expected:** Listed with the time range + weekday summary; toggle enables/disables.

### TC-5.2 Schedule blocks at the right time [Device] (long-running)
- **Pre:** A schedule whose window includes "now" on today's weekday (≥15 min).
- **Expected:** Apps are shielded during the window without manually starting a session.

### TC-5.3 Weekday filtering [Device]
- **Pre:** Schedule excluding today's weekday.
- **Expected:** No blocking today; blocking on included weekdays.

### TC-5.4 Smart suggestions [Sim OK]
- **Steps:** Schedules tab → "Suggested" strip → tap a card.
- **Expected:** The schedule editor opens prefilled; can be saved.

---

## 6. Analytics & Insights (Phase 3)

### TC-6.1 Weekly focus chart [Device for data]
- **Pre:** Some completed sessions exist.
- **Steps:** Insights tab.
- **Expected:** Bar chart of focus minutes over 7 days; total this week matches.

### TC-6.2 Productivity score [Sim OK logic]
- **Expected:** 0–100, rises with completed focus + consistency, falls with
  distraction attempts. 0 with no data.

### TC-6.3 Distraction attempts [Device]
- **Pre:** App Groups enabled on ZenlyShield App ID.
- **Steps:** During a session, open a blocked app a few times (triggering the shield).
- **Expected:** The distraction chart / count increases (deduped to ~1 per open).

### TC-6.4 App usage report [Device]
- **Steps:** Insights → "App usage" card.
- **Expected:** Total screen time + top apps render (DeviceActivityReport). Blank on Simulator.

---

## 7. Widget & Live Activity

### TC-7.1 Home-screen widget [Device]
- **Steps:** Add the Zenly widget; configure its metric (streak / minutes / attempts).
- **Expected:** Shows the chosen stat from the latest snapshot; updates after sessions.

### TC-7.2 Live Activity — Lock Screen [Device]
- **Steps:** Start a session → lock the phone.
- **Expected:** Lock Screen banner with profile name + live countdown, accent-tinted.

### TC-7.3 Dynamic Island [Device, iPhone 14 Pro+]
- **Steps:** Start a session → observe the Dynamic Island.
- **Expected:** Compact pill shows a live countdown; long-press expands to show
  profile + progress bar. Ends when the session ends.

---

## 8. Gamification (Phase 4)

### TC-8.1 Badges [Device for data]
- **Steps:** Complete your first session → check the summary and Insights → Badges.
- **Expected:** "First Focus" badge awarded; grid highlights earned badges.

### TC-8.2 Daily challenge [Sim OK]
- **Steps:** Home challenge card.
- **Expected:** One challenge/day; progress updates from completed sessions;
  completion fires a notification.

### TC-8.3 Ambient sounds [Sim OK]
- **Steps:** Home → Focus sound → White / Pink / Brown.
- **Expected:** The corresponding noise plays; tapping again stops it.

### TC-8.4 Accountability leaderboard [Sim OK]
- **Steps:** Insights → Accountability.
- **Expected:** Shows "You" ranked by weekly minutes + an "iCloud coming" note.

### TC-8.5 Daily goal [Sim OK]
- **Steps:** Settings → set Daily focus goal; Home goal card.
- **Expected:** Progress reflects today's minutes vs goal; "goal reached" at/over target.

---

## 9. Integrations (Phase 5)

### TC-9.1 Calendar free-time [Device]
- **Pre:** Calendar access granted; a free gap today.
- **Steps:** Home.
- **Expected:** "Free until X — start focus now" card; tapping starts a session sized to the gap.

### TC-9.2 Tasks + Reminders [Sim OK]
- **Steps:** Home toolbar → Tasks; add/complete/delete; "Import from Reminders".
- **Expected:** Tasks persist; import pulls incomplete reminders; export creates a reminder.

### TC-9.3 Apple Music [Device]
- **Steps:** Settings → Music → Apple Music; Home music row play/pause/next.
- **Expected:** Controls the system Music player; now-playing title shows.

### TC-9.4 Spotify connect [Device, Premium]
- **Pre:** Spotify app installed + **Premium**; redirect URI registered.
- **Steps:** Settings → Music → Spotify → Connect Spotify → authorize → return.
- **Expected:** Returns to Zenly; play/pause/next control Spotify playback; track title shows.
  *(Non-Premium: connects but controls do nothing — expected limitation.)*

### TC-9.5 Focus filter [Device]
- **Steps:** iOS Settings → Focus → a Focus → add the Zenly filter, pick a profile.
- **Expected:** When that Focus turns on, Zenly switches to the chosen profile on next open.

---

## 10. Start Focus Everywhere

### TC-10.1 Siri / Shortcuts [Device]
- **Steps:** "Hey Siri, start a focus session in Zenly" (or run from Shortcuts).
- **Expected:** Zenly opens and a session starts with the active profile.

### TC-10.2 Control Center [Device, iOS 18+]
- **Steps:** Add the "Start Focus" control to Control Center; tap it.
- **Expected:** Zenly opens and starts a session.

---

## 11. App Store / Signing checklist

- [ ] Archive uploads without entitlement errors (Family Controls Distribution granted).
- [ ] No `91179` (ZenlyReport must be ExtensionKit) — it embeds in `Extensions/`.
- [ ] No `90349` (shield-action id `com.apple.ManagedSettings.shield-action-service`).
- [ ] Export compliance not prompted (`ITSAppUsesNonExemptEncryption=false`).
- [ ] App icon renders (1024² light + dark).
- [ ] TestFlight build installs and the blocking engine works end-to-end.

---

## Known limitations (not bugs)

- Streak counts **completed** focus sessions only, by **day** (not per session).
- Spotify playback control requires **Premium**.
- Friend leaderboards are local until CloudKit + GameKit are enabled.
- Rain / lo-fi ambient sounds need bundled audio assets (only synthesized noise ships now).
- Live Activity / Dynamic Island and all blocking are **device-only**.
