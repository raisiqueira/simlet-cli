import ArgumentParser
import Foundation
import SimletKit

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List simulators, with booted ones first.",
        aliases: ["ls"]
    )

    @Flag(name: .shortAndLong, help: "Include simulators whose runtime is not installed.")
    var all = false

    @Flag(help: "Print the list as JSON.")
    var json = false

    func run() throws {
        let inventory = try Simctl().inventory()
        let devices = inventory.devices.filter { all || $0.isAvailable }

        if json {
            try printJSON(devices, inventory: inventory)
        } else if devices.isEmpty {
            Output.info("No simulators found. Create one with `simlet create`.")
        } else {
            print(DeviceTable(inventory: inventory, devices: devices).render())
        }
    }

    private func printJSON(_ devices: [Device], inventory: Inventory) throws {
        let summaries = devices.map { device in
            DeviceSummary(
                name: device.name,
                udid: device.udid,
                state: device.state,
                os: inventory.osName(for: device),
                runtime: device.runtimeIdentifier,
                deviceType: device.deviceTypeIdentifier,
                isAvailable: device.isAvailable
            )
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        print(String(decoding: try encoder.encode(summaries), as: UTF8.self))
    }
}

private struct DeviceSummary: Encodable {
    let name: String
    let udid: String
    let state: String
    let os: String
    let runtime: String
    let deviceType: String?
    let isAvailable: Bool
}
