import SwiftUI

extension Color {
    // MARK: - Rugged Earth Palette
    static let trBase = Color(red: 0x11/255, green: 0x1A/255, blue: 0x12/255)        // #111A12
    static let trSurface = Color(red: 0x1E/255, green: 0x33/255, blue: 0x22/255)     // #1E3322
    static let trSurfaceBorder = Color(red: 0x2A/255, green: 0x4A/255, blue: 0x2E/255) // #2A4A2E
    static let trPrimary = Color(red: 0x52/255, green: 0xB7/255, blue: 0x88/255)     // #52B788
    static let trAccent = Color(red: 0xD4/255, green: 0xA5/255, blue: 0x74/255)      // #D4A574
    static let trDestructive = Color(red: 0xE0/255, green: 0x7A/255, blue: 0x5F/255) // #E07A5F
    static let trWarning = Color(red: 0xE9/255, green: 0xC4/255, blue: 0x6A/255)     // #E9C46A
    static let trTextPrimary = Color(red: 0xE8/255, green: 0xE0/255, blue: 0xD8/255) // #E8E0D8
    static let trTextSecondary = Color(red: 0x6A/255, green: 0x8A/255, blue: 0x6A/255) // #6A8A6A
    static let trTextTertiary = Color(red: 0x3A/255, green: 0x5A/255, blue: 0x3C/255) // #3A5A3C
    static let trBadgeDark = Color(red: 0x2C/255, green: 0x2C/255, blue: 0x2E/255)   // #2C2C2E

    // Derived colors
    static let trSurfaceDarker = Color(red: 0x18/255, green: 0x2A/255, blue: 0x1C/255)
    static let trSurfaceLighter = Color(red: 0x24/255, green: 0x3D/255, blue: 0x28/255)
    static let trPrimaryDarker = Color(red: 0x40/255, green: 0x91/255, blue: 0x6C/255)
}

extension ShapeStyle where Self == Color {
    static var trBase: Color { .trBase }
    static var trSurface: Color { .trSurface }
    static var trSurfaceBorder: Color { .trSurfaceBorder }
    static var trPrimary: Color { .trPrimary }
    static var trAccent: Color { .trAccent }
    static var trDestructive: Color { .trDestructive }
    static var trWarning: Color { .trWarning }
    static var trTextPrimary: Color { .trTextPrimary }
    static var trTextSecondary: Color { .trTextSecondary }
    static var trTextTertiary: Color { .trTextTertiary }
    static var trBadgeDark: Color { .trBadgeDark }
    static var trSurfaceDarker: Color { .trSurfaceDarker }
    static var trSurfaceLighter: Color { .trSurfaceLighter }
    static var trPrimaryDarker: Color { .trPrimaryDarker }
}
