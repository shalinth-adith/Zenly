//
//  AppUsageReportView.swift
//  Zenly
//
//  Host for the DeviceActivityReport. The system renders the ZenlyReport
//  extension's SwiftUI inside this view. Only shows real data on a physical
//  device with Screen Time authorization.
//

import SwiftUI
import DeviceActivity

struct AppUsageReportView: View {
    private let filter: DeviceActivityFilter

    init() {
        let now = Date()
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        filter = DeviceActivityFilter(
            segment: .daily(during: DateInterval(start: weekAgo, end: now)),
            users: .all,
            devices: .init([.iPhone])
        )
    }

    var body: some View {
        DeviceActivityReport(.totalActivity, filter: filter)
    }
}
