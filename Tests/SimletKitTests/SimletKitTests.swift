import Foundation
import Testing
@testable import SimletKit

private let fixture = """
{
  "devicetypes": [
    { "identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro", "name": "iPhone 16 Pro", "productFamily": "iPhone" },
    { "identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max", "name": "iPhone 16 Pro Max", "productFamily": "iPhone" },
    { "identifier": "com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Ultra", "name": "Apple Watch Ultra", "productFamily": "Apple Watch" }
  ],
  "runtimes": [
    {
      "identifier": "com.apple.CoreSimulator.SimRuntime.iOS-17-5", "name": "iOS 17.5", "version": "17.5",
      "buildversion": "21F79", "platform": "iOS", "isAvailable": true,
      "supportedDeviceTypes": [{ "identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro", "name": "iPhone 16 Pro" }]
    },
    {
      "identifier": "com.apple.CoreSimulator.SimRuntime.iOS-18-2", "name": "iOS 18.2", "version": "18.2",
      "buildversion": "22C150", "platform": "iOS", "isAvailable": true,
      "supportedDeviceTypes": [
        { "identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro", "name": "iPhone 16 Pro" },
        { "identifier": "com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max", "name": "iPhone 16 Pro Max" }
      ]
    }
  ],
  "devices": {
    "com.apple.CoreSimulator.SimRuntime.iOS-18-2": [
      { "udid": "AAAA1111-0000-0000-0000-000000000001", "name": "iPhone 16 Pro", "state": "Booted", "isAvailable": true },
      { "udid": "BBBB2222-0000-0000-0000-000000000002", "name": "iPhone 16 Pro Max", "state": "Shutdown", "isAvailable": true }
    ],
    "com.apple.CoreSimulator.SimRuntime.iOS-17-5": [
      { "udid": "CCCC3333-0000-0000-0000-000000000003", "name": "iPhone 16 Pro", "state": "Shutdown", "isAvailable": true }
    ],
    "com.apple.CoreSimulator.SimRuntime.iOS-16-4": [
      { "udid": "DDDD4444-0000-0000-0000-000000000004", "name": "Old Phone", "state": "Shutdown", "isAvailable": false }
    ]
  }
}
"""

private func makeInventory() throws -> Inventory {
    try JSONDecoder().decode(Inventory.self, from: Data(fixture.utf8))
}

@Suite struct InventoryDecodingTests {
    @Test func attachesRuntimeAndSortsDevices() throws {
        let inventory = try makeInventory()
        #expect(inventory.devices.map { $0.udid.prefix(4) } == ["DDDD", "CCCC", "AAAA", "BBBB"])
        #expect(inventory.devices[1].runtimeIdentifier == "com.apple.CoreSimulator.SimRuntime.iOS-17-5")
    }

    @Test func osNameFallsBackToIdentifierForMissingRuntime() throws {
        let inventory = try makeInventory()
        let oldPhone = try inventory.device(matching: "old phone")
        #expect(inventory.osName(for: oldPhone) == "iOS 16.4")
    }

    @Test func filtersDeviceTypesByRuntime() throws {
        let inventory = try makeInventory()
        let ios17 = try inventory.runtime(matching: "iOS 17.5")
        #expect(inventory.deviceTypes(for: ios17).map(\.name) == ["iPhone 16 Pro"])
    }
}

@Suite struct DeviceLookupTests {
    @Test func matchesUDIDCaseInsensitively() throws {
        let device = try makeInventory().device(matching: "bbbb2222-0000-0000-0000-000000000002")
        #expect(device.name == "iPhone 16 Pro Max")
    }

    @Test func matchesUDIDPrefix() throws {
        #expect(try makeInventory().device(matching: "CCCC").udid.hasPrefix("CCCC"))
    }

    @Test func matchesPartialName() throws {
        #expect(try makeInventory().device(matching: "max").name == "iPhone 16 Pro Max")
    }

    @Test func reportsDuplicateNamesAsAmbiguous() throws {
        #expect {
            try makeInventory().device(matching: "iPhone 16 Pro")
        } throws: { error in
            guard case let .ambiguous(_, _, candidates) = error as? LookupError else { return false }
            return candidates.count == 2 && candidates.allSatisfy { $0.hasPrefix("iPhone 16 Pro (iOS") }
        }
    }

    @Test func resolvesBootedKeyword() throws {
        #expect(try makeInventory().device(matching: "booted").udid.hasPrefix("AAAA"))
    }

    @Test func throwsWhenNothingIsBooted() throws {
        let inventory = try makeInventory()
        let shutDown = Inventory(
            devices: inventory.devices.filter { !$0.isBooted },
            runtimes: inventory.runtimes,
            deviceTypes: inventory.deviceTypes
        )
        #expect(throws: LookupError.noBootedDevice) { try shutDown.device(matching: "booted") }
    }

    @Test func throwsNotFound() throws {
        #expect(throws: LookupError.self) { try makeInventory().device(matching: "Pixel") }
    }
}

@Suite struct CatalogLookupTests {
    @Test func partialRuntimeNamePicksNewest() throws {
        #expect(try makeInventory().runtime(matching: "ios").name == "iOS 18.2")
    }

    @Test func runtimeMatchesVersion() throws {
        #expect(try makeInventory().runtime(matching: "17.5").name == "iOS 17.5")
    }

    @Test func exactDeviceTypeNameWinsOverPartial() throws {
        #expect(try makeInventory().deviceType(matching: "iphone 16 pro").name == "iPhone 16 Pro")
    }

    @Test func partialDeviceTypeNameMustBeUnique() throws {
        #expect(throws: LookupError.self) { try makeInventory().deviceType(matching: "iPhone") }
    }

    @Test func newestRuntimeSupportingType() throws {
        let inventory = try makeInventory()
        let pro = try inventory.deviceType(matching: "iPhone 16 Pro")
        let watch = try inventory.deviceType(matching: "watch")
        #expect(inventory.newestRuntime(supporting: pro)?.name == "iOS 18.2")
        #expect(inventory.newestRuntime(supporting: watch) == nil)
    }
}

@Suite struct FormattingTests {
    @Test(arguments: [
        ("com.apple.CoreSimulator.SimRuntime.iOS-18-2", "iOS 18.2"),
        ("com.apple.CoreSimulator.SimRuntime.watchOS-11-0", "watchOS 11.0"),
        ("com.apple.CoreSimulator.SimRuntime.xrOS-2-1", "xrOS 2.1"),
    ])
    func runtimeDisplayName(identifier: String, expected: String) {
        #expect(RuntimeName.display(forIdentifier: identifier) == expected)
    }

    @Test func simctlErrorKeepsTheReason() {
        let output = """
            An error was encountered processing the command (domain=com.apple.CoreSimulator.SimError, code=405):
            Unable to boot device in current state: Booted
            """
        #expect(SimctlError.summarize(output) == "Unable to boot device in current state: Booted")
    }
}
