import Carbon.HIToolbox
import Foundation
import Testing

@testable import QuickAddCore

@Suite struct QuickAddURLTests {
  @Test func encodesReservedCharacters() {
    let url = quickAddURL(
      vault: "my notes", choice: "Add Todo", variable: "text", value: "a&b+c=d 100%")
    #expect(
      url.absoluteString
        == "obsidian://quickadd?vault=my%20notes&choice=Add%20Todo&value-text=a%26b%2Bc%3Dd%20100%25"
    )
  }

  @Test func encodesNonAscii() {
    let url = quickAddURL(vault: "v", choice: "c", variable: "text", value: "café ☕")
    #expect(url.absoluteString.hasSuffix("value-text=caf%C3%A9%20%E2%98%95"))
  }

  @Test func keepsNewlinesOutOfTheQuery() {
    let url = quickAddURL(vault: "v", choice: "c", variable: "text", value: "a\nb")
    #expect(url.absoluteString.hasSuffix("value-text=a%0Ab"))
  }
}

@Suite struct ChoicesTests {
  @Test func listsTopLevelChoices() throws {
    let data = Data(
      #"{"choices":[{"name":"TODO","type":"Capture"},{"name":"Daily","type":"Capture"}]}"#.utf8)
    #expect(try Choices.names(in: data) == ["TODO", "Daily"])
  }

  @Test func flattensMultiChoices() throws {
    let data = Data(
      #"""
      {"choices":[
        {"name":"Folder","type":"Multi","choices":[{"name":"Inner","type":"Template"}]},
        {"name":"Top","type":"Macro"}
      ]}
      """#.utf8)
    #expect(try Choices.names(in: data) == ["Inner", "Top"])
  }

  @Test func ignoresUnknownKeys() throws {
    let data = Data(
      #"{"version":"2","choices":[{"id":"x","name":"A","type":"Capture","format":{}}]}"#.utf8)
    #expect(try Choices.names(in: data) == ["A"])
  }
}

@Suite struct ProblemsTests {
  private func problems(_ json: String, variable: String = "text") throws -> [String: String] {
    Dictionary(
      uniqueKeysWithValues: try Choices.problems(in: Data(json.utf8), variable: variable)
        .map { ($0.name, $0.message) })
  }

  @Test func flagsBareValue() throws {
    let found = try problems(
      #"{"choices":[{"name":"A","type":"Capture","format":{"format":"- {{VALUE}}"}}]}"#)
    #expect(found["A"]?.contains("{{VALUE}}") == true)
    #expect(found["A"]?.contains("{{VALUE:text}}") == true)
  }

  @Test func flagsOtherNamesAndBareNameAndMacroValue() throws {
    let found = try problems(
      #"""
      {"choices":[
        {"name":"A","type":"Capture","format":"{{VALUE:title}}"},
        {"name":"B","type":"Template","fileName":"{{NAME}}"},
        {"name":"C","type":"Capture","format":"{{MVALUE}}"}
      ]}
      """#)
    #expect(Set(found.keys) == ["A", "B", "C"])
  }

  @Test func acceptsTheConfiguredVariable() throws {
    let found = try problems(
      #"""
      {"choices":[
        {"name":"A","type":"Capture","format":"{{VALUE:text}}"},
        {"name":"B","type":"Capture","format":"{{value: text | trim}}"},
        {"name":"C","type":"Capture","format":"{{DATE:YYYY}} {{VALUE:text|case:lower}}"}
      ]}
      """#)
    #expect(found.isEmpty)
  }

  @Test func usesTheConfiguredVariableInTheAdvice() throws {
    let found = try problems(
      #"{"choices":[{"name":"A","type":"Capture","format":"{{VALUE}}"}]}"#, variable: "note")
    #expect(found["A"]?.contains("{{VALUE:note}}") == true)
  }

  @Test func looksInsideMultiChoicesAndKeepsFolderOut() throws {
    let found = try problems(
      #"""
      {"choices":[{"name":"Folder","type":"Multi","choices":[
        {"name":"Inner","type":"Capture","format":"{{VALUE}}"},
        {"name":"Fine","type":"Capture","format":"{{VALUE:text}}"}
      ]}]}
      """#)
    #expect(Set(found.keys) == ["Inner"])
  }
}

@Suite struct VaultTests {
  private let registry = Data(
    #"""
    {"vaults":{
      "a":{"path":"/Users/me/work"},
      "b":{"path":"/Users/me/notes","open":true}
    }}
    """#.utf8)

  @Test func prefersTheOpenVault() throws {
    #expect(try Vault.resolve(name: nil, registry: registry).name == "notes")
  }

  @Test func matchesByFolderName() throws {
    #expect(try Vault.resolve(name: "work", registry: registry).name == "work")
  }

  @Test func throwsOnUnknownName() {
    #expect(throws: QuickAddError.vaultNotFound("nope")) {
      try Vault.resolve(name: "nope", registry: registry)
    }
  }

  @Test func locatesTheQuickAddData() throws {
    let vault = try Vault.resolve(name: "notes", registry: registry)
    #expect(vault.choicesURL.path == "/Users/me/notes/.obsidian/plugins/quickadd/data.json")
  }
}

@Suite struct SelectTests {
  @Test func keepsEverythingWithoutASetting() {
    #expect(Choices.select(from: ["A", "B"], wanted: nil) == ["A", "B"])
  }

  @Test func followsTheWantedOrder() {
    #expect(Choices.select(from: ["A", "B", "C"], wanted: ["C", "A"]) == ["C", "A"])
  }

  @Test func dropsNamesTheVaultLacks() {
    #expect(Choices.select(from: ["A"], wanted: ["Gone", "A"]) == ["A"])
  }
}

@Suite struct TOMLTests {
  @Test func parsesStringsIntegersAndArrays() throws {
    let table = try TOML.parse(
      """
      a = "x"
      b = 41
      c = ["p", 'q']
      """)
    #expect(table == ["a": .string("x"), "b": .int(41), "c": .strings(["p", "q"])])
  }

  @Test func ignoresCommentsAndBlankLines() throws {
    let table = try TOML.parse(
      """
      # heading

      a = "x" # trailing
      """)
    #expect(table == ["a": .string("x")])
  }

  @Test func keepsHashInsideStrings() throws {
    #expect(try TOML.parse(#"a = "x # y""#) == ["a": .string("x # y")])
  }

  @Test func readsEscapes() throws {
    #expect(try TOML.parse(#"a = "q\"uote\\""#) == ["a": .string("q\"uote\\")])
  }

  @Test func allowsTrailingCommaAndEmptyArray() throws {
    #expect(try TOML.parse(#"a = ["x",]"#) == ["a": .strings(["x"])])
    #expect(try TOML.parse("a = []") == ["a": .strings([])])
  }

  @Test(arguments: [
    "[table]", "a", "a = ", "a = tru", #"a = "open"#, #"a = ["x" "y"]"#, "a = [\"x\"",
    #"a = "x" junk"#, "a = 1\na = 2", "= 1",
  ])
  func rejectsMalformedInput(_ text: String) {
    #expect(throws: QuickAddError.self) { try TOML.parse(text) }
  }
}

@Suite struct ConfigTests {
  @Test func emptyFileGivesDefaults() throws {
    #expect(try Config.parse("") == .default)
  }

  @Test func overridesEachKey() throws {
    let config = try Config.parse(
      """
      vault = "v"
      variable = "x"
      choices = ["B", "A"]
      reminder_list = "Inbox"
      key_code = 0
      modifiers = ["ctrl", "Option"]
      """)
    #expect(config.vault == "v")
    #expect(config.variable == "x")
    #expect(config.choices == ["B", "A"])
    #expect(config.reminderList == "Inbox")
    #expect(config.keyCode == 0)
    #expect(config.modifiers == UInt32(controlKey | optionKey))
  }

  @Test(arguments: [
    #"modifiers = ["hyper"]"#, "modifiers = []", #"variable = """#, "key_code = -1",
    #"key_code = "41""#, #"vault = 3"#, #"choices = "TODO""#, #"typo = "x""#,
    #"reminder_list = """#, "reminder_list = 3",
  ])
  func rejectsInvalidSettings(_ text: String) {
    #expect(throws: QuickAddError.self) { try Config.parse(text) }
  }

  @Test func reportsTheLineOfASyntaxError() {
    #expect(throws: QuickAddError.invalidConfig("line 2: expected `key = value`")) {
      try Config.parse("variable = \"x\"\noops")
    }
  }

  @Test(arguments: [
    Config.default,
    Config(
      vault: "My \"Vault\" \\ #1", variable: "x", choices: ["B", "A#"], reminderList: "L \"1\"",
      keyCode: 0,
      modifiers: UInt32(controlKey | optionKey | cmdKey | shiftKey)),
    Config(
      vault: nil, variable: "text", choices: [], reminderList: "QuickAdd", keyCode: 12,
      modifiers: UInt32(cmdKey)),
  ])
  func serializedConfigParsesBack(_ config: Config) throws {
    #expect(try Config.parse(config.serialized()) == config)
  }
}

@Suite struct VaultNamesTests {
  @Test func listsVaultFolderNamesSorted() {
    let json = #"{"vaults":{"a":{"path":"/x/Zeta"},"b":{"path":"/y/Alpha","open":true}}}"#
    #expect(Vault.names(registry: Data(json.utf8)) == ["Alpha", "Zeta"])
  }

  @Test func badRegistryGivesNoNames() {
    #expect(Vault.names(registry: Data("nope".utf8)).isEmpty)
  }
}

@Suite struct ReminderTests {
  @Test func keepsShortTitles() {
    #expect(Reminder.title(for: "  buy milk ") == "buy milk")
  }

  @Test func usesTheFirstLine() {
    #expect(Reminder.title(for: "first\nsecond") == "first")
  }

  @Test func cutsLongTitles() {
    let title = Reminder.title(for: String(repeating: "a", count: 100))
    #expect(title == String(repeating: "a", count: 60) + "…")
  }

  @Test func keepsATitleOfExactlyTheLimit() {
    let text = String(repeating: "é", count: 60)
    #expect(Reminder.title(for: text) == text)
  }

  @Test func encodesTheVaultName() {
    #expect(
      Reminder.vaultURL(vault: "my & notes").absoluteString
        == "obsidian://open?vault=my%20%26%20notes")
  }
}
