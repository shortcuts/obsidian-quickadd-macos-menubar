import Foundation

/// Builds `obsidian://quickadd?...`. `value-<variable>` fills `{{VALUE:<variable>}}`, so the
/// choice runs without a prompt.
public func quickAddURL(vault: String, choice: String, variable: String, value: String) -> URL {
  // URLComponents leaves `&` and `+` raw in query values, which would split the text.
  var allowed = CharacterSet.alphanumerics
  allowed.insert(charactersIn: "-._~")
  func encode(_ s: String) -> String {
    s.addingPercentEncoding(withAllowedCharacters: allowed) ?? s
  }

  var components = URLComponents()
  components.scheme = "obsidian"
  components.host = "quickadd"
  components.percentEncodedQuery =
    "vault=\(encode(vault))&choice=\(encode(choice))&value-\(encode(variable))=\(encode(value))"
  return components.url!
}
