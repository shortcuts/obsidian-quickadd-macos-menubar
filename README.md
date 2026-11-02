<p align="center">
  <h1 align="center">✏️ quickadd-macos-menubar</h1>
</p>

<p align="center">
	Run your Obsidian QuickAdd choices from anywhere on your Mac, without opening Obsidian.
</p>

Press a global hotkey. A small prompt floats over whatever you are doing. Pick a QuickAdd choice, type a line, and press Enter. The text lands in your vault, and the window you were using keeps focus.

<!-- SECTION: FEATURES -->
## ⚡️ Features

- Opens with a global hotkey. The default is `Cmd+Shift+;`.
- Lists the choices from your vault's QuickAdd configuration. You maintain no second list.
- Works with the keyboard only: `Tab` picks the choice, `Enter` captures, `Esc` cancels.
- Remembers the last choice you used.
- Runs Obsidian in the background. The prompt does not switch apps.
- Needs no Accessibility or other privacy permission.
- Supports Apple Silicon and Intel Macs on macOS 13 or later.

<!-- SECTION: INSTALLATION -->
## 📋 Installation

```sh
curl -fsSL https://raw.githubusercontent.com/shortcuts/quickadd-macos-menubar/main/install.sh | sh
```

The script downloads the latest release into `~/Applications` and starts it. If no release exists, it builds from source. That needs the Swift toolchain, which comes with the Xcode Command Line Tools (`xcode-select --install`).

To build from a clone instead:

```sh
git clone https://github.com/shortcuts/quickadd-macos-menubar
cd quickadd-macos-menubar
make install
```

A pencil icon appears in the menu bar. Check **Launch at login** in **Settings…** to start it with your Mac.

<!-- SECTION: GETTING_STARTED -->
## ☄ Getting started

The app passes your text to QuickAdd as the variable `text`. Each choice must read it with `{{VALUE:text}}` and must not ask for anything else. A choice that opens its own prompt would show that prompt inside Obsidian. The app warns you about such a choice: in the menu, and under the choice names when the prompt opens. It flags a bare `{{VALUE}}`, `{{NAME}}` or `{{MVALUE}}`, and any `{{VALUE:<other name>}}`. It does not read template files that a choice links to.

Example: a Capture choice named `TODO` that appends to `00 Inbox/TODO.md`, with this capture format:

```
- [ ] {{DATE:YYYY-MM-DD}} {{VALUE:text}}
```

Then:

1. Open Obsidian once, so that it registers your vault.
2. Press `Cmd+Shift+;` from any app.
3. Press `Tab` until the choice you want is highlighted.
4. Type your text and press `Enter`.

QuickAdd shows its usual notification when the capture is done.

<!-- SECTION: CONFIGURATION -->
## ⚙ Configuration

The app works with no configuration. To change the defaults, choose **Settings…** in the menu. The window sets the vault, the choices, the variable, the hotkey, and whether the app launches at login. To set the hotkey, click the shortcut button and press the keys you want. Saving applies the change at once.

The window writes `~/.config/quickadd-menubar/config.toml`. It drops comments from the file. To edit the file by hand, create it at that path, then choose **Reload Config** after you save.

```toml
vault = "My Vault"
choices = ["TODO", "Daily"]
variable = "text"
key_code = 41
modifiers = ["cmd", "shift"]
```

Every key is optional:

|   Key   |  Default  | Description |
|---------|-----------|-------------|
|`vault`| the open vault | The folder name of the vault to use. Set it when you keep several vaults. |
|`choices`| every choice | The QuickAdd choices to show, in this order. Names that the vault lacks are skipped. |
|`variable`| `"text"` | The `{{VALUE:<variable>}}` name that your choices read. |
|`key_code`| `41` (`;`) | The virtual key code of the hotkey. [Key code list](https://eastmanreference.com/complete-list-of-applescript-key-codes). |
|`modifiers`| `["cmd", "shift"]` | Any of `cmd`, `shift`, `option` (or `alt`), `control` (or `ctrl`). At least one is required. |

The parser reads a subset of TOML: top-level `key = value` lines, `#` comments, strings, integers, and string arrays on one line. It rejects unknown keys, so a typo shows an alert instead of doing nothing. An invalid file keeps the previous hotkey. A missing file uses the defaults.

If another app already owns your hotkey, the app tells you at launch. Choose another shortcut in **Settings…**.

<!-- SECTION: KEYBOARD -->
## ⌨ Keyboard

|      Key       |           Action           |
|----------------|----------------------------|
|`Tab`, `↓`| Selects the next choice. |
|`Shift+Tab`, `↑`| Selects the previous choice. |
|`Enter`| Runs the choice with your text. |
|`Esc`| Closes the prompt. |

Clicking outside the prompt also closes it.

<!-- SECTION: MENU -->
## 🧰 Menu bar

|      Item      |           Description           |
|----------------|---------------------------------|
|**Capture…**| Opens the prompt, like the hotkey. Shows the hotkey. |
|**Settings…**| Opens the settings window. |
|**Reload Config**| Reads the config file and registers the hotkey again. |
|**Quit QuickAdd Menubar**| Stops the app. |

<!-- SECTION: HOW_IT_WORKS -->
## 🔧 How it works

The app reads two files, and it never writes to your vault:

- `~/Library/Application Support/obsidian/obsidian.json` lists your vaults and tells which one is open.
- `<vault>/.obsidian/plugins/quickadd/data.json` lists your QuickAdd choices.

Nothing leaves your Mac except that URI, which goes to Obsidian on the same machine. The app makes no network request and stores nothing but the last choice you used (in `UserDefaults`).

On Enter, it opens `obsidian://quickadd?vault=…&choice=…&value-text=…` without activating Obsidian. QuickAdd does the capture. If Obsidian is closed, macOS starts it first.

<!-- SECTION: CONTRIBUTING -->
## ⌨ Contributing

Pull requests and issues are welcome. See [CONTRIBUTING.md](./CONTRIBUTING.md). Add as much context as you can, such as your macOS version and your QuickAdd choice.

Before you open a pull request, run:

```sh
make lint
make test
make build
```

## 💖 Sponsoring

See [SPONSORING.md](./SPONSORING.md).
