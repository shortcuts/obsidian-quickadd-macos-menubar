import AppKit
import QuickAddCore

/// The floating prompt: one row of destinations over one text field. It never activates the
/// app, so the window you were typing in keeps focus once the panel closes.
final class CapturePanel: NSPanel, NSTextViewDelegate {
  /// `remind` is the due date when the reminder box is checked.
  var onSubmit: ((_ choice: String, _ text: String, _ remind: Date?) -> Void)?

  private let field = CaptureTextView()
  private let scroll = NSScrollView()
  private let placeholder = NSTextField(labelWithString: "Capture…")
  private lazy var fieldHeight = scroll.heightAnchor.constraint(equalToConstant: 0)
  private var screenHeight: CGFloat = 0
  private let chips = NSStackView()
  private let remindBox = NSButton(checkboxWithTitle: "Remind me", target: nil, action: nil)
  private let picker = NSDatePicker()
  private let warning = NSTextField(wrappingLabelWithString: "")
  private var problems: [String: String] = [:]
  private var choices: [String] = []
  private var selected = 0

  init() {
    super.init(
      contentRect: NSRect(x: 0, y: 0, width: 520, height: 92),
      styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    isFloatingPanel = true
    level = .floating
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    hidesOnDeactivate = false
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

    let background = NSVisualEffectView(frame: contentRect(forFrameRect: frame))
    background.material = .hudWindow
    background.state = .active
    background.wantsLayer = true
    background.layer?.cornerRadius = 14
    background.layer?.masksToBounds = true
    contentView = background

    chips.orientation = .horizontal
    chips.spacing = 6

    field.isRichText = false
    field.drawsBackground = false
    field.font = captureFont
    field.textContainerInset = .zero
    // 2 pt matches the text inset of the placeholder label.
    field.textContainer?.lineFragmentPadding = 2
    field.autoresizingMask = .width
    field.isVerticallyResizable = true
    field.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
    field.delegate = self
    placeholder.font = captureFont
    placeholder.textColor = .placeholderTextColor
    placeholder.sizeToFit()
    field.addSubview(placeholder)
    scroll.documentView = field
    scroll.drawsBackground = false
    scroll.hasVerticalScroller = true
    scroll.autohidesScrollers = true

    warning.font = .systemFont(ofSize: 12)
    warning.textColor = .systemOrange
    warning.preferredMaxLayoutWidth = 484

    remindBox.font = .systemFont(ofSize: 12)
    remindBox.target = self
    remindBox.action = #selector(remindToggled)
    picker.datePickerStyle = .textFieldAndStepper
    picker.datePickerElements = [.yearMonthDay, .hourMinute]
    picker.controlSize = .small
    let reminder = NSStackView(views: [remindBox, picker])
    reminder.spacing = 10

    let stack = NSStackView(views: [chips, scroll, reminder, warning])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 12
    stack.edgeInsets = NSEdgeInsets(top: 14, left: 18, bottom: 14, right: 18)
    stack.translatesAutoresizingMaskIntoConstraints = false
    background.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
      stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
      stack.topAnchor.constraint(equalTo: background.topAnchor),
      stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
      scroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
      fieldHeight,
    ])
  }

  override var canBecomeKey: Bool { true }

  override func resignKey() {
    super.resignKey()
    orderOut(nil)
  }

  func show(choices: [String], problems: [String: String], last: String?) {
    self.choices = choices
    self.problems = problems
    selected = last.flatMap { choices.firstIndex(of: $0) } ?? 0
    field.string = ""
    remindBox.state = .off
    picker.isHidden = true
    // The next full hour is a sensible default and is never in the past.
    let hour = Calendar.current.dateInterval(of: .hour, for: Date())?.end
    picker.dateValue = hour ?? Date().addingTimeInterval(3600)

    // Open on the screen that holds the pointer: that is where the user is looking.
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? .main
    screenHeight = screen?.visibleFrame.height ?? 0
    fitField()
    if let area = screen?.visibleFrame {
      setFrameOrigin(
        NSPoint(x: area.midX - frame.width / 2, y: area.minY + area.height * 0.62))
    }
    makeKeyAndOrderFront(nil)
    makeFirstResponder(field)
  }

  private func refreshChips() {
    for chip in chips.arrangedSubviews { chip.removeFromSuperview() }
    for (index, name) in choices.enumerated() {
      let chip = NSTextField(labelWithString: " \(name) ")
      chip.font = .systemFont(ofSize: 12, weight: .medium)
      chip.wantsLayer = true
      chip.layer?.cornerRadius = 5
      if index == selected {
        chip.textColor = .white
        chip.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
      } else {
        chip.textColor = .secondaryLabelColor
        chip.layer?.backgroundColor = NSColor.quaternaryLabelColor.cgColor
      }
      chips.addArrangedSubview(chip)
    }
    let message = problems[choices[selected]]
    warning.stringValue = message.map { "⚠ \($0)" } ?? ""
    warning.isHidden = message == nil
    // Grow downward: keep the top edge where it is.
    let height = (contentView?.subviews.first as? NSStackView)?.fittingSize.height ?? frame.height
    var next = frame
    next.origin.y += next.height - height
    next.size.height = height
    setFrame(next, display: true)
  }

  func textDidChange(_ notification: Notification) {
    fitField()
  }

  private func fitField() {
    placeholder.isHidden = !field.string.isEmpty
    guard let layout = field.layoutManager, let container = field.textContainer else { return }
    layout.ensureLayout(for: container)
    fieldHeight.constant = captureFieldHeight(
      content: layout.usedRect(for: container).height, screen: screenHeight)
    refreshChips()
    field.scrollRangeToVisible(field.selectedRange())
  }

  @objc private func remindToggled() {
    picker.isHidden = remindBox.state == .off
    refreshChips()
  }

  private func cycle(_ step: Int) {
    selected = (selected + step + choices.count) % choices.count
    refreshChips()
  }

  private func submit() {
    let text = field.string.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, choices.indices.contains(selected) else { return }
    let choice = choices[selected]
    orderOut(nil)
    onSubmit?(choice, text, remindBox.state == .on ? picker.dateValue : nil)
  }

  func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
    switch selector {
    case #selector(insertNewline(_:)):
      if NSApp.currentEvent?.modifierFlags.contains(.shift) == true { return false }
      submit()
    case #selector(cancelOperation(_:)):
      orderOut(nil)
    case #selector(insertTab(_:)), #selector(moveDown(_:)):
      cycle(1)
    case #selector(insertBacktab(_:)), #selector(moveUp(_:)):
      cycle(-1)
    default:
      return false
    }
    return true
  }
}

/// Handles Cmd+V itself: the app has no main menu, so no Edit menu routes `paste:`.
private final class CaptureTextView: NSTextView {
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard isPasteModifier(event.modifierFlags),
      event.charactersIgnoringModifiers == "v", window?.firstResponder === self
    else { return super.performKeyEquivalent(with: event) }
    let urls =
      NSPasteboard.general.readObjects(
        forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
    let paths = pastePaths(urls)
    if paths.isEmpty {
      pasteAsPlainText(nil)
    } else {
      insertText(paths, replacementRange: selectedRange())
    }
    return true
  }
}
