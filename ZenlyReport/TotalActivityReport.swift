//
//  TotalActivityReport.swift
//  ZenlyReport
//
//  Reduces the privacy-preserving DeviceActivityResults stream into a total
//  duration + top apps, inside the extension's sandbox.
//

import DeviceActivity
import SwiftUI

struct AppDuration: Identifiable {
    let id = UUID()
    let name: String
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
        var durationsByApp: [String: TimeInterval] = [:]

        for await result in data {
            for await segment in result.activitySegments {
                totalDuration += segment.totalActivityDuration
                for await category in segment.categories {
                    for await app in category.applications {
                        let name = app.application.localizedDisplayName ?? "Other"
                        durationsByApp[name, default: 0] += app.totalActivityDuration
                    }
                }
            }
        }

        let topApps = durationsByApp
            .sorted { $0.value > $1.value }
            .prefix(5)
            .map { AppDuration(name: $0.key, duration: $0.value) }

        return TotalActivity(totalDuration: totalDuration, apps: topApps)
    }
}
