import Foundation

protocol ApprovalServicing {
    func fetchApproval(for userID: UUID) async throws -> ApprovalState
}

struct StaticApprovalService: ApprovalServicing {
    let state: ApprovalState

    func fetchApproval(for userID: UUID) async throws -> ApprovalState {
        state
    }
}
