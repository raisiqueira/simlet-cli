import Foundation

public enum LookupError: Error, Equatable, CustomStringConvertible {
    case notFound(kind: String, query: String, hint: String)
    case ambiguous(kind: String, query: String, candidates: [String])
    case noBootedDevice

    public var description: String {
        switch self {
        case let .notFound(kind, query, hint):
            return "No \(kind) matches \"\(query)\". \(hint)"
        case let .ambiguous(kind, query, candidates):
            let list = candidates.map { "  \($0)" }.joined(separator: "\n")
            return "\"\(query)\" matches \(candidates.count) \(kind)s. Be more specific:\n\(list)"
        case .noBootedDevice:
            return "No simulator is booted."
        }
    }
}

extension Inventory {
    /// Accepts a UDID, a UDID prefix, a full or partial name, or `booted`.
    public func device(matching query: String) throws -> Device {
        let needle = normalized(query)
        let matches: [Device]
        if needle == "booted" {
            matches = devices.filter(\.isBooted)
            guard !matches.isEmpty else { throw LookupError.noBootedDevice }
        } else {
            matches = firstMatching(devices, rules: [
                { $0.udid.lowercased() == needle },
                { $0.name.lowercased() == needle },
                { $0.udid.lowercased().hasPrefix(needle) },
                { $0.name.lowercased().contains(needle) },
            ])
        }
        return try unique(matches, kind: "simulator", query: query,
                          hint: "Run `simlet list` to see all simulators.") {
            "\($0.name) (\(osName(for: $0)))  \($0.udid)"
        }
    }

    /// Accepts an identifier, a full or partial name.
    public func deviceType(matching query: String) throws -> DeviceType {
        let needle = normalized(query)
        let matches = firstMatching(deviceTypes, rules: [
            { $0.identifier.lowercased() == needle },
            { $0.name.lowercased() == needle },
            { $0.name.lowercased().contains(needle) },
        ])
        return try unique(matches, kind: "device type", query: query,
                          hint: "Run `simlet types` to see all device types.") { $0.name }
    }

    /// Accepts an identifier, a name such as `iOS 18.2`, or a version.
    /// A partial name such as `iOS` selects the newest match.
    public func runtime(matching query: String) throws -> Runtime {
        let needle = normalized(query)
        let matches = firstMatching(availableRuntimes, rules: [
            { $0.identifier.lowercased() == needle },
            { $0.name.lowercased() == needle },
            { $0.version == needle },
            { $0.name.lowercased().contains(needle) },
        ])
        guard let newest = matches.max(by: Runtime.isOlder) else {
            throw LookupError.notFound(kind: "runtime", query: query,
                                       hint: "Run `simlet runtimes` to see installed runtimes.")
        }
        return newest
    }

    private func normalized(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespaces).lowercased()
    }

    private func firstMatching<T>(_ items: [T], rules: [(T) -> Bool]) -> [T] {
        for rule in rules {
            let matches = items.filter(rule)
            if !matches.isEmpty { return matches }
        }
        return []
    }

    private func unique<T>(
        _ matches: [T], kind: String, query: String, hint: String, label: (T) -> String
    ) throws -> T {
        switch matches.count {
        case 0: throw LookupError.notFound(kind: kind, query: query, hint: hint)
        case 1: return matches[0]
        default: throw LookupError.ambiguous(kind: kind, query: query, candidates: matches.map(label))
        }
    }
}
