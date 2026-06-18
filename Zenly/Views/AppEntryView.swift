//
//  AppEntryView.swift
//  Zenly
//
//  Shows the animated splash on launch, then crossfades into the app
//  (onboarding or the tab bar).
//

import SwiftUI

struct AppEntryView: View {
    @State private var showSplash = true

    var body: some View {
        ZStack {
            RootContainerView()

            if showSplash {
                SplashView {
                    withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}
