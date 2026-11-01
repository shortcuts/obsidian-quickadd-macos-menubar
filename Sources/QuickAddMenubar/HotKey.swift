import Carbon.HIToolbox

/// A global hotkey. Carbon is the only API that needs no Accessibility permission.
final class HotKey {
  private var ref: EventHotKeyRef?
  private var handler: EventHandlerRef?
  private let action: () -> Void

  init?(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
    self.action = action

    var spec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let status = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, context in
        guard let context else { return OSStatus(eventNotHandledErr) }
        Unmanaged<HotKey>.fromOpaque(context).takeUnretainedValue().action()
        return noErr
      }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    guard status == noErr else { return nil }

    // RegisterEventHotKey fails when another app owns the combination.
    let id = EventHotKeyID(signature: OSType(0x5141_4D42), id: 1)
    guard
      RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &ref) == noErr
    else { return nil }
  }

  deinit {
    if let ref { UnregisterEventHotKey(ref) }
    if let handler { RemoveEventHandler(handler) }
  }
}
