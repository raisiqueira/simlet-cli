import ArgumentParser

struct InteractiveMenu {
    private struct Action {
        let title: String
        let command: ParsableCommand.Type?
    }

    private let actions = [
        Action(title: "Boot a simulator", command: BootCommand.self),
        Action(title: "Shut down a simulator", command: ShutdownCommand.self),
        Action(title: "Create a simulator", command: CreateCommand.self),
        Action(title: "Rename a simulator", command: RenameCommand.self),
        Action(title: "Erase a simulator", command: EraseCommand.self),
        Action(title: "Delete a simulator", command: DeleteCommand.self),
        Action(title: "Take a screenshot", command: ScreenshotCommand.self),
        Action(title: "Open Simulator.app", command: OpenCommand.self),
        Action(title: "Quit", command: nil),
    ]

    func run() throws {
        while true {
            try ListCommand.parse([]).run()
            print()

            guard let action = try? Picker(title: "What do you want to do?", items: actions, label: \.title).choose(),
                  let commandType = action.command
            else { return }

            do {
                var command = try commandType.parse([])
                try command.run()
            } catch is Cancelled {
                Output.info("Cancelled.")
            } catch {
                Output.error(Simlet.message(for: error))
            }
            print()
        }
    }
}
