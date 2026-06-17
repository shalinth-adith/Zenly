//
//  BlockingViewModel.swift
//  Zenly
//
//  Phase 1 plumbing view model: owns the current selection, authorization, and
//  the manual block toggle. Schedules / Pomodoro / profiles arrive in Phase 2.
//

import Foundation
import FamilyControls
import Observation

@Observable
@MainActor
final class BlockingViewModel {
    var selection: FamilyActivitySelection
    var isBlocking: Bool = false
    var isPickerPresented: Bool = false

    let authorization: AuthorizationService
    private let blocking = BlockingService()

    init(authorization: AuthorizationService) {
        self.authorization = authorization
        self.selection = SelectionStore.load()
    }

    /// Total number of selected apps + categories + website domains.
    var selectionCount: Int {
        selection.applicationTokens.count
            + selection.categoryTokens.count
            + selection.webDomainTokens.count
    }

    var canBlock: Bool {
        authorization.isAuthorized && selectionCount > 0
    }

    func requestAuthorization() async {
        await authorization.requestAuthorization()
    }

    func persistSelection() {
        SelectionStore.save(selection)
    }

    func toggleBlocking() {
        if isBlocking {
            blocking.stopBlocking()
            isBlocking = false
        } else {
            persistSelection()
            blocking.startBlocking(selection)
            isBlocking = true
        }
    }
}
