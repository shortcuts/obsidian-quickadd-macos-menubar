// Usage: swift Resources/make-icon.swift Resources/AppIcon.icns
import AppKit

func render(_ px: Int) -> Data {
  let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
    bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let s = CGFloat(px)
  let tile = NSRect(x: s * 0.0977, y: s * 0.0977, width: s * 0.8047, height: s * 0.8047)
  let path = NSBezierPath(roundedRect: tile, xRadius: s * 0.18, yRadius: s * 0.18)
  NSGradient(
    starting: NSColor(red: 0.45, green: 0.35, blue: 0.95, alpha: 1),
    ending: NSColor(red: 0.25, green: 0.2, blue: 0.7, alpha: 1))!.draw(in: path, angle: -90)
  let config = NSImage.SymbolConfiguration(pointSize: s * 0.45, weight: .regular)
    .applying(.init(paletteColors: [.white]))
  let glyph = NSImage(systemSymbolName: "square.and.pencil", accessibilityDescription: nil)!
    .withSymbolConfiguration(config)!
  let g = glyph.size
  glyph.draw(in: NSRect(x: (s - g.width) / 2, y: (s - g.height) / 2, width: g.width, height: g.height))
  NSGraphicsContext.restoreGraphicsState()
  return rep.representation(using: .png, properties: [:])!
}

let out = CommandLine.arguments[1]
let set = NSTemporaryDirectory() + "AppIcon.iconset"
try? FileManager.default.removeItem(atPath: set)
try FileManager.default.createDirectory(atPath: set, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
  try render(base).write(to: URL(fileURLWithPath: "\(set)/icon_\(base)x\(base).png"))
  try render(base * 2).write(to: URL(fileURLWithPath: "\(set)/icon_\(base)x\(base)@2x.png"))
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set, "-o", out]
try p.run()
p.waitUntilExit()
exit(p.terminationStatus)
