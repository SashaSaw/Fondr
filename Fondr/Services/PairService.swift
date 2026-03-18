import Foundation
import FirebaseAuth
import FirebaseFirestore

@Observable
final class PairService {
    var currentPair: Pair?
    var errorMessage: String?
    var isLoading = false

    private var pairListener: ListenerRegistration?
    private var db: Firestore { Firestore.firestore() }

    deinit {
        pairListener?.remove()
    }

    // MARK: - Create Pair

    func createPair() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let code = generateInviteCode()
                let pair = Pair(userA: uid, inviteCode: code)

                let docRef = db.collection(Constants.Firestore.pairsCollection).document()
                try docRef.setData(from: pair)

                // Update user doc with pairId
                try await db.collection(Constants.Firestore.usersCollection)
                    .document(uid)
                    .updateData(["pairId": docRef.documentID])

                await MainActor.run {
                    self.listenToPair(pairId: docRef.documentID)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Join Pair

    func joinPair(inviteCode: String) {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("🔴 [joinPair] No authenticated user")
            return
        }
        isLoading = true
        errorMessage = nil

        print("🟡 [joinPair] Starting join with code: \(inviteCode), uid: \(uid)")

        Task {
            do {
                let snapshot = try await db.collection(Constants.Firestore.pairsCollection)
                    .whereField("inviteCode", isEqualTo: inviteCode.uppercased())
                    .whereField("status", isEqualTo: Pair.Status.pending.rawValue)
                    .limit(to: 1)
                    .getDocuments()

                guard let doc = snapshot.documents.first else {
                    print("🔴 [joinPair] No matching pair found for code: \(inviteCode.uppercased())")
                    await MainActor.run {
                        self.errorMessage = "Invalid or expired invite code."
                        self.isLoading = false
                    }
                    return
                }

                let pairId = doc.documentID
                let docData = doc.data()

                let existingPair = try doc.data(as: Pair.self)
                let userAId = existingPair.userA

                print("🟡 [joinPair] Found pair: \(pairId)")
                print("🟡 [joinPair]   userA: \(userAId)")
                print("🟡 [joinPair]   userB: \(String(describing: docData["userB"]))")
                print("🟡 [joinPair]   status: \(String(describing: docData["status"]))")
                print("🟡 [joinPair]   current uid: \(uid)")

                // Step 1: Update pair with userB and set active
                print("🟡 [joinPair] Step 1: Updating pair doc...")
                do {
                    try await doc.reference.updateData([
                        "userB": uid,
                        "status": Pair.Status.active.rawValue
                    ])
                    print("🟢 [joinPair] Step 1 succeeded: pair doc updated")
                } catch {
                    print("🔴 [joinPair] Step 1 FAILED: pair doc update error: \(error)")
                    throw error
                }

                // Step 2: Update only current user's doc
                print("🟡 [joinPair] Step 2: Updating user doc for \(uid)...")
                do {
                    try await db.collection(Constants.Firestore.usersCollection)
                        .document(uid)
                        .updateData(["pairId": pairId, "partnerUid": userAId])
                    print("🟢 [joinPair] Step 2 succeeded: user doc updated")
                } catch {
                    print("🔴 [joinPair] Step 2 FAILED: user doc update error: \(error)")
                    throw error
                }

                await MainActor.run {
                    self.listenToPair(pairId: pairId)
                    self.isLoading = false
                }
            } catch {
                print("🔴 [joinPair] Overall error: \(error)")
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Listen to Pair

    func listenToPair(pairId: String) {
        pairListener?.remove()
        pairListener = db.collection(Constants.Firestore.pairsCollection)
            .document(pairId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let snapshot, snapshot.exists else {
                    self?.currentPair = nil
                    return
                }
                let pair = try? snapshot.data(as: Pair.self)
                self?.currentPair = pair

                // If pair just became active, userA needs to set partnerUid on their own doc
                if let pair, pair.status == .active, let userB = pair.userB {
                    let uid = Auth.auth().currentUser?.uid
                    if uid == pair.userA {
                        Firestore.firestore().collection(Constants.Firestore.usersCollection)
                            .document(pair.userA)
                            .updateData(["partnerUid": userB])
                    }
                }
            }
    }

    // MARK: - Cancel Pending Pair

    func cancelPair() {
        guard let pair = currentPair, let pairId = pair.id, pair.status == .pending,
              let uid = Auth.auth().currentUser?.uid else { return }

        Task {
            do {
                let batch = db.batch()

                // Clear pairId from current user's doc
                let userRef = db.collection(Constants.Firestore.usersCollection).document(uid)
                batch.updateData(["pairId": FieldValue.delete()], forDocument: userRef)

                // Delete the pending pair doc
                let pairRef = db.collection(Constants.Firestore.pairsCollection).document(pairId)
                batch.deleteDocument(pairRef)

                try await batch.commit()

                await MainActor.run {
                    self.pairListener?.remove()
                    self.currentPair = nil
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Unpair

    func unpair() {
        guard let pair = currentPair, let pairId = pair.id,
              let currentUid = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        Task {
            do {
                let batch = db.batch()

                // Clear current user's pair data and reset onboarding
                let currentUserRef = db.collection(Constants.Firestore.usersCollection).document(currentUid)
                batch.updateData([
                    "pairId": FieldValue.delete(),
                    "partnerUid": FieldValue.delete(),
                    "partnerName": FieldValue.delete(),
                    "onboardingCompleted": FieldValue.delete()
                ], forDocument: currentUserRef)

                // Delete pair doc — partner will detect this via their pair listener
                // and can handle their own cleanup
                let pairRef = db.collection(Constants.Firestore.pairsCollection).document(pairId)
                batch.deleteDocument(pairRef)

                try await batch.commit()

                await MainActor.run {
                    self.pairListener?.remove()
                    self.currentPair = nil
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    // MARK: - Helpers

    private func generateInviteCode() -> String {
        let characters = Array(Constants.Pairing.codeCharacters)
        return String((0..<Constants.Pairing.codeLength).map { _ in
            characters[Int.random(in: 0..<characters.count)]
        })
    }
}
