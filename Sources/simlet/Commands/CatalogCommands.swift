import ArgumentParser
import SimletKit

struct RuntimesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "runtimes",
        abstract: "List installed simulator runtimes."
    )

    func run() throws {
        let runtimes = try Simctl().inventory().availableRuntimes
        guard !runtimes.isEmpty else {
            return Output.info("No simulator runtime is installed. Install one in Xcode > Settings > Components.")
        }
        let nameWidth = runtimes.map(\.name.count).max() ?? 0
        for runtime in runtimes {
            let name = runtime.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            print("  \(Style.cyan(name))  \(runtime.buildVersion ?? "")  \(Style.dim(runtime.identifier))")
        }
    }
}

struct TypesCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "types",
        abstract: "List device types that you can create."
    )

    @Option(name: .shortAndLong, help: "Show only the types that this runtime supports, for example \"iOS\".")
    var runtime: String?

    func run() throws {
        let inventory = try Simctl().inventory()
        let types = try runtime.map { try inventory.deviceTypes(for: inventory.runtime(matching: $0)) }
            ?? inventory.deviceTypes
        let nameWidth = types.map(\.name.count).max() ?? 0
        for type in types {
            let name = type.name.padding(toLength: nameWidth, withPad: " ", startingAt: 0)
            print("  \(name)  \(Style.dim(type.identifier))")
        }
    }
}
