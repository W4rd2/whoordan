import CryptoKit
import Foundation

struct SupabaseConfig: Equatable {
    let url: URL?
    let publishableKey: String?
    let projectID: String?

    var isConfigured: Bool {
        url != nil && !(publishableKey ?? "").isEmpty
    }

    static func fromBundle(_ bundle: Bundle = .main) -> SupabaseConfig {
        let urlString = firstNonPlaceholder([
            bundle.object(forInfoDictionaryKey: "WHOORDAN_SUPABASE_URL") as? String,
            ProcessInfo.processInfo.environment["WHOORDAN_SUPABASE_URL"]
        ])
        let publishable = firstClientSafePublishableKey([
            bundle.object(forInfoDictionaryKey: "WHOORDAN_SUPABASE_PUBLISHABLE_KEY") as? String,
            ProcessInfo.processInfo.environment["WHOORDAN_SUPABASE_PUBLISHABLE_KEY"],
            ProcessInfo.processInfo.environment["SUPABASE_PUBLISHABLE_KEY"],
            ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
        ])
        let project = firstNonPlaceholder([
            bundle.object(forInfoDictionaryKey: "SUPABASE_PROJECT_ID") as? String,
            ProcessInfo.processInfo.environment["SUPABASE_PROJECT_ID"]
        ])
        let resolvedURL = normalizedSupabaseURL(from: urlString)
            ?? project.flatMap { normalizedSupabaseURL(from: "https://\($0).supabase.co") }
        return SupabaseConfig(
            url: resolvedURL,
            publishableKey: publishable,
            projectID: project
        )
    }

    private static func normalizedSupabaseURL(from value: String?) -> URL? {
        guard let value,
              var components = URLComponents(string: value),
              components.scheme == "https",
              let host = components.host?.trimmed,
              !host.isEmpty else {
            return nil
        }
        components.host = host
        if components.path == "/" {
            components.path = ""
        }
        return components.url
    }

    private static func firstNonPlaceholder(_ values: [String?]) -> String? {
        values.compactMap { value in
            guard let trimmed = value?.trimmed, !trimmed.isEmpty, !trimmed.contains("$(") else {
                return nil
            }
            return trimmed
        }.first
    }

    private static func firstClientSafePublishableKey(_ values: [String?]) -> String? {
        guard let key = firstNonPlaceholder(values) else { return nil }
        return isClientSafePublishableKey(key) ? key : nil
    }

    private static func isClientSafePublishableKey(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        if lowercased.hasPrefix("sb_secret_") || lowercased.contains("service_role") {
            return false
        }
        return jwtRole(from: value) != "service_role"
    }

    private static func jwtRole(from value: String) -> String? {
        let parts = value.split(separator: ".")
        guard parts.count >= 2 else { return nil }
        var payload = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = payload.count % 4
        if padding > 0 {
            payload += String(repeating: "=", count: 4 - padding)
        }
        guard
            let data = Data(base64Encoded: payload),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return (json["role"] as? String)?.lowercased()
    }
}

protocol AuthTokenProviding: AnyObject {
    var accessToken: String? { get }
}

protocol HTTPClienting {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClienting {}

struct HTTPRequestRejected: LocalizedError {
    let statusCode: Int
    let code: String
    let message: String?

    var errorDescription: String? {
        if let message, !message.isEmpty {
            return "Request was rejected. Status \(statusCode), code \(code): \(message)"
        }
        return "Request was rejected. Status \(statusCode), code \(code)."
    }
}

final class SupabaseAuthService: AuthServicing, SessionRefreshing, AuthTokenProviding {
    private let config: SupabaseConfig
    private let keychain: KeychainStoring
    private let httpClient: HTTPClienting
    private let now: () -> Date
    private(set) var accessToken: String?

    init(
        config: SupabaseConfig,
        keychain: KeychainStoring,
        httpClient: HTTPClienting = URLSession.shared,
        now: @escaping () -> Date = Date.init
    ) {
        self.config = config
        self.keychain = keychain
        self.httpClient = httpClient
        self.now = now
    }

    func restoreSession() async throws -> AuthSession? {
        try await refreshStoredSession(force: false)
    }

    func refreshStoredSession(force: Bool) async throws -> AuthSession? {
        guard let data = keychain.data(for: "auth.session") else {
            return nil
        }
        let session: AuthSession
        do {
            session = try JSONDecoder.whoordan.decode(AuthSession.self, from: data)
        } catch {
            keychain.deleteData(for: "auth.session")
            accessToken = nil
            return nil
        }
        if force || shouldRefresh(session) {
            guard let refreshToken = session.refreshToken?.trimmed, !refreshToken.isEmpty else {
                keychain.deleteData(for: "auth.session")
                accessToken = nil
                throw AuthError.sessionExpired
            }
            do {
                return try await refreshSession(refreshToken: refreshToken, fallbackEmail: session.email)
            } catch let error as URLError where !force && Self.isNetworkUnavailable(error) {
                accessToken = session.accessToken
                return session
            }
        }
        accessToken = session.accessToken
        return session
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        try validate(email: email, password: password)
        return try await passwordRequest(path: "/auth/v1/token?grant_type=password", email: email, password: password)
    }

    func signUp(email: String, password: String) async throws -> AuthSession {
        try validate(email: email, password: password)
        return try await passwordRequest(path: "/auth/v1/signup", email: email, password: password)
    }

    func resetPassword(email: String) async throws {
        guard email.trimmed.contains("@") else { throw AuthError.invalidInput }
        guard let request = try makeRequest(path: "/auth/v1/recover", method: "POST") else {
            throw AuthError.missingConfiguration
        }
        var mutable = request
        mutable.httpBody = try JSONEncoder().encode(["email": email.trimmed])
        let (data, response) = try await httpClient.data(for: mutable)
        do {
            try validateSuccess(response: response, data: data)
        } catch let rejection as HTTPRequestRejected {
            throw AuthError.requestRejected(rejection.code)
        }
    }

    func signOut() async {
        keychain.deleteData(for: "auth.session")
        accessToken = nil
    }

    private func validate(email: String, password: String) throws {
        guard email.trimmed.contains("@"), password.count >= 8 else {
            throw AuthError.invalidInput
        }
    }

    private func passwordRequest(path: String, email: String, password: String) async throws -> AuthSession {
        guard let request = try makeRequest(path: path, method: "POST") else {
            throw AuthError.missingConfiguration
        }
        var mutable = request
        mutable.httpBody = try JSONEncoder().encode(["email": email.trimmed, "password": password])
        let (data, urlResponse) = try await httpClient.data(for: mutable)
        do {
            try validateSuccess(response: urlResponse, data: data)
        } catch let rejection as HTTPRequestRejected {
            throw AuthError.requestRejected(rejection.code)
        }
        let sessionResponse = try JSONDecoder.whoordan.decode(SupabaseSessionResponse.self, from: data)
        let session = try sessionResponse.toSession(fallbackEmail: email.trimmed, now: now())
        accessToken = session.accessToken
        keychain.set(data: try JSONEncoder.whoordan.encode(session), for: "auth.session")
        return session
    }

    private func refreshSession(refreshToken: String, fallbackEmail: String) async throws -> AuthSession {
        guard let request = try makeRequest(path: "/auth/v1/token?grant_type=refresh_token", method: "POST") else {
            throw AuthError.missingConfiguration
        }
        var mutable = request
        mutable.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])
        let (data, response) = try await httpClient.data(for: mutable)
        do {
            try validateSuccess(response: response, data: data)
        } catch let rejection as HTTPRequestRejected {
            if [400, 401, 403].contains(rejection.statusCode) {
                keychain.deleteData(for: "auth.session")
                accessToken = nil
                throw AuthError.sessionExpired
            }
            throw rejection
        }
        let refreshed = try JSONDecoder.whoordan.decode(SupabaseSessionResponse.self, from: data)
        let session = try refreshed.toSession(fallbackEmail: fallbackEmail, now: now())
        accessToken = session.accessToken
        keychain.set(data: try JSONEncoder.whoordan.encode(session), for: "auth.session")
        return session
    }

    private func shouldRefresh(_ session: AuthSession) -> Bool {
        guard let expiresAt = session.expiresAt else { return false }
        return expiresAt <= now().addingTimeInterval(60)
    }

    private static func isNetworkUnavailable(_ error: URLError) -> Bool {
        [
            .notConnectedToInternet,
            .networkConnectionLost,
            .cannotFindHost,
            .cannotConnectToHost,
            .timedOut
        ].contains(error.code)
    }

    private func validateSuccess(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) else {
            return
        }
        let envelope = try? JSONDecoder().decode(SupabaseErrorEnvelope.self, from: data)
        let code = envelope?.code ?? "HTTP \(http.statusCode)"
        throw HTTPRequestRejected(statusCode: http.statusCode, code: code, message: envelope?.message)
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest? {
        guard let base = config.url, let key = config.publishableKey else {
            return nil
        }
        guard let url = URL(string: path, relativeTo: base)?.absoluteURL else {
            return nil
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

enum ApprovalFetchError: LocalizedError, Equatable {
    case unauthorized
    case forbidden
    case networkUnavailable
    case invalidRequest
    case requestFailed(String)

    var errorDescription: String? {
        switch self {
        case .unauthorized: return "Approval check was not authorized."
        case .forbidden: return "Approval check was forbidden."
        case .networkUnavailable: return "Can't verify approval while offline."
        case .invalidRequest: return "Invalid approval request."
        case .requestFailed(let message): return message
        }
    }
}

final class SupabaseApprovalService: ApprovalServicing {
    private let config: SupabaseConfig
    private weak var authTokenProvider: AuthTokenProviding?
    private let httpClient: HTTPClienting

    init(
        config: SupabaseConfig,
        authTokenProvider: AuthTokenProviding,
        httpClient: HTTPClienting = URLSession.shared
    ) {
        self.config = config
        self.authTokenProvider = authTokenProvider
        self.httpClient = httpClient
    }

    func fetchApproval(for userID: UUID) async throws -> ApprovalState {
        guard let base = config.url,
              let key = config.publishableKey,
              let token = authTokenProvider?.accessToken else {
            return .unknown(message: "Approval cannot be checked until Supabase is configured.")
        }

        var components = URLComponents(url: base.appendingPathComponent("/rest/v1/user_access"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "approval_status"),
            URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)")
        ]
        guard let url = components.url else {
            throw ApprovalFetchError.invalidRequest
        }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await httpClient.data(for: request)
        } catch let error as URLError where Self.isNetworkUnavailable(error) {
            throw ApprovalFetchError.networkUnavailable
        }
        guard let http = response as? HTTPURLResponse else {
            throw ApprovalFetchError.requestFailed("Approval response could not be read.")
        }
        switch http.statusCode {
        case 200...299:
            break
        case 401:
            throw ApprovalFetchError.unauthorized
        case 403:
            throw ApprovalFetchError.forbidden
        default:
            let code = (try? JSONDecoder().decode(SupabaseErrorEnvelope.self, from: data).code) ?? "HTTP \(http.statusCode)"
            throw ApprovalFetchError.requestFailed("Approval check failed with \(code).")
        }
        let rows = try JSONDecoder.whoordan.decode([ApprovalRow].self, from: data)
        guard let status = rows.first?.approvalStatus else {
            return .missing()
        }
        return ApprovalState(
            status: ApprovalStatus(rawValue: status) ?? .unknown,
            message: message(for: ApprovalStatus(rawValue: status) ?? .unknown),
            checkedAt: Date()
        )
    }

    private func message(for status: ApprovalStatus) -> String {
        switch status {
        case .approved: return "Approved"
        case .offlineApproved: return "Offline mode with last verified approval."
        case .pending: return "Waiting for W4rd2 approval."
        case .rejected: return "Access was not approved."
        case .revoked: return "Access was revoked."
        case .missing: return "Approval status is missing."
        case .checkingApproval: return "Checking account approval."
        case .authExpired: return "Session expired."
        case .networkUnavailable: return "Approval cannot be checked while offline."
        case .approvalFetchFailed: return "Approval check failed."
        case .unknown: return "Approval status is unknown."
        case .unknownError, .error: return "Approval status could not be checked."
        }
    }

    private static func isNetworkUnavailable(_ error: URLError) -> Bool {
        [
            .notConnectedToInternet,
            .networkConnectionLost,
            .cannotFindHost,
            .cannotConnectToHost,
            .timedOut
        ].contains(error.code)
    }
}

enum HealthSyncStatus: String, Codable, Equatable {
    case blocked
    case nothingToSync
    case uploaded
    case failed
}

struct HealthSyncResult: Codable, Equatable {
    let status: HealthSyncStatus
    let sampleCount: Int
    let message: String
}

enum HealthCloudRestoreStatus: String, Codable, Equatable {
    case blocked
    case nothingToRestore
    case restored
    case failed
}

struct HealthSummaryRestoreResult: Codable, Equatable {
    let status: HealthCloudRestoreStatus
    let summaries: [DailyHealthSummary]
    let message: String
}

struct HealthSampleRestoreResult: Codable, Equatable {
    let status: HealthCloudRestoreStatus
    let samples: [HealthSample]
    let message: String
}

enum AccountSyncStatus: String, Codable, Equatable {
    case blocked
    case nothingToSync
    case synced
    case failed
}

struct AccountSyncResult: Codable, Equatable {
    let status: AccountSyncStatus
    let message: String

    static let notRun = AccountSyncResult(
        status: .nothingToSync,
        message: "Account settings sync has not run."
    )
}

struct AccountSyncSnapshot: Codable, Equatable {
    var email: String?
    var bodyProfile: BodyProfile
    var consentState: ConsentState
    var skinTemperatureBaselineProfile: SkinTemperatureBaselineProfile? = nil
    var callVibrationSettings: CallVibrationSettings
    var alarms: [Alarm]
    var themePreference: String
    var movementGoal: Int
    var updatedAt: Date?
    var includesProfile = true
    var includesSettings = true

    var hasSyncableContent: Bool {
        true
    }
}

protocol AccountSyncServicing {
    func fetchAccountSnapshot(
        session: AuthSession?,
        approval: ApprovalState?,
        includeHealthBaselines: Bool
    ) async -> AccountSyncSnapshot?

    func uploadAccountSnapshot(
        _ snapshot: AccountSyncSnapshot,
        session: AuthSession?,
        approval: ApprovalState?
    ) async -> AccountSyncResult

    func requestAccountDeletion(session: AuthSession?) async -> AccountSyncResult
}

struct NoopAccountSyncService: AccountSyncServicing {
    func fetchAccountSnapshot(
        session: AuthSession?,
        approval: ApprovalState?,
        includeHealthBaselines: Bool
    ) async -> AccountSyncSnapshot? {
        nil
    }

    func uploadAccountSnapshot(
        _ snapshot: AccountSyncSnapshot,
        session: AuthSession?,
        approval: ApprovalState?
    ) async -> AccountSyncResult {
        AccountSyncResult(status: .nothingToSync, message: "Account settings sync is unavailable in this runtime.")
    }

    func requestAccountDeletion(session: AuthSession?) async -> AccountSyncResult {
        AccountSyncResult(status: .failed, message: "Account deletion requests are unavailable in this runtime.")
    }
}

final class SupabaseAccountSyncService: AccountSyncServicing {
    private let config: SupabaseConfig
    private let httpClient: HTTPClienting

    init(
        config: SupabaseConfig,
        httpClient: HTTPClienting = URLSession.shared
    ) {
        self.config = config
        self.httpClient = httpClient
    }

    func fetchAccountSnapshot(
        session: AuthSession?,
        approval: ApprovalState?,
        includeHealthBaselines: Bool
    ) async -> AccountSyncSnapshot? {
        guard approval?.allowsProtectedLocalAccess == true,
              let session,
              let base = config.url,
              let key = config.publishableKey else {
            return nil
        }

        do {
            async let profileRows = fetchRows(
                CloudUserProfileRow.self,
                from: "user_profiles",
                select: "email,birth_date,biological_sex,height_centimeters,weight_kilograms,configured_max_heart_rate,updated_at",
                userID: session.userID,
                base: base,
                key: key,
                token: session.accessToken
            )
            async let settingsRows = fetchRows(
                CloudUserSettingsRow.self,
                from: "user_settings",
                select: Self.userSettingsSelect(includeHealthBaselines: includeHealthBaselines),
                userID: session.userID,
                base: base,
                key: key,
                token: session.accessToken
            )

            let profile = try await profileRows.first
            let settings = try await settingsRows.first
            guard profile != nil || settings != nil else { return nil }
            return AccountSyncSnapshot(
                email: profile?.email ?? session.email,
                bodyProfile: profile?.bodyProfile ?? BodyProfile(),
                consentState: settings?.consentState ?? ConsentState(),
                skinTemperatureBaselineProfile: settings?.baselineProfiles?.skinTemperature.sanitizedForCloudSync,
                callVibrationSettings: settings?.callVibrationSettings?.settings ?? CallVibrationSettings(),
                alarms: settings?.wearableDeviceConfiguration?.alarms ?? [],
                themePreference: settings?.uiPreferences?.themePreference ?? "system",
                movementGoal: settings?.uiPreferences?.movementGoal ?? MovementSummary.empty().goal,
                updatedAt: [profile?.updatedAt, settings?.updatedAt].compactMap { $0 }.max(),
                includesProfile: profile != nil,
                includesSettings: settings != nil
            )
        } catch {
            return nil
        }
    }

    private static func userSettingsSelect(includeHealthBaselines: Bool) -> String {
        var columns = [
            "apple_health_enabled",
            "health_cloud_sync_enabled",
            "sync_preferences",
            "apple_health_preferences",
            "call_vibration_settings",
            "ui_preferences",
            "wearable_device_configuration",
            "updated_at"
        ]
        if includeHealthBaselines {
            columns.insert("baseline_profiles", at: 4)
        }
        return columns.joined(separator: ",")
    }

    func uploadAccountSnapshot(
        _ snapshot: AccountSyncSnapshot,
        session: AuthSession?,
        approval: ApprovalState?
    ) async -> AccountSyncResult {
        guard approval?.allowsCloudUpload == true else {
            return AccountSyncResult(status: .blocked, message: "Account settings sync requires approved account access.")
        }
        guard let session else {
            return AccountSyncResult(status: .blocked, message: "Account settings sync requires a signed-in session.")
        }
        guard snapshot.hasSyncableContent else {
            return AccountSyncResult(status: .nothingToSync, message: "No account settings are ready to sync.")
        }
        guard let base = config.url, let key = config.publishableKey else {
            return AccountSyncResult(status: .failed, message: "Supabase is not configured for account settings sync.")
        }

        do {
            let profile = CloudUserProfileUpsertRow(
                userID: session.userID,
                email: snapshot.email ?? session.email,
                bodyProfile: snapshot.bodyProfile
            )
            let settings = CloudUserSettingsUpsertRow(
                userID: session.userID,
                snapshot: snapshot
            )
            try await upsert([profile], table: "user_profiles", onConflict: "user_id", base: base, key: key, token: session.accessToken)
            try await upsert([settings], table: "user_settings", onConflict: "user_id", base: base, key: key, token: session.accessToken)
            return AccountSyncResult(status: .synced, message: "Saved account settings and profile to cloud.")
        } catch {
            return AccountSyncResult(status: .failed, message: Self.accountSyncFailureMessage(for: error))
        }
    }

    func requestAccountDeletion(session: AuthSession?) async -> AccountSyncResult {
        guard let session else {
            return AccountSyncResult(status: .blocked, message: "Account deletion requires a signed-in session.")
        }
        guard let base = config.url, let key = config.publishableKey else {
            return AccountSyncResult(status: .failed, message: "Supabase is not configured for account deletion requests.")
        }

        do {
            let row = AccountDeletionRequestRow(userID: session.userID, email: session.email)
            try await insert([row], table: "account_deletion_requests", base: base, key: key, token: session.accessToken)
            return AccountSyncResult(
                status: .synced,
                message: "Account deletion request received. W4rd2 will process the request server-side."
            )
        } catch {
            return AccountSyncResult(status: .failed, message: Self.accountDeletionFailureMessage(for: error))
        }
    }

    private static func accountSyncFailureMessage(for error: Error) -> String {
        if let rejection = error as? HTTPRequestRejected {
            var message = "Account settings sync failed. Supabase rejected the write: status \(rejection.statusCode), code \(rejection.code)"
            if let detail = rejection.message?.trimmed, !detail.isEmpty {
                message += ", \(sanitizedDetail(detail))"
            }
            return message + "."
        }
        let detail = sanitizedDetail(error.localizedDescription)
        return detail.isEmpty ? "Account settings sync failed." : "Account settings sync failed: \(detail)."
    }

    private static func accountDeletionFailureMessage(for error: Error) -> String {
        if let rejection = error as? HTTPRequestRejected {
            var message = "Account deletion request failed. Supabase rejected the write: status \(rejection.statusCode), code \(rejection.code)"
            if let detail = rejection.message?.trimmed, !detail.isEmpty {
                message += ", \(sanitizedDetail(detail))"
            }
            return message + "."
        }
        let detail = sanitizedDetail(error.localizedDescription)
        return detail.isEmpty ? "Account deletion request failed." : "Account deletion request failed: \(detail)."
    }

    private static func sanitizedDetail(_ value: String) -> String {
        String(
            value
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(220)
        )
    }

    private func fetchRows<Row: Decodable>(
        _ type: Row.Type,
        from table: String,
        select: String,
        userID: UUID,
        base: URL,
        key: String,
        token: String
    ) async throws -> [Row] {
        var components = URLComponents(url: base.appendingPathComponent("/rest/v1/\(table)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: select),
            URLQueryItem(name: "user_id", value: "eq.\(userID.uuidString)"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let url = components.url else {
            throw AccountSyncRequestError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await httpClient.data(for: request)
        try validateSuccess(response: response, data: data)
        return try JSONDecoder.whoordan.decode([Row].self, from: data)
    }

    private func upsert<Row: Encodable>(
        _ rows: [Row],
        table: String,
        onConflict: String,
        base: URL,
        key: String,
        token: String
    ) async throws {
        guard !rows.isEmpty else { return }
        var components = URLComponents(url: base.appendingPathComponent("/rest/v1/\(table)"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "on_conflict", value: onConflict)]
        guard let url = components.url else {
            throw AccountSyncRequestError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.whoordan.encode(rows)
        let (data, response) = try await httpClient.data(for: request)
        try validateSuccess(response: response, data: data)
    }

    private func insert<Row: Encodable>(
        _ rows: [Row],
        table: String,
        base: URL,
        key: String,
        token: String
    ) async throws {
        guard !rows.isEmpty else { return }
        guard let url = URLComponents(
            url: base.appendingPathComponent("/rest/v1/\(table)"),
            resolvingAgainstBaseURL: false
        )?.url else {
            throw AccountSyncRequestError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONEncoder.whoordan.encode(rows)
        let (data, response) = try await httpClient.data(for: request)
        try validateSuccess(response: response, data: data)
    }

    private func validateSuccess(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) else {
            return
        }
        let envelope = try? JSONDecoder().decode(SupabaseErrorEnvelope.self, from: data)
        let code = envelope?.code ?? "HTTP \(http.statusCode)"
        throw HTTPRequestRejected(statusCode: http.statusCode, code: code, message: envelope?.message)
    }
}

protocol HealthSyncServicing {
    func uploadHealthSamples(
        _ samples: [HealthSample],
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState
    ) async -> HealthSyncResult

    func uploadDailySummary(
        _ summary: DailyHealthSummary,
        metricSnapshots: [WhoordanMetricSnapshot],
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState
    ) async -> HealthSyncResult

    func fetchRecentDailySummaries(
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState,
        since: Date,
        limit: Int
    ) async -> HealthSummaryRestoreResult

    func fetchRecentHealthSamples(
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState,
        since: Date,
        limit: Int
    ) async -> HealthSampleRestoreResult
}

final class SupabaseHealthSyncService: HealthSyncServicing {
    private let config: SupabaseConfig
    private let httpClient: HTTPClienting

    init(
        config: SupabaseConfig,
        httpClient: HTTPClienting = URLSession.shared
    ) {
        self.config = config
        self.httpClient = httpClient
    }

    func uploadHealthSamples(
        _ samples: [HealthSample],
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState
    ) async -> HealthSyncResult {
        guard approval?.allowsCloudUpload == true, consent.canUploadHealthData else {
            return HealthSyncResult(status: .blocked, sampleCount: 0, message: "Cloud health sync requires approval and cloud sync enabled.")
        }
        guard let session else {
            return HealthSyncResult(status: .blocked, sampleCount: 0, message: "Cloud health sync requires a signed-in session.")
        }
        guard !samples.isEmpty else {
            return HealthSyncResult(status: .nothingToSync, sampleCount: 0, message: "No locally persisted health samples are ready to sync.")
        }
        guard let base = config.url, let key = config.publishableKey else {
            return HealthSyncResult(status: .failed, sampleCount: 0, message: "Supabase is not configured for health sync.")
        }
        do {
            let rows = Self.makeHealthSampleRows(Array(samples.prefix(500)), userID: session.userID)
            var components = URLComponents(url: base.appendingPathComponent("/rest/v1/health_samples"), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "on_conflict", value: "user_id,dedupe_key")]
            guard let url = components.url else {
                return HealthSyncResult(status: .failed, sampleCount: 0, message: "Health sync URL could not be built.")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(key, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
            request.httpBody = try JSONEncoder.whoordan.encode(rows)
            let (data, response) = try await httpClient.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return HealthSyncResult(status: .failed, sampleCount: 0, message: Self.rejectionMessage(from: data, response: response))
            }
            return HealthSyncResult(status: .uploaded, sampleCount: rows.count, message: "Uploaded queued local health samples.")
        } catch {
            return HealthSyncResult(status: .failed, sampleCount: 0, message: "Health sync failed.")
        }
    }

    func uploadDailySummary(
        _ summary: DailyHealthSummary,
        metricSnapshots: [WhoordanMetricSnapshot],
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState
    ) async -> HealthSyncResult {
        guard approval?.allowsCloudUpload == true, consent.canUploadHealthData else {
            return HealthSyncResult(status: .blocked, sampleCount: 0, message: "Cloud health sync requires approval and cloud sync enabled.")
        }
        guard let session else {
            return HealthSyncResult(status: .blocked, sampleCount: 0, message: "Cloud health sync requires a signed-in session.")
        }
        guard let base = config.url, let key = config.publishableKey else {
            return HealthSyncResult(status: .failed, sampleCount: 0, message: "Supabase is not configured for health sync.")
        }
        guard summary.hasSyncableContent else {
            return HealthSyncResult(status: .nothingToSync, sampleCount: 0, message: "No daily metric summary content is ready to sync.")
        }

        do {
            let row = Self.makeDailySummaryRow(summary, metricSnapshots: metricSnapshots, userID: session.userID)
            var components = URLComponents(url: base.appendingPathComponent("/rest/v1/daily_health_summaries"), resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "on_conflict", value: "user_id,summary_date")]
            guard let url = components.url else {
                return HealthSyncResult(status: .failed, sampleCount: 0, message: "Health summary sync URL could not be built.")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(key, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")
            request.httpBody = try JSONEncoder.whoordan.encode([row])
            let (data, response) = try await httpClient.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return HealthSyncResult(status: .failed, sampleCount: 0, message: Self.rejectionMessage(from: data, response: response))
            }
            return HealthSyncResult(status: .uploaded, sampleCount: 1, message: "Uploaded daily metric summary cache.")
        } catch {
            return HealthSyncResult(status: .failed, sampleCount: 0, message: "Health summary sync failed.")
        }
    }

    func fetchRecentDailySummaries(
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState,
        since: Date,
        limit: Int
    ) async -> HealthSummaryRestoreResult {
        guard approval?.allowsCloudUpload == true, consent.canUploadHealthData else {
            return HealthSummaryRestoreResult(status: .blocked, summaries: [], message: "Cloud metric restore requires account access and cloud sync enabled.")
        }
        guard let session else {
            return HealthSummaryRestoreResult(status: .blocked, summaries: [], message: "Cloud metric restore requires a signed-in session.")
        }
        guard let base = config.url, let key = config.publishableKey else {
            return HealthSummaryRestoreResult(status: .failed, summaries: [], message: "Supabase is not configured for metric restore.")
        }

        do {
            var components = URLComponents(url: base.appendingPathComponent("/rest/v1/daily_health_summaries"), resolvingAgainstBaseURL: false)!
            components.queryItems = [
                URLQueryItem(name: "select", value: [
                    "summary_date",
                    "recovery_score",
                    "sleep_seconds",
                    "strain",
                    "confidence",
                    "source",
                    "metadata",
                    "summary_payload",
                    "ready_metric_snapshots",
                    "metric_payload_version",
                    "last_synced_at"
                ].joined(separator: ",")),
                URLQueryItem(name: "user_id", value: "eq.\(session.userID.uuidString)"),
                URLQueryItem(name: "summary_date", value: "gte.\(Self.dayFormatter.string(from: since))"),
                URLQueryItem(name: "deleted_at", value: "is.null"),
                URLQueryItem(name: "order", value: "summary_date.asc"),
                URLQueryItem(name: "limit", value: "\(max(1, min(limit, 3_650)))")
            ]
            guard let url = components.url else {
                return HealthSummaryRestoreResult(status: .failed, summaries: [], message: "Metric restore URL could not be built.")
            }
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue(key, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await httpClient.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return HealthSummaryRestoreResult(status: .failed, summaries: [], message: Self.rejectionMessage(from: data, response: response))
            }
            let rows = try JSONDecoder.whoordan.decode([CloudDailyHealthSummaryRow].self, from: data)
            let summaries = rows.compactMap { $0.dailySummary() }
            guard !summaries.isEmpty else {
                return HealthSummaryRestoreResult(status: .nothingToRestore, summaries: [], message: "No cloud metric summaries were ready to restore.")
            }
            return HealthSummaryRestoreResult(status: .restored, summaries: summaries, message: "Restored \(summaries.count) cloud metric summaries.")
        } catch {
            return HealthSummaryRestoreResult(status: .failed, summaries: [], message: "Cloud metric restore failed.")
        }
    }

    func fetchRecentHealthSamples(
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState,
        since: Date,
        limit: Int
    ) async -> HealthSampleRestoreResult {
        guard approval?.allowsCloudUpload == true, consent.canUploadHealthData else {
            return HealthSampleRestoreResult(status: .blocked, samples: [], message: "Cloud sample restore requires account access and cloud sync enabled.")
        }
        guard let session else {
            return HealthSampleRestoreResult(status: .blocked, samples: [], message: "Cloud sample restore requires a signed-in session.")
        }
        guard let base = config.url, let key = config.publishableKey else {
            return HealthSampleRestoreResult(status: .failed, samples: [], message: "Supabase is not configured for sample restore.")
        }

        do {
            var restoredRowsByDedupeKey: [String: HealthSampleRow] = [:]
            for batch in Self.cloudRestoreSampleTypeBatches {
                let rows = try await fetchHealthSampleRows(
                    base: base,
                    key: key,
                    session: session,
                    since: since,
                    sampleTypes: batch,
                    limit: Self.cloudRestoreLimit(for: batch, requestedLimit: limit)
                )
                for row in rows {
                    restoredRowsByDedupeKey[row.dedupeKey] = row
                }
            }
            let samples = restoredRowsByDedupeKey.values
                .compactMap { $0.cloudRestoredSample() }
                .sorted { $0.startDate < $1.startDate }
            guard !samples.isEmpty else {
                return HealthSampleRestoreResult(status: .nothingToRestore, samples: [], message: "No cloud health samples were ready to restore.")
            }
            return HealthSampleRestoreResult(status: .restored, samples: samples, message: "Restored \(samples.count) cloud health samples.")
        } catch SupabaseHealthRestoreError.rejected(let message) {
            return HealthSampleRestoreResult(status: .failed, samples: [], message: message)
        } catch {
            return HealthSampleRestoreResult(status: .failed, samples: [], message: "Cloud sample restore failed.")
        }
    }

    private func fetchHealthSampleRows(
        base: URL,
        key: String,
        session: AuthSession,
        since: Date,
        sampleTypes: [String],
        limit: Int
    ) async throws -> [HealthSampleRow] {
        var components = URLComponents(url: base.appendingPathComponent("/rest/v1/health_samples"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: Self.healthSampleRestoreSelect),
            URLQueryItem(name: "user_id", value: "eq.\(session.userID.uuidString)"),
            URLQueryItem(name: "sampled_at", value: "gte.\(Self.isoFormatter.string(from: since))"),
            URLQueryItem(name: "sampled_at", value: "lte.\(Self.isoFormatter.string(from: Date().addingTimeInterval(86_400)))"),
            URLQueryItem(name: "sample_type", value: "in.(\(sampleTypes.joined(separator: ",")))"),
            URLQueryItem(name: "sync_status", value: "eq.synced"),
            URLQueryItem(name: "deleted_at", value: "is.null"),
            URLQueryItem(name: "order", value: "sampled_at.desc"),
            URLQueryItem(name: "limit", value: "\(max(1, min(limit, 5_000)))")
        ]
        guard let url = components.url else {
            throw SupabaseHealthRestoreError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(key, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await httpClient.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SupabaseHealthRestoreError.rejected(Self.rejectionMessage(from: data, response: response))
        }
        return try JSONDecoder.whoordan.decode([HealthSampleRow].self, from: data)
    }

    static func makeHealthSampleRows(_ samples: [HealthSample], userID: UUID, syncedAt: Date = Date()) -> [HealthSampleRow] {
        samples.map { sample in
            var metadata = sample.metadata
            metadata["confidence"] = sample.confidence.rawValue
            metadata["source_label"] = sample.metadata["source_label"] ?? sample.source.label
            return HealthSampleRow(
                userID: userID,
                sampleType: sample.type.rawValue,
                value: sample.value,
                unit: sample.unit,
                sampledAt: sample.startDate,
                endedAt: sample.endDate,
                source: sample.source.rawValue,
                sourceRecordID: hashed(sample.sourceRecordID),
                metadata: metadata,
                dedupeKey: hashed(sample.dedupeID),
                syncStatus: "synced",
                lastSyncedAt: syncedAt
            )
        }
    }

    static func makeDailySummaryRow(
        _ summary: DailyHealthSummary,
        metricSnapshots: [WhoordanMetricSnapshot],
        userID: UUID,
        syncedAt: Date = Date()
    ) -> DailyHealthSummaryRow {
        let day = Self.dayFormatter.string(from: summary.date)
        var metadata: [String: String] = [
            "confidence": summary.confidence.rawValue,
            "movement_confidence": summary.movement.confidence.rawValue
        ]
        if let resting = summary.restingHeartRate { metadata["resting_heart_rate_bpm"] = String(format: "%.1f", resting) }
        if let source = summary.restingHeartRateSource { metadata["resting_heart_rate_source"] = source.rawValue }
        if let confidence = summary.restingHeartRateConfidence { metadata["resting_heart_rate_confidence"] = confidence.rawValue }
        if let average = summary.averageHeartRate { metadata["average_heart_rate_bpm"] = String(format: "%.1f", average) }
        if let maximum = summary.maxHeartRate { metadata["max_heart_rate_bpm"] = String(format: "%.1f", maximum) }
        if let count = summary.heartRateSampleCount { metadata["heart_rate_sample_count"] = "\(count)" }
        if let coverage = summary.heartRateCoverageMinutes { metadata["heart_rate_coverage_minutes"] = String(format: "%.1f", coverage) }
        if let hrv = summary.hrv { metadata["hrv_ms"] = String(format: "%.1f", hrv) }
        if let source = summary.hrvSource { metadata["hrv_source"] = source.rawValue }
        if let confidence = summary.hrvConfidence { metadata["hrv_confidence"] = confidence.rawValue }
        if let respiratory = summary.respiratoryRate { metadata["respiratory_rate"] = String(format: "%.1f", respiratory) }
        if let source = summary.respiratoryRateSource { metadata["respiratory_rate_source"] = source.rawValue }
        if let confidence = summary.respiratoryRateConfidence { metadata["respiratory_rate_confidence"] = confidence.rawValue }
        if let oxygen = summary.oxygenSaturation { metadata["oxygen_saturation_percent"] = String(format: "%.1f", oxygen) }
        if let source = summary.oxygenSaturationSource { metadata["oxygen_saturation_source"] = source.rawValue }
        if let confidence = summary.oxygenSaturationConfidence { metadata["oxygen_saturation_confidence"] = confidence.rawValue }
        if let vo2Max = summary.vo2Max { metadata["vo2_max_ml_kg_min"] = String(format: "%.1f", vo2Max) }
        if let source = summary.vo2MaxSource { metadata["vo2_max_source"] = source.rawValue }
        if let confidence = summary.vo2MaxConfidence { metadata["vo2_max_confidence"] = confidence.rawValue }
        if let rawWristTemperature = summary.rawWristTemperatureC { metadata["raw_wrist_temperature_c"] = String(format: "%.2f", rawWristTemperature) }
        if let source = summary.rawWristTemperatureSource { metadata["raw_wrist_temperature_source"] = source.rawValue }
        if let confidence = summary.rawWristTemperatureConfidence { metadata["raw_wrist_temperature_confidence"] = confidence.rawValue }
        if let delta = summary.bodyTemperatureDelta { metadata["skin_temperature_delta_c"] = String(format: "%.2f", delta) }
        if let sleepNeed = summary.sleepNeedMinutes { metadata["sleep_need_minutes"] = String(format: "%.1f", sleepNeed) }
        if let sleepDebt = summary.sleepDebtMinutes { metadata["sleep_debt_minutes"] = String(format: "%.1f", sleepDebt) }
        if let steps = summary.movement.steps { metadata["steps"] = "\(steps)" }
        if let energy = summary.movement.activeEnergyKilocalories { metadata["active_energy_kcal"] = String(format: "%.1f", energy) }
        if let distance = summary.movement.walkingRunningDistanceMeters { metadata["distance_m"] = String(format: "%.1f", distance) }
        if let movementMinutes = summary.movement.movementMinutes { metadata["movement_minutes"] = String(format: "%.1f", movementMinutes) }
        if let source = summary.movement.source { metadata["movement_source"] = source.rawValue }
        if let restorative = summary.sleepSummary?.restorativePercent { metadata["restorative_sleep_percent"] = String(format: "%.1f", restorative) }
        if let restorativeMinutes = summary.sleepSummary?.restorativeMinutes { metadata["restorative_sleep_minutes"] = String(format: "%.1f", restorativeMinutes) }
        if let source = summary.source ?? summary.sleepSummary?.source ?? summary.movement.source {
            metadata["source_label"] = source.label
        }
        return DailyHealthSummaryRow(
            userID: userID,
            summaryDate: day,
            recoveryScore: summary.recovery?.value,
            sleepSeconds: summary.sleepMinutes.map { Int(($0 * 60).rounded()) },
            strain: summary.strain?.value,
            confidence: confidenceScore(summary.confidence),
            source: (summary.source ?? summary.sleepSummary?.source ?? summary.movement.source ?? .whoordanEstimate).rawValue,
            metadata: metadata,
            metricPayloadVersion: 1,
            summaryPayload: summary,
            readyMetricSnapshots: metricSnapshots.filter { $0.readiness != .laterBlocked && $0.value != nil },
            dedupeKey: hashed("daily_summary:\(userID.uuidString):\(day)"),
            syncStatus: "synced",
            lastSyncedAt: syncedAt
        )
    }

    private static func confidenceLevel(from score: Double) -> ConfidenceLevel {
        switch score {
        case 0.9...:
            return .high
        case 0.5..<0.9:
            return .medium
        case 0.01..<0.5:
            return .low
        default:
            return .unavailable
        }
    }

    private static func doubleMetadata(_ metadata: [String: String], _ key: String) -> Double? {
        metadata[key].flatMap(Double.init)
    }

    private static func intMetadata(_ metadata: [String: String], _ key: String) -> Int? {
        metadata[key].flatMap(Int.init)
    }

    private static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let healthSampleRestoreSelect = [
        "user_id",
        "sample_type",
        "value",
        "unit",
        "sampled_at",
        "ended_at",
        "source",
        "source_record_id",
        "metadata",
        "dedupe_key",
        "sync_status",
        "last_synced_at"
    ].joined(separator: ",")

    private static let cloudRestoreSampleTypeBatches: [[String]] = [
        ["sleepAnalysis", "sleep", "sleep_analysis"],
        [
            "steps",
            "activeEnergy",
            "active_energy",
            "active_energy_burned",
            "distanceWalkingRunning",
            "distance",
            "distance_walking_running",
            "workout"
        ],
        [
            "restingHeartRate",
            "resting_heart_rate",
            "heartRateVariabilityRMSSD",
            "hrv",
            "hrv_rmssd",
            "heart_rate_variability_rmssd",
            "heartRateVariabilitySDNN",
            "hrv_sdnn",
            "heart_rate_variability_sdnn",
            "respiratoryRate",
            "respiratory_rate",
            "oxygenSaturation",
            "oxygen_saturation",
            "spo2",
            "vo2Max",
            "vo2_max"
        ],
        ["heartRate", "heart_rate"],
        [
            "wristTemperature",
            "wrist_temperature",
            "bodyTemperature",
            "body_temperature",
            "temperatureEvent",
            "temperature_event"
        ]
    ]

    private static func cloudRestoreLimit(for batch: [String], requestedLimit: Int) -> Int {
        let bounded = max(1, min(requestedLimit, 25_000))
        if batch.contains("heartRate") || batch.contains("wristTemperature") {
            return min(bounded, 10_000)
        }
        return bounded
    }

    private static func confidenceScore(_ confidence: ConfidenceLevel) -> Double {
        switch confidence {
        case .high:
            return 1.0
        case .medium:
            return 0.75
        case .directional:
            return 0.5
        case .low:
            return 0.25
        case .blocked, .unavailable:
            return 0
        }
    }

    private static func hashed(_ value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func rejectionMessage(from data: Data, response: URLResponse) -> String {
        let status = (response as? HTTPURLResponse)?.statusCode ?? -1
        let code = (try? JSONDecoder().decode(SupabaseErrorEnvelope.self, from: data).code) ?? "unknown"
        return "Health sync request was rejected. Status \(status), code \(code)."
    }
}

private struct SupabaseErrorEnvelope: Decodable {
    let code: String?
    let message: String?
}

private enum SupabaseHealthRestoreError: Error {
    case invalidURL
    case rejected(String)
}

private struct CloudDailyHealthSummaryRow: Decodable {
    let summaryDate: String
    let recoveryScore: Double?
    let sleepSeconds: Int?
    let strain: Double?
    let confidence: Double
    let source: String?
    let metadata: [String: String]?
    let metricPayloadVersion: Int?
    let summaryPayload: DailyHealthSummary?
    let readyMetricSnapshots: [WhoordanMetricSnapshot]?
    let lastSyncedAt: Date?

    enum CodingKeys: String, CodingKey {
        case summaryDate = "summary_date"
        case recoveryScore = "recovery_score"
        case sleepSeconds = "sleep_seconds"
        case strain
        case confidence
        case source
        case metadata
        case metricPayloadVersion = "metric_payload_version"
        case summaryPayload = "summary_payload"
        case readyMetricSnapshots = "ready_metric_snapshots"
        case lastSyncedAt = "last_synced_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summaryDate = try container.decode(String.self, forKey: .summaryDate)
        recoveryScore = try container.decodeIfPresent(Double.self, forKey: .recoveryScore)
        sleepSeconds = try container.decodeIfPresent(Int.self, forKey: .sleepSeconds)
        strain = try container.decodeIfPresent(Double.self, forKey: .strain)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        source = try container.decodeIfPresent(String.self, forKey: .source)
        metadata = container.decodeStringMetadataIfPresent(forKey: .metadata)
        metricPayloadVersion = try container.decodeIfPresent(Int.self, forKey: .metricPayloadVersion)
        summaryPayload = try? container.decode(DailyHealthSummary.self, forKey: .summaryPayload)
        readyMetricSnapshots = try? container.decode([WhoordanMetricSnapshot].self, forKey: .readyMetricSnapshots)
        lastSyncedAt = try container.decodeIfPresent(Date.self, forKey: .lastSyncedAt)
    }

    func dailySummary() -> DailyHealthSummary? {
        guard let date = Self.dayFormatter.date(from: summaryDate) else { return nil }

        let resolvedConfidence = Self.confidenceLevel(from: confidence)
        var fallback = DailyHealthSummary.empty
        fallback.date = date
        fallback.confidence = resolvedConfidence
        fallback.source = DataSource(rawValue: source ?? "") ?? .cloudImport
        fallback.sleepMinutes = sleepSeconds.map { Double($0) / 60 }
        fallback.recovery = recoveryScore.map {
            ScoreValue(value: $0, scale: 0...100, confidence: resolvedConfidence, explanation: "Restored from cloud daily metric summary.")
        }
        fallback.strain = strain.map {
            ScoreValue(value: $0, scale: 0...21, confidence: resolvedConfidence, explanation: "Restored from cloud daily metric summary.")
        }

        let metadata = metadata ?? [:]
        fallback.sleepNeedMinutes = Self.doubleMetadata(metadata, "sleep_need_minutes")
        fallback.sleepDebtMinutes = Self.doubleMetadata(metadata, "sleep_debt_minutes")
        fallback.restingHeartRate = Self.doubleMetadata(metadata, "resting_heart_rate_bpm")
        fallback.restingHeartRateSource = Self.dataSourceMetadata(metadata, "resting_heart_rate_source") ?? fallback.source
        fallback.restingHeartRateConfidence = Self.confidenceMetadata(metadata, "resting_heart_rate_confidence") ?? resolvedConfidence
        fallback.averageHeartRate = Self.doubleMetadata(metadata, "average_heart_rate_bpm")
        fallback.maxHeartRate = Self.doubleMetadata(metadata, "max_heart_rate_bpm")
        fallback.heartRateSampleCount = Self.intMetadata(metadata, "heart_rate_sample_count")
        fallback.heartRateCoverageMinutes = Self.doubleMetadata(metadata, "heart_rate_coverage_minutes")
        fallback.hrv = Self.doubleMetadata(metadata, "hrv_ms")
        fallback.hrvSource = Self.dataSourceMetadata(metadata, "hrv_source") ?? fallback.source
        fallback.hrvConfidence = Self.confidenceMetadata(metadata, "hrv_confidence") ?? resolvedConfidence
        fallback.respiratoryRate = Self.doubleMetadata(metadata, "respiratory_rate")
        fallback.respiratoryRateSource = Self.dataSourceMetadata(metadata, "respiratory_rate_source") ?? fallback.source
        fallback.respiratoryRateConfidence = Self.confidenceMetadata(metadata, "respiratory_rate_confidence") ?? resolvedConfidence
        fallback.oxygenSaturation = Self.doubleMetadata(metadata, "oxygen_saturation_percent")
        fallback.oxygenSaturationSource = Self.dataSourceMetadata(metadata, "oxygen_saturation_source") ?? fallback.source
        fallback.oxygenSaturationConfidence = Self.confidenceMetadata(metadata, "oxygen_saturation_confidence") ?? resolvedConfidence
        fallback.vo2Max = Self.doubleMetadata(metadata, "vo2_max_ml_kg_min")
        fallback.vo2MaxSource = Self.dataSourceMetadata(metadata, "vo2_max_source") ?? fallback.source
        fallback.vo2MaxConfidence = Self.confidenceMetadata(metadata, "vo2_max_confidence") ?? resolvedConfidence
        fallback.rawWristTemperatureC = Self.doubleMetadata(metadata, "raw_wrist_temperature_c")
        fallback.rawWristTemperatureSource = Self.dataSourceMetadata(metadata, "raw_wrist_temperature_source") ?? fallback.source
        fallback.rawWristTemperatureConfidence = Self.confidenceMetadata(metadata, "raw_wrist_temperature_confidence") ?? resolvedConfidence
        fallback.bodyTemperatureDelta = Self.doubleMetadata(metadata, "skin_temperature_delta_c")
        fallback.movement.steps = Self.intMetadata(metadata, "steps")
        fallback.movement.activeEnergyKilocalories = Self.doubleMetadata(metadata, "active_energy_kcal")
        fallback.movement.walkingRunningDistanceMeters = Self.doubleMetadata(metadata, "distance_m")
        fallback.movement.movementMinutes = Self.doubleMetadata(metadata, "movement_minutes")
        fallback.movement.source = Self.dataSourceMetadata(metadata, "movement_source") ?? fallback.source
        fallback.movement.confidence = resolvedConfidence
        fallback.movement.lastUpdated = lastSyncedAt

        if var summary = summaryPayload, summary.hasSyncableContent {
            Self.mergeMissingCloudSummaryFields(into: &summary, from: fallback)
            return summary.hasSyncableContent ? summary : nil
        }

        return fallback.hasSyncableContent ? fallback : nil
    }

    private static func mergeMissingCloudSummaryFields(
        into summary: inout DailyHealthSummary,
        from fallback: DailyHealthSummary
    ) {
        fillMissing(\.recovery, in: &summary, from: fallback)
        fillMissing(\.strain, in: &summary, from: fallback)
        if summary.sleepSummary?.hasSleep != true, fallback.sleepSummary?.hasSleep == true {
            summary.sleepSummary = fallback.sleepSummary
        }
        fillMissing(\.sleepMinutes, in: &summary, from: fallback)
        fillMissing(\.sleepNeedMinutes, in: &summary, from: fallback)
        fillMissing(\.sleepDebtMinutes, in: &summary, from: fallback)
        fillMissing(\.restingHeartRate, in: &summary, from: fallback)
        fillMissing(\.restingHeartRateSource, in: &summary, from: fallback)
        fillMissing(\.restingHeartRateConfidence, in: &summary, from: fallback)
        fillMissing(\.averageHeartRate, in: &summary, from: fallback)
        fillMissing(\.maxHeartRate, in: &summary, from: fallback)
        fillMissing(\.heartRateSampleCount, in: &summary, from: fallback)
        fillMissing(\.heartRateCoverageMinutes, in: &summary, from: fallback)
        fillMissing(\.hrv, in: &summary, from: fallback)
        fillMissing(\.hrvSource, in: &summary, from: fallback)
        fillMissing(\.hrvConfidence, in: &summary, from: fallback)
        fillMissing(\.respiratoryRate, in: &summary, from: fallback)
        fillMissing(\.respiratoryRateSource, in: &summary, from: fallback)
        fillMissing(\.respiratoryRateConfidence, in: &summary, from: fallback)
        fillMissing(\.oxygenSaturation, in: &summary, from: fallback)
        fillMissing(\.oxygenSaturationSource, in: &summary, from: fallback)
        fillMissing(\.oxygenSaturationConfidence, in: &summary, from: fallback)
        fillMissing(\.vo2Max, in: &summary, from: fallback)
        fillMissing(\.vo2MaxSource, in: &summary, from: fallback)
        fillMissing(\.vo2MaxConfidence, in: &summary, from: fallback)
        fillMissing(\.rawWristTemperatureC, in: &summary, from: fallback)
        fillMissing(\.rawWristTemperatureSource, in: &summary, from: fallback)
        fillMissing(\.rawWristTemperatureConfidence, in: &summary, from: fallback)
        fillMissing(\.bodyTemperatureDelta, in: &summary, from: fallback)
        if summary.movement.steps == nil {
            summary.movement.steps = fallback.movement.steps
        }
        if summary.movement.activeEnergyKilocalories == nil {
            summary.movement.activeEnergyKilocalories = fallback.movement.activeEnergyKilocalories
        }
        if summary.movement.walkingRunningDistanceMeters == nil {
            summary.movement.walkingRunningDistanceMeters = fallback.movement.walkingRunningDistanceMeters
        }
        if summary.movement.movementMinutes == nil {
            summary.movement.movementMinutes = fallback.movement.movementMinutes
        }
        if summary.movement.source == nil {
            summary.movement.source = fallback.movement.source
        }
        if summary.movement.confidence == .unavailable {
            summary.movement.confidence = fallback.movement.confidence
        }
        if summary.movement.lastUpdated == nil {
            summary.movement.lastUpdated = fallback.movement.lastUpdated
        }
        if summary.source == nil {
            summary.source = fallback.source
        }
        if summary.confidence == .unavailable {
            summary.confidence = fallback.confidence
        }
    }

    private static func fillMissing<Value>(
        _ keyPath: WritableKeyPath<DailyHealthSummary, Value?>,
        in summary: inout DailyHealthSummary,
        from fallback: DailyHealthSummary
    ) {
        if summary[keyPath: keyPath] == nil {
            summary[keyPath: keyPath] = fallback[keyPath: keyPath]
        }
    }

    private static var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static func confidenceLevel(from score: Double) -> ConfidenceLevel {
        switch score {
        case 0.9...:
            return .high
        case 0.5..<0.9:
            return .medium
        case 0.01..<0.5:
            return .low
        default:
            return .unavailable
        }
    }

    private static func doubleMetadata(_ metadata: [String: String], _ key: String) -> Double? {
        metadata[key].flatMap(Double.init)
    }

    private static func intMetadata(_ metadata: [String: String], _ key: String) -> Int? {
        metadata[key].flatMap(Int.init)
    }

    private static func dataSourceMetadata(_ metadata: [String: String], _ key: String) -> DataSource? {
        metadata[key].flatMap(DataSource.init(rawValue:))
    }

    private static func confidenceMetadata(_ metadata: [String: String], _ key: String) -> ConfidenceLevel? {
        metadata[key].flatMap(ConfidenceLevel.init(rawValue:))
    }
}

private enum AccountSyncRequestError: Error {
    case invalidURL
}

private struct CloudUserProfileRow: Codable, Equatable {
    let email: String?
    let birthDate: String?
    let biologicalSex: BiologicalSex?
    let heightCentimeters: Double?
    let weightKilograms: Double?
    let configuredMaxHeartRate: Double?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case email
        case birthDate = "birth_date"
        case biologicalSex = "biological_sex"
        case heightCentimeters = "height_centimeters"
        case weightKilograms = "weight_kilograms"
        case configuredMaxHeartRate = "configured_max_heart_rate"
        case updatedAt = "updated_at"
    }

    var bodyProfile: BodyProfile {
        BodyProfile(
            birthDate: Self.date(from: birthDate),
            biologicalSex: biologicalSex ?? .notSet,
            heightCentimeters: heightCentimeters,
            weightKilograms: weightKilograms,
            configuredMaxHeartRate: configuredMaxHeartRate,
            updatedAt: updatedAt
        )
    }

    private static func date(from value: String?) -> Date? {
        guard let value else { return nil }
        return AccountSyncDateCodec.birthDateFormatter.date(from: value)
    }
}

private struct CloudUserProfileUpsertRow: Codable, Equatable {
    let userID: UUID
    let email: String?
    let birthDate: String?
    let biologicalSex: BiologicalSex
    let heightCentimeters: Double?
    let weightKilograms: Double?
    let configuredMaxHeartRate: Double?

    init(userID: UUID, email: String?, bodyProfile: BodyProfile) {
        self.userID = userID
        self.email = email
        birthDate = AccountSyncDateCodec.birthDateString(from: bodyProfile.birthDate)
        biologicalSex = bodyProfile.biologicalSex
        heightCentimeters = bodyProfile.heightCentimeters
        weightKilograms = bodyProfile.weightKilograms
        configuredMaxHeartRate = bodyProfile.configuredMaxHeartRate
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case birthDate = "birth_date"
        case biologicalSex = "biological_sex"
        case heightCentimeters = "height_centimeters"
        case weightKilograms = "weight_kilograms"
        case configuredMaxHeartRate = "configured_max_heart_rate"
    }
}

private struct AccountDeletionRequestRow: Codable, Equatable {
    let userID: UUID
    let email: String?
    let status = "pending"

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case status
    }
}

private struct CloudUserSettingsRow: Decodable, Equatable {
    let appleHealthEnabled: Bool?
    let healthCloudSyncEnabled: Bool?
    let syncPreferences: CloudSyncPreferences?
    let appleHealthPreferences: CloudAppleHealthPreferences?
    let baselineProfiles: CloudBaselineProfiles?
    let callVibrationSettings: CloudCallVibrationSettings?
    let uiPreferences: CloudUIPreferences?
    let wearableDeviceConfiguration: CloudWearableDeviceConfiguration?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case appleHealthEnabled = "apple_health_enabled"
        case healthCloudSyncEnabled = "health_cloud_sync_enabled"
        case syncPreferences = "sync_preferences"
        case appleHealthPreferences = "apple_health_preferences"
        case baselineProfiles = "baseline_profiles"
        case callVibrationSettings = "call_vibration_settings"
        case uiPreferences = "ui_preferences"
        case wearableDeviceConfiguration = "wearable_device_configuration"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        appleHealthEnabled = try container.decodeIfPresent(Bool.self, forKey: .appleHealthEnabled)
        healthCloudSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .healthCloudSyncEnabled)
        syncPreferences = try? container.decodeIfPresent(CloudSyncPreferences.self, forKey: .syncPreferences)
        appleHealthPreferences = try? container.decodeIfPresent(CloudAppleHealthPreferences.self, forKey: .appleHealthPreferences)
        baselineProfiles = try? container.decodeIfPresent(CloudBaselineProfiles.self, forKey: .baselineProfiles)
        callVibrationSettings = try? container.decodeIfPresent(CloudCallVibrationSettings.self, forKey: .callVibrationSettings)
        uiPreferences = try? container.decodeIfPresent(CloudUIPreferences.self, forKey: .uiPreferences)
        wearableDeviceConfiguration = try? container.decodeIfPresent(
            CloudWearableDeviceConfiguration.self,
            forKey: .wearableDeviceConfiguration
        )
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
    }

    var consentState: ConsentState {
        ConsentState(
            cloudSyncEnabled: healthCloudSyncEnabled ?? false,
            healthDataCloudConsent: syncPreferences?.healthDataCloudConsent ?? false,
            appleHealthEnabled: appleHealthPreferences?.enabled ?? appleHealthEnabled ?? false,
            cloudSyncPromptDismissed: syncPreferences?.cloudSyncPromptDismissed ?? false
        )
    }
}

private struct CloudCallVibrationSettings: Decodable, Equatable {
    let enabled: Bool?
    let patternID: UUID?
    let declineOnDoubleTapEnabled: Bool?
    let supportsDecline: Bool?
    let platformStatus: CallPlatformStatus?
    let lastUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case enabled
        case patternID
        case declineOnDoubleTapEnabled
        case supportsDecline
        case platformStatus
        case lastUpdatedAt
    }

    var settings: CallVibrationSettings {
        CallVibrationSettings(
            enabled: enabled ?? false,
            patternID: patternID ?? VibrationPattern.standardID,
            declineOnDoubleTapEnabled: declineOnDoubleTapEnabled ?? false,
            supportsDecline: supportsDecline ?? false,
            platformStatus: platformStatus ?? .normalCellularPlatformBlocked,
            lastUpdatedAt: lastUpdatedAt ?? .distantPast
        )
    }
}

private struct CloudUserSettingsUpsertRow: Codable, Equatable {
    let userID: UUID
    let metricUnits: Bool
    let appleHealthEnabled: Bool
    let healthCloudSyncEnabled: Bool
    let syncPreferences: CloudSyncPreferences
    let appleHealthPreferences: CloudAppleHealthPreferences
    let notificationVibrationPreferences: CloudNotificationVibrationPreferences
    let baselineProfiles: CloudBaselineProfiles?
    let callVibrationSettings: CallVibrationSettings
    let uiPreferences: CloudUIPreferences
    let wearableDeviceConfiguration: CloudWearableDeviceConfiguration

    init(userID: UUID, snapshot: AccountSyncSnapshot) {
        self.userID = userID
        metricUnits = true
        appleHealthEnabled = snapshot.consentState.appleHealthEnabled
        healthCloudSyncEnabled = snapshot.consentState.cloudSyncEnabled
        syncPreferences = CloudSyncPreferences(consent: snapshot.consentState)
        appleHealthPreferences = CloudAppleHealthPreferences(enabled: snapshot.consentState.appleHealthEnabled)
        notificationVibrationPreferences = CloudNotificationVibrationPreferences()
        baselineProfiles = snapshot.consentState.canUploadHealthData
            ? snapshot.skinTemperatureBaselineProfile.map { CloudBaselineProfiles(skinTemperature: $0) }
            : nil
        callVibrationSettings = snapshot.callVibrationSettings
        uiPreferences = CloudUIPreferences(
            themePreference: snapshot.themePreference,
            movementGoal: snapshot.movementGoal
        )
        wearableDeviceConfiguration = CloudWearableDeviceConfiguration(alarms: snapshot.alarms)
    }

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case metricUnits = "metric_units"
        case appleHealthEnabled = "apple_health_enabled"
        case healthCloudSyncEnabled = "health_cloud_sync_enabled"
        case syncPreferences = "sync_preferences"
        case appleHealthPreferences = "apple_health_preferences"
        case notificationVibrationPreferences = "notification_vibration_preferences"
        case baselineProfiles = "baseline_profiles"
        case callVibrationSettings = "call_vibration_settings"
        case uiPreferences = "ui_preferences"
        case wearableDeviceConfiguration = "wearable_device_configuration"
    }
}

private struct CloudBaselineProfiles: Codable, Equatable {
    var skinTemperature: SkinTemperatureBaselineProfile

    init(skinTemperature: SkinTemperatureBaselineProfile = SkinTemperatureBaselineProfile()) {
        self.skinTemperature = skinTemperature.sanitizedForCloudSync
    }

    enum CodingKeys: String, CodingKey {
        case skinTemperature
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        skinTemperature = (try container.decodeIfPresent(
            SkinTemperatureBaselineProfile.self,
            forKey: .skinTemperature
        ) ?? SkinTemperatureBaselineProfile()).sanitizedForCloudSync
    }
}

private struct CloudSyncPreferences: Codable, Equatable {
    var localModeEnabled: Bool
    var healthDataCloudConsent: Bool
    var cloudSyncPromptDismissed: Bool

    init(
        localModeEnabled: Bool = true,
        healthDataCloudConsent: Bool = false,
        cloudSyncPromptDismissed: Bool = false
    ) {
        self.localModeEnabled = true
        self.healthDataCloudConsent = healthDataCloudConsent
        self.cloudSyncPromptDismissed = cloudSyncPromptDismissed
    }

    init(consent: ConsentState) {
        localModeEnabled = true
        healthDataCloudConsent = consent.healthDataCloudConsent
        cloudSyncPromptDismissed = consent.cloudSyncPromptDismissed
    }

    enum CodingKeys: String, CodingKey {
        case localModeEnabled
        case healthDataCloudConsent
        case cloudSyncPromptDismissed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        localModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .localModeEnabled) ?? true
        healthDataCloudConsent = try container.decodeIfPresent(Bool.self, forKey: .healthDataCloudConsent) ?? false
        cloudSyncPromptDismissed = try container.decodeIfPresent(Bool.self, forKey: .cloudSyncPromptDismissed) ?? false
    }
}

private struct CloudAppleHealthPreferences: Codable, Equatable {
    var enabled: Bool

    init(enabled: Bool = false) {
        self.enabled = enabled
    }

    enum CodingKeys: String, CodingKey {
        case enabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
    }
}

private struct CloudNotificationVibrationPreferences: Codable, Equatable {
    var enabled: Bool = false
}

private struct CloudUIPreferences: Codable, Equatable {
    var themePreference: String
    var movementGoal: Int

    init(
        themePreference: String = "system",
        movementGoal: Int = MovementSummary.empty().goal
    ) {
        self.themePreference = themePreference
        self.movementGoal = movementGoal
    }

    enum CodingKeys: String, CodingKey {
        case themePreference
        case movementGoal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        themePreference = try container.decodeIfPresent(String.self, forKey: .themePreference) ?? "system"
        movementGoal = try container.decodeIfPresent(Int.self, forKey: .movementGoal) ?? MovementSummary.empty().goal
    }
}

private struct CloudWearableDeviceConfiguration: Codable, Equatable {
    var alarms: [Alarm]

    init(alarms: [Alarm] = []) {
        self.alarms = alarms
    }

    enum CodingKeys: String, CodingKey {
        case alarms
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        alarms = try container.decodeIfPresent([Alarm].self, forKey: .alarms) ?? []
    }
}

private enum AccountSyncDateCodec {
    static let birthDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func birthDateString(from date: Date?) -> String? {
        date.map { birthDateFormatter.string(from: $0) }
    }
}

struct HealthSampleRow: Codable, Equatable {
    let userID: UUID
    let sampleType: String
    let value: Double
    let unit: String
    let sampledAt: Date
    let endedAt: Date?
    let source: String
    let sourceRecordID: String?
    let metadata: [String: String]
    let dedupeKey: String
    let syncStatus: String
    let lastSyncedAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case sampleType = "sample_type"
        case value
        case unit
        case sampledAt = "sampled_at"
        case endedAt = "ended_at"
        case source
        case sourceRecordID = "source_record_id"
        case metadata
        case dedupeKey = "dedupe_key"
        case syncStatus = "sync_status"
        case lastSyncedAt = "last_synced_at"
    }

    init(
        userID: UUID,
        sampleType: String,
        value: Double,
        unit: String,
        sampledAt: Date,
        endedAt: Date?,
        source: String,
        sourceRecordID: String?,
        metadata: [String: String],
        dedupeKey: String,
        syncStatus: String,
        lastSyncedAt: Date
    ) {
        self.userID = userID
        self.sampleType = sampleType
        self.value = value
        self.unit = unit
        self.sampledAt = sampledAt
        self.endedAt = endedAt
        self.source = source
        self.sourceRecordID = sourceRecordID
        self.metadata = metadata
        self.dedupeKey = dedupeKey
        self.syncStatus = syncStatus
        self.lastSyncedAt = lastSyncedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        userID = try container.decode(UUID.self, forKey: .userID)
        sampleType = try container.decode(String.self, forKey: .sampleType)
        value = try container.decode(Double.self, forKey: .value)
        unit = try container.decode(String.self, forKey: .unit)
        sampledAt = try container.decode(Date.self, forKey: .sampledAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        source = try container.decode(String.self, forKey: .source)
        sourceRecordID = try container.decodeIfPresent(String.self, forKey: .sourceRecordID)
        metadata = container.decodeStringMetadataIfPresent(forKey: .metadata) ?? [:]
        dedupeKey = try container.decode(String.self, forKey: .dedupeKey)
        syncStatus = try container.decode(String.self, forKey: .syncStatus)
        lastSyncedAt = try container.decode(Date.self, forKey: .lastSyncedAt)
    }

    func cloudRestoredSample() -> HealthSample? {
        guard let type = Self.restoredSampleType(sampleType) else { return nil }
        let storedSource = Self.restoredSource(source)
        let originalSource: DataSource = storedSource == .appleHealth ? .legacyWearableDeviceExport : storedSource
        var restoredMetadata = metadata
        restoredMetadata["cloud_restored"] = "true"
        restoredMetadata["cloud_dedupe_key"] = dedupeKey
        if sampleType != type.rawValue {
            restoredMetadata["cloud_original_sample_type"] = sampleType
        }
        if source != originalSource.rawValue {
            restoredMetadata["cloud_original_source"] = source
        }
        if storedSource == .appleHealth {
            restoredMetadata["legacy_wearable_device_export"] = "true"
            restoredMetadata["cloud_original_source"] = DataSource.appleHealth.rawValue
            restoredMetadata["source_label"] = originalSource.label
        } else {
            restoredMetadata["source_label"] = restoredMetadata["source_label"] ?? originalSource.label
        }
        let restoredRecordID = "cloud:\(dedupeKey)"
        return HealthSample(
            id: restoredRecordID,
            type: type,
            value: value,
            unit: unit,
            startDate: sampledAt,
            endDate: endedAt,
            source: originalSource,
            sourceRecordID: restoredRecordID,
            confidence: restoredMetadata["confidence"].flatMap(ConfidenceLevel.init(rawValue:)) ?? .medium,
            metadata: restoredMetadata
        )
    }

    private static func restoredSampleType(_ rawValue: String) -> HealthSampleType? {
        if let type = HealthSampleType(rawValue: rawValue) {
            return type
        }
        switch rawValue {
        case "active_energy", "active_energy_burned":
            return .activeEnergy
        case "body_temperature":
            return .bodyTemperature
        case "distance", "distance_walking_running":
            return .distanceWalkingRunning
        case "heart_rate":
            return .heartRate
        case "hrv", "hrv_rmssd", "heart_rate_variability_rmssd":
            return .heartRateVariabilityRMSSD
        case "hrv_sdnn", "heart_rate_variability_sdnn":
            return .heartRateVariabilitySDNN
        case "oxygen_saturation", "spo2":
            return .oxygenSaturation
        case "respiratory_rate":
            return .respiratoryRate
        case "resting_heart_rate":
            return .restingHeartRate
        case "sleep", "sleep_analysis":
            return .sleepAnalysis
        case "temperature_event":
            return .temperatureEvent
        case "vo2_max":
            return .vo2Max
        case "wearable_imu":
            return .wearableIMU
        case "wearable_ppg":
            return .wearablePPG
        case "wrist_temperature":
            return .wristTemperature
        default:
            return nil
        }
    }

    private static func restoredSource(_ rawValue: String) -> DataSource {
        if let source = DataSource(rawValue: rawValue) {
            return source
        }
        switch rawValue {
        case "wearable_live", "wearable_summary":
            return .wearableBLE
        case "legacy_wearable", "wearable_device_export", "legacy_wearable_export":
            return .legacyWearableDeviceExport
        case "whoordan":
            return .whoordanEstimate
        default:
            return .cloudImport
        }
    }
}

private struct LossyMetadataValue: Decodable {
    let stringValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            stringValue = ""
        } else if let value = try? container.decode(String.self) {
            stringValue = value
        } else if let value = try? container.decode(Int.self) {
            stringValue = "\(value)"
        } else if let value = try? container.decode(Double.self) {
            stringValue = "\(value)"
        } else if let value = try? container.decode(Bool.self) {
            stringValue = value ? "true" : "false"
        } else {
            stringValue = ""
        }
    }
}

private extension KeyedDecodingContainer {
    func decodeStringMetadataIfPresent(forKey key: Key) -> [String: String]? {
        if let metadata = try? decodeIfPresent([String: String].self, forKey: key) {
            return metadata
        }
        if let metadata = try? decodeIfPresent([String: LossyMetadataValue].self, forKey: key) {
            return metadata.mapValues(\.stringValue)
        }
        return nil
    }
}

struct DailyHealthSummaryRow: Codable, Equatable {
    let userID: UUID
    let summaryDate: String
    let recoveryScore: Double?
    let sleepSeconds: Int?
    let strain: Double?
    let confidence: Double
    let source: String
    let metadata: [String: String]
    let metricPayloadVersion: Int
    let summaryPayload: DailyHealthSummary
    let readyMetricSnapshots: [WhoordanMetricSnapshot]
    let dedupeKey: String
    let syncStatus: String
    let lastSyncedAt: Date

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case summaryDate = "summary_date"
        case recoveryScore = "recovery_score"
        case sleepSeconds = "sleep_seconds"
        case strain
        case confidence
        case source
        case metadata
        case metricPayloadVersion = "metric_payload_version"
        case summaryPayload = "summary_payload"
        case readyMetricSnapshots = "ready_metric_snapshots"
        case dedupeKey = "dedupe_key"
        case syncStatus = "sync_status"
        case lastSyncedAt = "last_synced_at"
    }
}

private struct SupabaseSessionResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: TimeInterval?
    let user: SupabaseUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }

    func toSession(fallbackEmail: String, now: Date = Date()) throws -> AuthSession {
        guard let token = accessToken, let id = user?.id else {
            throw AuthError.unsupportedResponse
        }
        return AuthSession(
            userID: id,
            email: user?.email ?? fallbackEmail,
            accessToken: token,
            refreshToken: refreshToken,
            expiresAt: expiresIn.map { now.addingTimeInterval($0) }
        )
    }
}

private struct SupabaseUser: Decodable {
    let id: UUID
    let email: String?
}

private struct ApprovalRow: Decodable {
    let approvalStatus: String

    enum CodingKeys: String, CodingKey {
        case approvalStatus = "approval_status"
    }
}

extension JSONDecoder {
    static var whoordan: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = SupabaseDateCodec.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid Supabase timestamp."
            )
        }
        return decoder
    }
}

extension JSONEncoder {
    static var whoordan: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private enum SupabaseDateCodec {
    static func date(from value: String) -> Date? {
        fractionalISOFormatter.date(from: value)
            ?? wholeSecondISOFormatter.date(from: value)
            ?? postgresFractionalFormatter.date(from: value)
            ?? postgresWholeSecondFormatter.date(from: value)
    }

    private static let fractionalISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let wholeSecondISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let postgresFractionalFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSxx"
        return formatter
    }()

    private static let postgresWholeSecondFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ssxx"
        return formatter
    }()
}
