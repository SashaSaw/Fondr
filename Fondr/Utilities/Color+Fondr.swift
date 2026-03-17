import SwiftUI

extension Color {
    /// Rose/coral primary
    static let fondrPrimary = Color(red: 0.918, green: 0.365, blue: 0.459)

    /// Lavender secondary
    static let fondrSecondary = Color(red: 0.686, green: 0.612, blue: 0.867)

    /// Gold accent
    static let fondrAccent = Color(red: 0.949, green: 0.784, blue: 0.373)

    /// Adaptive background — cream in light, charcoal in dark
    static let fondrBackground = Color("FondrBackground", bundle: nil)
}

extension ShapeStyle where Self == Color {
    static var fondrPrimary: Color { Color.fondrPrimary }
    static var fondrSecondary: Color { Color.fondrSecondary }
    static var fondrAccent: Color { Color.fondrAccent }
    static var fondrBackground: Color { Color.fondrBackground }
}
