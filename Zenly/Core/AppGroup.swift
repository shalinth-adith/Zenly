//
//  AppGroup.swift
//  Zenly
//
//  Shared App Group container + named ManagedSettingsStore.
//  These identifiers MUST stay byte-identical to the entitlements in every
//  target (defined in project.yml). They are the spine of the app↔extension link.
//

import Foundation
import ManagedSettings

enum AppGroup {
    /// App Group container identifier shared by the app and all extensions.
    static let identifier = "group.me.adithyan.shalinth.Zenly"

    /// UserDefaults backed by the App Group container. Falls back to `.standard`
    /// only if the suite can't be created (misconfigured entitlement) — which
    /// would itself be a loud bug to catch during on-device testing.
    static let defaults = UserDefaults(suiteName: identifier) ?? .standard
}

extension ManagedSettingsStore.Name {
    /// The single named store the app and the DeviceActivityMonitor extension
    /// both mutate, so shields applied in one are visible to the other.
    static let zenly = Self("zenly.focus")
}
