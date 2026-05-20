import Foundation

protocol AuthServicing: AnyObject {
    func restoreSession() async throws -> AuthSession?
    func signIn(email: String, password: String) async throws -> AuthSession
    func signUp(email: String, password: String) async throws -> AuthSession
    func resetPassword(email: String) async throws
    func signOut() async
}

protocol SessionRefreshing: AnyObject {
    func refreshStoredSession(force: Bool) async throws -> AuthSession?
}

enum AuthError: LocalizedError {
    case invalidInput
    case missingConfiguration
    case unsupportedResponse
    case sessionExpired
    case requestRejected(String)

    var errorDescription: String? {
        switch self {
        case .invalidInput: return "Enter a valid email and password."
        case .missingConfiguration: return "Supabase is not configured for this build."
        case .unsupportedResponse: return "The auth response could not be read."
        case .sessionExpired: return "Session expired. Sign in again to continue."
        case .requestRejected(let reason): return "Authentication request was rejected. \(reason)"
        }
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
