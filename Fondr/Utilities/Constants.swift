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

    enum Lists {
        static let collection = "lists"
        static let metaCollection = "lists-meta"
    }

    enum Sessions {
        static let collection = "sessions"
    }

    enum TMDB {
        static let apiKey = ""
        static let baseUrl = "https://api.themoviedb.org/3"
        static let imageBaseUrl = "https://image.tmdb.org/t/p/w500"
    }

    enum Animation {
        static let defaultDuration: Double = 0.3
    }
}
