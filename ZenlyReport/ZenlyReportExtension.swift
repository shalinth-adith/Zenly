//
//  ZenlyReportExtension.swift
//  ZenlyReport
//
//  DeviceActivityReport extension entry point. Uses the SwiftUI @main lifecycle
//  (no NSExtensionPrincipalClass — that breaks on-device install for this
//  extension point). Each scene maps a report context to a SwiftUI view.
//

import DeviceActivity
import SwiftUI

@main
struct ZenlyReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityReport { totalActivity in
            TotalActivityView(activity: totalActivity)
        }
    }
}
