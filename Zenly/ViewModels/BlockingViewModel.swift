//
//  BlockingViewModel.swift
//  Zenly
//
//  Phase 1 view model: owns the block + allow selections, authorization, strict
//  mode, and the manual block toggle. Schedules / Pomodoro / profiles arrive in
//  Phase 2. The view talks only to this; it never touches ManagedSettings.
//

import Foundation
import FamilyControls
import Observation

@Observable
@MainActor
final class BlockingViewModel {
    var blockSelection: FamilyActivitySelection
    var allowSelection: FamilyActivitySelection
    var isStrictMode: Bool {
        didSet { FocusSettings.isStrictMode = isStrictMode }
    }

    var isBlocking: Bool = false
    var isBlockPickerPresented: Bool = false
    var isAllowPickerPresented: Bool = false

    let authorization: AuthorizationService
    private let blocking = BlockingService()

    init(authorization: AuthorizationService) {
        self.authorization = authorization
        self.blockSelection = SelectionStore.load(.block)
        self.allowSelection = SelectionStore.load(.allow)
        self.isStrictMode = FocusSettings.isStrictMode
    }

    /// Number of apps + categories + website domains in the blocklist.
    var blockCount: Int {
        blockSelection.applicationTokens.count
            + blockSelection.categoryTokens.count
            + blockSelection.webDomainTokens.count
    }

    /// Number of always-allowed apps.
    var allowCount: Int {
        allowSelection.applicationTokens.count
    }

    var canBlock: Bool {
        authorization.isAuthorized && blockCount > 0
    }

    func requestAuthorization() async {
        await authorization.requestAuthorization()
    }

    func persist() {
        SelectionStore.save(blockSelection, for: .block)
        SelectionStore.save(allowSelection, for: .allow)
    }

    func start() {
        persist()
        blocking.startBlocking(blockSelection, allowing: allowSelection)
        isBlocking = true
    }

    func stop() {
        blocking.stopBlocking()
        isBlocking = false
    }
}
