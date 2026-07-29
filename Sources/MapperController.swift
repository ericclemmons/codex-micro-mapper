import AppKit
import ApplicationServices
import Combine
import Foundation
import IOKit.hid
import ServiceManagement

@MainActor
final class MapperController: ObservableObject {
    @Published var isConnected = false
    @Published var inputPermissionGranted = false
    @Published var accessibilityGranted = AXIsProcessTrusted()
    @Published var mappings: [ButtonMapping]
    @Published var learningMappingID: UUID?
    @Published var recordingShortcutForID: UUID?
    @Published var confirmingMappingID: UUID?
    @Published var pendingShortcut: ShortcutBinding?
    @Published var selectedMappingID: UUID?
    @Published var lastLearnedAction: String?
    @Published var message: String?
    @Published var launchAtLogin = false

    private let listener = HIDListener()
    private let shortcutCapture = ShortcutCapture()
    private let mappingsKey = "buttonMappings.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: mappingsKey),
           let saved = try? JSONDecoder().decode([ButtonMapping].self, from: data),
           !saved.isEmpty
        {
            mappings = saved
        } else {
            mappings = [.microphone]
        }

        listener.onConnectionChanged = { [weak self] connected in
            Task { @MainActor in
                self?.isConnected = connected
            }
        }
        listener.onAction = { [weak self] action in
            Task { @MainActor in
                self?.handle(action)
            }
        }
        shortcutCapture.onShortcut = { [weak self] shortcut in
            Task { @MainActor in
                self?.captured(shortcut)
            }
        }
        shortcutCapture.onCancel = { [weak self] in
            Task { @MainActor in
                self?.cancelEditing()
            }
        }

        let status = listener.start()
        inputPermissionGranted = status == kIOReturnSuccess
        accessibilityGranted = AXIsProcessTrusted()

        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    func beginMapping(_ mapping: ButtonMapping) {
        cancelEditing()
        selectedMappingID = mapping.id
        if mapping.actionID != nil {
            beginShortcutRecording(mapping)
            return
        }
        learningMappingID = mapping.id
        message = "Press this button on the Codex Micro."
    }

    func cancelLearning() {
        learningMappingID = nil
        if recordingShortcutForID == nil && confirmingMappingID == nil { message = nil }
    }

    func beginShortcutRecording(_ mapping: ButtonMapping) {
        shortcutCapture.stop()
        learningMappingID = nil
        recordingShortcutForID = mapping.id
        selectedMappingID = mapping.id
        confirmingMappingID = nil
        pendingShortcut = nil
        message = "Press the keyboard shortcut you want to assign."
        if !shortcutCapture.start() {
            recordingShortcutForID = nil
            message = "Shortcut capture needs Accessibility permission."
        }
    }

    func cancelShortcutRecording() {
        shortcutCapture.stop()
        recordingShortcutForID = nil
        if learningMappingID == nil && confirmingMappingID == nil { message = nil }
    }

    func cancelEditing() {
        shortcutCapture.stop()
        learningMappingID = nil
        recordingShortcutForID = nil
        confirmingMappingID = nil
        pendingShortcut = nil
        selectedMappingID = nil
        message = nil
    }

    func clearShortcut(_ mapping: ButtonMapping) {
        update(mapping.id) { $0.shortcut = nil }
        cancelEditing()
        message = "Cleared. This button now passes through to Codex."
    }

    func addMapping() {
        let number = mappings.count + 1
        mappings.append(ButtonMapping(
            id: UUID(),
            name: "Custom button \(number)",
            actionID: nil,
            shortcut: nil
        ))
        save()
    }

    func removeMapping(_ mapping: ButtonMapping) {
        guard mappings.count > 1 else { return }
        mappings.removeAll { $0.id == mapping.id }
        save()
    }

    func rename(_ mapping: ButtonMapping, to name: String) {
        update(mapping.id) { $0.name = name.isEmpty ? "Custom button" : name }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        accessibilityGranted = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func openInputMonitoringSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!)
    }

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func refreshPermissions() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            message = "Could not update launch at login: \(error.localizedDescription)"
        }
    }

    private func handle(_ action: HIDAction) {
        if let mappingID = learningMappingID, action.pressed {
            for index in mappings.indices
            where mappings[index].id != mappingID && mappings[index].actionID == action.id
            {
                mappings[index].actionID = nil
            }
            update(mappingID) { $0.actionID = action.id }
            lastLearnedAction = action.id
            learningMappingID = nil
            if let mapping = mappings.first(where: { $0.id == mappingID }) {
                beginShortcutRecording(mapping)
            }
            return
        }

        if let mappingID = confirmingMappingID,
           let mapping = mappings.first(where: { $0.id == mappingID }),
           mapping.actionID == action.id,
           action.pressed,
           let shortcut = pendingShortcut
        {
            update(mappingID) { $0.shortcut = shortcut }
            cancelEditing()
            message = "Saved \(shortcut.displayName)."
            return
        }

        if selectedMappingID != nil { return }

        guard let mapping = mappings.first(where: {
            $0.actionID == action.id && $0.shortcut != nil
        }), let shortcut = mapping.shortcut else { return }

        send(shortcut, pressed: action.pressed)
    }

    private func captured(_ shortcut: ShortcutBinding) {
        guard let mappingID = recordingShortcutForID else { return }
        recordingShortcutForID = nil
        pendingShortcut = shortcut
        confirmingMappingID = mappingID
        message = "\(shortcut.displayName) captured. Press the physical Micro button to save."
    }

    private func send(_ shortcut: ShortcutBinding, pressed: Bool) {
        accessibilityGranted = AXIsProcessTrusted()
        guard let event = CGEvent(
            keyboardEventSource: nil,
            virtualKey: CGKeyCode(shortcut.keyCode),
            keyDown: pressed
        ) else { return }
        event.flags = CGEventFlags(rawValue: shortcut.modifiers)
        event.post(tap: .cghidEventTap)
    }

    private func update(_ id: UUID, change: (inout ButtonMapping) -> Void) {
        guard let index = mappings.firstIndex(where: { $0.id == id }) else { return }
        change(&mappings[index])
        save()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(mappings) else { return }
        UserDefaults.standard.set(data, forKey: mappingsKey)
    }
}
