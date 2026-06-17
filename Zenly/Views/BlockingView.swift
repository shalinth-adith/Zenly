//
//  BlockingView.swift
//  Zenly
//
//  Phase 1 screen: grant Screen Time access, choose apps/websites to block,
//  set always-allowed exceptions, toggle strict mode, and start/stop blocking.
//  The polished Home screen (timer ring, streaks) arrives in Phase 2.
//
//  View is "dumb": it owns a BlockingViewModel and only renders / forwards
//  intents. No ManagedSettings / AuthorizationCenter calls live here.
//

import SwiftUI
import FamilyControls

struct BlockingView: View {
    @State private var model: BlockingViewModel
    @State private var isRequestingAuth = false
    @State private var showStopConfirmation = false

    init(authorization: AuthorizationService) {
        _model = State(initialValue: BlockingViewModel(authorization: authorization))
    }

    var body: some View {
        NavigationStack {
            List {
                permissionSection
                if model.authorization.isAuthorized {
                    blocklistSection
                    allowlistSection
                    strictModeSection
                    actionSection
                }
            }
            .navigationTitle("Zenly")
            .familyActivityPicker(isPresented: $model.isBlockPickerPresented,
                                  selection: $model.blockSelection)
            .familyActivityPicker(isPresented: $model.isAllowPickerPresented,
                                  selection: $model.allowSelection)
            .onChange(of: model.blockSelection) { model.persist() }
            .onChange(of: model.allowSelection) { model.persist() }
            .sheet(isPresented: $showStopConfirmation) {
                StopBlockingConfirmation(
                    onConfirm: {
                        showStopConfirmation = false
                        model.stop()
                    },
                    onCancel: { showStopConfirmation = false }
                )
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
                Button(action: requestAuthorization) {
                    HStack {
                        Label("Grant Screen Time Access", systemImage: "hand.raised.fill")
                        if isRequestingAuth {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(isRequestingAuth)

            default:
                EmptyView()
            }
        }
    }

    // MARK: - Blocklist

    private var blocklistSection: some View {
        Section("Blocklist") {
            Button {
                model.isBlockPickerPresented = true
            } label: {
                Label("Choose apps & websites to block",
                      systemImage: "app.badge.checkmark")
            }
            .disabled(model.isBlocking)

            if model.blockCount > 0 {
                Text("^[\(model.blockCount) item](inflect: true) blocked")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Allowlist

    private var allowlistSection: some View {
        Section {
            Button {
                model.isAllowPickerPresented = true
            } label: {
                Label("Always allow these apps", systemImage: "checkmark.shield")
            }
            .disabled(model.isBlocking)

            if model.allowCount > 0 {
                Text("^[\(model.allowCount) app](inflect: true) always allowed")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Allowlist")
        } footer: {
            Text("Allowed apps stay open even when their category is blocked (e.g. Maps, Phone).")
        }
    }

    // MARK: - Strict mode

    private var strictModeSection: some View {
        Section {
            Toggle(isOn: $model.isStrictMode) {
                Label("Strict mode", systemImage: "lock.shield")
            }
            .disabled(model.isBlocking)
        } footer: {
            Text("When on, you must wait 5 seconds and confirm before you can stop a focus session early.")
        }
    }

    // MARK: - Action

    private var actionSection: some View {
        Section {
            Button(action: handlePrimaryAction) {
                Label(model.isBlocking ? "Stop Blocking" : "Block Now",
                      systemImage: model.isBlocking ? "lock.open.fill" : "lock.fill")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isBlocking ? .red : .accentColor)
            .disabled(!model.isBlocking && !model.canBlock)
        } footer: {
            if !model.isBlocking && !model.canBlock {
                Text("Select at least one app or website to start blocking.")
            }
        }
    }

    // MARK: - Intents

    private func handlePrimaryAction() {
        if model.isBlocking {
            if model.isStrictMode {
                showStopConfirmation = true
            } else {
                model.stop()
            }
        } else {
            model.start()
        }
    }

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
