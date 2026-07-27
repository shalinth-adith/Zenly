//
//  StopBlockingConfirmation.swift
//  Zenly
//
//  Strict-mode override gate: a deliberate 5-second delay plus a streak-loss
//  warning before the user can end a focus session early. The friction is the
//  point — it gives the impulse a moment to pass.
//

import SwiftUI

struct StopBlockingConfirmation: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var secondsRemaining = 5
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text("End focus early?")
                .font(.title2.bold())

            Text("Strict mode is on. Ending now breaks your focus — this session won't count toward your streak.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            // Explicit fill + label colours, deliberately NOT `.borderedProminent`.
            // That style fills with the inherited tint, and the Quiet theme sets
            // `.tint(ZTheme.Palette.textPrimary)` — near-white in dark mode — which
            // rendered a white label on a white button: the confirm action was
            // invisible once the countdown finished.
            Button(action: onConfirm) {
                Text(secondsRemaining > 0 ? "Wait \(secondsRemaining)s…" : "End focus")
                    .frame(maxWidth: .infinity)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.vertical, 15)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(secondsRemaining > 0
                                  ? Color.red.opacity(0.35)   // waiting: visibly muted
                                  : Color.red)                // armed: full strength
                    )
            }
            .buttonStyle(.plain)
            .disabled(secondsRemaining > 0)
            .animation(.easeInOut(duration: 0.2), value: secondsRemaining == 0)
            .accessibilityLabel(secondsRemaining > 0
                                ? "End focus, available in \(secondsRemaining) seconds"
                                : "End focus")

            Button("Keep focusing", action: onCancel)
                .fontWeight(.semibold)
        }
        .padding(32)
        .multilineTextAlignment(.center)
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
        .onReceive(timer) { _ in
            if secondsRemaining > 0 { secondsRemaining -= 1 }
        }
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            StopBlockingConfirmation(onConfirm: {}, onCancel: {})
        }
}
