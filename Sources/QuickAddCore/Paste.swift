import AppKit
import Foundation

/// The text a paste inserts for files copied in Finder: their paths, one space apart.
public func pastePaths(_ urls: [URL]) -> String {
  urls.filter(\.isFileURL).map(\.path).joined(separator: " ")
}

/// True when the flags are Cmd alone, ignoring Caps Lock, Fn and the numeric-pad bit.
public func isPasteModifier(_ flags: NSEvent.ModifierFlags) -> Bool {
  flags.intersection([.command, .shift, .option, .control]) == .command
}
