import SwiftUI

struct MapperView: View {
    @ObservedObject var controller: MapperController

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 16) {
                    statusCard
                    deviceCard
                    mappingsCard
                    footer
                }
                .padding(16)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { controller.refreshPermissions() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.purple.gradient)
                    .frame(width: 40, height: 40)
                Image(systemName: "command")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Micro Mapper")
                    .font(.headline)
                Text(controller.isConnected ? "Micro connected" : "Waiting for Codex Micro")
                    .font(.caption)
                    .foregroundStyle(controller.isConnected ? .green : .secondary)
            }
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.plain)
            .help("Quit Mapper")
        }
        .padding(16)
        .background(.bar)
    }

    private var statusCard: some View {
        VStack(spacing: 10) {
            permissionRow(
                title: "Input Monitoring",
                granted: controller.inputPermissionGranted,
                action: controller.openInputMonitoringSettings
            )
            Divider()
            permissionRow(
                title: "Accessibility",
                granted: controller.accessibilityGranted,
                action: {
                    controller.requestAccessibility()
                    if !controller.accessibilityGranted {
                        controller.openAccessibilitySettings()
                    }
                }
            )
            Divider()
            Toggle("Launch at login", isOn: Binding(
                get: { controller.launchAtLogin },
                set: controller.setLaunchAtLogin
            ))
            .toggleStyle(.switch)
        }
        .padding(14)
        .background(cardBackground)
    }

    private func permissionRow(
        title: String,
        granted: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.medium))
                Text(granted ? "Granted" : "Required")
                    .font(.caption)
                    .foregroundStyle(granted ? .green : .orange)
            }
            Spacer()
            if !granted {
                Button("Open Settings", action: action)
                    .controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }

    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Codex Micro")
                    .font(.headline)
                Spacer()
                Text("Top keys are Codex-managed")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 7) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 7), count: 3), spacing: 7) {
                    ForEach(0..<6) { index in
                        lockedKey(index)
                    }
                }
                HStack(spacing: 7) {
                    deviceKey("⚡︎", subtitle: "Codex")
                    deviceKey("✓", subtitle: "Codex")
                    deviceKey("×", subtitle: "Codex")
                    deviceKey("↗", subtitle: "Codex")
                }
                HStack(spacing: 7) {
                    deviceKey("◉", subtitle: "Knob")
                    deviceKey("Mic", subtitle: mappingSummary, accent: true)
                        .frame(maxWidth: .infinity)
                    deviceKey("◌", subtitle: "Codex")
                }
            }
            .padding(12)
            .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(14)
        .background(cardBackground)
    }

    private func lockedKey(_ index: Int) -> some View {
        Button {
            controller.message = "Configure illuminated agent key \(index + 1) in Codex Desktop."
        } label: {
            VStack(spacing: 4) {
                Circle().fill(index < 2 ? .green : .gray.opacity(0.65)).frame(width: 8, height: 8)
                Text("Agent \(index + 1)").font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(DeviceButtonStyle())
    }

    private func deviceKey(
        _ title: String,
        subtitle: String,
        accent: Bool = false
    ) -> some View {
        VStack(spacing: 3) {
            Text(title).font(.caption.weight(.semibold))
            Text(subtitle).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 42)
        .background(
            accent ? Color.purple.opacity(0.32) : Color.white.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(accent ? Color.purple.opacity(0.8) : Color.white.opacity(0.08))
        )
    }

    private var mappingSummary: String {
        controller.mappings.first?.shortcut?.displayName ?? "Pass-through"
    }

    private var mappingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Button mappings").font(.headline)
                    Text("Learn a Micro event, then record its shortcut.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    controller.addMapping()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ForEach(controller.mappings) { mapping in
                MappingRow(mapping: mapping, controller: controller)
                if mapping.id != controller.mappings.last?.id { Divider() }
            }

            if let message = controller.message {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: controller.learningMappingID == nil ? "info.circle.fill" : "dot.radiowaves.left.and.right")
                        .foregroundStyle(controller.learningMappingID == nil ? .purple : .orange)
                    Text(message)
                        .font(.caption)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
                .padding(10)
                .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
            }
        }
        .padding(14)
        .background(cardBackground)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            Text("Custom shortcuts do not suppress Codex actions.")
                .font(.caption.weight(.medium))
            Text("Set the corresponding key to Unassigned in Codex before mapping it here.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 4)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(nsColor: .controlBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.primary.opacity(0.08)))
    }
}

private struct MappingRow: View {
    let mapping: ButtonMapping
    @ObservedObject var controller: MapperController
    @State private var editingName = false
    @State private var draftName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if editingName {
                    TextField("Mapping name", text: $draftName, onCommit: saveName)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Button {
                        draftName = mapping.name
                        editingName = true
                    } label: {
                        HStack(spacing: 5) {
                            Text(mapping.name).font(.subheadline.weight(.semibold))
                            Image(systemName: "pencil").font(.caption2)
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if controller.mappings.count > 1 {
                    Button(role: .destructive) {
                        controller.removeMapping(mapping)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 8) {
                Button {
                    if controller.learningMappingID == mapping.id {
                        controller.cancelLearning()
                    } else {
                        controller.beginLearning(mapping)
                    }
                } label: {
                    Label(
                        controller.learningMappingID == mapping.id ? "Listening…" : (mapping.actionID ?? "Learn button"),
                        systemImage: controller.learningMappingID == mapping.id ? "wave.3.right" : "scope"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(controller.learningMappingID == mapping.id ? .orange : .purple)

                Button {
                    controller.beginShortcutRecording(mapping)
                } label: {
                    Label(
                        controller.recordingShortcutForID == mapping.id ? "Press keys…" : (mapping.shortcut?.displayName ?? "Pass-through"),
                        systemImage: "keyboard"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .disabled(mapping.actionID == nil)
            }

            if mapping.shortcut != nil {
                Button("Clear shortcut") {
                    controller.clearShortcut(mapping)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func saveName() {
        controller.rename(mapping, to: draftName)
        editingName = false
    }
}

private struct DeviceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Color.white.opacity(configuration.isPressed ? 0.14 : 0.07),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08)))
    }
}
