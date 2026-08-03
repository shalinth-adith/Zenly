//
//  FocusSessionController.swift
//  Zenly
//
//  The active-session state machine driving Home → Session → Summary. Owns the
//  drift-free countdown, applies/clears enforcement, records history, and runs
//  the Pomodoro focus → break flow.
//

import Foundation
import FamilyControls
import Observation

@Observable
@MainActor
final class FocusSessionController {
    enum Phase {
        case idle
        case focus
        case breakTime
        case summary
    }

    private(set) var phase: Phase = .idle
    private(set) var profileName = ""
    private(set) var accentHex = "1A3FA8"
    private(set) var totalSeconds = 0
    private(set) var remainingSeconds = 0
    private(set) var summary: SessionSummary?
    /// The session is held: the countdown has stopped and the shields are off,
    /// but nothing has been recorded and the remaining time is kept.
    private(set) var isPaused = false

    /// Whether the user has tucked the session screen away to use the rest of
    /// the app. Session state, not view state — it lives here because two views
    /// need it (the cover that presents the session, and the Focus tab's resume
    /// banner) and they sit at different levels of the hierarchy.
    private(set) var isMinimized = false

    /// True when there is a session screen to show at all.
    var hasScreenToShow: Bool { isActive || phase == .summary }

    func minimize() { isMinimized = true }
    func surface() { isMinimized = false }

    private var phaseStart = Date()
    private var focusStartedAt = Date()
    private var isStrict = false
    private var plannedFocusMinutes = 0
    private var breakMinutes = 0
    private var ticker: Task<Void, Never>?
    private var lastSession: FocusSession?
    private var pausedSeconds: TimeInterval = 0
    private var pauseStartedAt: Date?

    // What this session is enforcing. Held so a pause can lift the shields and
    // a resume can put back exactly the same ones.
    private var currentBlock = FamilyActivitySelection()
    private var currentAllow = FamilyActivitySelection()
    private var currentBlockAll = true
    private var currentAllowedWebDomains: [String] = []

    /// The live controller, for App Intents fired from the Live Activity. Those
    /// run in this process but have no view hierarchy to reach through.
    static private(set) weak var current: FocusSessionController?

    private let blocking = BlockingService()
    private let schedule = ScheduleCenter.shared
    private let notifications = NotificationService.shared
    private let liveActivity = LiveActivityManager.shared
    private let history: SessionHistory

    init(history: SessionHistory? = nil) {
        self.history = history ?? SessionHistory()
        Self.current = self
        // Live Activity buttons run in this process but have no view hierarchy
        // to reach through — they call in here instead.
        SessionControlRequest.handler = { [weak self] action in
            switch action {
            case .resume: self?.resume()
            case .again:  self?.repeatLastSession()
            }
        }
    }

    /// Apply a Live Activity button press that arrived before this process was
    /// ready to take it. Called on activation.
    func applyPendingControlRequest() {
        guard let action = SessionControlRequest.consume() else { return }
        switch action {
        case .resume: resume()
        case .again:  repeatLastSession()
        }
    }

    // MARK: - Derived

    var isActive: Bool { phase == .focus || phase == .breakTime }
    var strictLockActive: Bool { isStrict && phase == .focus }
    var canTakeBreak: Bool { breakMinutes > 0 && (summary?.wasCompleted ?? false) }

    func currentStreak() -> Int { history.currentStreak() }
    func todayFocusMinutes() -> Int { history.todayFocusMinutes() }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    var timeString: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Lifecycle

    func startFocus(profileName: String,
                    accentHex: String,
                    focusMinutes: Int,
                    breakMinutes: Int,
                    isStrict: Bool,
                    blockAll: Bool,
                    allowedWebDomains: [String] = [],
                    block: FamilyActivitySelection,
                    allow: FamilyActivitySelection) {
        self.profileName = profileName
        self.accentHex = accentHex
        self.plannedFocusMinutes = focusMinutes
        self.breakMinutes = breakMinutes
        self.isStrict = isStrict
        self.focusStartedAt = Date()
        self.currentBlock = block
        self.currentAllow = allow
        self.currentBlockAll = blockAll
        self.currentAllowedWebDomains = allowedWebDomains
        self.pausedSeconds = 0
        self.isPaused = false
        // A session the user just asked for is never already tucked away.
        self.isMinimized = false

        beginPhase(.focus, minutes: focusMinutes)

        blocking.startBlocking(block, allowing: allow, blockAll: blockAll,
                               allowedWebDomains: allowedWebDomains)
        schedule.startOneOff(activity: .focusSession, block: block, allow: allow,
                             blockAll: blockAll, allowedWebDomains: allowedWebDomains,
                             durationMinutes: focusMinutes)
        notifications.scheduleFocusEnd(after: TimeInterval(focusMinutes * 60),
                                       profileName: profileName)
        liveActivity.start(profileName: profileName, accentHex: accentHex,
                           startsAt: focusStartedAt,
                           endsAt: focusStartedAt.addingTimeInterval(TimeInterval(focusMinutes * 60)),
                           phase: .focus)
        // The block screen renders in another process and reads this to say how
        // much quiet is left.
        ActiveSessionInfo.set(profileName: profileName,
                              endsAt: focusStartedAt.addingTimeInterval(TimeInterval(focusMinutes * 60)))

        // Persist so the session is recorded even if iOS kills the app while
        // it's backgrounded during the session.
        persistSnapshot()
    }

    /// Write the current session state to the App Group. Called on every change
    /// that a relaunch would otherwise lose — start, pause, resume.
    private func persistSnapshot() {
        FocusSessionStore.save(PersistedFocusSession(
            startedAt: focusStartedAt,
            focusMinutes: plannedFocusMinutes,
            breakMinutes: breakMinutes,
            isStrict: isStrict,
            profileName: profileName,
            accentHex: accentHex,
            pausedAt: isPaused ? pauseStartedAt : nil,
            pausedSeconds: pausedSeconds,
            blockData: SelectionCodec.encode(currentBlock),
            allowData: SelectionCodec.encode(currentAllow),
            blockAll: currentBlockAll,
            allowedWebDomains: currentAllowedWebDomains
        ))
    }

    /// On launch/foreground: if a focus session was in flight, either record it
    /// (its planned time already elapsed) or restore the running timer.
    func restoreIfNeeded() {
        guard phase == .idle, let saved = FocusSessionStore.load() else { return }

        profileName = saved.profileName
        accentHex = saved.accentHex
        plannedFocusMinutes = saved.focusMinutes
        breakMinutes = saved.breakMinutes
        isStrict = saved.isStrict
        focusStartedAt = saved.startedAt
        totalSeconds = saved.focusMinutes * 60
        currentBlock = SelectionCodec.decode(saved.blockData)
        currentAllow = SelectionCodec.decode(saved.allowData)
        currentBlockAll = saved.blockAll
        currentAllowedWebDomains = saved.allowedWebDomains
        phase = .focus

        // A session that was held while the app was away is still held, and the
        // time it spent held doesn't count against the countdown.
        if let pausedAt = saved.pausedAt {
            pausedSeconds = saved.pausedSeconds
            pauseStartedAt = pausedAt
            isPaused = true
            phaseStart = saved.startedAt.addingTimeInterval(saved.pausedSeconds)
            let elapsed = Int(pausedAt.timeIntervalSince(phaseStart))
            remainingSeconds = max(0, totalSeconds - elapsed)
            liveActivity.hold(profileName: profileName, accentHex: accentHex,
                              remaining: TimeInterval(remainingSeconds))
            return   // no ticker: a held session doesn't run
        }

        pausedSeconds = saved.pausedSeconds
        phaseStart = saved.startedAt.addingTimeInterval(saved.pausedSeconds)
        let elapsed = Int(Date().timeIntervalSince(phaseStart))
        if elapsed >= totalSeconds {
            finishFocus(completed: true) // completed while away → record it
        } else {
            remainingSeconds = totalSeconds - elapsed
            // Put the shields back rather than assuming they survived.
            //
            // This restored the countdown, the card and the block screen's
            // strings, and nothing else — it trusted that whatever `startFocus`
            // wrote to the shared ManagedSettingsStore was still in place. Most
            // of the time it is; when it is not, the session came back as
            // RUNNING with nothing enforced and no code path that would ever
            // re-apply for the rest of it. A timer counting down over an
            // unblocked phone is the worst shape this app can take, and it is
            // exactly what App Review reported.
            //
            // Applying shields that are already applied is a no-op, so this
            // costs nothing when the usual case holds.
            reassertEnforcement(forRemaining: remainingSeconds)
            liveActivity.start(profileName: profileName, accentHex: accentHex,
                               startsAt: phaseStart,
                               endsAt: phaseStart.addingTimeInterval(TimeInterval(totalSeconds)),
                               phase: .focus)
            ActiveSessionInfo.set(profileName: profileName,
                                  endsAt: phaseStart.addingTimeInterval(TimeInterval(totalSeconds)))
            startTicker()
        }
    }

    /// Register this session and apply its shields for the time it has left.
    ///
    /// Idempotent, and the order matters: the store entry goes in first because
    /// `ShieldReconciler` clears anything it cannot account for, so a session
    /// missing from the store would have its own shields taken down by the very
    /// check meant to keep them up.
    private func reassertEnforcement(forRemaining seconds: Int) {
        schedule.startOneOff(activity: .focusSession,
                             block: currentBlock, allow: currentAllow,
                             blockAll: currentBlockAll,
                             allowedWebDomains: currentAllowedWebDomains,
                             durationMinutes: max(1, Int(ceil(Double(seconds) / 60))))
        blocking.startBlocking(currentBlock, allowing: currentAllow,
                               blockAll: currentBlockAll,
                               allowedWebDomains: currentAllowedWebDomains)
    }

    // MARK: - Pause / resume

    /// Hold the session: stop the clock and lift the shields, keeping the time
    /// that's left. Nothing is recorded — a paused session hasn't ended.
    ///
    /// Strict mode deliberately refuses. Strict exists so a session can't be
    /// wriggled out of, and a pause with no time limit would be exactly that.
    func pause() {
        guard phase == .focus, !isPaused, !isStrict else { return }
        ticker?.cancel()
        isPaused = true
        pauseStartedAt = Date()

        // Drop this session's own enforcement, then reconcile so any recurring
        // schedule that happens to be open keeps its shields.
        schedule.stop(.focusSession)
        blocking.reconcile()
        notifications.cancelSession()

        liveActivity.hold(profileName: profileName, accentHex: accentHex,
                          remaining: TimeInterval(remainingSeconds))
        // A held session has no shields up, so nothing should be quoting a
        // countdown on a block screen that can no longer appear.
        ActiveSessionInfo.clear()
        persistSnapshot()
        Haptics.light()
    }

    /// Put the shields back and start the clock again from where it stopped.
    func resume() {
        guard isPaused else { return }
        let held = Date().timeIntervalSince(pauseStartedAt ?? Date())
        pausedSeconds += max(0, held)
        pauseStartedAt = nil
        isPaused = false

        // The countdown is anchored to `phaseStart`, so pushing that forward by
        // the time spent held resumes at exactly the same number.
        phaseStart = phaseStart.addingTimeInterval(max(0, held))

        let secondsLeft = TimeInterval(remainingSeconds)
        blocking.startBlocking(currentBlock, allowing: currentAllow,
                               blockAll: currentBlockAll,
                               allowedWebDomains: currentAllowedWebDomains)
        schedule.startOneOff(activity: .focusSession, block: currentBlock, allow: currentAllow,
                             blockAll: currentBlockAll,
                             allowedWebDomains: currentAllowedWebDomains,
                             durationMinutes: max(1, Int(ceil(secondsLeft / 60))))
        notifications.scheduleFocusEnd(after: secondsLeft, profileName: profileName)
        // Anchor the card to the (shifted) phase start, not to now — otherwise
        // the progress rule snaps back to empty every time you resume, and a
        // session paused near the end looks like it just began.
        liveActivity.start(profileName: profileName, accentHex: accentHex,
                           startsAt: phaseStart,
                           endsAt: phaseStart.addingTimeInterval(TimeInterval(totalSeconds)),
                           phase: .focus)
        ActiveSessionInfo.set(profileName: profileName,
                              endsAt: phaseStart.addingTimeInterval(TimeInterval(totalSeconds)))
        persistSnapshot()
        startTicker()
        Haptics.light()
    }

    /// User ends the focus session before the timer completes.
    func endEarly() {
        ticker?.cancel()
        switch phase {
        case .focus: finishFocus(completed: false)
        case .breakTime: finishBreak()
        default: break
        }
    }

    /// From the summary screen: start the profile's break, or finish.
    func startBreak() {
        guard breakMinutes > 0 else { dismissSummary(); return }
        summary = nil
        let start = Date()
        beginPhase(.breakTime, minutes: breakMinutes)
        notifications.scheduleBreakEnd(after: TimeInterval(breakMinutes * 60),
                                       focusedToday: history.todayFocusMinutes() > 0)
        liveActivity.start(profileName: profileName, accentHex: accentHex,
                           startsAt: start,
                           endsAt: start.addingTimeInterval(TimeInterval(breakMinutes * 60)),
                           phase: .breakTime)
    }

    func dismissSummary() {
        summary = nil
        phase = .idle
    }

    /// Attach the post-session review to the session just recorded.
    func saveReview(rating: Int, note: String) {
        guard let lastSession else { return }
        lastSession.rating = Int16(rating)
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        lastSession.note = trimmed.isEmpty ? nil : trimmed
        history.save()
    }

    /// Re-sync the countdown after returning from the background.
    func refresh() {
        guard isActive else { return }
        tick()
    }

    // MARK: - Phase machinery

    private func beginPhase(_ newPhase: Phase, minutes: Int) {
        phase = newPhase
        totalSeconds = max(0, minutes * 60)
        phaseStart = Date()
        remainingSeconds = totalSeconds
        startTicker()
    }

    private func startTicker() {
        ticker?.cancel()
        ticker = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                self.tick()
            }
        }
    }

    private func tick() {
        let elapsed = Int(Date().timeIntervalSince(phaseStart))
        remainingSeconds = max(0, totalSeconds - elapsed)
        if remainingSeconds == 0 { phaseDidComplete() }
    }

    private func phaseDidComplete() {
        ticker?.cancel()
        switch phase {
        case .focus: finishFocus(completed: true)
        case .breakTime: finishBreak()
        default: break
        }
    }

    private func finishFocus(completed: Bool) {
        // Settle any pause still open, so the time held is excluded from what
        // the user is credited with.
        if isPaused, let pauseStartedAt {
            pausedSeconds += max(0, Date().timeIntervalSince(pauseStartedAt))
        }
        isPaused = false
        pauseStartedAt = nil

        clearEnforcement()

        let focusedSeconds = Date().timeIntervalSince(focusStartedAt) - pausedSeconds
        let completedMinutes = completed
            ? plannedFocusMinutes
            : max(0, Int(focusedSeconds / 60))

        lastSession = history.record(profileName: profileName,
                                     plannedMinutes: plannedFocusMinutes,
                                     completedMinutes: completedMinutes,
                                     kind: "focus",
                                     wasCompleted: completed,
                                     endedEarly: !completed,
                                     startedAt: focusStartedAt,
                                     endedAt: Date())

        // A session just finished → re-arm the daily reminder to the "break" nudge.
        notifications.refreshDailyReminderAfterSession()

        Haptics.success()

        // Nothing is pushed to the Lock Screen here, and that is the point.
        //
        // `clearEnforcement()` above has already ended the Live Activity and
        // cancelled the session's alerts. This used to follow it with a
        // "finished" card that lingered two minutes offering "Again" — so the
        // card was torn down and immediately rebuilt. Two things were wrong
        // with it. The small one is that nobody wanted it: the session is over,
        // and the summary screen is where you decide what happens next. The
        // large one is that its self-dismissal was a `Task` sleeping in this
        // process, which only fires if the app is still running two minutes
        // later — and a session that ends with the phone in a pocket ends with
        // the app suspended. The card then had nothing left to clear it.

        summary = SessionSummary(profileName: profileName,
                                 accentHex: accentHex,
                                 plannedMinutes: plannedFocusMinutes,
                                 completedMinutes: completedMinutes,
                                 // A session that ran to the end is credited
                                 // with its planned length; one cut short is
                                 // credited with what actually elapsed, to the
                                 // second, so 04b's ring can show a clock.
                                 completedSeconds: completed
                                     ? plannedFocusMinutes * 60
                                     : max(0, Int(focusedSeconds)),
                                 wasCompleted: completed,
                                 endedEarly: !completed,
                                 streak: history.currentStreak())
        isMinimized = false          // the celebration is never tucked away
        phase = .summary
    }

    /// "Again" from the finished Live Activity, and "Try a shorter one" from the
    /// ended-early screen — run the same profile with the same enforcement.
    /// `minutes` overrides the length; nil keeps the profile's own.
    func repeatLastSession(minutes: Int? = nil) {
        guard phase != .focus, plannedFocusMinutes > 0 else { return }
        summary = nil
        startFocus(profileName: profileName,
                   accentHex: accentHex,
                   focusMinutes: minutes ?? plannedFocusMinutes,
                   breakMinutes: breakMinutes,
                   isStrict: isStrict,
                   blockAll: currentBlockAll,
                   allowedWebDomains: currentAllowedWebDomains,
                   block: currentBlock,
                   allow: currentAllow)
    }

    private func finishBreak() {
        notifications.cancelSession()
        liveActivity.end()
        Haptics.light()
        summary = nil
        phase = .idle
    }

    /// Recompute the shields from what is currently true.
    ///
    /// Everything that applies shields derives them rather than editing them,
    /// so granting a five-minute pass is just data with an expiry — this is
    /// what makes the pass take effect now instead of at the next foreground.
    func reapplyEnforcement() {
        // A live session is re-registered BEFORE reconciling, and that ordering
        // is the whole safety of this method.
        //
        // `reconcile` rebuilds the shield state from the registered activities
        // and clears whatever it cannot account for. Called against a running
        // session that is missing from the store — which is how this app's worst
        // bug worked — it does not restore enforcement, it removes it. Putting
        // the session back first means this check can only ever add shields to a
        // running session, never take them away.
        if phase == .focus && !isPaused {
            reassertEnforcement(forRemaining: remainingSeconds)
        }
        blocking.reconcile()
    }

    private func clearEnforcement() {
        // Remove THIS session's one-off entry first, then reconcile — so if a
        // recurring schedule window is still open, its shields stay applied
        // instead of being cleared along with the session.
        schedule.stop(.focusSession)
        blocking.reconcile()
        notifications.cancelSession()
        liveActivity.end()
        ActiveSessionInfo.clear()
        FocusSessionStore.clear()
    }
}
