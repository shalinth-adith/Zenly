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
                    Label(title(context), systemImage: icon(context.state.phase))
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
                Image(systemName: icon(context.state.phase))
                    .foregroundStyle(tint)
            } compactTrailing: {
                Text(timerInterval: context.state.startDate...context.state.endDate, countsDown: true)
                    .monospacedDigit()
                    .frame(width: 44)
            } minimal: {
                Image(systemName: icon(context.state.phase)).foregroundStyle(tint)
            }
            .keylineTint(tint)
        }
    }

    private func lockScreen(_ context: ActivityViewContext<FocusActivityAttributes>) -> some View {
        let tint = Color(hex: context.attributes.accentHex)
        return HStack(spacing: 16) {
            Image(systemName: icon(context.state.phase))
                .font(.title2)
                .foregroundStyle(tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title(context))
                    .font(.headline)
                Text(subtitle(context.state.phase))
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

    private func title(_ context: ActivityViewContext<FocusActivityAttributes>) -> String {
        switch context.state.phase {
        case .focus:     return context.attributes.profileName
        case .breakTime: return "Break"
        case .upcoming:  return "Focus starts soon"
        }
    }

    private func subtitle(_ phase: FocusActivityAttributes.Phase) -> String {
        switch phase {
        case .focus:     return "Stay focused"
        case .breakTime: return "Time to recharge"
        case .upcoming:  return "Get ready to focus"
        }
    }

    private func icon(_ phase: FocusActivityAttributes.Phase) -> String {
        switch phase {
        case .focus:     return "timer"
        case .breakTime: return "cup.and.saucer.fill"
        case .upcoming:  return "hourglass"
        }
    }
}
