import AppKit
import Combine
import SwiftUI

@main
struct CodexMicroMapperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = MapperController()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "Codex Micro Mapper")
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Codex Micro Mapper"
        }

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 440, height: 560)
        popover.contentViewController = NSHostingController(
            rootView: MapperView(controller: controller)
                .preferredColorScheme(.light)
        )

        controller.$isConnected
            .receive(on: RunLoop.main)
            .sink { [weak self] connected in
                self?.statusItem.button?.image = NSImage(
                    systemSymbolName: connected ? "command.square.fill" : "command.square",
                    accessibilityDescription: connected ? "Codex Micro connected" : "Codex Micro disconnected"
                )
            }
            .store(in: &cancellables)
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApplication.shared.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu()
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            controller.refreshPermissions()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        let permissions = NSMenuItem(title: "Permissions", action: nil, keyEquivalent: "")
        permissions.isEnabled = false
        menu.addItem(permissions)

        let input = NSMenuItem(
            title: "Input Monitoring…",
            action: #selector(openInputMonitoring),
            keyEquivalent: ""
        )
        input.target = self
        menu.addItem(input)

        let accessibility = NSMenuItem(
            title: "Accessibility…",
            action: #selector(openAccessibility),
            keyEquivalent: ""
        )
        accessibility.target = self
        menu.addItem(accessibility)

        menu.addItem(.separator())
        let login = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        login.target = self
        login.state = controller.launchAtLogin ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Codex Micro Mapper", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openInputMonitoring() {
        controller.openInputMonitoringSettings()
    }

    @objc private func openAccessibility() {
        controller.openAccessibilitySettings()
    }

    @objc private func toggleLaunchAtLogin() {
        controller.setLaunchAtLogin(!controller.launchAtLogin)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
