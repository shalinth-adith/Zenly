//
//  ZenlyWidget.swift
//  ZenlyWidget
//
//  Home-screen widget showing a focus stat from the App-Group StatsSnapshot.
//  Uses AppIntentConfiguration so the user picks which metric to display
//  (WidgetKit + AppIntents).
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration intent

enum WidgetMetric: String, AppEnum {
    case streak
    case minutes
    case attempts

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Metric" }

    static var caseDisplayRepresentations: [WidgetMetric: DisplayRepresentation] {
        [
            .streak: "Day streak",
            .minutes: "Focus minutes today",
            .attempts: "Distractions blocked"
        ]
    }
}

struct ZenlyWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Zenly Stat"
    static var description = IntentDescription("Choose which focus stat to show.")

    @Parameter(title: "Metric", default: .streak)
    var metric: WidgetMetric
}

// MARK: - Timeline

struct ZenlyEntry: TimelineEntry {
    let date: Date
    let snapshot: StatsSnapshot
    let metric: WidgetMetric
}

struct ZenlyProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ZenlyEntry {
        ZenlyEntry(date: .now, snapshot: .empty, metric: .streak)
    }

    func snapshot(for configuration: ZenlyWidgetConfiguration, in context: Context) async -> ZenlyEntry {
        ZenlyEntry(date: .now, snapshot: StatsStore.load(), metric: configuration.metric)
    }

    func timeline(for configuration: ZenlyWidgetConfiguration, in context: Context) async -> Timeline<ZenlyEntry> {
        let entry = ZenlyEntry(date: .now, snapshot: StatsStore.load(), metric: configuration.metric)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(1800)))
    }
}

// MARK: - View

struct ZenlyWidgetEntryView: View {
    let entry: ZenlyEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Zenly", systemImage: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tint)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var icon: String {
        switch entry.metric {
        case .streak: return "flame.fill"
        case .minutes: return "clock.fill"
        case .attempts: return "shield.fill"
        }
    }

    private var value: String {
        switch entry.metric {
        case .streak: return "\(entry.snapshot.streak)"
        case .minutes: return "\(entry.snapshot.todayMinutes)"
        case .attempts: return "\(entry.snapshot.todayAttempts)"
        }
    }

    private var label: String {
        switch entry.metric {
        case .streak: return "day streak"
        case .minutes: return "min focused today"
        case .attempts: return "distractions blocked"
        }
    }
}

// MARK: - Widget

struct ZenlyWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "ZenlyWidget",
            intent: ZenlyWidgetConfiguration.self,
            provider: ZenlyProvider()
        ) { entry in
            ZenlyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Zenly")
        .description("Your focus at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct ZenlyWidgetBundle: WidgetBundle {
    var body: some Widget {
        ZenlyWidget()
        FocusLiveActivity()
    }
}
