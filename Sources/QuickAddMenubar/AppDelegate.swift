import AppKit
import QuickAddCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
  private let panel = CapturePanel()
  private let loginItem = NSMenuItem(
    title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
  private var statusItem: NSStatusItem?
  private var hotKey: HotKey?
  private var config = Config.default
  private var vault: Vault?
  private var warningItems: [NSMenuItem] = []

  func applicationDidFinishLaunching(_ notification: Notification) {
    panel.onSubmit = { [weak self] choice, text in self?.submit(choice: choice, text: text) }
    setUpStatusItem()
    reloadConfig()
  }

  private func setUpStatusItem() {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.button?.image = NSImage(
      systemSymbolName: "square.and.pencil", accessibilityDescription: "QuickAdd")

    let menu = NSMenu()
    menu.delegate = self
    menu.addItem(withTitle: "Capture…", action: #selector(capture), keyEquivalent: "").target = self
    menu.addItem(.separator())
    loginItem.target = self
    menu.addItem(loginItem)
    menu.addItem(withTitle: "Edit Config…", action: #selector(editConfig), keyEquivalent: "")
      .target = self
    menu.addItem(withTitle: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "")
      .target = self
    menu.addItem(.separator())
    menu.addItem(
      withTitle: "Quit QuickAdd Menubar", action: #selector(NSApplication.terminate(_:)),
      keyEquivalent: "q")
    item.menu = menu
    statusItem = item
  }

  func menuWillOpen(_ menu: NSMenu) {
    loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    for item in warningItems { menu.removeItem(item) }
    warningItems = []
    let found = currentProblems()
    guard !found.isEmpty else { return }
    let header = NSMenuItem(
      title: "⚠ These choices ask for input in Obsidian:", action: nil, keyEquivalent: "")
    let rows = found.map { problem -> NSMenuItem in
      let row = NSMenuItem(
        title: "    \(problem.name)", action: #selector(showProblem(_:)), keyEquivalent: "")
      row.target = self
      row.representedObject = problem
      return row
    }
    warningItems = [header] + rows
    for (offset, item) in warningItems.enumerated() { menu.insertItem(item, at: 1 + offset) }
  }

  @objc private func showProblem(_ sender: NSMenuItem) {
    guard let problem = sender.representedObject as? Choices.Problem else { return }
    alert(problem.name, problem.message)
  }

  /// Problems for the choices the panel would show. Errors stay silent here: opening the
  /// panel reports them.
  private func currentProblems() -> [Choices.Problem] {
    guard let vault = try? Vault.resolve(name: config.vault),
      let data = try? Data(contentsOf: vault.choicesURL),
      let names = try? Choices.names(in: data),
      let found = try? Choices.problems(in: data, variable: config.variable)
    else { return [] }
    let shown = Choices.select(from: names, wanted: config.choices)
    return found.filter { shown.contains($0.name) }
  }

  @objc private func reloadConfig() {
    // Parse before dropping the old hotkey, so a typo in the file does not leave the user
    // with no hotkey at all.
    let loaded: Config
    do {
      loaded = try Config.load()
    } catch {
      return alert(error)
    }
    config = loaded
    hotKey = nil
    hotKey = HotKey(keyCode: config.keyCode, modifiers: config.modifiers) { [weak self] in
      self?.capture()
    }
    if hotKey == nil {
      alert(
        "Hotkey unavailable",
        "Another app uses this key combination. Change `keyCode` or `modifiers` in the config.")
    }
  }

  @objc private func capture() {
    do {
      let vault = try Vault.resolve(name: config.vault)
      let names = try Choices.names(at: vault.choicesURL)
      guard !names.isEmpty else { throw QuickAddError.noChoices(vault.name) }
      let shown = Choices.select(from: names, wanted: config.choices)
      guard !shown.isEmpty else {
        throw QuickAddError.noMatchingChoices(vault: vault.name, available: names)
      }
      self.vault = vault
      let problems = Dictionary(
        currentProblems().map { ($0.name, $0.message) }, uniquingKeysWith: { first, _ in first })
      panel.show(
        choices: shown, problems: problems, last: UserDefaults.standard.string(forKey: "lastChoice")
      )
    } catch {
      alert(error)
    }
  }

  private func submit(choice: String, text: String) {
    guard let vault else { return }
    UserDefaults.standard.set(choice, forKey: "lastChoice")
    let url = quickAddURL(
      vault: vault.name, choice: choice, variable: config.variable, value: text)
    // Do not activate: Obsidian runs the choice in the background.
    let options = NSWorkspace.OpenConfiguration()
    options.activates = false
    NSWorkspace.shared.open(url, configuration: options) { _, error in
      if let error { DispatchQueue.main.async { self.alert(error) } }
    }
  }

  @objc private func toggleLogin() {
    do {
      if SMAppService.mainApp.status == .enabled {
        try SMAppService.mainApp.unregister()
      } else {
        try SMAppService.mainApp.register()
      }
    } catch {
      alert(error)
    }
  }

  @objc private func editConfig() {
    let url = Config.fileURL
    if !FileManager.default.fileExists(atPath: url.path) {
      try? FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
      try? Config.template.write(to: url, atomically: true, encoding: .utf8)
    }
    NSWorkspace.shared.open(url)
  }

  private func alert(_ error: Error) {
    alert("QuickAdd Menubar", error.localizedDescription)
  }

  private func alert(_ title: String, _ message: String) {
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.runModal()
  }
}
