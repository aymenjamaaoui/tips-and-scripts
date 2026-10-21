#!/usr/bin/env swift
// Make a 1024x1024 PNG icon: the icon of an app with a round badge image at the top left.
//
// Usage: swift make-icon.swift <app> <badge image> <output.png>

import AppKit

let canvasSize: CGFloat = 1024
// Size and place of the badge. AppKit puts y = 0 at the bottom of the image.
let badgeSize: CGFloat = 600
let badgeMargin: CGFloat = 24
let badgeRect = NSRect(
    x: badgeMargin,
    y: canvasSize - badgeMargin - badgeSize,
    width: badgeSize,
    height: badgeSize
)
let borderWidth: CGFloat = 18

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

let args = CommandLine.arguments
guard args.count == 4 else {
    fail("Usage: swift make-icon.swift <app> <badge image> <output.png>")
}
let appPath = args[1]
let badgePath = args[2]
let outputPath = args[3]

guard FileManager.default.fileExists(atPath: appPath) else {
    fail("Error: app not found: \(appPath)")
}
guard let badge = NSImage(contentsOfFile: badgePath), badge.size.width > 0, badge.size.height > 0 else {
    fail("Error: cannot read the badge image: \(badgePath)")
}
let appIcon = NSWorkspace.shared.icon(forFile: appPath)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize),
    pixelsHigh: Int(canvasSize),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fail("Error: cannot create the image.")
}
bitmap.size = NSSize(width: canvasSize, height: canvasSize)

guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fail("Error: cannot create the drawing context.")
}
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high

appIcon.draw(in: NSRect(x: 0, y: 0, width: canvasSize, height: canvasSize))

// White circle for the border, then the badge in a smaller circle on top.
NSColor.white.setFill()
NSBezierPath(ovalIn: badgeRect).fill()

// Keep the center square of the badge image if it is not square.
let side = min(badge.size.width, badge.size.height)
let badgeSquare = NSRect(
    x: (badge.size.width - side) / 2,
    y: (badge.size.height - side) / 2,
    width: side,
    height: side
)
let imageRect = badgeRect.insetBy(dx: borderWidth, dy: borderWidth)
NSGraphicsContext.saveGraphicsState()
NSBezierPath(ovalIn: imageRect).addClip()
badge.draw(in: imageRect, from: badgeSquare, operation: .sourceOver, fraction: 1)
NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fail("Error: cannot encode the PNG.")
}
do {
    try png.write(to: URL(fileURLWithPath: outputPath))
} catch {
    fail("Error: cannot write \(outputPath): \(error.localizedDescription)")
}
