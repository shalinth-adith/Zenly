//
//  TotalActivityReport.swift
//  ZenlyReport
//
//  Reduces the privacy-preserving DeviceActivityResults stream into a total
//  duration + top apps (kept as ApplicationTokens so the view can render real
//  names/icons via Label — localizedDisplayName is nil by design).
//

import DeviceActivity
import ManagedSettings
import SwiftUI

struct AppDuration: Identifiable {
    let id = UUID()
    let token: ApplicationToken?
    let duration: TimeInterval
}

struct TotalActivity {
    let totalDuration: TimeInterval
    let apps: [AppDuration]

    static let empty = TotalActivity(totalDuration: 0, apps: [])
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (TotalActivity) -> TotalActivityView

    func makeConfiguration(representing data: DeviceActivityResults<DeviceActivityData>) async -> TotalActivity {
        var totalDuration: TimeInterval = 0
        var byToken: [ApplicationToken: TimeInterval] = [:]

        for await result in data {
            for await segment in result.activitySegments {
                totalDuration += segment.totalActivityDuration
                for await category in segment.categories {
                    for await app in category.applications {
                        guard let token = app.application.token else { continue }
                        byToken[token, default: 0] += app.totalActivityDuration
                    }
                }
            }
        }

        let topApps = byToken
            .sorted { $0.value > $1.value }
            .prefix(6)
            .map { AppDuration(token: $0.key, duration: $0.value) }

        return TotalActivity(totalDuration: totalDuration, apps: topApps)
    }
}
