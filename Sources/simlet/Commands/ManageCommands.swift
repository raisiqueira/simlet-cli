import ArgumentParser
import SimletKit

struct RenameCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "rename",
        abstract: "Rename a simulator."
    )

    @Argument(help: .device)
    var device: String?

    @Argument(help: "The new name. Omit it to type it in a prompt.")
    var newName: String?

    func run() throws {
        let simctl = Simctl()
        let inventory = try simctl.inventory()
        let target = try inventory.selectDevice(
            device,
            from: inventory.devices,
            title: "Which simulator do you want to rename?",
            whenEmpty: "No simulators found."
        )

        let newName = try newName ?? promptForName(current: target.name)
        guard !newName.isEmpty else {
            throw UserError("The new name cannot be empty.")
        }
        guard newName != target.name else {
            return Output.info("The name is already \(Style.bold(newName)).")
        }
        try simctl.rename(target, to: newName)
        Output.success("Renamed \(Style.bold(target.name)) to \(Style.bold(newName))")
    }

    private func promptForName(current: String) throws -> String {
        guard Terminal.isInteractive else {
            throw UserError("Missing new name. Pass it after the device.")
        }
        return try Terminal.prompt("New name:", default: current)
    }
}

struct DeleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "delete",
        abstract: "Delete simulators and all of their data.",
        aliases: ["rm"]
    )

    @Argument(help: "UDIDs or names of the simulators. Omit them to pick from a list.")
    var devices: [String] = []

    @Flag(help: "Delete all simulators whose runtime is not installed.")
    var unavailable = false

    @Flag(name: .shortAndLong, help: "Do not ask for confirmation.")
    var yes = false

    func validate() throws {
        if unavailable, !devices.isEmpty {
            throw ValidationError("Pass devices or --unavailable, not both.")
        }
    }

    func run() throws {
        let simctl = Simctl()
        let inventory = try simctl.inventory()

        if unavailable {
            let count = inventory.devices.filter { !$0.isAvailable }.count
            guard count > 0 else { return Output.info("No unavailable simulators.") }
            try confirm("Delete \(count) unavailable simulator(s)?")
            try simctl.deleteUnavailable()
            return Output.success("Deleted \(count) unavailable simulator(s)")
        }

        let targets = devices.isEmpty
            ? [try inventory.selectDevice(
                nil,
                from: inventory.devices,
                title: "Which simulator do you want to delete?",
                whenEmpty: "No simulators found."
            )]
            : try devices.map(inventory.device(matching:))

        let names = targets.map(inventory.display).joined(separator: ", ")
        try confirm("Delete \(names)? This removes all of its data.")
        for target in targets {
            try Output.step("Deleting \(target.name)") {
                if target.isBooted { try simctl.shutdown(target) }
                try simctl.delete(target)
            }
            Output.success("Deleted \(inventory.display(target))")
        }
    }

    private func confirm(_ question: String) throws {
        guard !yes, Terminal.isInteractive else { return }
        guard Terminal.confirm(question) else { throw Cancelled() }
    }
}

struct EraseCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "erase",
        abstract: "Erase all content and settings of a simulator.",
        aliases: ["reset"]
    )

    @Argument(help: .device)
    var device: String?

    @Flag(name: .shortAndLong, help: "Do not ask for confirmation.")
    var yes = false

    func run() throws {
        let simctl = Simctl()
        let inventory = try simctl.inventory()
        let target = try inventory.selectDevice(
            device,
            from: inventory.devices.filter(\.isAvailable),
            title: "Which simulator do you want to erase?",
            whenEmpty: "No simulators found."
        )

        if !yes, Terminal.isInteractive {
            guard Terminal.confirm("Erase all content and settings of \(inventory.display(target))?") else {
                throw Cancelled()
            }
        }

        // simctl can only erase a shut-down simulator, so a booted one is restarted after.
        try Output.step("Erasing \(target.name)") {
            if target.isBooted { try simctl.shutdown(target) }
            try simctl.erase(target)
            if target.isBooted { try simctl.boot(target) }
        }
        Output.success("Erased \(inventory.display(target))")
    }
}
