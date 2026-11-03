import AppKit

/// The font of the capture field.
public let captureFont = NSFont.systemFont(ofSize: 22)

/// The height of the capture field: its content, at least one line, at most a fifth of the
/// screen. Past that height the field scrolls.
public func captureFieldHeight(content: CGFloat, screen: CGFloat) -> CGFloat {
  let line = NSLayoutManager().defaultLineHeight(for: captureFont)
  return max(min(content, screen * 0.2), line)
}
