import ArgumentParser
import Foundation
import SimletKit

struct ScreenshotCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screenshot",
        abstract: "Save a screenshot of a booted simulator.",
        aliases: ["shot"]
    )

    @Argument(help: .device)
    var device: String?

    @Option(name: .shortAndLong, help: "Output file. The default is a PNG in the current folder.")
    var output: String?

    func run() throws {
        let simctl = Simctl()
        let inventory = try simctl.inventory()
        let target = try inventory.selectDevice(
            device,
            from: inventory.devices.filter(\.isBooted),
            title: "Which simulator do you want to capture?",
            whenEmpty: "No simulator is booted. Boot one with `simlet boot`.",
            autoSelectSingle: true
        )
        guard target.isBooted else {
            throw UserError("\(target.name) is not booted. Boot it with `simlet boot`.")
        }

        let url = URL(fileURLWithPath: output ?? defaultFileName(for: target)).standardizedFileURL
        try simctl.screenshot(target, to: url.path)
        Output.success("Saved screenshot to \(Style.bold(url.path))")
    }

    private func defaultFileName(for device: Device) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
        let name = device.name.replacingOccurrences(of: "/", with: "-")
        return "\(name) \(formatter.string(from: Date())).png"
    }
}
