import Foundation

enum ApprovalStatus: String, Codable, Equatable, CaseIterable {
    case checkingApproval = "checking_approval"
    case pending
    case approved
    case offlineApproved = "offline_approved"
    case rejected
    case revoked
    case missing
    case authExpired = "auth_expired"
    case networkUnavailable = "network_unavailable"
    case approvalFetchFailed = "approval_fetch_failed"
    case unknown
    case unknownError = "unknown_error"
    case error
}

enum AppLifecyclePhase: Equatable {
    case active
    case inactive
    case background
}

struct ApprovalState: Codable, Equatable {
    let status: ApprovalStatus
    let message: String
    let checkedAt: Date

    static func approved() -> ApprovalState {
        ApprovalState(status: .approved, message: "Approved", checkedAt: Date())
    }

    static func offlineApproved(lastVerifiedAt: Date) -> ApprovalState {
        ApprovalState(
            status: .offlineApproved,
            message: "Offline mode. Using last verified approval from \(shortDateFormatter.string(from: lastVerifiedAt)). Cloud sync will stay paused until Whoordan verifies approval online again.",
            checkedAt: Date()
        )
    }

    static func checkingApproval() -> ApprovalState {
        ApprovalState(status: .checkingApproval, message: "Checking account approval.", checkedAt: Date())
    }

    static func pending() -> ApprovalState {
        ApprovalState(status: .pending, message: "Waiting for W4rd2 approval.", checkedAt: Date())
    }

    static func missing() -> ApprovalState {
        ApprovalState(status: .missing, message: "No approval row was found.", checkedAt: Date())
    }

    static func authExpired() -> ApprovalState {
        ApprovalState(status: .authExpired, message: "Session expired. Sign in again to continue.", checkedAt: Date())
    }

    static func networkUnavailable(lastVerifiedAt: Date? = nil) -> ApprovalState {
        var message = "Can't verify approval while offline."
        if let lastVerifiedAt {
            message += " Last successful approval check: \(Self.shortDateFormatter.string(from: lastVerifiedAt))."
        }
        return ApprovalState(status: .networkUnavailable, message: message, checkedAt: Date())
    }

    static func approvalFetchFailed(message: String = "Approval check failed. Try again.") -> ApprovalState {
        ApprovalState(status: .approvalFetchFailed, message: message, checkedAt: Date())
    }

    static func unknown(message: String) -> ApprovalState {
        ApprovalState(status: .unknown, message: message, checkedAt: Date())
    }

    static func error(message: String) -> ApprovalState {
        ApprovalState(status: .error, message: message, checkedAt: Date())
    }

    static func unknownError(message: String) -> ApprovalState {
        ApprovalState(status: .unknownError, message: message, checkedAt: Date())
    }

    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    var allowsProtectedLocalAccess: Bool {
        status == .approved || status == .offlineApproved
    }

    var allowsCloudUpload: Bool {
        status == .approved
    }
}

struct AuthSession: Codable, Equatable {
    let userID: UUID
    let email: String
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date?
}

enum ConfidenceLevel: String, Codable, Equatable {
    case high
    case medium
    case directional
    case low
    case blocked
    case unavailable

    var label: String {
        switch self {
        case .high: return "High confidence"
        case .medium: return "Medium confidence"
        case .directional: return "Directional"
        case .low: return "Limited data"
        case .blocked: return "Blocked"
        case .unavailable: return "Unavailable"
        }
    }
}

enum DataSource: String, Codable, Equatable {
    case appleHealth = "apple_health"
    case wearableBLE = "wearable_ble"
    case legacyWearableDeviceExport = "legacy_wearable_device_export"
    case localManual = "local_manual"
    case whoordanEstimate = "whoordan_estimate"
    case cloudImport = "cloud_import"
    case syntheticFixture = "synthetic_fixture"

    var label: String {
        switch self {
        case .appleHealth: return "Apple Health"
        case .wearableBLE: return "Wearable direct"
        case .legacyWearableDeviceExport: return "Legacy device export"
        case .localManual: return "Manual"
        case .whoordanEstimate: return "Whoordan estimate"
        case .cloudImport: return "Cloud backup"
        case .syntheticFixture: return "Synthetic test fixture"
        }
    }

    var deviceFirstRank: Int {
        switch self {
        case .wearableBLE:
            return 0
        case .legacyWearableDeviceExport:
            return 1
        case .appleHealth:
            return 2
        case .cloudImport:
            return 3
        case .whoordanEstimate:
            return 4
        case .localManual:
            return 5
        case .syntheticFixture:
            return 6
        }
    }
}

struct ConsentState: Codable, Equatable {
    var localModeEnabled = true
    var cloudSyncEnabled = false
    var healthDataCloudConsent = false
    var appleHealthEnabled = false
    var cloudSyncPromptDismissed = false

    init(
        localModeEnabled: Bool = true,
        cloudSyncEnabled: Bool = false,
        healthDataCloudConsent: Bool = false,
        appleHealthEnabled: Bool = false,
        cloudSyncPromptDismissed: Bool = false
    ) {
        self.localModeEnabled = localModeEnabled
        self.cloudSyncEnabled = cloudSyncEnabled
        self.healthDataCloudConsent = cloudSyncEnabled && healthDataCloudConsent
        self.appleHealthEnabled = appleHealthEnabled
        self.cloudSyncPromptDismissed = cloudSyncPromptDismissed
    }

    var canUploadHealthData: Bool {
        cloudSyncEnabled && healthDataCloudConsent
    }

    var normalizedForCurrentPrivacyModel: ConsentState {
        var normalized = self
        normalized.localModeEnabled = true
        if !normalized.cloudSyncEnabled {
            normalized.healthDataCloudConsent = false
        }
        return normalized
    }
}

struct VibrationPreviewResult: Codable, Equatable {
    var status: VibrationPreviewStatus
    var commandsSent: [String] = []
    var message: String = ""
    var occurredAt = Date()
    var errorCategory: VibrationPlaybackErrorCategory?

    var safeMessage: String {
        message
    }
}
