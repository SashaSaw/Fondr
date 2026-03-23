import Foundation

extension Notification.Name {
    static let switchToTab = Notification.Name("switchToTab")
}

enum Constants {
    enum App {
        static let name = "Fondr"
        static let bundleID = "com.incept5.Fondr"
    }

    enum Pairing {
        static let codeLength = 6
        static let codeCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    }

    enum Vault {
        static let labelSuggestions: [FactCategory: [String]] = [
            .basics: [
                "Birthday", "Anniversary", "Love Language", "Zodiac Sign",
                "Shoe Size", "Ring Size", "Shirt Size", "Favourite Colour"
            ],
            .food: [
                "Favourite Restaurant", "Coffee Order", "Favourite Cuisine",
                "Food Allergies", "Comfort Food", "Favourite Snack"
            ],
            .gifts: [
                "Wishlist Item", "Mentioned Wanting", "Favourite Brand",
                "Favourite Store", "Ring Size"
            ]
        ]
    }

    enum TMDB {
        static let imageBaseUrl = "https://image.tmdb.org/t/p/w500"
    }

    enum Calendar {
        static let defaultStartHour = 8
        static let defaultEndHour = 23
    }

    enum OurStory {
        static let maxImageDimension: CGFloat = 500
        static let jpegCompression: CGFloat = 0.7
    }

    enum Animation {
        static let defaultDuration: Double = 0.3
    }
}
