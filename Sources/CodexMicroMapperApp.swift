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
            button.image = microStatusImage(connected: false)
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
                self?.statusItem.button?.image = self?.microStatusImage(connected: connected)
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

    private func microStatusImage(connected: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { rect in
            NSColor.black.setStroke()
            NSColor.black.setFill()

            let shell = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: 3, yRadius: 3)
            shell.lineWidth = 1.35
            shell.stroke()

            let keySize: CGFloat = 3.0
            for row in 0..<2 {
                for column in 0..<2 {
                    let key = NSRect(
                        x: 4.0 + CGFloat(column) * 5.0,
                        y: 10.0 - CGFloat(row) * 3.8,
                        width: keySize,
                        height: keySize
                    )
                    NSBezierPath(roundedRect: key, xRadius: 0.7, yRadius: 0.7).fill()
                }
            }

            let microphone = NSRect(x: 4.0, y: 2.6, width: 9.8, height: 2.2)
            NSBezierPath(roundedRect: microphone, xRadius: 0.9, yRadius: 0.9).fill()

            if connected {
                NSBezierPath(ovalIn: NSRect(x: 14.0, y: 2.2, width: 1.8, height: 1.8)).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = connected ? "Codex Micro connected" : "Codex Micro disconnected"
        return image
    }
}
