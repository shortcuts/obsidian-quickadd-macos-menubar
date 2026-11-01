import AppKit
import Carbon.HIToolbox
import QuickAddCore

/// Edits `config.toml` through native controls. The hotkey modifiers stay hidden: the user
/// presses the whole shortcut and the recorder keeps both parts.
final class SettingsWindow: NSWindowController, NSWindowDelegate {
  var onSave: (() -> Void)?
  var onError: ((Error) -> Void)?
  /// Carbon swallows the saved shortcut before the recorder sees it, so the owner must
  /// unregister the hotkey while recording.
  var onRecording: ((Bool) -> Void)?

  private let vaultPopUp = NSPopUpButton()
  private let variableField = NSTextField()
  private let hotKeyButton = NSButton()
  private let choicesStack = NSStackView()
  private var keyCode = Config.default.keyCode
  private var modifiers = Config.default.modifiers
  private var recorder: Any?
  /// Choices that were checked, kept when the vault changes and the list is rebuilt.
  private var checked: Set<String>?

  private static let openVaultTitle = "Vault open in Obsidian"

  init() {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 420, height: 100),
      styleMask: [.titled, .closable], backing: .buffered, defer: true)
    window.title = "QuickAdd Settings"
    window.isReleasedWhenClosed = false
    super.init(window: window)
    window.delegate = self

    vaultPopUp.target = self
    vaultPopUp.action = #selector(vaultChanged)
    hotKeyButton.bezelStyle = .rounded
    hotKeyButton.target = self
    hotKeyButton.action = #selector(startRecording)
    choicesStack.orientation = .vertical
    choicesStack.alignment = .leading
    choicesStack.spacing = 4
    let save = NSButton(title: "Save", target: self, action: #selector(save))
    save.keyEquivalent = "\r"

    let grid = NSGridView(views: [
      [NSTextField(labelWithString: "Vault"), vaultPopUp],
      [NSTextField(labelWithString: "Choices"), choicesStack],
      [NSTextField(labelWithString: "Variable"), variableField],
      [NSTextField(labelWithString: "Hotkey"), hotKeyButton],
      [NSGridCell.emptyContentView, save],
    ])
    grid.column(at: 0).xPlacement = .trailing
    grid.rowSpacing = 12
    grid.translatesAutoresizingMaskIntoConstraints = false
    variableField.widthAnchor.constraint(equalToConstant: 200).isActive = true
    let content = window.contentView!
    content.addSubview(grid)
    NSLayoutConstraint.activate([
      grid.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
      grid.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
      grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
      grid.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
    ])
  }

  required init?(coder: NSCoder) { fatalError("unused") }

  func present(config: Config) {
    keyCode = config.keyCode
    modifiers = config.modifiers
    checked = config.choices.map(Set.init)
    variableField.stringValue = config.variable
    reloadVaults(selecting: config.vault)
    updateHotKeyTitle()
    window?.center()
    NSApp.activate(ignoringOtherApps: true)
    showWindow(nil)
  }

  private func reloadVaults(selecting selected: String?) {
    var names = Vault.names()
    if let selected, !names.contains(selected) { names.append(selected) }
    vaultPopUp.removeAllItems()
    vaultPopUp.addItem(withTitle: Self.openVaultTitle)
    vaultPopUp.menu?.addItem(.separator())
    vaultPopUp.addItems(withTitles: names)
    if let selected { vaultPopUp.selectItem(withTitle: selected) }
    reloadChoices()
  }

  private var selectedVault: String? {
    vaultPopUp.indexOfSelectedItem == 0 ? nil : vaultPopUp.titleOfSelectedItem
  }

  @objc private func vaultChanged() {
    checked = nil
    reloadChoices()
  }

  private func reloadChoices() {
    for view in choicesStack.arrangedSubviews { view.removeFromSuperview() }
    let names =
      (try? Vault.resolve(name: selectedVault)).flatMap { try? Choices.names(at: $0.choicesURL) }
      ?? []
    if names.isEmpty {
      choicesStack.addArrangedSubview(NSTextField(labelWithString: "No QuickAdd choices found."))
    }
    for name in names {
      let box = NSButton(checkboxWithTitle: name, target: nil, action: nil)
      box.state = checked.map { $0.contains(name) } ?? true ? .on : .off
      choicesStack.addArrangedSubview(box)
    }
  }

  private var choiceBoxes: [NSButton] {
    choicesStack.arrangedSubviews.compactMap { $0 as? NSButton }
  }

  @objc private func save() {
    let variable = variableField.stringValue.trimmingCharacters(in: .whitespaces)
    guard !variable.isEmpty else { return NSSound.beep() }
    let boxes = choiceBoxes
    let picked = boxes.filter { $0.state == .on }.map(\.title)
    var config = Config.default
    config.vault = selectedVault
    config.variable = variable
    // Every box checked means "all", so choices added to the vault later appear on their own.
    config.choices = picked.count == boxes.count ? nil : picked
    config.keyCode = keyCode
    config.modifiers = modifiers
    do {
      try FileManager.default.createDirectory(
        at: Config.fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
      try config.serialized().write(to: Config.fileURL, atomically: true, encoding: .utf8)
    } catch {
      return onError?(error) ?? ()
    }
    window?.close()
    onSave?()
  }

  func windowWillClose(_ notification: Notification) { stopRecording() }

  // MARK: Hotkey recorder

  @objc private func startRecording() {
    stopRecording()
    hotKeyButton.title = "Press shortcut…"
    onRecording?(true)
    recorder = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self else { return event }
      let mask = Self.carbonModifiers(event.modifierFlags)
      if event.keyCode == UInt16(kVK_Escape) && mask == 0 {
        stopRecording()
        return nil
      }
      // A shortcut without a modifier would swallow a plain key everywhere.
      guard mask != 0 else {
        NSSound.beep()
        return nil
      }
      keyCode = UInt32(event.keyCode)
      modifiers = mask
      stopRecording()
      return nil
    }
  }

  private func stopRecording() {
    if let recorder {
      NSEvent.removeMonitor(recorder)
      self.recorder = nil
      onRecording?(false)
    }
    updateHotKeyTitle()
  }

  private func updateHotKeyTitle() {
    hotKeyButton.title = Self.describe(keyCode: keyCode, modifiers: modifiers)
  }

  private static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
    var mask = 0
    if flags.contains(.command) { mask |= cmdKey }
    if flags.contains(.shift) { mask |= shiftKey }
    if flags.contains(.option) { mask |= optionKey }
    if flags.contains(.control) { mask |= controlKey }
    return UInt32(mask)
  }

  private static func describe(keyCode: UInt32, modifiers: UInt32) -> String {
    var text = ""
    if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
    if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
    if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
    if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
    return text + keyName(keyCode)
  }

  /// Asks the current keyboard layout for the key's character. Carbon has no name table.
  private static func keyName(_ keyCode: UInt32) -> String {
    let fallback = "Key \(keyCode)"
    guard
      let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
      let raw = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
    else { return fallback }
    let layout = unsafeBitCast(raw, to: CFData.self)
    var dead: UInt32 = 0
    var length = 0
    var chars = [UniChar](repeating: 0, count: 4)
    let status = UCKeyTranslate(
      CFDataGetBytePtr(layout).withMemoryRebound(to: UCKeyboardLayout.self, capacity: 1) { $0 },
      UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
      OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, chars.count, &length, &chars)
    guard status == noErr, length > 0 else { return fallback }
    return String(utf16CodeUnits: chars, count: length).uppercased()
  }
}
