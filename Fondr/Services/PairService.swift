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
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let snapshot = try await db.collection(Constants.Firestore.pairsCollection)
                    .whereField("inviteCode", isEqualTo: inviteCode.uppercased())
                    .whereField("status", isEqualTo: Pair.Status.pending.rawValue)
                    .limit(to: 1)
                    .getDocuments()

                guard let doc = snapshot.documents.first else {
                    await MainActor.run {
                        self.errorMessage = "Invalid or expired invite code."
                        self.isLoading = false
                    }
                    return
                }

                let pairId = doc.documentID

                let existingPair = try doc.data(as: Pair.self)
                let userAId = existingPair.userA

                // Update pair with userB and set active
                try await doc.reference.updateData([
                    "userB": uid,
                    "status": Pair.Status.active.rawValue
                ])

                // Update both user docs with pairId and partnerUid
                let batch = db.batch()
                let userBRef = db.collection(Constants.Firestore.usersCollection).document(uid)
                batch.updateData(["pairId": pairId, "partnerUid": userAId], forDocument: userBRef)

                let userARef = db.collection(Constants.Firestore.usersCollection).document(userAId)
                batch.updateData(["partnerUid": uid], forDocument: userARef)

                try await batch.commit()

                await MainActor.run {
                    self.listenToPair(pairId: pairId)
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
                self?.currentPair = try? snapshot.data(as: Pair.self)
            }
    }

    // MARK: - Cancel Pending Pair

    func cancelPair() {
        guard let pair = currentPair, let pairId = pair.id, pair.status == .pending else { return }

        Task {
            do {
                let batch = db.batch()

                // Clear pairId from user
                let userRef = db.collection(Constants.Firestore.usersCollection).document(pair.userA)
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
        guard let pair = currentPair, let pairId = pair.id else { return }
        isLoading = true

        Task {
            do {
                // Clear pairId from both users
                let batch = db.batch()

                let userARef = db.collection(Constants.Firestore.usersCollection).document(pair.userA)
                batch.updateData(["pairId": FieldValue.delete(), "partnerUid": FieldValue.delete()], forDocument: userARef)

                if let userB = pair.userB {
                    let userBRef = db.collection(Constants.Firestore.usersCollection).document(userB)
                    batch.updateData(["pairId": FieldValue.delete(), "partnerUid": FieldValue.delete()], forDocument: userBRef)
                }

                // Delete pair doc
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
