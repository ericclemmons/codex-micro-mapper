import SwiftUI

@main
struct CodexMicroMapperApp: App {
    @StateObject private var controller = MapperController()

    var body: some Scene {
        MenuBarExtra {
            MapperView(controller: controller)
                .frame(width: 420, height: 650)
        } label: {
            Label(
                "Codex Micro Mapper",
                systemImage: controller.isConnected ? "command.square.fill" : "command.square"
            )
        }
        .menuBarExtraStyle(.window)
    }
}
