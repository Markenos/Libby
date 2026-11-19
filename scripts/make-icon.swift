// Renders the Libby app icon: a soft blue gradient squircle with a stacked-tray glyph.
import AppKit
let size: CGFloat = 1024
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let inset: CGFloat = 100
let rect = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
let path = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
NSGradient(colors: [NSColor(calibratedRed: 0.36, green: 0.62, blue: 1, alpha: 1),
                    NSColor(calibratedRed: 0.42, green: 0.32, blue: 0.95, alpha: 1)])!.draw(in: path, angle: -60)
NSColor(white: 1, alpha: 0.18).setStroke(); path.lineWidth = 6; path.stroke()
let cfg = NSImage.SymbolConfiguration(pointSize: 430, weight: .regular)
    .applying(.init(paletteColors: [.white]))
if let sym = NSImage(systemSymbolName: "tray.full", accessibilityDescription: nil)?.withSymbolConfiguration(cfg) {
    let s = sym.size
    sym.draw(in: NSRect(x: (size - s.width) / 2, y: (size - s.height) / 2, width: s.width, height: s.height))
}
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
