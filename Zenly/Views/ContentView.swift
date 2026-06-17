//
//  ContentView.swift
//  Zenly
//
//  Root view. For Phase 1 it simply hosts the blocking screen; in later phases
//  this becomes the tab bar (Home / Analytics / Profiles / Settings).
//

import SwiftUI

struct ContentView: View {
    let authorization: AuthorizationService

    var body: some View {
        BlockingView(authorization: authorization)
    }
}

#Preview {
    ContentView(authorization: AuthorizationService())
}
