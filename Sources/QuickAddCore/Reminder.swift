import Foundation

public enum Reminder {
  public static let titleLimit = 60

  /// First line of the capture, cut to `titleLimit` characters. The full text stays in the vault.
  public static func title(for text: String) -> String {
    let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.count > titleLimit else { return trimmed }
    return String(trimmed.prefix(titleLimit)).trimmingCharacters(in: .whitespaces) + "…"
  }

  /// Opens the vault. QuickAdd's own URI would run the choice a second time.
  public static func vaultURL(vault: String) -> URL {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    let name = vault.addingPercentEncoding(withAllowedCharacters: allowed) ?? vault
    return URL(string: "obsidian://open?vault=\(name)")!
  }
}
