//
//  LiveActivityManager.swift
//  Zenly
//
//  Starts / updates / ends the focus-session Live Activity (Dynamic Island +
//  Lock Screen). The countdown is driven by the start…end range, so no
//  per-second updates are needed.
//

import ActivityKit
import Foundation

@MainActor
final class LiveActivityManager {
    /// Shared so the session and the schedule-countdown never show two activities
    /// at once — starting one automatically ends any prior (see `start`).
    static let shared = LiveActivityManager()

    private var activity: Activity<FocusActivityAttributes>?
    private var currentPhase: FocusActivityAttributes.Phase?
    private var currentEnd: Date?

    func start(profileName: String, accentHex: String,
               startsAt: Date, endsAt: Date, phase: FocusActivityAttributes.Phase) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end() // clear any prior activity

        let attributes = FocusActivityAttributes(profileName: profileName, accentHex: accentHex)
        let state = FocusActivityAttributes.ContentState(startDate: startsAt, endDate: endsAt, phase: phase)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: endsAt)
            )
            currentPhase = phase
            currentEnd = endsAt
        } catch {
            print("[Zenly] Live Activity start failed: \(error)")
        }
    }

    /// Start the last-minute countdown to a scheduled window. Idempotent: if an
    /// upcoming countdown ending at ~the same time is already showing, do nothing
    /// (so the 30s foreground watcher doesn't restart/flicker it every tick).
    func startUpcoming(title: String, accentHex: String, startsAt: Date, endsAt: Date) {
        if currentPhase == .upcoming, let e = currentEnd, abs(e.timeIntervalSince(endsAt)) < 5 {
            return
        }
        start(profileName: title, accentHex: accentHex, startsAt: startsAt, endsAt: endsAt, phase: .upcoming)
    }

    var isShowingUpcoming: Bool { currentPhase == .upcoming }

    func end() {
        guard let current = activity else { return }
        activity = nil
        currentPhase = nil
        currentEnd = nil
        Task { await current.end(nil, dismissalPolicy: .immediate) }
    }
}
