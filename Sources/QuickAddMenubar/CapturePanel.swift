import AppKit

/// The floating prompt: one row of destinations over one text field. It never activates the
/// app, so the window you were typing in keeps focus once the panel closes.
final class CapturePanel: NSPanel, NSTextFieldDelegate {
  var onSubmit: ((_ choice: String, _ text: String) -> Void)?

  private let field = NSTextField()
  private let chips = NSStackView()
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

    field.isBordered = false
    field.drawsBackground = false
    field.focusRingType = .none
    field.font = .systemFont(ofSize: 22)
    field.placeholderString = "Capture…"
    field.delegate = self

    warning.font = .systemFont(ofSize: 12)
    warning.textColor = .systemOrange
    warning.preferredMaxLayoutWidth = 484

    let stack = NSStackView(views: [chips, field, warning])
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
      field.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -36),
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
    field.stringValue = ""
    refreshChips()

    // Open on the screen that holds the pointer: that is where the user is looking.
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? .main
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

  private func cycle(_ step: Int) {
    selected = (selected + step + choices.count) % choices.count
    refreshChips()
  }

  private func submit() {
    let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty, choices.indices.contains(selected) else { return }
    let choice = choices[selected]
    orderOut(nil)
    onSubmit?(choice, text)
  }

  func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
    switch selector {
    case #selector(insertNewline(_:)):
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
