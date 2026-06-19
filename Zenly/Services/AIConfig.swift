//
//  AIConfig.swift
//  Zenly
//
//  Anthropic API key for the AI Research Browser's website classifier.
//  The key is read from the App Group (so it can be pasted in Settings at
//  runtime); `compileTimeKey` is an optional fallback if you'd rather bake it
//  in like SpotifyConfig. With no key, the browser falls back to the on-device
//  heuristic classifier and still works — just less nuanced on unknown sites.
//

import Foundation

enum AIConfig {
    /// Optional baked-in key. Leave empty to require pasting one in Settings.
    private static let compileTimeKey = ""

    /// App Group key under which the runtime-entered key is stored.
    static let storageKey = "anthropicAPIKey"

    /// The active key: a runtime-entered key (Settings) wins over the compile-time one.
    static var apiKey: String {
        let stored = AppGroup.defaults.string(forKey: storageKey) ?? ""
        return stored.isEmpty ? compileTimeKey : stored
    }

    /// True when a usable key is present and the AI path can be used.
    static var isConfigured: Bool { !apiKey.isEmpty }

    /// Fast, cheap model — built for one-word classification well under 2s.
    static let classifierModel = "claude-haiku-4-5"
}
