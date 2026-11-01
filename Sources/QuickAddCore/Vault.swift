import Foundation

public struct Vault: Equatable {
  public let name: String
  public let path: URL

  public init(path: URL) {
    self.path = path
    self.name = path.lastPathComponent
  }

  /// The QuickAdd plugin stores its choices here.
  public var choicesURL: URL {
    path.appendingPathComponent(".obsidian/plugins/quickadd/data.json")
  }

  public static var registryURL: URL {
    URL(fileURLWithPath: NSHomeDirectory())
      .appendingPathComponent("Library/Application Support/obsidian/obsidian.json")
  }

  private struct Registry: Decodable {
    struct Entry: Decodable {
      let path: String
      let open: Bool?
    }
    let vaults: [String: Entry]
  }

  /// Reads Obsidian's own vault list (`obsidian.json`). Without a name, the open vault
  /// wins, so the hotkey follows the vault the user is working in.
  public static func resolve(name: String?, registry data: Data) throws -> Vault {
    guard let registry = try? JSONDecoder().decode(Registry.self, from: data) else {
      throw QuickAddError.vaultNotFound(name)
    }
    // Dictionary order is random. Sort so the choice is stable between runs.
    let entries = registry.vaults.values.sorted { $0.path < $1.path }
    let match: Registry.Entry?
    if let name {
      match = entries.first { URL(fileURLWithPath: $0.path).lastPathComponent == name }
    } else {
      match = entries.first { $0.open == true } ?? entries.first
    }
    guard let match else { throw QuickAddError.vaultNotFound(name) }
    return Vault(path: URL(fileURLWithPath: match.path))
  }

  /// Folder names of the vaults that Obsidian knows, for the Settings window.
  public static func names(registry data: Data) -> [String] {
    guard let registry = try? JSONDecoder().decode(Registry.self, from: data) else { return [] }
    return registry.vaults.values.map { URL(fileURLWithPath: $0.path).lastPathComponent }.sorted()
  }

  public static func names() -> [String] {
    (try? Data(contentsOf: registryURL)).map { names(registry: $0) } ?? []
  }

  public static func resolve(name: String?) throws -> Vault {
    guard let data = try? Data(contentsOf: registryURL) else {
      throw QuickAddError.vaultNotFound(name)
    }
    return try resolve(name: name, registry: data)
  }
}
