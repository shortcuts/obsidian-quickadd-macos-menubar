import Foundation

public enum Choices {
  private struct Root: Decodable {
    let choices: [Choice]
  }

  private struct Choice: Decodable {
    let name: String
    let type: String
    let choices: [Choice]?
  }

  /// Lists the names QuickAdd accepts in `choice=`. A `Multi` choice is a folder, so its
  /// children count and the folder itself does not.
  public static func names(in data: Data) throws -> [String] {
    func flatten(_ choices: [Choice]) -> [String] {
      choices.flatMap { $0.type == "Multi" ? flatten($0.choices ?? []) : [$0.name] }
    }
    return flatten(try JSONDecoder().decode(Root.self, from: data).choices)
  }

  /// Applies the `choices` setting. Wanted names that the vault lacks drop out, so a renamed
  /// choice does not break the others.
  public static func select(from available: [String], wanted: [String]?) -> [String] {
    guard let wanted else { return available }
    return wanted.filter(available.contains)
  }

  public struct Problem: Equatable {
    public let name: String
    public let message: String
  }

  /// Flags choices whose placeholders QuickAdd cannot fill from the URI: a bare `{{VALUE}}`,
  /// `{{NAME}}` or `{{MVALUE}}`, or a `{{VALUE:<other>}}`. QuickAdd prompts for those inside
  /// Obsidian, which defeats the app. Text in files that a choice links to is not scanned.
  public static func problems(in data: Data, variable: String) throws -> [Problem] {
    let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    var found: [Problem] = []

    func strings(in value: Any) -> [String] {
      switch value {
      case let text as String: return [text]
      case let list as [Any]: return list.flatMap(strings)
      case let object as [String: Any]: return object.values.flatMap(strings)
      default: return []
      }
    }

    func visit(_ choices: [Any]) {
      for case let choice as [String: Any] in choices {
        if choice["type"] as? String == "Multi" {
          visit(choice["choices"] as? [Any] ?? [])
          continue
        }
        var bad: [String] = []
        for text in strings(in: choice.filter { $0.key != "choices" }) {
          for token in placeholders(in: text, variable: variable) where !bad.contains(token) {
            bad.append(token)
          }
        }
        guard !bad.isEmpty, let name = choice["name"] as? String else { continue }
        found.append(
          Problem(
            name: name,
            message:
              "Obsidian will ask for input because of \(bad.joined(separator: ", ")). "
              + "Replace it with {{VALUE:\(variable)}} in this choice."))
      }
    }
    visit(root?["choices"] as? [Any] ?? [])
    return found
  }

  private static func placeholders(in text: String, variable: String) -> [String] {
    let pattern = #"\{\{\s*(VALUE|NAME|MVALUE)\s*(?::([^}|]*))?[^}]*\}\}"#
    let regex = try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    let whole = NSRange(text.startIndex..., in: text)
    return regex.matches(in: text, range: whole).compactMap { match in
      let kind = (text as NSString).substring(with: match.range(at: 1)).uppercased()
      let argument = Range(match.range(at: 2), in: text).map {
        text[$0].trimmingCharacters(in: .whitespaces)
      }
      switch (kind, argument) {
      case ("VALUE", let name?) where name == variable: return nil
      case ("VALUE", _), (_, nil): return (text as NSString).substring(with: match.range)
      default: return nil
      }
    }
  }

  public static func problems(at url: URL, variable: String) throws -> [Problem] {
    try problems(in: Data(contentsOf: url), variable: variable)
  }

  public static func names(at url: URL) throws -> [String] {
    try names(in: Data(contentsOf: url))
  }
}
