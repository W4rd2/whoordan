import Foundation

enum AppRoute: Equatable {
    case sessionRestore
    case signedOut
    case approvalLocked(ApprovalState)
    case approved
}

struct AppRouter {
    static func route(session: AuthSession?, approval: ApprovalState?, restoring: Bool) -> AppRoute {
        if restoring {
            return .sessionRestore
        }
        if let approval, approval.status == .authExpired {
            return .approvalLocked(approval)
        }
        guard session != nil else {
            return .signedOut
        }
        guard let approval else {
            return .approvalLocked(.checkingApproval())
        }
        return approval.allowsProtectedLocalAccess ? .approved : .approvalLocked(approval)
    }
}
