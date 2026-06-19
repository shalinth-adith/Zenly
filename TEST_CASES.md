# Zenly — Full Manual Test Plan

Most of Zenly depends on Apple's Screen Time stack, which **does not run on the
iOS Simulator**. Each case is tagged:

- **[Device]** — needs a physical iPhone (FamilyControls / ManagedSettings / DeviceActivity).
- **[Sim OK]** — works in the Simulator too (pure SwiftUI / Core Data logic).

## Prerequisites

- Physical iPhone + paid Apple Developer account.
- Family Controls capability enabled on App IDs: `…Zenly`, `…ZenlyMonitor`, `…ZenlyReport`.
- App Groups enabled on **all** App IDs (`group.me.adithyan.shalinth.Zenly`) — including
  `…ZenlyShield` and `…ZenlyShieldAction` (needed for distraction-attempt logging).
- Spotify cases: Spotify app installed, **Premium**, redirect URI `zenly://spotify-callback`
  registered in the Spotify dashboard.
- Lo-fi sound: a `lofi.m4a`/`.mp3` added to the Zenly app target.
- Clean install (delete app first) to test onboarding / splash / first-run.

Legend: **Pre** = preconditions · **Steps** · **Expected**.

---

## 1. Entry & Onboarding

### TC-1.1 Animated splash [Sim OK]
- **Steps:** Launch the app.
- **Expected:** Deep-indigo splash with the periwinkle "scope" mark, breathing rings, and
  "Zenly / Find your focus", then a smooth crossfade into the app (~2.2s). No white flash first.

### TC-1.2 First-run onboarding [Sim OK]
- **Pre:** Fresh install.
- **Expected:** 5 pages (Welcome → Focus → Habit → Screen Time → Done); swipe + buttons advance.

### TC-1.3 Screen Time priming [Device]
- **Steps:** On "Screen Time Access", tap Grant.
- **Expected:** System prompt appears; approving shows "Access Granted"; "Maybe later" skips.

### TC-1.4 Onboarding shows once [Sim OK]
- **Steps:** Complete onboarding, relaunch.
- **Expected:** Goes straight to Home (reinstall to see onboarding again).

### TC-1.5 No repeated permission prompt [Device] ⚠️ regression
- **Steps:** Grant Screen Time once, then open/close the app several times.
- **Expected:** It does **not** ask for Screen Time again on later launches.

### TC-1.6 Reduce Motion [Sim OK]
- **Pre:** Settings → Accessibility → Reduce Motion ON.
- **Expected:** Splash shows the static mark without the looping rings.

---

## 2. Core Blocking

### TC-2.1 Block selected apps [Device]
- **Pre:** Profile, "Block all apps" OFF, a specific app chosen in the blocklist.
- **Steps:** Start Focus → open the blocked app.
- **Expected:** Zenly's custom shield appears instead of the app.

### TC-2.2 Block all apps [Device]
- **Pre:** Profile with "Block all apps" ON (default).
- **Steps:** Start Focus → try several apps + Safari.
- **Expected:** All non-system apps shielded; Phone, Messages, Settings, and Zenly stay usable.

### TC-2.3 Allowed apps (keep open) [Device]
- **Pre:** Block-all ON, one app added under "Allowed apps" (Profiles → profile → Blocking).
- **Steps:** Start Focus → open the allowed app.
- **Expected:** It opens normally; others blocked.

### TC-2.4 Research mode — website allowlist [Device]
- **Pre:** Profile "Research mode — allowed websites" = `claude.ai, docs.google.com`.
- **Steps:** Start Focus → open Safari → visit an allowed site, then an entertainment site.
- **Expected:** Allowed sites load; all other sites are blocked. Safari itself stays open.

### TC-2.5 Custom shield + message [Device]
- **Pre:** Settings → "Shield message" set (e.g. "Future you will thank you").
- **Steps:** Start Focus → open a blocked app.
- **Expected:** The calm indigo shield shows the custom message (default text when empty).

### TC-2.6 Strict mode override [Device]
- **Pre:** Profile Strict mode ON, session running.
- **Steps:** Tap "End early".
- **Expected:** Confirmation sheet with a 5-second countdown + streak-loss warning; confirm
  disabled until the countdown ends.

### TC-2.7 Stop blocking [Device]
- **Steps:** End the session.
- **Expected:** Previously-blocked apps + websites open normally again.

---

## 3. Sessions & Timer

### TC-3.1 Start a focus session [Device]
- **Steps:** Home → set duration with −/+ → Start Focus.
- **Expected:** Full-screen Session with countdown ring; blocking engages; start haptic.

### TC-3.2 Editable duration [Sim OK]
- **Steps:** On Home, tap −/+.
- **Expected:** Ring minutes update (5–120, step 5). Switching profiles resets to that default.

### TC-3.3 Minimize & resume [Device/Sim]
- **Steps:** Start a session → tap the ▾ (minimize) → browse other tabs → tap the resume banner.
- **Expected:** Minimizing keeps the session running; the app is navigable; banner (and Dynamic
  Island) reopen the full timer. Start Focus is disabled while active.

### TC-3.4 Session completes naturally [Device]
- **Steps:** Short session (5 min), wait for it to finish.
- **Expected:** Celebration summary (confetti + haptic); "Focus complete" notification; shields lift.

### TC-3.5 Recorded after app is killed [Device] ⚠️ regression-critical
- **Steps:** Start a session, leave Zenly for the full duration so iOS terminates it, reopen.
- **Expected:** The session is recorded (focus minutes / streak update or summary shows). Not lost.

### TC-3.6 End early excluded [Sim logic / Device flow]
- **Steps:** Start a session, end early.
- **Expected:** Logged as "ended early"; does NOT add to streak or today's minutes.

### TC-3.7 Pomodoro break [Device]
- **Pre:** Profile with a non-zero break.
- **Steps:** Complete focus → "Take a break".
- **Expected:** Break timer runs (no blocking); "Break over" notification at the end.

### TC-3.8 Post-session review [Sim OK]
- **Steps:** On the summary, tap a star rating + type a note → Done.
- **Expected:** Rating + note save to that session (visible later in History).

---

## 4. Profiles

### TC-4.1 Defaults seeded [Sim OK]
- **Pre:** Fresh install. **Expected:** Work / Study / Gym profiles exist.

### TC-4.2 Create / edit profile [Sim OK]
- **Steps:** Profiles → +; set name/icon/accent/blocklist/allowlist/research/lengths/strict; Save.
- **Expected:** Persists; appears in the list and active picker.

### TC-4.3 Delete confirmation [Sim OK]
- **Steps:** Swipe a profile → Delete.
- **Expected:** A "Delete …?" confirmation appears; Cancel keeps it, Delete removes it.

### TC-4.4 Empty-profile guard [Sim OK]
- **Steps:** Delete all profiles → go to Home.
- **Expected:** A "No focus profiles — create one" card instead of a dead Start button.

### TC-4.5 Active profile drives session [Device]
- **Steps:** Set a profile active → Start Focus.
- **Expected:** Session uses that profile's selection, strict, block-all, and research sites.

---

## 5. Schedules

### TC-5.1 Create recurring schedule [Device]
- **Steps:** Schedules → +; title, time window, weekdays, blocking; Save.
- **Expected:** Listed with time range + weekday summary; toggle enables/disables.

### TC-5.2 Blocks at the right time [Device] (long-running)
- **Pre:** Schedule whose window includes "now" on today's weekday (≥15 min).
- **Expected:** Apps shielded during the window without starting a session manually.

### TC-5.3 Weekday filtering [Device]
- **Pre:** Schedule excluding today's weekday. **Expected:** No blocking today.

### TC-5.4 Smart suggestions [Sim OK]
- **Steps:** Schedules → "Suggested" → tap a card. **Expected:** Editor opens prefilled.

### TC-5.5 Delete confirmation [Sim OK]
- **Steps:** Swipe a schedule → Delete. **Expected:** Confirmation before deletion.

---

## 6. Analytics & Insights

### TC-6.1 Weekly focus chart [Device for data]
- **Pre:** Some completed sessions. **Expected:** 7-day bar chart; weekly total matches.

### TC-6.2 Productivity score [Sim logic]
- **Expected:** 0–100; rises with focus + consistency, falls with distractions; 0 with no data.

### TC-6.3 Distraction attempts [Device]
- **Pre:** App Groups enabled on ZenlyShield/ZenlyShieldAction App IDs.
- **Steps:** During a session, open a blocked app a few times (trigger the shield).
- **Expected:** The distraction chart/count increases (deduped ~1 per open). If 0: verify the
  custom shield shows AND App Groups is enabled on the shield App IDs.

### TC-6.4 App usage — per-app detail [Device]
- **Steps:** Insights → "App usage" card.
- **Expected:** Total screen time + top apps with real names/icons + durations (not just a total).
  Blank on Simulator.

### TC-6.5 History [Sim OK / Device data]
- **Steps:** Insights → History.
- **Expected:** Past focus sessions: date, profile, duration, completed/ended-early, rating, note.

### TC-6.6 Badges & Accountability links [Sim OK]
- **Steps:** Insights → Badges / Accountability.
- **Expected:** Badge grid (earned highlighted); leaderboard with "You" + "iCloud coming" note.

---

## 7. Widget & Live Activity

### TC-7.1 Home-screen widget [Device]
- **Steps:** Add the Zenly widget; configure metric (streak / minutes / attempts).
- **Expected:** Shows the chosen stat; updates after sessions.

### TC-7.2 Live Activity — Lock Screen [Device]
- **Steps:** Start a session → lock the phone.
- **Expected:** Lock Screen banner with profile + live countdown, accent-tinted.

### TC-7.3 Dynamic Island [Device, iPhone 14 Pro+]
- **Expected:** Compact pill counts down; long-press expands to profile + progress; ends with session.

---

## 8. Motivation & Gamification

### TC-8.1 Badges [Device for data]
- **Steps:** Complete your first session.
- **Expected:** "First Focus" badge awarded (shown on summary + Badges grid).

### TC-8.2 Daily challenge [Sim OK]
- **Expected:** One challenge/day; progress updates from sessions; completion notification.

### TC-8.3 Ambient sounds [Sim OK]
- **Steps:** Home → Focus sound → White / Pink / Brown / Rain (Lo-fi only if `lofi.m4a` bundled).
- **Expected:** The chosen sound plays/loops; tapping again stops it.

### TC-8.4 Daily goal [Sim OK]
- **Steps:** Settings → set Daily focus goal; Home goal card.
- **Expected:** Progress = today's minutes vs goal; "goal reached" at/over target.

---

## 9. Integrations

### TC-9.1 Calendar free-time [Device]
- **Pre:** Calendar access granted; a free gap today.
- **Expected:** "Free until X — start focus now" card; tapping starts a session sized to the gap.

### TC-9.2 Tasks + Reminders [Sim OK]
- **Steps:** Home toolbar → Tasks; add/complete/delete; "Import from Reminders".
- **Expected:** Tasks persist; import pulls incomplete reminders; export creates a reminder.

### TC-9.3 Apple Music [Device]
- **Steps:** Settings → Music → Apple Music; Home music row play/pause/next.
- **Expected:** Controls the system Music player; now-playing title shows.

### TC-9.4 Spotify [Device, Premium]
- **Pre:** Spotify app + Premium; redirect URI registered.
- **Steps:** Settings → Music → Spotify → Connect → authorize → return; use the music row.
- **Expected:** Returns to Zenly; play/pause/next control Spotify. (Non-Premium: connects but
  controls do nothing — expected.)

### TC-9.5 Focus filter [Device]
- **Steps:** iOS Settings → Focus → add the Zenly filter, pick a profile.
- **Expected:** When that Focus turns on, Zenly switches to that profile on next open.

### TC-9.6 Permission denied states [Device]
- **Pre:** Deny Calendar or Reminders.
- **Expected:** Settings shows "access denied — enable in Settings app" (no dead Connect button).

---

## 10. Start Focus Everywhere

### TC-10.1 Siri / Shortcuts [Device]
- **Steps:** "Hey Siri, start a focus session in Zenly" (or run from Shortcuts).
- **Expected:** Zenly opens and a session starts with the active profile.

### TC-10.2 Control Center [Device, iOS 18+]
- **Steps:** Add the "Start Focus" control to Control Center; tap it.
- **Expected:** Zenly opens and starts a session.

---

## 11. Accessibility

### TC-11.1 VoiceOver labels [Sim OK]
- **Pre:** VoiceOver ON.
- **Steps:** Swipe through Home, a session, the summary.
- **Expected:** Music transport announces Previous/Play-Pause/Next; −/+ announce duration; Tasks,
  minimize, and resume controls are labeled; the star rating and profile icon/accent pickers are
  operable buttons that announce their selected state.

### TC-11.2 Dynamic Type [Sim OK]
- **Pre:** Largest accessibility text size.
- **Expected:** Text scales without clipping/overlap on the main screens.

---

## 12. App Store / Signing checklist

- [ ] Archive uploads without entitlement errors (Family Controls Distribution granted).
- [ ] No `91179` (ZenlyReport is ExtensionKit, embeds in `Extensions/`).
- [ ] No `90349` (shield-action id `com.apple.ManagedSettings.shield-action-service`).
- [ ] Export compliance not prompted (`ITSAppUsesNonExemptEncryption=false`).
- [ ] App icon renders (1024² light + dark).
- [ ] Privacy policy URL + App Privacy labels (FamilyControls / Calendar / Reminders / Music).
- [ ] TestFlight build installs; blocking works end-to-end.

---

## 13. Known limitations (not bugs)

- Streak counts **completed** focus sessions only, by **day** (not per session).
- Spotify playback control requires **Premium**.
- Friend leaderboards are local until CloudKit + GameKit are enabled.
- Lo-fi needs a bundled audio file; rain is synthesized and always available.
- Live Activity / Dynamic Island and all blocking are **device-only**.
- Per-app usage names/icons render via tokens (Apple privacy); raw names aren't readable as text.
