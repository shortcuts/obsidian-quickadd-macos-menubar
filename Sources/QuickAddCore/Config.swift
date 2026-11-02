import Carbon.HIToolbox
import Foundation

/// Settings from `~/.config/quickadd-menubar/config.toml`. Every key is optional.
public struct Config: Equatable {
  /// `nil` selects the vault that Obsidian has open.
  public var vault: String?
  /// The `{{VALUE:<variable>}}` name that the QuickAdd choices read.
  public var variable: String
  /// The choices to show, in this order. `nil` shows every QuickAdd choice.
  public var choices: [String]?
  /// A virtual key code. Carbon has no name table, so the file stores the number.
  public var keyCode: UInt32
  /// A Carbon modifier mask.
  public var modifiers: UInt32

  public static let `default` = Config(
    vault: nil,
    variable: "text",
    choices: nil,
    keyCode: UInt32(kVK_ANSI_Semicolon),
    modifiers: UInt32(cmdKey | shiftKey)
  )

  public static var fileURL: URL {
    URL(fileURLWithPath: NSHomeDirectory())
      .appendingPathComponent(".config/quickadd-menubar/config.toml")
  }

  private static let modifierMasks: [String: Int] = [
    "cmd": cmdKey, "shift": shiftKey, "option": optionKey, "alt": optionKey,
    "control": controlKey, "ctrl": controlKey,
  ]

  /// A missing file gives the defaults. An unreadable file throws, so a typo never
  /// silently falls back to a hotkey the user did not choose.
  public static func load(from url: URL = fileURL) throws -> Config {
    guard FileManager.default.fileExists(atPath: url.path) else { return .default }
    return try parse(String(contentsOf: url, encoding: .utf8))
  }

  public static func parse(_ text: String) throws -> Config {
    var config = Config.default
    for (key, value) in try TOML.parse(text) {
      switch (key, value) {
      case ("vault", .string(let name)):
        config.vault = name
      case ("variable", .string(let name)):
        guard !name.isEmpty else { throw invalid("`variable` is empty") }
        config.variable = name
      case ("choices", .strings(let names)):
        config.choices = names
      case ("key_code", .int(let code)):
        guard let code = UInt32(exactly: code) else { throw invalid("`key_code` is negative") }
        config.keyCode = code
      case ("modifiers", .strings(let names)):
        config.modifiers = try mask(names)
      case ("vault", _), ("variable", _):
        throw invalid("`\(key)` must be a string")
      case ("choices", _), ("modifiers", _):
        throw invalid("`\(key)` must be a list of strings")
      case ("key_code", _):
        throw invalid("`key_code` must be a number")
      default:
        throw invalid("unknown key `\(key)`")
      }
    }
    return config
  }

  /// The text that the Settings window saves. Comments are not kept, so a hand edit loses them.
  public func serialized() -> String {
    func quoted(_ text: String) -> String {
      let escaped = text.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
        .replacingOccurrences(of: "\t", with: "\\t")
      return "\"\(escaped)\""
    }
    var lines: [String] = []
    if let vault { lines.append("vault = \(quoted(vault))") }
    if let choices { lines.append("choices = [\(choices.map(quoted).joined(separator: ", "))]") }
    lines.append("variable = \(quoted(variable))")
    lines.append("key_code = \(keyCode)")
    let names = Self.canonicalModifiers.filter { modifiers & UInt32($0.1) != 0 }.map {
      quoted($0.0)
    }
    lines.append("modifiers = [\(names.joined(separator: ", "))]")
    return lines.joined(separator: "\n") + "\n"
  }

  private static let canonicalModifiers: [(String, Int)] = [
    ("cmd", cmdKey), ("shift", shiftKey), ("option", optionKey), ("control", controlKey),
  ]

  private static func mask(_ names: [String]) throws -> UInt32 {
    var mask = 0
    for name in names {
      guard let bit = modifierMasks[name.lowercased()] else {
        throw invalid("unknown modifier \"\(name)\"")
      }
      mask |= bit
    }
    guard mask != 0 else {
      throw invalid("`modifiers` is empty, so the hotkey would eat a plain key")
    }
    return UInt32(mask)
  }

  private static func invalid(_ reason: String) -> QuickAddError {
    .invalidConfig(reason)
  }
}
