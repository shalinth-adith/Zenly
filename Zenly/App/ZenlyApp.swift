//
//  ZenlyApp.swift
//  Zenly
//
//  App entry point. Owns the single AuthorizationService instance and injects
//  it into the view tree (MVVM dependency injection from the composition root).
//

import SwiftUI

@main
struct ZenlyApp: App {
    @State private var authorization = AuthorizationService()

    var body: some Scene {
        WindowGroup {
            ContentView(authorization: authorization)
        }
    }
}
