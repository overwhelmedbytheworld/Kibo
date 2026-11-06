import AppKit

public enum MenuBarIconStyle: String, CaseIterable, Identifiable, Sendable {
    case color = "color"
    case monochrome = "monochrome"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .color: "Full Color"
        case .monochrome: "Monochrome"
        }
    }
}

@MainActor
public enum MenuBarIcon {
    public static var currentStyle: MenuBarIconStyle {
        let saved = UserDefaults.standard.string(forKey: "appearance.menuBarIconStyle") ?? MenuBarIconStyle.color.rawValue
        return MenuBarIconStyle(rawValue: saved) ?? .color
    }

    public static var image: NSImage {
        image(for: currentStyle)
    }

    public static func image(for style: MenuBarIconStyle) -> NSImage {
        switch style {
        case .color:
            return colorImage
        case .monochrome:
            return monochromeImage
        }
    }

    /// The full-color Liquid Glass app icon (isTemplate = false).
    public static var colorImage: NSImage {
        let base: NSImage
        if let icon = NSImage(named: NSImage.applicationIconName), icon.isValid {
            base = icon
        } else if let bundleIcon = Bundle.main.image(forResource: "AppIcon"), bundleIcon.isValid {
            base = bundleIcon
        } else if let path = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
                  let icon = NSImage(contentsOfFile: path), icon.isValid {
            base = icon
        } else if let icon = NSApp.applicationIconImage, icon.isValid {
            base = icon
        } else if let fallback = NSImage(contentsOfFile: "Resources/AppIcon.icns"), fallback.isValid {
            base = fallback
        } else {
            return NSImage(systemSymbolName: "chevron.right.square.fill", accessibilityDescription: "Kibo") ?? NSImage()
        }

        let copy = (base.copy() as? NSImage) ?? base
        copy.size = NSSize(width: 18, height: 18) // grid: ok macOS status bar standard icon size
        copy.isTemplate = false
        return copy
    }

    /// The black and white normal matching menu bar icon (isTemplate = true).
    /// Retains the exact keycap shape and prompt chevron cutout from AppIcon.icon,
    /// adapting automatically to light and dark macOS menu bars.
    public static var monochromeImage: NSImage {
        let size = NSSize(width: 18, height: 18) // grid: ok macOS status bar standard icon size
        let img = NSImage(size: size, flipped: false) { _ in
            let cx: CGFloat = 9.0
            let cy: CGFloat = 9.0
            let s: CGFloat = 15.0 / 460.0

            let path = NSBezierPath(
                roundedRect: NSRect(x: cx - 230.0 * s, y: cy - 230.0 * s, width: 460.0 * s, height: 460.0 * s),
                xRadius: 88.0 * s,
                yRadius: 88.0 * s
            )

            let chevron = NSBezierPath()
            chevron.move(to: NSPoint(x: cx - 110.0 * s, y: cy + 130.0 * s))
            chevron.line(to: NSPoint(x: cx + 30.0 * s, y: cy))
            chevron.line(to: NSPoint(x: cx - 110.0 * s, y: cy - 130.0 * s))
            chevron.line(to: NSPoint(x: cx - 30.0 * s, y: cy - 130.0 * s))
            chevron.line(to: NSPoint(x: cx + 110.0 * s, y: cy))
            chevron.line(to: NSPoint(x: cx - 30.0 * s, y: cy + 130.0 * s))
            chevron.close()

            path.append(chevron)
            path.windingRule = .evenOdd

            NSColor.black.setFill()
            path.fill()
            return true
        }
        img.isTemplate = true
        return img
    }
}
