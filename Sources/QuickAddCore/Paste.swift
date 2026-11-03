import Foundation

/// The text a paste inserts for files copied in Finder: their paths, one space apart.
public func pastePaths(_ urls: [URL]) -> String {
  urls.filter(\.isFileURL).map(\.path).joined(separator: " ")
}
