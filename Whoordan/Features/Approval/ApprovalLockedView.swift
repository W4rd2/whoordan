import SwiftUI

struct ApprovalLockedView: View {
    @EnvironmentObject private var environment: AppEnvironment
    let state: ApprovalState

    var body: some View {
        WLockedState(
            title: title,
            message: message,
            status: state.status.rawValue,
            refresh: {
                Task { try? await environment.refreshApproval() }
            },
            signOut: {
                Task { await environment.signOut() }
            },
            secondaryButtonTitle: state.status == .authExpired ? "Sign In" : "Erase Local Data and Sign Out"
        )
    }

    private var title: String {
        switch state.status {
        case .checkingApproval: return "Checking approval."
        case .pending: return "Access is waiting for approval."
        case .rejected: return "Access was not approved."
        case .revoked: return "Access has been revoked."
        case .missing: return "Approval status is missing."
        case .authExpired: return "Session expired."
        case .networkUnavailable: return "Can't verify approval while offline."
        case .approvalFetchFailed: return "Approval check failed."
        case .unknownError, .error, .unknown: return "Approval status unavailable."
        case .approved: return "Approved"
        case .offlineApproved: return "Offline mode"
        }
    }

    private var message: String {
        switch state.status {
        case .checkingApproval:
            return "Whoordan is verifying account approval before protected services start."
        case .pending:
            return "Whoordan stays locked until W4rd2 approves this account. No cached health, Bluetooth, Apple Health, local mode, or settings data is shown here."
        case .rejected:
            return "This account is locked. Sign out or contact W4rd2 if you think this is incorrect."
        case .revoked:
            return "Protected services have been stopped. Cached health and wearable data are hidden while access is revoked."
        case .authExpired:
            return "Sign in again so Whoordan can verify approval. Protected data and services remain locked until approval is confirmed."
        case .networkUnavailable:
            return state.message + " Protected features stay locked until approval can be verified."
        case .approvalFetchFailed:
            return state.message + " Use Refresh Status to retry without signing out."
        case .missing, .unknownError, .error, .unknown:
            return "Whoordan could not verify approval. The app fails closed and keeps protected features locked."
        case .approved, .offlineApproved:
            return state.message
        }
    }
}
