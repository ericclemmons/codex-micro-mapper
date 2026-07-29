import AppKit
import SwiftUI

struct MapperView: View {
    @ObservedObject var controller: MapperController

    private var microphone: ButtonMapping {
        controller.mappings.first ?? .microphone
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            VStack(spacing: 14) {
                compactStatus
                deviceFace
                instructionCard
            }
            .padding(16)
        }
        .frame(width: 440, height: 560, alignment: .top)
        .background(appBackground)
        .environment(\.colorScheme, .light)
        .onAppear { controller.refreshPermissions() }
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.purple.gradient)
                    .frame(width: 38, height: 38)
                Image(systemName: "command")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Codex Micro Mapper").font(.headline)
                Text(controller.isConnected ? "Micro connected" : "Waiting for Codex Micro")
                    .font(.caption)
                    .foregroundStyle(controller.isConnected ? .green : .secondary)
            }
            Spacer()
            Button { NSApplication.shared.terminate(nil) } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help("Quit Mapper")
        }
        .padding(14)
        .background(appBackground)
    }

    private var compactStatus: some View {
        HStack(spacing: 12) {
            permissionBadge("Input", granted: controller.inputPermissionGranted) {
                controller.openInputMonitoringSettings()
            }
            permissionBadge("Accessibility", granted: controller.accessibilityGranted) {
                controller.requestAccessibility()
                if !controller.accessibilityGranted { controller.openAccessibilitySettings() }
            }
            Spacer()
            Toggle("Login", isOn: Binding(
                get: { controller.launchAtLogin },
                set: controller.setLaunchAtLogin
            ))
            .toggleStyle(.switch)
            .controlSize(.small)
            .help("Launch at login")
        }
        .padding(.horizontal, 4)
    }

    private func permissionBadge(
        _ label: String,
        granted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(label, systemImage: granted ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.caption.weight(.medium))
                .foregroundStyle(granted ? .green : .orange)
        }
        .buttonStyle(.plain)
        .help(granted ? "Permission granted" : "Open System Settings")
    }

    private var deviceFace: some View {
        VStack(spacing: 0) {
            HStack {
                Text("CODEX MICRO")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.68))
                Spacer()
                Circle().fill(.black.opacity(0.7)).frame(width: 7, height: 7)
            }
            .padding(.bottom, 9)

            Grid(horizontalSpacing: 7, verticalSpacing: 7) {
                GridRow {
                    knob
                    agentKey(0, color: .mint)
                    agentKey(1, color: .orange)
                    analogStick
                }
                GridRow {
                    agentKey(2, color: .cyan)
                    agentKey(3, color: .blue)
                    agentKey(4, color: .indigo)
                    agentKey(5, color: .pink)
                }
                GridRow {
                    lockedKey("bolt.fill")
                    lockedKey("checkmark.circle")
                    lockedKey("xmark.circle")
                    lockedKey("arrow.up.right")
                }
                GridRow {
                    statusLights
                    microphoneKey.gridCellColumns(2)
                    lockedKey("brain.head.profile")
                }
            }

            Text("LET'S BUILD")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.black.opacity(0.42))
                .padding(.top, 9)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(white: 0.96), Color(white: 0.79)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 24)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(.white.opacity(0.75), lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.28), radius: 12, y: 6)
    }

    private var knob: some View {
        ZStack {
            Circle().fill(Color(white: 0.76))
            Circle()
                .trim(from: 0.08, to: 0.70)
                .stroke(.black.opacity(0.7), style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(45))
                .padding(9)
        }
        .frame(height: 58)
        .help("Configure the knob in Codex Desktop")
        .blockedCursor()
    }

    private var analogStick: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12).fill(.black.opacity(0.08))
            Circle().fill(Color(white: 0.10)).padding(10)
            Image(systemName: "xmark").foregroundStyle(.gray.opacity(0.6))
        }
        .frame(height: 58)
        .help("Configure the analog stick in Codex Desktop")
        .blockedCursor()
    }

    private func agentKey(_ index: Int, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.62).gradient)
                .shadow(color: color.opacity(0.75), radius: 9)
            RoundedRectangle(cornerRadius: 9)
                .stroke(.white.opacity(0.8), lineWidth: 2)
                .padding(4)
            Circle().fill(.gray.opacity(0.72)).frame(width: 14, height: 14)
        }
        .frame(height: 58)
        .help("Agent key \(index + 1) is managed by Codex Desktop")
        .blockedCursor()
    }

    private func lockedKey(_ icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.black.opacity(0.76))
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(keySurface)
            .help("Configure this key in Codex Desktop")
            .blockedCursor()
    }

    private var statusLights: some View {
        HStack(spacing: 4) {
            VStack(spacing: 4) {
                Circle().fill(.blue).frame(width: 5, height: 5)
                Circle().fill(.yellow).frame(width: 5, height: 5)
                Circle().fill(.green).frame(width: 5, height: 5)
            }
            Circle().fill(.black.opacity(0.82)).frame(width: 25, height: 25)
        }
        .frame(maxWidth: .infinity, minHeight: 54)
        .help("Device status")
        .blockedCursor()
    }

    private var microphoneKey: some View {
        Button {
            if controller.selectedMappingID == microphone.id {
                controller.cancelEditing()
            } else {
                controller.beginMapping(microphone)
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 21, weight: .medium))
                Text(microphoneLabel)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.black.opacity(0.82))
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                controller.selectedMappingID == microphone.id
                    ? AnyShapeStyle(Color.purple.opacity(0.42).gradient)
                    : AnyShapeStyle(keySurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(controller.selectedMappingID == microphone.id ? .purple : .white.opacity(0.8), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .pointingCursor()
        .help("Click to change the microphone shortcut")
    }

    private var microphoneLabel: String {
        if controller.recordingShortcutForID == microphone.id { return "PRESS SHORTCUT" }
        if controller.confirmingMappingID == microphone.id { return "PRESS MIC TO SAVE" }
        return microphone.shortcut?.displayName ?? "PASS-THROUGH"
    }

    private var instructionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: instructionIcon)
                    .font(.title3)
                    .foregroundStyle(.purple)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(instructionTitle).font(.subheadline.weight(.semibold))
                    Text(instructionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if controller.selectedMappingID == microphone.id {
                HStack {
                    if microphone.shortcut != nil {
                        Button("Clear mapping") { controller.clearShortcut(microphone) }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                    }
                    Spacer()
                    Button("Cancel") { controller.cancelEditing() }
                }
                .font(.caption)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(appBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.08)))
    }

    private var instructionIcon: String {
        if controller.recordingShortcutForID != nil { return "keyboard" }
        if controller.confirmingMappingID != nil { return "mic.badge.plus" }
        if controller.message != nil { return "checkmark.circle.fill" }
        return "hand.tap"
    }

    private var instructionTitle: String {
        if controller.recordingShortcutForID != nil { return "Record a shortcut" }
        if controller.confirmingMappingID != nil { return "Confirm on the Micro" }
        if controller.message != nil { return "Mapping updated" }
        return "Click the microphone key"
    }

    private var instructionText: String {
        controller.message ?? "Then press a keyboard shortcut and press the physical Mic button to save."
    }

    private var keySurface: some ShapeStyle {
        LinearGradient(
            colors: [.white, Color(white: 0.82)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var appBackground: Color {
        Color(red: 245.0 / 255.0, green: 245.0 / 255.0, blue: 245.0 / 255.0)
    }
}

private extension View {
    func pointingCursor() -> some View {
        onHover { hovering in
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
    }

    func blockedCursor() -> some View {
        onHover { hovering in
            if hovering { NSCursor.operationNotAllowed.push() } else { NSCursor.pop() }
        }
    }
}
