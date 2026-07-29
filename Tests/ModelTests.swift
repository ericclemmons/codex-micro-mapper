import Foundation

@main
enum ModelTests {
    static func main() {
        let press = [0x06, 0x02, 0x2d] + Array(#"{"m":"v.oai.hid","p":{"k":"ACT10","act":1}}"#.utf8) + [0x0d, 0x0a, 0x7d]
        precondition(HIDPayloadParser.parse(report: press) == HIDAction(id: "ACT10", pressed: true))

        let release = [0x06, 0x02, 0x2d] + Array(#"{"m":"v.oai.hid","p":{"k":"ACT10","act":0}}"#.utf8) + [0x0d, 0x0a]
        precondition(HIDPayloadParser.parse(report: release) == HIDAction(id: "ACT10", pressed: false))

        let unrelated = Array(#"{"m":"other","p":{"k":"ACT10","act":1}}"#.utf8)
        precondition(HIDPayloadParser.parse(report: unrelated) == nil)

        precondition(ShortcutBinding.hyperSpace.displayName == "✦Space")

        let controlA = ShortcutBinding(keyCode: 0, modifiers: 1 << 18)
        precondition(controlA.displayName == "⌃A")

        let raycastHyperSpace = ShortcutBinding(
            keyCode: 49,
            modifiers: (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20)
        )
        precondition(raycastHyperSpace.displayName == "✦Space")

        print("Model tests passed")
    }
}
