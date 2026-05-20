import Foundation

#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

final class BackgroundSyncCoordinator {
    static let refreshIdentifier = "com.w4rd2.whoordan.refresh"
    private var isRegistered = false
    private var onRefresh: (@Sendable () async -> Void)?

    func register(onRefresh: @escaping @Sendable () async -> Void) {
        self.onRefresh = onRefresh
        #if canImport(BackgroundTasks)
        guard !isRegistered else { return }
        isRegistered = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.refreshIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handle(task: task)
        }
        #endif
    }

    func schedule() {
        #if canImport(BackgroundTasks)
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 30 * 60)
        try? BGTaskScheduler.shared.submit(request)
        #endif
    }

    #if canImport(BackgroundTasks)
    private func handle(task: BGTask) {
        schedule()
        let work = Task {
            await onRefresh?()
            task.setTaskCompleted(success: !Task.isCancelled)
        }
        task.expirationHandler = {
            work.cancel()
        }
    }
    #endif
}
