# simlet

Friendly commands for iOS Simulator. simlet is a Swift version of [simux](https://github.com/custardcream98/simux). It calls `xcrun simctl` for you.

## Requirements

- macOS 13 or later
- Xcode with at least one simulator runtime

## Install

With [Homebrew](https://brew.sh). This also installs shell completions.

```sh
brew install raisiqueira/tap/simlet
```

With [mise](https://mise.jdx.dev):

```sh
mise use -g github:raisiqueira/simlet-cli
```

Both install a prebuilt binary for Apple silicon or Intel.

## Usage

Run `simlet` with no command to open the interactive menu.

```sh
simlet                          # interactive menu
simlet list                     # list simulators, booted first
simlet list --json              # list as JSON
simlet boot "iPhone 16 Pro"     # boot and open Simulator.app
simlet boot                     # pick a simulator from a list
simlet shutdown --all           # shut down all booted simulators
simlet create                   # pick a runtime and a device type
simlet create --type "iPhone 16 Pro" --runtime iOS --boot
simlet rename booted "Demo Phone"
simlet erase "Demo Phone"       # erase content and settings
simlet delete --unavailable     # delete simulators with no runtime
simlet screenshot -o shot.png   # capture the booted simulator
simlet runtimes                 # list installed runtimes
simlet types --runtime iOS      # list device types for a runtime
```

## Select a device

A device argument can be one of these:

- A full UDID or the start of a UDID, for example `6CF7`.
- A full or partial name, for example `"iPhone 16 Pro"` or `max`. Case does not matter.
- The word `booted`, for the booted simulator.

If more than one simulator matches, simlet shows the matches. Then you can use a more specific value.

If you do not give a device in a terminal, simlet shows a list. Use the arrow keys to move. Type to filter the list. Push Enter to select, or Esc to cancel.

## Scripts

simlet does not ask questions when its input or output is not a terminal. Destructive commands ask for confirmation only in a terminal. Use `--yes` to skip the confirmation. Colors stop when `NO_COLOR` is set.

A cancelled prompt exits with code 130.

## Development

```sh
swift build
swift test
```

## Release

1. Set the new version in `Sources/simlet/Simlet.swift`.
2. Commit the change, then push a tag with the same version:

   ```sh
   git tag v0.2.0
   git push origin v0.2.0
   ```

The release workflow runs the tests and builds the binaries. Then it publishes a GitHub release and updates the formula in [raisiqueira/homebrew-tap](https://github.com/raisiqueira/homebrew-tap). The workflow stops if the tag and the version in the code are different.

To update the formula, the workflow needs the `HOMEBREW_TAP_TOKEN` secret. Use a fine-grained token with "Contents: read and write" access to `homebrew-tap` only. If the secret is not set, the workflow shows the formula in the job summary. Then you copy it to the tap by hand.

## License

MIT. See [LICENSE](LICENSE).
