//
//  RootContainerView.swift
//  Zenly
//
//  Shows onboarding on first launch, then the main tab bar. The completion flag
//  lives in the App Group so it persists.
//

import SwiftUI

struct RootContainerView: View {
    @AppStorage("hasCompletedOnboarding", store: AppGroup.defaults)
    private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            RootView()
        } else {
            OnboardingView { hasCompletedOnboarding = true }
        }
    }
}
