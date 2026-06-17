//
//  FocusLiveActivity.swift
//  ZenlyWidget
//
//  Live Activity for the running focus/break session — Lock Screen banner +
//  Dynamic Island. The countdown auto-updates from the start…end range.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            lockScreen(context)
        } dynamicIsland: { context in
            let tint = Color(hex: context.attributes.accentHex)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.isBreak ? "Break" : context.attributes.profileName,
                          systemImage: context.state.isBreak ? "cup.and.saucer.fill" : "timer")
                        .font(.caption)
                        .foregroundStyle(tint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                        .font(.headline.monospacedDigit())
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(timerInterval: context.state.startDate...context.state.endDate)
                        .tint(tint)
                }
            } compactLeading: {
                Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "timer")
                    .foregroundStyle(tint)
            } compactTrailing: {
                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 44)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(tint)
            }
            .keylineTint(tint)
        }
    }

    private func lockScreen(_ context: ActivityViewContext<FocusActivityAttributes>) -> some View {
        let tint = Color(hex: context.attributes.accentHex)
        return HStack(spacing: 16) {
            Image(systemName: context.state.isBreak ? "cup.and.saucer.fill" : "timer")
                .font(.title2)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(context.state.isBreak ? "Break" : context.attributes.profileName)
                    .font(.headline)
                Text(context.state.isBreak ? "Time to recharge" : "Stay focused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                .font(.title2.monospacedDigit().bold())
                .foregroundStyle(tint)
                .frame(width: 72)
        }
        .padding()
        .activityBackgroundTint(tint.opacity(0.12))
        .activitySystemActionForegroundColor(tint)
    }
}
