import ArgumentParser
import SimletKit

extension ArgumentHelp {
    static var device: ArgumentHelp {
        "A UDID, a full or partial name, or \"booted\". Omit it to pick from a list."
    }
}

extension Inventory {
    func display(_ device: Device) -> String {
        "\(Style.bold(device.name)) \(Style.dim("(\(osName(for: device)))"))"
    }

    func selectDevice(
        _ query: String?,
        from candidates: [Device],
        title: String,
        whenEmpty emptyMessage: String,
        autoSelectSingle: Bool = false
    ) throws -> Device {
        if let query {
            return try device(matching: query)
        }
        guard devices.contains(where: \.isAvailable) else {
            throw UserError("No simulators found. Create one with `simlet create`.")
        }
        guard !candidates.isEmpty else { throw UserError(emptyMessage) }
        if autoSelectSingle, candidates.count == 1 {
            return candidates[0]
        }
        guard Terminal.isInteractive else {
            throw UserError("Missing device. Pass a UDID or a name, or run in a terminal to pick from a list.")
        }
        let nameWidth = candidates.map(\.name.count).max() ?? 0
        return try Picker(title: title, items: candidates) { device in
            let dot = device.isBooted ? "●" : "○"
            return "\(dot) \(device.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0))  \(osName(for: device))"
        }.choose()
    }
}

struct DeviceTable {
    let inventory: Inventory
    let devices: [Device]

    func render() -> String {
        let nameWidth = devices.map(\.name.count).max() ?? 0
        let osWidth = devices.map { inventory.osName(for: $0).count }.max() ?? 0
        let groups = [
            ("Booted", devices.filter(\.isBooted)),
            ("Other", devices.filter { !$0.isBooted }),
        ]

        var lines: [String] = []
        for (title, group) in groups where !group.isEmpty {
            if !lines.isEmpty { lines.append("") }
            lines.append(Style.bold(title))
            lines += group.map { row(for: $0, nameWidth: nameWidth, osWidth: osWidth) }
        }
        return lines.joined(separator: "\n")
    }

    private func row(for device: Device, nameWidth: Int, osWidth: Int) -> String {
        let dot = device.isBooted ? Style.green("●") : Style.dim("○")
        let name = device.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
        let os = inventory.osName(for: device).padding(toLength: osWidth, withPad: " ", startingAt: 0)
        var row = "  \(dot) \(name)  \(Style.cyan(os))  \(Style.dim(device.udid))"
        if !device.isAvailable {
            row += Style.yellow("  unavailable")
        } else if !device.isBooted, device.state != "Shutdown" {
            row += Style.yellow("  \(device.state.lowercased())")
        }
        return row
    }
}
