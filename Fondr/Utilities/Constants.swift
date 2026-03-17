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

    enum Animation {
        static let defaultDuration: Double = 0.3
    }
}
