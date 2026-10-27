import ArgumentParser
import SimletKit

struct CreateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "create",
        abstract: "Create a simulator. Missing options are asked for in a terminal.",
        discussion: """
            Examples:
              simlet create
              simlet create --type "iPhone 16 Pro"
              simlet create --type "iPad Air" --runtime "iOS 18.2" --name "Test iPad" --boot
            """,
        aliases: ["new"]
    )

    @Option(name: .shortAndLong, help: "Name of the simulator. The default is the device type name.")
    var name: String?

    @Option(name: .shortAndLong, help: "Device type, for example \"iPhone 16 Pro\". See `simlet types`.")
    var type: String?

    @Option(name: .shortAndLong, help: "Runtime, for example \"iOS 18.2\". \"iOS\" selects the newest iOS. See `simlet runtimes`.")
    var runtime: String?

    @Flag(name: .shortAndLong, help: "Boot the simulator after it is created.")
    var boot = false

    @Flag(name: .shortAndLong, help: "Boot the simulator and open Simulator.app.")
    var open = false

    func run() throws {
        let simctl = Simctl()
        let inventory = try simctl.inventory()
        guard !inventory.availableRuntimes.isEmpty else {
            throw UserError("No simulator runtime is installed. Install one in Xcode > Settings > Components.")
        }

        var asked = false
        let requestedType = try type.map(inventory.deviceType(matching:))
        let runtime = try selectRuntime(in: inventory, for: requestedType, asked: &asked)
        let deviceType = try requestedType ?? selectDeviceType(in: inventory, for: runtime, asked: &asked)
        guard runtime.supports(deviceType) else {
            throw UserError("\(runtime.name) does not support \(deviceType.name).")
        }
        let name = try name ?? (asked ? Terminal.prompt("Name:", default: deviceType.name) : deviceType.name)

        let udid = try Output.step("Creating \(name)") {
            try simctl.create(name: name, deviceType: deviceType, runtime: runtime)
        }
        Output.success("Created \(Style.bold(name)) \(Style.dim("(\(runtime.name))"))  \(Style.dim(udid))")

        let shouldBoot = boot || open || (asked && Terminal.confirm("Boot it now?", default: true))
        guard shouldBoot else { return }
        try BootCommand.parse([udid] + (open || asked ? [] : ["--no-open"])).run()
    }

    private func selectRuntime(in inventory: Inventory, for deviceType: DeviceType?, asked: inout Bool) throws -> Runtime {
        if let runtime {
            return try inventory.runtime(matching: runtime)
        }
        if let deviceType {
            guard let newest = inventory.newestRuntime(supporting: deviceType) else {
                throw UserError("No installed runtime supports \(deviceType.name).")
            }
            return newest
        }
        guard Terminal.isInteractive else {
            throw UserError("Pass --type, or run in a terminal to pick from a list.")
        }
        asked = true
        let runtimes = inventory.availableRuntimes.sorted { lhs, rhs in
            lhs.platform == rhs.platform ? Runtime.isOlder(rhs, than: lhs) : (lhs.platform ?? "") < (rhs.platform ?? "")
        }
        return try Picker(title: "Runtime:", items: runtimes) { runtime in
            runtime.buildVersion.map { "\(runtime.name) (\($0))" } ?? runtime.name
        }.choose()
    }

    private func selectDeviceType(in inventory: Inventory, for runtime: Runtime, asked: inout Bool) throws -> DeviceType {
        guard Terminal.isInteractive else {
            throw UserError("Pass --type, or run in a terminal to pick from a list.")
        }
        asked = true
        return try Picker(title: "Device type:", items: inventory.deviceTypes(for: runtime), label: \.name).choose()
    }
}
