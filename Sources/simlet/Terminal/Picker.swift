import Foundation

/// An arrow-key list picker. Typing filters the list.
struct Picker<Item> {
    let title: String
    let items: [Item]
    let label: (Item) -> String

    func choose() throws -> Item {
        guard !items.isEmpty, var rawMode = RawMode() else { throw Cancelled() }
        defer { rawMode.restore() }

        Terminal.write("\u{1B}[?25l")
        defer { Terminal.write("\u{1B}[?25h") }

        var query = ""
        var selected = 0
        var offset = 0
        var drawnLines = 0

        while true {
            let matches = filtered(by: query)
            let pageSize = max(3, min(12, Terminal.size.rows - 4))
            selected = min(selected, max(matches.count - 1, 0))
            offset = min(offset, selected)
            offset = max(offset, selected - pageSize + 1)

            erase(drawnLines)
            drawnLines = draw(matches, query: query, selected: selected, offset: offset, pageSize: pageSize)

            switch Key.read() {
            case .up:
                selected = max(selected - 1, 0)
            case .down:
                selected = min(selected + 1, max(matches.count - 1, 0))
            case .pageUp:
                selected = max(selected - pageSize, 0)
            case .pageDown:
                selected = min(selected + pageSize, max(matches.count - 1, 0))
            case .backspace:
                if !query.isEmpty {
                    query.removeLast()
                    selected = 0
                }
            case let .character(character):
                query.append(character)
                selected = 0
            case .enter:
                guard !matches.isEmpty else { continue }
                let choice = matches[selected]
                erase(drawnLines)
                Terminal.write("\(Style.green("✔")) \(Style.bold(title)) \(Style.cyan(choice.label))\n")
                return choice.item
            case .cancel:
                erase(drawnLines)
                throw Cancelled()
            case .other:
                continue
            }
        }
    }

    private func filtered(by query: String) -> [(item: Item, label: String)] {
        let terms = query.lowercased().split(separator: " ")
        return items.map { ($0, label($0)) }.filter { _, label in
            let label = label.lowercased()
            return terms.allSatisfy { label.contains($0) }
        }
    }

    private func draw(
        _ matches: [(item: Item, label: String)], query: String, selected: Int, offset: Int, pageSize: Int
    ) -> Int {
        let width = Terminal.size.columns - 3
        let filter = query.isEmpty ? Style.dim("type to filter") : query
        var lines = ["\(Style.cyan("?")) \(Style.bold(title)) \(filter)"]

        if matches.isEmpty {
            lines.append(Style.dim("  No matches"))
        }
        for index in matches.indices.dropFirst(offset).prefix(pageSize) {
            let text = String(matches[index].label.prefix(width))
            lines.append(index == selected ? Style.cyan("❯ \(text)") : "  \(text)")
        }

        var footer = "↑↓ move · enter select · esc cancel"
        if matches.count > pageSize {
            footer += " · \(selected + 1)/\(matches.count)"
        }
        lines.append(Style.dim(String(footer.prefix(width))))

        Terminal.write(lines.map { $0 + "\n" }.joined())
        return lines.count
    }

    private func erase(_ lineCount: Int) {
        guard lineCount > 0 else { return }
        Terminal.write("\u{1B}[\(lineCount)A\r\u{1B}[J")
    }
}

private enum Key {
    case up, down, pageUp, pageDown, enter, cancel, backspace, other
    case character(Character)

    static func read() -> Key {
        guard let byte = readByte() else { return .cancel }
        switch byte {
        case 0x0D, 0x0A: return .enter
        case 0x03, 0x04: return .cancel
        case 0x7F, 0x08: return .backspace
        case 0x10: return .up
        case 0x0E: return .down
        case 0x1B: return readEscapeSequence()
        case 0x20...0x7E: return .character(Character(UnicodeScalar(byte)))
        default: return .other
        }
    }

    /// A lone Esc means cancel. Arrow keys arrive as `Esc [ A` and similar.
    private static func readEscapeSequence() -> Key {
        guard let bracket = readByte(timeout: 30) else { return .cancel }
        guard bracket == 0x5B || bracket == 0x4F, let code = readByte(timeout: 30) else { return .other }
        switch code {
        case 0x41: return .up
        case 0x42: return .down
        case 0x35: _ = readByte(timeout: 30); return .pageUp
        case 0x36: _ = readByte(timeout: 30); return .pageDown
        default: return .other
        }
    }

    private static func readByte(timeout milliseconds: Int32? = nil) -> UInt8? {
        if let milliseconds {
            var descriptor = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
            guard poll(&descriptor, 1, milliseconds) > 0 else { return nil }
        }
        var byte: UInt8 = 0
        return Darwin.read(STDIN_FILENO, &byte, 1) == 1 ? byte : nil
    }
}

private struct RawMode {
    private var original = termios()

    init?() {
        guard tcgetattr(STDIN_FILENO, &original) == 0 else { return nil }
        var raw = original
        raw.c_lflag &= ~tcflag_t(ICANON | ECHO | ISIG | IEXTEN)
        raw.c_iflag &= ~tcflag_t(IXON | ICRNL)
        withUnsafeMutableBytes(of: &raw.c_cc) { controlCharacters in
            controlCharacters[Int(VMIN)] = 1
            controlCharacters[Int(VTIME)] = 0
        }
        guard tcsetattr(STDIN_FILENO, TCSANOW, &raw) == 0 else { return nil }
    }

    mutating func restore() {
        tcsetattr(STDIN_FILENO, TCSANOW, &original)
    }
}
