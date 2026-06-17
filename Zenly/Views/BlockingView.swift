//
//  BlockingView.swift
//  Zenly
//
//  Phase 1 plumbing screen: request Screen Time access, pick apps/websites to
//  block, and toggle blocking on/off. Deliberately minimal — this proves the
//  picker → ManagedSettings shield path end-to-end. The polished Home screen
//  (timer ring, streaks) comes in Phase 2.
//
//  View is "dumb": it owns a BlockingViewModel and only renders / forwards
//  intents to it. No ManagedSettings / AuthorizationCenter calls live here.
//

import SwiftUI
import FamilyControls

struct BlockingView: View {
    @State private var model: BlockingViewModel
    @State private var isRequestingAuth = false

    init(authorization: AuthorizationService) {
        _model = State(initialValue: BlockingViewModel(authorization: authorization))
    }

    var body: some View {
        NavigationStack {
            List {
                permissionSection
                if model.authorization.isAuthorized {
                    blocklistSection
                    actionSection
                }
            }
            .navigationTitle("Zenly")
            .familyActivityPicker(isPresented: $model.isPickerPresented,
                                  selection: $model.selection)
            .onChange(of: model.selection) {
                model.persistSelection()
            }
        }
    }

    // MARK: - Permission

    @ViewBuilder
    private var permissionSection: some View {
        Section("Screen Time Permission") {
            switch model.authorization.status {
            case .approved:
                Label("Access granted", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)

            case .denied:
                VStack(alignment: .leading, spacing: 8) {
                    Label("Access denied", systemImage: "xmark.seal.fill")
                        .foregroundStyle(.red)
                    Text("Enable Screen Time access for Zenly in Settings to block apps.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

            case .notDetermined:
                Button {
                    requestAuthorization()
                } label: {
                    HStack {
                        Label("Grant Screen Time Access", systemImage: "hand.raised.fill")
                        if isRequestingAuth {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRequestingAuth)

            @unknown default:
                EmptyView()
            }
        }
    }

    // MARK: - Blocklist

    private var blocklistSection: some View {
        Section("Blocklist") {
            Button {
                model.isPickerPresented = true
            } label: {
                Label("Choose apps & websites to block",
                      systemImage: "app.badge.checkmark")
            }
            if model.selectionCount > 0 {
                Text("^[\(model.selectionCount) item](inflect: true) selected")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Action

    private var actionSection: some View {
        Section {
            Button {
                model.toggleBlocking()
            } label: {
                Label(model.isBlocking ? "Stop Blocking" : "Block Now",
                      systemImage: model.isBlocking ? "lock.open.fill" : "lock.fill")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isBlocking ? .red : .accentColor)
            .disabled(!model.canBlock)
        } footer: {
            if !model.isBlocking && !model.canBlock {
                Text("Select at least one app or website to start blocking.")
            }
        }
    }

    // MARK: - Intents

    private func requestAuthorization() {
        isRequestingAuth = true
        Task {
            await model.requestAuthorization()
            isRequestingAuth = false
        }
    }
}

#Preview {
    BlockingView(authorization: AuthorizationService())
}
