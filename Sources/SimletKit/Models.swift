import Foundation

public struct Device: Decodable, Equatable, Sendable {
    public let udid: String
    public let name: String
    public let state: String
    public let isAvailable: Bool
    public let deviceTypeIdentifier: String?
    public internal(set) var runtimeIdentifier = ""

    private enum CodingKeys: String, CodingKey {
        case udid, name, state, isAvailable, deviceTypeIdentifier
    }

    public var isBooted: Bool { state == "Booted" }
}

public struct Runtime: Decodable, Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let version: String
    public let buildVersion: String?
    public let platform: String?
    public let isAvailable: Bool
    public let supportedDeviceTypes: [DeviceType]?

    private enum CodingKeys: String, CodingKey {
        case identifier, name, version, platform, isAvailable, supportedDeviceTypes
        case buildVersion = "buildversion"
    }

    public func supports(_ deviceType: DeviceType) -> Bool {
        supportedDeviceTypes?.contains { $0.identifier == deviceType.identifier } ?? true
    }

    public static func isOlder(_ lhs: Runtime, than rhs: Runtime) -> Bool {
        lhs.versionNumbers.lexicographicallyPrecedes(rhs.versionNumbers)
    }

    private var versionNumbers: [Int] {
        version.split(separator: ".").compactMap { Int($0) }
    }
}

public struct DeviceType: Decodable, Equatable, Sendable {
    public let identifier: String
    public let name: String
    public let productFamily: String?
}

public enum RuntimeName {
    /// Turns `com.apple.CoreSimulator.SimRuntime.iOS-18-2` into `iOS 18.2`.
    /// Used when the runtime of a device is no longer installed.
    public static func display(forIdentifier identifier: String) -> String {
        let suffix = identifier.split(separator: ".").last.map(String.init) ?? identifier
        let parts = suffix.split(separator: "-")
        guard let platform = parts.first else { return identifier }
        let version = parts.dropFirst().joined(separator: ".")
        return version.isEmpty ? String(platform) : "\(platform) \(version)"
    }
}
