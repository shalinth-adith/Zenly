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
    private var activity: Activity<FocusActivityAttributes>?

    func start(profileName: String, accentHex: String, startsAt: Date, endsAt: Date, isBreak: Bool) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        end() // clear any prior activity

        let attributes = FocusActivityAttributes(profileName: profileName, accentHex: accentHex)
        let state = FocusActivityAttributes.ContentState(startDate: startsAt, endDate: endsAt, isBreak: isBreak)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: endsAt)
            )
        } catch {
            print("[Zenly] Live Activity start failed: \(error)")
        }
    }

    func end() {
        guard let current = activity else { return }
        activity = nil
        Task { await current.end(nil, dismissalPolicy: .immediate) }
    }
}
