import AppKit
import Foundation

let output = URL(fileURLWithPath: CommandLine.arguments[1])
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size, flipped: false) { rect in
    let background = NSBezierPath(
        roundedRect: rect.insetBy(dx: 58, dy: 58),
        xRadius: 225, yRadius: 225
    )
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.27)
    shadow.shadowBlurRadius = 48
    shadow.shadowOffset = NSSize(width: 0, height: -20)
    shadow.set()
    NSGradient(
        starting: NSColor(calibratedRed: 0.055, green: 0.16, blue: 0.22, alpha: 1),
        ending: NSColor(calibratedRed: 0.055, green: 0.36, blue: 0.33, alpha: 1)
    )!.draw(in: background, angle: -38)
    NSShadow().set()

    let highlight = NSBezierPath()
    highlight.move(to: NSPoint(x: 176, y: 762))
    highlight.curve(
        to: NSPoint(x: 790, y: 798),
        controlPoint1: NSPoint(x: 325, y: 918),
        controlPoint2: NSPoint(x: 636, y: 916)
    )
    highlight.lineWidth = 7
    highlight.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.13).setStroke()
    highlight.stroke()

    let branch = NSBezierPath()
    branch.move(to: NSPoint(x: 366, y: 260))
    branch.line(to: NSPoint(x: 366, y: 680))
    branch.curve(
        to: NSPoint(x: 648, y: 510),
        controlPoint1: NSPoint(x: 366, y: 480),
        controlPoint2: NSPoint(x: 505, y: 510)
    )
    branch.lineWidth = 78
    branch.lineCapStyle = .round
    branch.lineJoinStyle = .round
    NSColor(calibratedRed: 0.75, green: 0.98, blue: 0.88, alpha: 1).setStroke()
    branch.stroke()

    func node(_ x: CGFloat, _ y: CGFloat, accent: Bool = false) {
        let outer = NSBezierPath(
            ovalIn: NSRect(x: x - 63, y: y - 63, width: 126, height: 126)
        )
        NSColor(calibratedRed: 0.75, green: 0.98, blue: 0.88, alpha: 1).setFill()
        outer.fill()
        let inner = NSBezierPath(
            ovalIn: NSRect(x: x - 32, y: y - 32, width: 64, height: 64)
        )
        (accent
            ? NSColor(calibratedRed: 0.97, green: 0.76, blue: 0.37, alpha: 1)
            : NSColor(calibratedRed: 0.055, green: 0.28, blue: 0.29, alpha: 1)
        ).setFill()
        inner.fill()
    }
    node(366, 260)
    node(366, 680)
    node(648, 510, accent: true)
    return true
}

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render app icon")
}
try png.write(to: output)
