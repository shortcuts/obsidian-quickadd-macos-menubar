import Foundation

public enum QuickAddError: Error, LocalizedError, Equatable {
  case vaultNotFound(String?)
  case noChoices(String)
  case noMatchingChoices(vault: String, available: [String])
  case invalidConfig(String)

  public var errorDescription: String? {
    switch self {
    case .vaultNotFound(let name?):
      return "No Obsidian vault named \"\(name)\". Check `vault` in the config file."
    case .vaultNotFound(nil):
      return "No Obsidian vault found. Open a vault in Obsidian once, then try again."
    case .noChoices(let vault):
      return "The vault \"\(vault)\" has no QuickAdd choices. Is the QuickAdd plugin installed?"
    case .noMatchingChoices(let vault, let available):
      return
        "None of the `choices` in the config exist in \"\(vault)\". Available: \(available.joined(separator: ", "))."
    case .invalidConfig(let reason):
      return "Invalid config file: \(reason)"
    }
  }
}
