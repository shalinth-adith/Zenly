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

    /// Ends every focus Live Activity the system is showing — not just the one
    /// this instance happens to hold a reference to.
    ///
    /// `activity` only lives as long as the process. ActivityKit activities do
    /// not: if iOS terminates the app mid-session, the relaunched process has
    /// `activity == nil` while the Dynamic Island / Lock Screen timer is still
    /// on screen. Guarding on the local reference made `end()` silently no-op in
    /// exactly that case, stranding the timer after the session had ended (and
    /// letting `start()` add a second activity beside the orphan). Sweeping
    /// `Activity.activities` makes this authoritative and idempotent.
    func end() {
        activity = nil
        currentPhase = nil
        currentEnd = nil
        // Snapshot synchronously: `start()` calls `end()` and then immediately
        // requests a new activity. Reading the list inside the Task instead
        // would let the sweep tear down that brand-new activity.
        let stale = Activity<FocusActivityAttributes>.activities
        Task {
            for activity in stale {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
