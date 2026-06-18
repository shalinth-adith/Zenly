//
//  CalendarService.swift
//  Zenly
//
//  Reads the user's calendar (EventKit) to find free blocks for auto-starting or
//  suggesting focus sessions.
//

import Foundation
import EventKit
import Observation

struct FreeBlock: Identifiable {
    let id = UUID()
    let start: Date
    let end: Date
    var minutes: Int { max(0, Int(end.timeIntervalSince(start) / 60)) }
}

@Observable
@MainActor
final class CalendarService {
    private(set) var isAuthorized = false
    private let store = EKEventStore()

    init() {
        isAuthorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    var isDenied: Bool {
        EKEventStore.authorizationStatus(for: .event) == .denied
    }

    func requestAccess() async {
        do {
            isAuthorized = try await store.requestFullAccessToEvents()
        } catch {
            print("[Zenly] Calendar access failed: \(error)")
            isAuthorized = false
        }
    }

    /// Free gaps (≥ 15 min) between today's timed events, from now until end of day.
    func freeBlocks(minimumMinutes: Int = 15) -> [FreeBlock] {
        guard isAuthorized else { return [] }
        let calendar = Calendar.current
        let now = Date()
        guard let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 0, of: now) else { return [] }

        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        let events = store.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }

        var blocks: [FreeBlock] = []
        var cursor = now
        for event in events {
            if event.startDate > cursor {
                blocks.append(FreeBlock(start: cursor, end: event.startDate))
            }
            cursor = max(cursor, event.endDate)
        }
        if cursor < endOfDay {
            blocks.append(FreeBlock(start: cursor, end: endOfDay))
        }
        return blocks.filter { $0.minutes >= minimumMinutes }
    }

    var nextFreeBlock: FreeBlock? { freeBlocks().first }
}
