//
//  ZenlyBackground.swift
//  Zenly
//
//  Flat, Apple-plain backdrop: a single solid dark surface (nightDeep, #0a0b12)
//  behind every screen. The previous "Living Focus" aurora (radial base + waving
//  ribbons + rising particles) was retired per the updated Zenly Matte spec.
//
//  Imported from the Claude Design spec (Zenly Matte.dc.html).
//

import SwiftUI

struct ZenlyBackground: View {
    /// Retained for source compatibility with call sites; the backdrop is now a
    /// single flat surface, so these no longer alter the rendering.
    enum Variant { case standard, session }
    var variant: Variant = .standard
    var particles: Bool = false
    var calm: Bool = false

    var body: some View {
        ZTheme.Palette.nightDeep
            .ignoresSafeArea()
    }
}

#Preview {
    ZenlyBackground()
}
