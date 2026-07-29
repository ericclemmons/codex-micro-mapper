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
    @Published var lastLearnedAction: String?
    @Published var message: String?
    @Published var launchAtLogin = false

    private let listener = HIDListener()
    private var localKeyMonitor: Any?
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

        let status = listener.start()
        inputPermissionGranted = status == kIOReturnSuccess
        accessibilityGranted = AXIsProcessTrusted()

        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    deinit {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
        }
    }

    func beginLearning(_ mapping: ButtonMapping) {
        cancelShortcutRecording()
        learningMappingID = mapping.id
        lastLearnedAction = nil
        message = "Press the Codex Micro button you want to map."
    }

    func cancelLearning() {
        learningMappingID = nil
        message = nil
    }

    func beginShortcutRecording(_ mapping: ButtonMapping) {
        cancelLearning()
        cancelShortcutRecording()
        recordingShortcutForID = mapping.id
        message = "Press the keyboard shortcut. Escape cancels; Delete clears."

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            Task { @MainActor in
                self?.record(event)
            }
            return nil
        }
    }

    func cancelShortcutRecording() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
        recordingShortcutForID = nil
        if learningMappingID == nil { message = nil }
    }

    func clearShortcut(_ mapping: ButtonMapping) {
        update(mapping.id) { $0.shortcut = nil }
        message = "Mapping cleared. The button now passes through unchanged."
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
            message = "Learned \(action.id). Now record a keyboard shortcut."
            return
        }

        guard let mapping = mappings.first(where: {
            $0.actionID == action.id && $0.shortcut != nil
        }), let shortcut = mapping.shortcut else { return }

        send(shortcut, pressed: action.pressed)
    }

    private func record(_ event: NSEvent) {
        guard let mappingID = recordingShortcutForID else { return }
        if event.keyCode == 53 {
            cancelShortcutRecording()
            return
        }
        if event.keyCode == 51 || event.keyCode == 117 {
            update(mappingID) { $0.shortcut = nil }
            cancelShortcutRecording()
            message = "Shortcut cleared."
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shortcut = ShortcutBinding(
            keyCode: event.keyCode,
            modifiers: UInt64(flags.rawValue)
        )
        update(mappingID) { $0.shortcut = shortcut }
        cancelShortcutRecording()
        message = "Saved \(shortcut.displayName)."
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
