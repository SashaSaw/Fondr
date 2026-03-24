import SwiftUI
import UIKit

extension Color {
    /// Rose/coral primary
    static let fondrPrimary = Color(red: 0.918, green: 0.365, blue: 0.459)

    /// Lavender secondary
    static let fondrSecondary = Color(red: 0.686, green: 0.612, blue: 0.867)

    /// Gold accent
    static let fondrAccent = Color(red: 0.949, green: 0.784, blue: 0.373)

    /// Adaptive background — cream in light, charcoal in dark
    static let fondrBackground = Color("FondrBackground", bundle: nil)

    /// Sparkle gold — success states
    static let fondrSuccess = Color(red: 0.949, green: 0.784, blue: 0.373)

    /// Soft blue — "you" indicator (#7EB6D7)
    static let fondrYou = Color(red: 0.494, green: 0.714, blue: 0.843)

    /// Soft pink — partner indicator (#F2A7B3)
    static let fondrPartner = Color(red: 0.949, green: 0.655, blue: 0.702)

    /// Warm purple — overlap indicator (#9B7FBF)
    static let fondrOverlap = Color(red: 0.608, green: 0.498, blue: 0.749)

    /// Adaptive card background — white in light, secondarySystemBackground in dark
    static let fondrCardBackground = Color(UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? .secondarySystemBackground
            : .white
    })
}

extension ShapeStyle where Self == Color {
    static var fondrPrimary: Color { Color.fondrPrimary }
    static var fondrSecondary: Color { Color.fondrSecondary }
    static var fondrAccent: Color { Color.fondrAccent }
    static var fondrBackground: Color { Color.fondrBackground }
    static var fondrSuccess: Color { Color.fondrSuccess }
    static var fondrYou: Color { Color.fondrYou }
    static var fondrPartner: Color { Color.fondrPartner }
    static var fondrOverlap: Color { Color.fondrOverlap }
    static var fondrCardBackground: Color { Color.fondrCardBackground }
}
