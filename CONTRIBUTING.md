# Contributing

Thank you for helping. Issues and pull requests are welcome.

## Before you start

- Search the [issues](https://github.com/shortcuts/obsidian-quickadd-macos-menubar/issues) first.
- For a new feature, open an issue before you write code. A short description of the problem is enough.
- [README.md](./README.md) is the source of truth for behavior. A change that contradicts it needs a README change in the same pull request.

## Setup

You need macOS 13 or later and the Swift toolchain (`xcode-select --install`). There are no other dependencies.

```sh
git clone https://github.com/shortcuts/obsidian-quickadd-macos-menubar
cd obsidian-quickadd-macos-menubar
make test
```

## Run the app

```sh
make app
open .build/QuickAddMenubar.app
```

`make install` copies the app to `~/Applications` and starts it. It stops a running copy first.

## Check your change

Run all three before you push. CI runs the same commands.

```sh
make lint     # swift format lint --strict
make test     # swift test
make build    # swift build -c release
```

`make format` fixes the formatting.

## Where code goes

- Logic with no UI goes in `Sources/QuickAddCore`, with a test in `Tests/QuickAddCoreTests`.
- AppKit code goes in `Sources/QuickAddMenubar`. Keep it thin.

See [AGENTS.md](./AGENTS.md) for the architecture rules.

## Commits and pull requests

- Use [Conventional Commits](https://www.conventionalcommits.org): `feat:`, `fix:`, `docs:`, `chore:`. The release workflow reads them to pick the next version and to write the changelog.
- The subject says what changed. The body says why, and only when the reason is not obvious.
- Do not edit `CHANGELOG.md` or `version.txt`. The release workflow owns them.
- Keep a pull request to one concern. Add a screenshot when the prompt looks different.

## Bug reports

Include your macOS version, the app version, your Obsidian and QuickAdd versions, and your `config.toml` if you changed it. Say what you pressed and what you expected.
