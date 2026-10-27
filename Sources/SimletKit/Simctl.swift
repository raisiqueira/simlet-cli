import Foundation

public struct SimctlError: Error, Equatable, CustomStringConvertible {
    public let arguments: [String]
    public let message: String

    public init(arguments: [String], output: String) {
        self.arguments = arguments
        self.message = Self.summarize(output)
    }

    public var description: String {
        message.isEmpty ? "`simctl \(arguments.joined(separator: " "))` failed." : message
    }

    /// simctl prints a generic header line before the real reason.
    static func summarize(_ output: String) -> String {
        let lines = output.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let reason = lines.first {
            !$0.hasPrefix("An error was encountered processing the command")
                && !$0.hasPrefix("Underlying error")
        }
        return reason ?? lines.first ?? ""
    }
}

public struct Simctl: Sendable {
    public init() {}

    public func inventory() throws -> Inventory {
        let output = try simctl(["list", "--json"])
        return try JSONDecoder().decode(Inventory.self, from: Data(output.utf8))
    }

    public func boot(_ device: Device) throws {
        try simctl(["boot", device.udid])
    }

    public func shutdown(_ device: Device) throws {
        try simctl(["shutdown", device.udid])
    }

    public func shutdownAll() throws {
        try simctl(["shutdown", "all"])
    }

    public func rename(_ device: Device, to name: String) throws {
        try simctl(["rename", device.udid, name])
    }

    public func delete(_ device: Device) throws {
        try simctl(["delete", device.udid])
    }

    public func deleteUnavailable() throws {
        try simctl(["delete", "unavailable"])
    }

    public func erase(_ device: Device) throws {
        try simctl(["erase", device.udid])
    }

    /// Returns the UDID of the new simulator.
    public func create(name: String, deviceType: DeviceType, runtime: Runtime) throws -> String {
        try simctl(["create", name, deviceType.identifier, runtime.identifier])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func screenshot(_ device: Device, to path: String) throws {
        try simctl(["io", device.udid, "screenshot", path])
    }

    public func openSimulatorApp(focusing device: Device? = nil) throws {
        var arguments = ["-a", "Simulator"]
        if let device {
            arguments += ["--args", "-CurrentDeviceUDID", device.udid]
        }
        let result = try Shell.run("/usr/bin/open", arguments)
        guard result.status == 0 else {
            throw SimctlError(arguments: ["open"] + arguments, output: result.errorOutput)
        }
    }

    @discardableResult
    private func simctl(_ arguments: [String]) throws -> String {
        let result = try Shell.run("/usr/bin/xcrun", ["simctl"] + arguments)
        guard result.status == 0 else {
            throw SimctlError(arguments: arguments, output: result.errorOutput + result.output)
        }
        return result.output
    }
}
