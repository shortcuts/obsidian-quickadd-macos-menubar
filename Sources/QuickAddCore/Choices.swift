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

  public static func names(at url: URL) throws -> [String] {
    try names(in: Data(contentsOf: url))
  }
}
