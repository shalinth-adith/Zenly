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

    private var phaseStart = Date()
    private var focusStartedAt = Date()
    private var isStrict = false
    private var plannedFocusMinutes = 0
    private var breakMinutes = 0
    private var ticker: Task<Void, Never>?
    private var lastSession: FocusSession?

    private let blocking = BlockingService()
    private let schedule = ScheduleCenter.shared
    private let notifications = NotificationService.shared
    private let liveActivity = LiveActivityManager()
    private let history: SessionHistory

    init(history: SessionHistory? = nil) {
        self.history = history ?? SessionHistory()
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
                           isBreak: false)

        // Persist so the session is recorded even if iOS kills the app while
        // it's backgrounded during the session.
        FocusSessionStore.save(PersistedFocusSession(
            startedAt: focusStartedAt,
            focusMinutes: focusMinutes,
            breakMinutes: breakMinutes,
            isStrict: isStrict,
            profileName: profileName,
            accentHex: accentHex
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
        phaseStart = saved.startedAt
        phase = .focus

        let elapsed = Int(Date().timeIntervalSince(saved.startedAt))
        if elapsed >= totalSeconds {
            finishFocus(completed: true) // completed while away → record it
        } else {
            remainingSeconds = totalSeconds - elapsed
            liveActivity.start(profileName: profileName, accentHex: accentHex,
                               startsAt: saved.startedAt,
                               endsAt: saved.startedAt.addingTimeInterval(TimeInterval(totalSeconds)),
                               isBreak: false)
            startTicker()
        }
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
        notifications.scheduleBreakEnd(after: TimeInterval(breakMinutes * 60))
        liveActivity.start(profileName: profileName, accentHex: accentHex,
                           startsAt: start,
                           endsAt: start.addingTimeInterval(TimeInterval(breakMinutes * 60)),
                           isBreak: true)
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
        clearEnforcement()

        let completedMinutes = completed
            ? plannedFocusMinutes
            : max(0, Int(Date().timeIntervalSince(focusStartedAt) / 60))

        lastSession = history.record(profileName: profileName,
                                     plannedMinutes: plannedFocusMinutes,
                                     completedMinutes: completedMinutes,
                                     kind: "focus",
                                     wasCompleted: completed,
                                     endedEarly: !completed,
                                     startedAt: focusStartedAt,
                                     endedAt: Date())

        Haptics.success()
        summary = SessionSummary(profileName: profileName,
                                 accentHex: accentHex,
                                 plannedMinutes: plannedFocusMinutes,
                                 completedMinutes: completedMinutes,
                                 wasCompleted: completed,
                                 endedEarly: !completed,
                                 streak: history.currentStreak())
        phase = .summary
    }

    private func finishBreak() {
        notifications.cancelSession()
        liveActivity.end()
        Haptics.light()
        summary = nil
        phase = .idle
    }

    private func clearEnforcement() {
        // Remove THIS session's one-off entry first, then reconcile — so if a
        // recurring schedule window is still open, its shields stay applied
        // instead of being cleared along with the session.
        schedule.stop(.focusSession)
        blocking.reconcile()
        notifications.cancelSession()
        liveActivity.end()
        FocusSessionStore.clear()
    }
}
