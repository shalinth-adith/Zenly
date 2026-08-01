//
//  ShieldPreviewView.swift
//  Zenly
//
//  A DEBUG-only rehearsal of the block screen (Quiet spec, screen 03).
//
//  The real screen 03 is drawn by iOS from a `ShieldConfiguration` inside the
//  ZenlyShield app extension, and it only ever appears when a Screen Time shield
//  is up — which cannot happen on Simulator, because FamilyControls has no
//  authorization to grant there. That leaves the one screen in the app that is
//  impossible to look at while building it.
//
//  So this reassembles it from the *same inputs the extension uses*: the same
//  `ShieldRibbon` bitmap, the same `ShieldMessage` strings, the same
//  `ShieldTheme`-mirrored palette. It is a preview of the content, laid out the
//  way the comp lays it out. iOS's own layout of those slots will differ — its
//  metrics are private — so this proves the words and the artwork, not the
//  spacing.
//
//  Two gates: the whole file is compiled out of Release, and it is only ever
//  reachable when the launch argument is present.
//

#if DEBUG

import SwiftUI

struct ShieldPreviewView: View {
    /// Set by `ZenlyPreviewShield <name>`; the app name the shield is standing
    /// in front of.
    var subject: String
    var tone: Color

    var body: some View {
        ZStack(alignment: .top) {
            backdrop

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                Text(ShieldMessage.title())
                    .font(ZTheme.Font.display(25, weight: .semibold))
                    .foregroundStyle(Color(hex: "E7E8EC"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 290)
                    .padding(.top, 10)

                Text(ShieldMessage.subtitle(subject: subject, custom: ""))
                    .font(ZTheme.Font.body(14))
                    .foregroundStyle(Color(hex: "E7E8EC").opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 272)
                    .padding(.top, 12)

                Spacer(minLength: 0)

                VStack(spacing: 4) {
                    Text("Back to focus")
                        .font(ZTheme.Font.display(16, weight: .semibold))
                        .foregroundStyle(Color(hex: "0A0B0E"))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(tone, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text("I need it for 5 minutes")
                        .font(ZTheme.Font.body(14))
                        .foregroundStyle(Color(hex: "E7E8EC").opacity(0.55))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 40)
            // The comp reserves the top 220pt for the ribbon before the text
            // block begins.
            .padding(.top, 220)
        }
        .accessibilityIdentifier("shield-preview")
    }

    /// The extension's own backdrop bitmap — the same one it hands to
    /// `ShieldConfiguration.backgroundColor` as a pattern — drawn 1:1 so the
    /// preview shows the ribbon at exactly the size the shield will.
    private var backdrop: some View {
        // Measured here rather than taken from the App Group, so the preview
        // draws at the size of the device it is actually running on.
        GeometryReader { geo in
            if let image = ShieldRibbon.backdrop(subject: subject,
                                                 tone: UIColor(tone),
                                                 screen: geo.size) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .accessibilityIdentifier("shield-preview-ribbon")
            } else {
                Color(hex: "0A0B0E")
            }
        }
        .ignoresSafeArea()
    }
}

#endif
