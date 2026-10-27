import ArgumentParser

@main
struct Simlet: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "simlet",
        abstract: "Friendly commands for iOS Simulator, on top of `xcrun simctl`.",
        discussion: "Run `simlet` with no command to open the interactive menu.",
        version: "0.1.0",
        subcommands: [
            ListCommand.self,
            BootCommand.self,
            ShutdownCommand.self,
            CreateCommand.self,
            RenameCommand.self,
            EraseCommand.self,
            DeleteCommand.self,
            ScreenshotCommand.self,
            OpenCommand.self,
            RuntimesCommand.self,
            TypesCommand.self,
        ]
    )

    static func main() {
        do {
            var command = try parseAsRoot()
            try command.run()
        } catch is Cancelled {
            Output.error("Cancelled.")
            exit(withError: ExitCode(130))
        } catch {
            exit(withError: error)
        }
    }

    func run() throws {
        guard Terminal.isInteractive else {
            return try ListCommand.parse([]).run()
        }
        try InteractiveMenu().run()
    }
}
