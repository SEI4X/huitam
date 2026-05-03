import FirebaseFirestore
import FirebaseFunctions
import Foundation

enum FirebaseAsync {
    static func getDocument(_ reference: DocumentReference) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            reference.getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: FirebaseMappingError.missingField("snapshot"))
                }
            }
        }
    }

    static func getDocuments(_ query: Query) async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { continuation in
            query.getDocuments { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: FirebaseMappingError.missingField("snapshot"))
                }
            }
        }
    }

    static func setData(_ data: [String: Any], on reference: DocumentReference, merge: Bool = true) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.setData(data, merge: merge) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    static func commit(_ batch: WriteBatch) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    static func delete(_ reference: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    static func call(_ name: String, payload: [String: Any]) async throws -> Any {
        try await withCheckedThrowingContinuation { continuation in
            Functions.functions().httpsCallable(name).call(payload) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data = result?.data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: FirebaseMappingError.missingField("callableResult"))
                }
            }
        }
    }
}
