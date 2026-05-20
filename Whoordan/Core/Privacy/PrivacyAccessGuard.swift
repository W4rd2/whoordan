import Foundation

struct PrivacyAccessGuard {
    func canAccessProtectedData(approval: ApprovalState?) -> Bool {
        approval?.allowsProtectedLocalAccess == true
    }

    func canStartProtectedService(approval: ApprovalState?) -> Bool {
        approval?.allowsProtectedLocalAccess == true
    }

    func canUploadHealthData(approval: ApprovalState?, consent: ConsentState) -> Bool {
        approval?.allowsCloudUpload == true && consent.canUploadHealthData
    }

    func canRestoreHealthData(approval: ApprovalState?, consent: ConsentState) -> Bool {
        approval?.allowsCloudUpload == true && consent.canUploadHealthData
    }

    func canUploadSettingsData(approval: ApprovalState?, consent: ConsentState) -> Bool {
        approval?.allowsCloudUpload == true && consent.cloudSyncEnabled
    }

    func canRestoreSettingsData(approval: ApprovalState?, consent: ConsentState) -> Bool {
        approval?.allowsCloudUpload == true && consent.cloudSyncEnabled
    }

    func canQueueHealthData(approval: ApprovalState?, consent: ConsentState, userID: UUID?) -> Bool {
        userID != nil && approval?.allowsProtectedLocalAccess == true && consent.canUploadHealthData
    }

    func canQueueSettingsData(approval: ApprovalState?, consent: ConsentState, userID: UUID?) -> Bool {
        userID != nil
            && approval?.allowsCloudUpload == true
            && consent.cloudSyncEnabled
    }
}
