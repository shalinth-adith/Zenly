//
//  StartFocusControl.swift
//  ZenlyWidget
//
//  Control Center / Lock Screen control (iOS 18+) to start a focus session with
//  one tap. Runs StartFocusIntent.
//

import WidgetKit
import SwiftUI
import AppIntents

@available(iOS 18.0, *)
struct StartFocusControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "me.adithyan.shalinth.Zenly.startfocus") {
            ControlWidgetButton(action: StartFocusIntent()) {
                Label("Start Focus", systemImage: "timer")
            }
        }
        .displayName("Start Focus")
        .description("Begin a Zen-ly focus session.")
    }
}
