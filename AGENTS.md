# AGENTS.md

Repository: https://github.com/shortcuts/obsidian-quickadd-macos-menubar
Language: Swift
Target runtime: macOS ≥ 13

`obsidian-quickadd-macos-menubar` is a menu bar app that runs [QuickAdd](https://github.com/chhoumann/quickadd) choices from anywhere on the Mac.
A global hotkey opens a small floating prompt. The user picks a choice, types text, and presses Enter.
Obsidian receives the text through its URI handler and stays in the background.

## Source of Truth

Use `@README.md` as the authoritative reference for:

* behavior
* configuration
* keyboard controls
* expected UX

Do not implement behavior that contradicts the README.

## Required Validation

Before assuming any change is valid, always run:

```
make lint
make test
make build
```

All three must pass. Run `make app` when you change `Resources/Info.plist` or anything that
affects the bundle.

## Layout

* `Sources/QuickAddCore` — logic with no UI: config (a small TOML parser), vault lookup, choice discovery, URI building.
  Everything here has a test.
* `Sources/QuickAddMenubar` — AppKit shell: status item, hotkey, floating panel.
  Keep it thin. Move any decision into `QuickAddCore`.
* `Tests/QuickAddCoreTests` — Swift Testing suites for `QuickAddCore`.
* `Resources/Info.plist` — bundle metadata. `version.txt` holds the version, and the release
  workflow bumps it. Never edit the version by hand.

## Architectural Principles

### Non-intrusive

The app must never steal focus. The panel is non-activating, and `open` runs with
`activates = false`. The window the user was typing in keeps focus.

### No extra permissions

Do not add features that need Accessibility, Input Monitoring, or Automation prompts.
The Carbon hotkey API needs none, and that is why the app uses it.

### Obsidian owns the data

The app never writes to the vault. It only builds `obsidian://quickadd` URIs.
It reads two files, and only to list choices: Obsidian's `obsidian.json` and the vault's
QuickAdd `data.json`.

### Minimal state

The only stored state is the last used choice, in `UserDefaults`. Read the config file and the
choice list each time the panel opens, so edits apply without a restart.

## Compatibility

* The app must run on Apple Silicon and Intel Macs. Do not hardcode a Homebrew prefix or an architecture.
* The URI format is QuickAdd's: `obsidian://quickadd?vault=…&choice=…&value-<variable>=…`.
  Percent-encode every value by hand. `URLComponents` leaves `&` and `+` raw.

## Testing Expectations

Tests must cover:

* URI encoding of reserved characters, non-ASCII text, and newlines
* choice discovery, including nested `Multi` choices
* vault resolution by name and by open state
* TOML parsing, config defaults, the `choices` filter, and every rejected input

AppKit code has no unit tests. Check it by hand: build with `make app`, then run the app.
