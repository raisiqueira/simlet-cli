import ArgumentParser
import SimletKit

struct BootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "boot",
        abstract: "Boot a simulator and show it in Simulator.app."
    )

    @Argument(help: .device)
    var device: String?

    @Flag(inversion: .prefixedNo, help: "Open Simulator.app after the boot.")
    var open = true

    func run() throws {
        let simctl = Simctl()
        let inventory = try simctl.inventory()
        let target = try inventory.selectDevice(
            device,
            from: inventory.devices.filter { $0.isAvailable && !$0.isBooted },
            title: "Which simulator do you want to boot?",
            whenEmpty: "All simulators are already booted."
        )

        if target.isBooted {
            Output.info("\(inventory.display(target)) is already booted.")
        } else {
            try Output.step("Booting \(target.name)") { try simctl.boot(target) }
            Output.success("Booted \(inventory.display(target))")
        }
        if open {
            try simctl.openSimulatorApp(focusing: target)
        }
    }
}

struct ShutdownCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "shutdown",
        abstract: "Shut down a booted simulator.",
        aliases: ["stop"]
    )

    @Argument(help: .device)
    var device: String?

    @Flag(name: .shortAndLong, help: "Shut down all booted simulators.")
    var all = false

    func validate() throws {
        if all, device != nil {
            throw ValidationError("Pass a device or --all, not both.")
        }
    }

    func run() throws {
        let simctl = Simctl()
        let inventory = try simctl.inventory()
        let booted = inventory.devices.filter(\.isBooted)

        if all {
            guard !booted.isEmpty else { return Output.info("No simulator is booted.") }
            try Output.step("Shutting down \(booted.count) simulator(s)") { try simctl.shutdownAll() }
            Output.success("Shut down \(booted.count) simulator(s)")
            return
        }

        let target = try inventory.selectDevice(
            device,
            from: booted,
            title: "Which simulator do you want to shut down?",
            whenEmpty: "No simulator is booted.",
            autoSelectSingle: true
        )
        guard target.isBooted else {
            return Output.info("\(inventory.display(target)) is not booted.")
        }
        try Output.step("Shutting down \(target.name)") { try simctl.shutdown(target) }
        Output.success("Shut down \(inventory.display(target))")
    }
}

struct OpenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "open",
        abstract: "Open Simulator.app."
    )

    func run() throws {
        try Simctl().openSimulatorApp()
    }
}
