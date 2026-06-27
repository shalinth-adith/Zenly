//
//  Color+Hex.swift
//  Zenly
//
//  Hex string <-> Color for profile/schedule accent colors stored in Core Data.
//

import SwiftUI

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    /// A color that resolves to `light` in light appearance and `dark` in dark
    /// appearance. Backed by a dynamic `UIColor` provider, so it re-resolves on
    /// every render against the active trait collection — the app follows the
    /// system Light/Dark setting live, with no `@Environment(\.colorScheme)`
    /// plumbing at the call sites.
    init(light: Color, dark: Color) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        self = dark
        #endif
    }

    /// Convenience: an adaptive color from two hex strings.
    init(lightHex: String, darkHex: String) {
        self.init(light: Color(hex: lightHex), dark: Color(hex: darkHex))
    }
}
