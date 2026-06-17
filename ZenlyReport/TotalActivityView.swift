//
//  TotalActivityView.swift
//  ZenlyReport
//
//  Renders the reduced activity model. This view lives in the extension and is
//  composited into the app by the system (the app never sees the raw numbers).
//

import SwiftUI

struct TotalActivityView: View {
    let activity: TotalActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Total screen time")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(format(activity.totalDuration))
                    .font(.title2.bold())
            }

            if activity.apps.isEmpty {
                Text("No activity recorded yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(activity.apps) { app in
                    HStack {
                        Text(app.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Text(format(app.duration))
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func format(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: duration) ?? "0m"
    }
}
