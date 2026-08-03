# App Review notes — paste into App Store Connect

Kept in the repo because these notes have drifted from the app twice, and a
reviewer sent looking for something that does not exist is how both previous
rejections started. Update this file in the same commit as any change to the
onboarding, the tab names, or the blocking flow.

Everything below is checked against the build at `35882ef`.

---

## Paste from here

**Zen-ly needs a physical device.** Screen Time (Family Controls / Managed
Settings) does nothing at all in the Simulator — permission cannot be granted
and no app can be blocked. Please test on an iPhone.

Zen-ly is an iPhone app. It runs on iPad in iPhone compatibility mode; Screen
Time must be granted on whichever device is used.

### Seeing an app get blocked — about 60 seconds

1. Launch the app and step through onboarding. On the "Screen Time Access"
   page, tap **Grant Screen Time Access** and allow the system prompt. (The
   device must not already have a Screen Time passcode set by someone else.)
2. Tap **Start Focusing** to reach the app.
3. You land on the **Focus** tab with the **Work** profile selected. Use the
   **−** button to shorten the session if you like; five minutes is the
   minimum.
4. Tap **Begin focus**.
5. Leave Zen-ly and open any other app. Zen-ly's block screen appears in its
   place: *"<App> is behind this door."* with a **Back to focus** button.

No setup is required to see this. All four bundled profiles — Work, Study, Gym,
Sleep — block everything by default, so step 1 to step 5 is the whole path.

### Choosing specific apps to block

1. **Settings** tab → **Focus profiles**.
2. Tap any profile (for example **Gym**) to open it.
3. Tap **Edit** at the top right.
4. Turn **Block everything** off. A **Blocked apps** row appears.
5. Tap the **Choose** row and pick apps in the system picker.
6. Tap **Save**.

### The four tabs

**Focus** · **Insights** · **Schedule** · **Settings**

### Privacy

Zen-ly uses Apple's Screen Time APIs. App usage stays on the device inside the
Family Controls sandbox — the app never receives, stores or transmits which
apps the user has installed or opened. There is no account and no server.

## Paste to here

---

## Things these notes must NOT say

Each of these was wrong in a previous version and cost a submission:

- **No Apple Music or Spotify integration.** It has never existed. Zero matches
  for `Spotify`, `MusicKit` or `Apple Music` anywhere in the project.
- **Apps are not picked on the Focus tab.** The picker lives in the profile
  editor and the schedule editor only.
- **There is no "I need it for 5 minutes" button.** It was removed at `bffd52c`:
  Screen Time withholds the `ApplicationToken` from a category shield, so the
  pass had no app to name and the button could never work.
- **The CTA is "Begin focus", not "Start Focus".** The tabs are "Focus /
  Insights / Schedule / Settings" — not "Home", not "Profiles", not
  "Schedules". The onboarding button is "Grant Screen Time Access".

## What the two rejected findings were, and what changed

Useful if a reviewer raises either again.

**"In the Profiles section, the features were unresponsive, preventing us from
selecting a specific app to block."** Correct. Every row in the Profiles list
drew a disclosure chevron but the tap only set the active profile, which
changes nothing visible; the editor was reachable solely by an undiscoverable
trailing swipe. Screens 20b and 20c were built and the row now navigates
(`35882ef`).

**"The app failed to block other apps after turning on Focus."** A session
shorter than fifteen minutes registered no DeviceActivity entry, and the shield
reconciler derives its whole state from that store — so it read "nothing is
enforcing" and cleared every shield mid-session while the countdown carried on
(`80b7175`). Fixed and confirmed blocking on device. Note this was traced from
the code rather than reproduced, because Screen Time cannot be exercised in the
Simulator.
