//
//  ReportContext.swift
//  Zenly (shared: app + ZenlyReport)
//
//  The report context name must match between the app (which embeds the
//  DeviceActivityReport) and the report extension (which renders it).
//

import SwiftUI
import DeviceActivity

extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
}
