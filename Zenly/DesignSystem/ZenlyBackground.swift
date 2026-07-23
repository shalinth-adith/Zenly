//
//  ZenlyBackground.swift
//  Zenly
//
//  Flat, quiet backdrop: a single neutral surface (design `--bg`, #0A0B0E dark /
//  #F3F3F0 light) behind every screen — no aurora, no gradient, nothing that
//  competes for attention.
//
//  Imported from the Claude Design spec (Zenly Quiet.dc.html).
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
        ZTheme.Palette.night
            .ignoresSafeArea()
    }
}

#Preview {
    ZenlyBackground()
}
