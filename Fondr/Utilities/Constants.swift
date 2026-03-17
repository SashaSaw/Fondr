import Foundation

enum Constants {
    enum App {
        static let name = "Fondr"
        static let bundleID = "com.incept5.Fondr"
    }

    enum Firestore {
        static let usersCollection = "users"
        static let pairsCollection = "pairs"
    }

    enum Pairing {
        static let codeLength = 6
        static let codeCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    }

    enum Vault {
        static let collection = "vault"
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

    enum Animation {
        static let defaultDuration: Double = 0.3
    }
}
