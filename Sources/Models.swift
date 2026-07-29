import Foundation

struct ShortcutBinding: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt64

    static let hyperSpace = ShortcutBinding(
        keyCode: 49,
        modifiers: (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20)
    )

    var displayName: String {
        let hyperMask: UInt64 = (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20)
        if modifiers & hyperMask == hyperMask && modifiers & ~hyperMask == 0 {
            return "✦\(Self.keyName(for: keyCode))"
        }

        var parts: [String] = []
        if modifiers & (1 << 18) != 0 { parts.append("⌃") }
        if modifiers & (1 << 19) != 0 { parts.append("⌥") }
        if modifiers & (1 << 17) != 0 { parts.append("⇧") }
        if modifiers & (1 << 20) != 0 { parts.append("⌘") }
        parts.append(Self.keyName(for: keyCode))
        return parts.joined()
    }

    static func keyName(for keyCode: UInt16) -> String {
        let names: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z",
            7: "X", 8: "C", 9: "V", 11: "B", 12: "Q", 13: "W",
            14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
            20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9",
            26: "7", 27: "-", 28: "8", 29: "0", 30: "]", 31: "O",
            32: "U", 33: "[", 34: "I", 35: "P", 36: "Return", 37: "L",
            38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",",
            44: "/", 45: "N", 46: "M", 47: ".", 48: "Tab", 49: "Space",
            50: "`", 51: "Delete", 53: "Escape", 65: ".", 67: "*",
            69: "+", 75: "/", 76: "Enter", 78: "-", 81: "=",
            82: "0", 83: "1", 84: "2", 85: "3", 86: "4", 87: "5",
            88: "6", 89: "7", 91: "8", 92: "9", 96: "F5", 97: "F6",
            98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
            109: "F10", 111: "F12", 115: "Home", 116: "Page Up",
            117: "Forward Delete", 119: "End", 121: "Page Down",
            123: "←", 124: "→", 125: "↓", 126: "↑",
        ]
        return names[keyCode] ?? "Key \(keyCode)"
    }
}

struct ButtonMapping: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var actionID: String?
    var shortcut: ShortcutBinding?

    static let microphone = ButtonMapping(
        id: UUID(uuidString: "51CBBD83-D03B-4CCB-AFB4-03055C12041E")!,
        name: "Microphone",
        actionID: "ACT10",
        shortcut: .hyperSpace
    )
}

struct HIDAction: Equatable {
    var id: String
    var pressed: Bool
}

enum HIDPayloadParser {
    static func parse(report: [UInt8]) -> HIDAction? {
        guard let open = report.firstIndex(of: Character("{").asciiValue!) else { return nil }
        var close: Int?
        if report.count >= 3 {
            for index in open..<(report.count - 2)
            where report[index] == Character("}").asciiValue!
                && report[index + 1] == 0x0d
                && report[index + 2] == 0x0a
            {
                close = index
                break
            }
        }
        guard let close else { return nil }

        let json = Data(report[open...close])
        guard let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              object["m"] as? String == "v.oai.hid",
              let payload = object["p"] as? [String: Any],
              let key = payload["k"] as? String,
              key.hasPrefix("ACT"),
              let action = payload["act"] as? Int
        else { return nil }

        return HIDAction(id: key, pressed: action == 1)
    }
}
