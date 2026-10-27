import Foundation

public struct Inventory: Decodable, Sendable {
    public let devices: [Device]
    public let runtimes: [Runtime]
    public let deviceTypes: [DeviceType]

    private enum CodingKeys: String, CodingKey {
        case devices, runtimes, devicetypes
    }

    public init(devices: [Device], runtimes: [Runtime], deviceTypes: [DeviceType]) {
        self.devices = devices.sorted { lhs, rhs in
            let lhsOS = Self.osName(for: lhs, runtimes: runtimes)
            let rhsOS = Self.osName(for: rhs, runtimes: runtimes)
            let order = lhsOS.localizedStandardCompare(rhsOS)
            guard order == .orderedSame else { return order == .orderedAscending }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        self.runtimes = runtimes
        self.deviceTypes = deviceTypes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let devicesByRuntime = try container.decode([String: [Device]].self, forKey: .devices)
        let devices = devicesByRuntime.flatMap { runtime, devices in
            devices.map { device in
                var device = device
                device.runtimeIdentifier = runtime
                return device
            }
        }
        self.init(
            devices: devices,
            runtimes: try container.decode([Runtime].self, forKey: .runtimes),
            deviceTypes: try container.decode([DeviceType].self, forKey: .devicetypes)
        )
    }

    public var availableRuntimes: [Runtime] {
        runtimes.filter(\.isAvailable)
    }

    public func osName(for device: Device) -> String {
        Self.osName(for: device, runtimes: runtimes)
    }

    public func deviceTypes(for runtime: Runtime) -> [DeviceType] {
        deviceTypes.filter(runtime.supports)
    }

    public func newestRuntime(supporting deviceType: DeviceType) -> Runtime? {
        availableRuntimes.filter { $0.supports(deviceType) }.max(by: Runtime.isOlder)
    }

    private static func osName(for device: Device, runtimes: [Runtime]) -> String {
        runtimes.first { $0.identifier == device.runtimeIdentifier }?.name
            ?? RuntimeName.display(forIdentifier: device.runtimeIdentifier)
    }
}
