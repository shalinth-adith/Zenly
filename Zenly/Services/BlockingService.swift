//
//  BlockingService.swift
//  Zenly
//
//  Applies and clears app/category/website shields via the named
//  ManagedSettingsStore. Setting a shield is effectively instant: the next time
//  the user launches a shielded app, iOS shows Zenly's shield instead.
//

import Foundation
import FamilyControls
import ManagedSettings

@MainActor
final class BlockingService {
    private let store = ManagedSettingsStore(named: .zenly)

    /// Shield everything in `block`, honoring `allow` as exceptions, for instant
    /// (in-app) blocking. Schedule-driven blocking applies the same shields from
    /// the extension via the shared ShieldApplier.
    func startBlocking(_ block: FamilyActivitySelection,
                       allowing allow: FamilyActivitySelection = FamilyActivitySelection(),
                       blockAll: Bool = false) {
        ShieldApplier.apply(block: block, allow: allow, blockAll: blockAll, to: store)
    }

    /// Remove every shield this store applied.
    func stopBlocking() {
        ShieldApplier.clear(store)
    }
}
