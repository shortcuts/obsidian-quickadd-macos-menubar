import Foundation

/// A parser for the small TOML subset that `config.toml` uses: top-level `key = value` lines,
/// comments, strings, integers and one-line string arrays.
// shortcut: no tables, multi-line arrays or booleans, swap in a TOML package if the config grows.
enum TOML {
  enum Value: Equatable {
    case string(String)
    case int(Int)
    case strings([String])
  }

  static func parse(_ text: String) throws -> [String: Value] {
    var table: [String: Value] = [:]
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    for (index, line) in lines.enumerated() {
      func fail(_ reason: String) -> QuickAddError {
        .invalidConfig("line \(index + 1): \(reason)")
      }

      let content = stripComment(String(line)).trimmingCharacters(in: .whitespaces)
      if content.isEmpty { continue }
      guard let equals = content.firstIndex(of: "=") else {
        throw fail("expected `key = value`")
      }
      let key = content[..<equals].trimmingCharacters(in: .whitespaces)
      guard !key.isEmpty, key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" })
      else { throw fail("invalid key \"\(key)\"") }
      guard table[key] == nil else { throw fail("duplicate key \"\(key)\"") }

      let raw = content[content.index(after: equals)...].trimmingCharacters(in: .whitespaces)
      guard let value = value(raw) else { throw fail("invalid value for \"\(key)\"") }
      table[key] = value
    }
    return table
  }

  /// Cuts at the first `#` that sits outside a string.
  private static func stripComment(_ line: String) -> String {
    var quote: Character?
    var escaped = false
    for (offset, char) in line.enumerated() {
      if let open = quote {
        if escaped {
          escaped = false
        } else if char == "\\" && open == "\"" {
          escaped = true
        } else if char == open {
          quote = nil
        }
      } else if char == "\"" || char == "'" {
        quote = char
      } else if char == "#" {
        return String(line.prefix(offset))
      }
    }
    return line
  }

  private static func value(_ raw: String) -> Value? {
    let chars = Array(raw)
    var i = 0
    if chars.first == "[" {
      i = 1
      var items: [String] = []
      while true {
        skipSpaces(chars, &i)
        if i < chars.count, chars[i] == "]" { break }
        guard let item = string(chars, &i) else { return nil }
        items.append(item)
        skipSpaces(chars, &i)
        guard i < chars.count else { return nil }
        if chars[i] == "," {
          i += 1
        } else if chars[i] != "]" {
          return nil
        }
      }
      return i + 1 == chars.count ? .strings(items) : nil
    }
    if let text = string(chars, &i) { return i == chars.count ? .string(text) : nil }
    return Int(raw).map(Value.int)
  }

  private static func skipSpaces(_ chars: [Character], _ i: inout Int) {
    while i < chars.count, chars[i] == " " || chars[i] == "\t" { i += 1 }
  }

  /// Reads a `"basic"` string, with `\"`, `\\`, `\n` and `\t`, or a `'literal'` string.
  private static func string(_ chars: [Character], _ i: inout Int) -> String? {
    guard i < chars.count, chars[i] == "\"" || chars[i] == "'" else { return nil }
    let quote = chars[i]
    i += 1
    var out = ""
    while i < chars.count {
      let char = chars[i]
      i += 1
      if char == quote { return out }
      guard char == "\\", quote == "\"" else {
        out.append(char)
        continue
      }
      guard i < chars.count else { return nil }
      let escape = chars[i]
      i += 1
      switch escape {
      case "n": out.append("\n")
      case "t": out.append("\t")
      case "\"", "\\": out.append(escape)
      default: return nil
      }
    }
    return nil
  }
}
