import Foundation

/// Thrown when the user cancels a prompt. The process exits with code 130, like fzf.
struct Cancelled: Error {}

struct UserError: Error, CustomStringConvertible {
    let description: String

    init(_ description: String) {
        self.description = description
    }
}

enum Terminal {
    static let outputIsTTY = isatty(STDOUT_FILENO) == 1
    static let isInteractive = outputIsTTY && isatty(STDIN_FILENO) == 1

    static var size: (columns: Int, rows: Int) {
        var size = winsize()
        guard ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0, size.ws_col > 0 else {
            return (80, 24)
        }
        return (Int(size.ws_col), Int(size.ws_row))
    }

    static func write(_ text: String) {
        print(text, terminator: "")
        fflush(nil)
    }

    static func prompt(_ message: String, default value: String? = nil) throws -> String {
        let suffix = value.map { Style.dim(" (\($0))") } ?? ""
        write("\(Style.cyan("?")) \(Style.bold(message))\(suffix) ")
        guard let line = readLine() else { throw Cancelled() }
        let answer = line.trimmingCharacters(in: .whitespaces)
        return answer.isEmpty ? value ?? "" : answer
    }

    static func confirm(_ message: String, default value: Bool = false) -> Bool {
        let hint = value ? "Y/n" : "y/N"
        write("\(Style.cyan("?")) \(Style.bold(message)) \(Style.dim("(\(hint))")) ")
        guard let line = readLine()?.trimmingCharacters(in: .whitespaces).lowercased(),
              !line.isEmpty
        else { return value }
        return line == "y" || line == "yes"
    }
}

enum Style {
    static let isEnabled = Terminal.outputIsTTY && ProcessInfo.processInfo.environment["NO_COLOR"] == nil

    static func bold(_ text: String) -> String { wrap(text, "1") }
    static func dim(_ text: String) -> String { wrap(text, "2") }
    static func red(_ text: String) -> String { wrap(text, "31") }
    static func green(_ text: String) -> String { wrap(text, "32") }
    static func yellow(_ text: String) -> String { wrap(text, "33") }
    static func cyan(_ text: String) -> String { wrap(text, "36") }

    private static func wrap(_ text: String, _ code: String) -> String {
        isEnabled ? "\u{1B}[\(code)m\(text)\u{1B}[0m" : text
    }
}

enum Output {
    static func success(_ message: String) {
        print("\(Style.green("✔")) \(message)")
    }

    static func info(_ message: String) {
        print("\(Style.cyan("ℹ")) \(message)")
    }

    static func error(_ message: String) {
        FileHandle.standardError.write(Data("\(Style.red("✖")) \(message)\n".utf8))
    }

    /// Shows a transient status line while slow simctl work runs.
    static func step<T>(_ message: String, _ work: () throws -> T) rethrows -> T {
        guard Terminal.outputIsTTY else { return try work() }
        Terminal.write("\(Style.dim("…")) \(message)")
        defer { Terminal.write("\r\u{1B}[K") }
        return try work()
    }
}
