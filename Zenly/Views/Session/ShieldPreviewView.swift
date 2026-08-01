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
//  `ShieldTheme`-mirrored palette.
//
//  It is deliberately laid out the way **iOS** lays the slots out, not the way
//  the comp does — icon, then title, then subtitle, stacked and centred, with
//  the buttons pinned. A preview that drew the comp's geometry would be a
//  picture of something that cannot ship, and this file exists to be screenshot
//  as evidence. Spacing is still approximate; iOS's real metrics are private.
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
        ZStack {
            Color(hex: "0A0B0E").ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                ribbon
                    .padding(.bottom, 22)

                Text(ShieldMessage.title())
                    .font(ZTheme.Font.display(25, weight: .semibold))
                    .foregroundStyle(Color(hex: "E7E8EC"))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 290)

                Text(ShieldMessage.subtitle(subject: subject, custom: ""))
                    .font(ZTheme.Font.body(14))
                    .foregroundStyle(Color(hex: "E7E8EC").opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 290)
                    .padding(.top, 10)

                Spacer(minLength: 0)

                VStack(spacing: 8) {
                    Text("Back to focus")
                        .font(ZTheme.Font.display(16, weight: .semibold))
                        .foregroundStyle(Color(hex: "0A0B0E"))
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(tone, in: Capsule())
                    Text("I need it for 5 minutes")
                        .font(ZTheme.Font.body(14))
                        .foregroundStyle(Color(hex: "E7E8EC").opacity(0.55))
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 1))
                }
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 40)
        }
        .accessibilityIdentifier("shield-preview")
    }

    /// The extension's own bitmap, at the size iOS gives the icon slot.
    ///
    /// 100pt, because that is what the slot measured out to on device. Drawing
    /// it any larger here would flatter the build.
    @ViewBuilder
    private var ribbon: some View {
        if let image = ShieldRibbon.icon(subject: subject, tone: UIColor(tone)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .accessibilityIdentifier("shield-preview-ribbon")
        }
    }
}

#endif
