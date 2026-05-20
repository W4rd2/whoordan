import XCTest
@testable import Whoordan

final class ApprovalGateTests: XCTestCase {
    func testRestoreSessionRefreshesExpiredSupabaseSessionAndPersistsRotatedTokens() async throws {
        let now = Date(timeIntervalSince1970: 1_000)
        let userID = UUID()
        let keychain = MemoryKeychainStore()
        let expired = AuthSession(
            userID: userID,
            email: "approved@example.invalid",
            accessToken: "expired-access",
            refreshToken: "old-refresh",
            expiresAt: now.addingTimeInterval(-5)
        )
        keychain.set(data: try JSONEncoder.whoordan.encode(expired), for: "auth.session")
        let httpClient = StubHTTPClient(
            data: """
            {
              "access_token": "fresh-access",
              "refresh_token": "new-refresh",
              "expires_in": 3600,
              "user": {
                "id": "\(userID.uuidString)",
                "email": "approved@example.invalid"
              }
            }
            """.data(using: .utf8)!
        )
        let auth = SupabaseAuthService(
            config: SupabaseConfig(
                url: URL(string: "https://project-ref.supabase.co"),
                publishableKey: "publishable-key",
                projectID: "project-ref"
            ),
            keychain: keychain,
            httpClient: httpClient,
            now: { now }
        )

        let restored = try await auth.restoreSession()

        XCTAssertEqual(restored?.accessToken, "fresh-access")
        XCTAssertEqual(restored?.refreshToken, "new-refresh")
        XCTAssertEqual(auth.accessToken, "fresh-access")
        XCTAssertEqual(httpClient.requests.first?.url?.absoluteString, "https://project-ref.supabase.co/auth/v1/token?grant_type=refresh_token")
        XCTAssertEqual(httpClient.requests.first?.value(forHTTPHeaderField: "apikey"), "publishable-key")
        let body = try XCTUnwrap(httpClient.requests.first?.httpBody)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(payload["refresh_token"], "old-refresh")
        let persistedData = try XCTUnwrap(keychain.data(for: "auth.session"))
        let persisted = try JSONDecoder.whoordan.decode(AuthSession.self, from: persistedData)
        XCTAssertEqual(persisted.accessToken, "fresh-access")
        XCTAssertEqual(persisted.refreshToken, "new-refresh")
    }

    func testRestoreSessionKeepsUnexpiredSessionWithoutRefreshing() async throws {
        let now = Date(timeIntervalSince1970: 2_000)
        let keychain = MemoryKeychainStore()
        let current = AuthSession(
            userID: UUID(),
            email: "approved@example.invalid",
            accessToken: "current-access",
            refreshToken: "current-refresh",
            expiresAt: now.addingTimeInterval(3_600)
        )
        keychain.set(data: try JSONEncoder.whoordan.encode(current), for: "auth.session")
        let httpClient = StubHTTPClient(data: Data())
        let auth = SupabaseAuthService(
            config: SupabaseConfig(
                url: URL(string: "https://project-ref.supabase.co"),
                publishableKey: "publishable-key",
                projectID: "project-ref"
            ),
            keychain: keychain,
            httpClient: httpClient,
            now: { now }
        )

        let restored = try await auth.restoreSession()

        XCTAssertEqual(restored, current)
        XCTAssertEqual(auth.accessToken, "current-access")
        XCTAssertTrue(httpClient.requests.isEmpty)
    }

    func testRestoreExpiredSessionFallsBackToStoredSessionWhenRefreshIsOffline() async throws {
        let now = Date(timeIntervalSince1970: 2_500)
        let keychain = MemoryKeychainStore()
        let expired = AuthSession(
            userID: UUID(),
            email: "approved@example.invalid",
            accessToken: "cached-access",
            refreshToken: "refresh-token",
            expiresAt: now.addingTimeInterval(-60)
        )
        keychain.set(data: try JSONEncoder.whoordan.encode(expired), for: "auth.session")
        let httpClient = StubHTTPClient(responses: [
            .init(error: URLError(.notConnectedToInternet))
        ])
        let auth = SupabaseAuthService(
            config: testSupabaseConfig(),
            keychain: keychain,
            httpClient: httpClient,
            now: { now }
        )

        let restored = try await auth.restoreSession()

        XCTAssertEqual(restored, expired)
        XCTAssertEqual(auth.accessToken, "cached-access")
        XCTAssertEqual(httpClient.requests.count, 1)
        XCTAssertNotNil(keychain.data(for: "auth.session"))
    }

    @MainActor
    func testApprovalFetchUnauthorizedRefreshesSessionAndRetriesOnce() async throws {
        let now = Date(timeIntervalSince1970: 3_000)
        let userID = UUID()
        let keychain = MemoryKeychainStore()
        let stale = AuthSession(
            userID: userID,
            email: "approved@example.invalid",
            accessToken: "stale-access",
            refreshToken: "refresh-token",
            expiresAt: now.addingTimeInterval(3_600)
        )
        keychain.set(data: try JSONEncoder.whoordan.encode(stale), for: "auth.session")
        let httpClient = StubHTTPClient(responses: [
            .init(data: "{}".data(using: .utf8)!, statusCode: 401),
            .init(data: sessionJSON(userID: userID, access: "fresh-access", refresh: "fresh-refresh"), statusCode: 200),
            .init(data: #"[{"approval_status":"approved"}]"#.data(using: .utf8)!, statusCode: 200)
        ])
        let config = testSupabaseConfig()
        let auth = SupabaseAuthService(config: config, keychain: keychain, httpClient: httpClient, now: { now })
        let environment = try makeEnvironment(auth: auth, approval: SupabaseApprovalService(config: config, authTokenProvider: auth, httpClient: httpClient))

        await environment.restore()

        let route = environment.route
        XCTAssertEqual(route, .approved)
        XCTAssertEqual(auth.accessToken, "fresh-access")
        XCTAssertEqual(httpClient.requests.count, 3)
        XCTAssertEqual(httpClient.requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer stale-access")
        XCTAssertEqual(httpClient.requests[1].url?.absoluteString, "https://project-ref.supabase.co/auth/v1/token?grant_type=refresh_token")
        XCTAssertEqual(httpClient.requests[2].value(forHTTPHeaderField: "Authorization"), "Bearer fresh-access")
    }

    @MainActor
    func testApprovalRetryShowsAuthExpiredWhenRefreshTokenIsRejected() async throws {
        let now = Date(timeIntervalSince1970: 4_000)
        let userID = UUID()
        let keychain = MemoryKeychainStore()
        keychain.set(data: try JSONEncoder.whoordan.encode(AuthSession(
            userID: userID,
            email: "approved@example.invalid",
            accessToken: "stale-access",
            refreshToken: "revoked-refresh",
            expiresAt: now.addingTimeInterval(3_600)
        )), for: "auth.session")
        let httpClient = StubHTTPClient(responses: [
            .init(data: "{}".data(using: .utf8)!, statusCode: 401),
            .init(data: #"{"code":"invalid_grant"}"#.data(using: .utf8)!, statusCode: 400)
        ])
        let config = testSupabaseConfig()
        let auth = SupabaseAuthService(config: config, keychain: keychain, httpClient: httpClient, now: { now })
        let environment = try makeEnvironment(auth: auth, approval: SupabaseApprovalService(config: config, authTokenProvider: auth, httpClient: httpClient))

        await environment.restore()

        let approval = try XCTUnwrap(environment.approvalState)
        let route = environment.route
        XCTAssertEqual(approval.status, .authExpired)
        XCTAssertEqual(route, .approvalLocked(approval))
        XCTAssertNil(keychain.data(for: "auth.session"))
    }

    @MainActor
    func testApprovalNetworkFailureStaysRetryableAndFailClosed() async throws {
        let now = Date(timeIntervalSince1970: 5_000)
        let userID = UUID()
        let keychain = MemoryKeychainStore()
        keychain.set(data: try JSONEncoder.whoordan.encode(AuthSession(
            userID: userID,
            email: "approved@example.invalid",
            accessToken: "valid-access",
            refreshToken: "refresh-token",
            expiresAt: now.addingTimeInterval(3_600)
        )), for: "auth.session")
        let httpClient = StubHTTPClient(responses: [
            .init(error: URLError(.notConnectedToInternet))
        ])
        let config = testSupabaseConfig()
        let auth = SupabaseAuthService(config: config, keychain: keychain, httpClient: httpClient, now: { now })
        let environment = try makeEnvironment(auth: auth, approval: SupabaseApprovalService(config: config, authTokenProvider: auth, httpClient: httpClient))

        await environment.restore()

        let approval = environment.approvalState
        let canStartProtectedService = environment.privacyGuard.canStartProtectedService(approval: approval)
        let snapshot = environment.todaySnapshot
        XCTAssertEqual(approval?.status, .networkUnavailable)
        XCTAssertFalse(canStartProtectedService)
        XCTAssertEqual(snapshot, .empty)
    }

    @MainActor
    func testRecentApprovedCacheUnlocksLocalOnlyWhenApprovalCheckIsOffline() async throws {
        let now = Date(timeIntervalSince1970: 6_000)
        let userID = UUID()
        let keychain = MemoryKeychainStore()
        keychain.set(data: try JSONEncoder.whoordan.encode(AuthSession(
            userID: userID,
            email: "approved@example.invalid",
            accessToken: "cached-access",
            refreshToken: "refresh-token",
            expiresAt: now.addingTimeInterval(3_600)
        )), for: "auth.session")
        let httpClient = StubHTTPClient(responses: [
            .init(error: URLError(.notConnectedToInternet))
        ])
        let config = testSupabaseConfig()
        let auth = SupabaseAuthService(config: config, keychain: keychain, httpClient: httpClient, now: { now })
        let store = testStore()
        await store.saveCachedApprovalState(ApprovalState(
            status: .approved,
            message: "Approved",
            checkedAt: now.addingTimeInterval(-300)
        ))
        var summary = DailyHealthSummary.empty
        summary.date = now
        summary.movement.steps = 1_234
        summary.movement.source = .appleHealth
        summary.movement.confidence = .high
        await store.saveTodaySummary(summary)
        let environment = AppEnvironment(
            authService: auth,
            approvalService: SupabaseApprovalService(config: config, authTokenProvider: auth, httpClient: httpClient),
            localStore: store,
            healthKitService: NoopHealthKitService(),
            healthSyncService: NoopHealthSyncService(),
            bleService: NoopBLEService(),
            hapticService: NoopHapticService(),
            scoringService: WhoordanScoringService(),
            now: { now }
        )

        await environment.restore()

        XCTAssertEqual(environment.approvalState?.status, .offlineApproved)
        XCTAssertEqual(environment.route, .approved)
        XCTAssertEqual(environment.todaySnapshot.movement.steps, 1_234)
        XCTAssertTrue(environment.privacyGuard.canStartProtectedService(approval: environment.approvalState))
        XCTAssertFalse(environment.privacyGuard.canUploadHealthData(
            approval: environment.approvalState,
            consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true)
        ))
    }

    @MainActor
    func testStaleApprovedCacheDoesNotUnlockOffline() async throws {
        let now = Date(timeIntervalSince1970: 7_000)
        let userID = UUID()
        let keychain = MemoryKeychainStore()
        keychain.set(data: try JSONEncoder.whoordan.encode(AuthSession(
            userID: userID,
            email: "approved@example.invalid",
            accessToken: "cached-access",
            refreshToken: "refresh-token",
            expiresAt: now.addingTimeInterval(3_600)
        )), for: "auth.session")
        let httpClient = StubHTTPClient(responses: [
            .init(error: URLError(.notConnectedToInternet))
        ])
        let config = testSupabaseConfig()
        let auth = SupabaseAuthService(config: config, keychain: keychain, httpClient: httpClient, now: { now })
        let store = testStore()
        await store.saveCachedApprovalState(ApprovalState(
            status: .approved,
            message: "Approved",
            checkedAt: now.addingTimeInterval(-(8 * 24 * 60 * 60))
        ))
        let environment = AppEnvironment(
            authService: auth,
            approvalService: SupabaseApprovalService(config: config, authTokenProvider: auth, httpClient: httpClient),
            localStore: store,
            healthKitService: NoopHealthKitService(),
            healthSyncService: NoopHealthSyncService(),
            bleService: NoopBLEService(),
            hapticService: NoopHapticService(),
            scoringService: WhoordanScoringService(),
            now: { now }
        )

        await environment.restore()

        XCTAssertEqual(environment.approvalState?.status, .networkUnavailable)
        XCTAssertNotEqual(environment.route, .approved)
        XCTAssertFalse(environment.privacyGuard.canStartProtectedService(approval: environment.approvalState))
    }

    @MainActor
    func testOfflineQueuedHealthDataDrainsAfterFreshOnlineApproval() async throws {
        let now = Date(timeIntervalSince1970: 8_000)
        let userID = UUID()
        let keychain = MemoryKeychainStore()
        keychain.set(data: try JSONEncoder.whoordan.encode(AuthSession(
            userID: userID,
            email: "approved@example.invalid",
            accessToken: "cached-access",
            refreshToken: "refresh-token",
            expiresAt: now.addingTimeInterval(3_600)
        )), for: "auth.session")
        let auth = SupabaseAuthService(
            config: testSupabaseConfig(),
            keychain: keychain,
            httpClient: StubHTTPClient(data: Data()),
            now: { now }
        )
        let store = testStore()
        await store.saveConsentState(ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true))
        await store.saveCachedApprovalState(ApprovalState(status: .approved, message: "Approved", checkedAt: now.addingTimeInterval(-60)))
        try await store.saveHealthSamples(
            [healthSample(sourceRecordID: "offline-step")],
            queueForSupabase: true,
            syncUserID: userID,
            queueForAppleHealth: false,
            importedAt: now
        )
        let approval = MutableApprovalService(result: .failure(ApprovalFetchError.networkUnavailable))
        let sync = CapturingHealthSyncService(resultStatus: .uploaded)
        let environment = AppEnvironment(
            authService: auth,
            approvalService: approval,
            localStore: store,
            healthKitService: NoopHealthKitService(),
            healthSyncService: sync,
            bleService: NoopBLEService(),
            hapticService: NoopHapticService(),
            scoringService: WhoordanScoringService(),
            now: { now }
        )

        await environment.restore()

        XCTAssertEqual(environment.approvalState?.status, .offlineApproved)
        XCTAssertTrue(sync.uploadedSamples.isEmpty)
        let offlinePendingUploads = await store.pendingSupabaseUploads(limit: 10, now: Date())
        XCTAssertEqual(offlinePendingUploads.count, 1)

        approval.result = .success(ApprovalState(status: .approved, message: "Approved", checkedAt: now.addingTimeInterval(30)))
        try await environment.refreshApproval()

        XCTAssertEqual(environment.approvalState?.status, .approved)
        XCTAssertEqual(sync.uploadedSamples.count, 1)
        let drainedPendingUploads = await store.pendingSupabaseUploads(limit: 10, now: Date())
        XCTAssertTrue(drainedPendingUploads.isEmpty)
    }

    @MainActor
    func testConsentedCloudSyncDrainsHistoricalLocalQueueAcrossBatches() async throws {
        let now = Date(timeIntervalSince1970: 8_500)
        let userID = UUID()
        let keychain = MemoryKeychainStore()
        keychain.set(data: try JSONEncoder.whoordan.encode(AuthSession(
            userID: userID,
            email: "approved@example.invalid",
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: now.addingTimeInterval(3_600)
        )), for: "auth.session")
        let auth = SupabaseAuthService(
            config: testSupabaseConfig(),
            keychain: keychain,
            httpClient: StubHTTPClient(data: Data()),
            now: { now }
        )
        let store = testStore()
        await store.saveConsentState(ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true))
        let samples = (0..<1_050).map { offset in
            healthSample(
                sourceRecordID: "historical-\(offset)",
                startDate: now.addingTimeInterval(Double(offset))
            )
        }
        try await store.saveHealthSamples(
            samples,
            queueForSupabase: false,
            syncUserID: nil,
            queueForAppleHealth: false,
            importedAt: now
        )
        let approval = MutableApprovalService(result: .success(ApprovalState(status: .approved, message: "Approved", checkedAt: now)))
        let sync = CapturingHealthSyncService(resultStatus: .uploaded)
        let environment = AppEnvironment(
            authService: auth,
            approvalService: approval,
            localStore: store,
            healthKitService: NoopHealthKitService(),
            healthSyncService: sync,
            bleService: NoopBLEService(),
            hapticService: NoopHapticService(),
            scoringService: WhoordanScoringService(),
            now: { now }
        )

        await environment.restore()

        XCTAssertEqual(sync.uploadedSamples.count, 1_050)
        XCTAssertEqual(environment.healthSyncResult.status, .uploaded)
        XCTAssertEqual(environment.healthSyncResult.sampleCount, 1_050)
        let pendingUploads = await store.pendingSupabaseUploads(limit: 2_000, now: now)
        XCTAssertTrue(pendingUploads.isEmpty)
    }

    @MainActor
    func testConsentedRestoreHydratesReadyMetricSummaryFromCloud() async throws {
        let now = Date(timeIntervalSince1970: 9_000)
        let userID = UUID()
        let keychain = MemoryKeychainStore()
        keychain.set(data: try JSONEncoder.whoordan.encode(AuthSession(
            userID: userID,
            email: "approved@example.invalid",
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: now.addingTimeInterval(3_600)
        )), for: "auth.session")
        let auth = SupabaseAuthService(
            config: testSupabaseConfig(),
            keychain: keychain,
            httpClient: StubHTTPClient(data: Data()),
            now: { now }
        )
        let store = testStore()
        await store.saveConsentState(ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true))
        var restored = DailyHealthSummary.empty
        restored.date = now
        restored.movement.steps = 8_432
        restored.sleepMinutes = 391
        restored.hrv = 62
        restored.confidence = .high
        restored.source = .cloudImport
        let restoredSample = HealthSample(
            id: "cloud-step",
            type: .steps,
            value: 8_432,
            unit: "count",
            startDate: now,
            endDate: nil,
            source: .whoordanEstimate,
            sourceRecordID: "cloud-step-record",
            confidence: .low,
            metadata: ["cloud_restored": "true"]
        )
        let approval = MutableApprovalService(result: .success(ApprovalState(status: .approved, message: "Approved", checkedAt: now)))
        let sync = CapturingHealthSyncService(resultStatus: .uploaded)
        sync.restoredSummaries = [restored]
        sync.restoredSamples = [restoredSample]
        let environment = AppEnvironment(
            authService: auth,
            approvalService: approval,
            localStore: store,
            healthKitService: NoopHealthKitService(),
            healthSyncService: sync,
            bleService: NoopBLEService(),
            hapticService: NoopHapticService(),
            scoringService: WhoordanScoringService(),
            now: { now }
        )

        await environment.restore()

        XCTAssertEqual(sync.fetchRecentHealthSamplesCount, 1)
        XCTAssertEqual(sync.fetchRecentDailySummariesCount, 1)
        XCTAssertEqual(environment.todaySnapshot.movement.steps, 8_432)
        XCTAssertEqual(environment.todaySnapshot.sleepMinutes, 391)
        XCTAssertEqual(environment.todaySnapshot.hrv, 62)
        let persistedToday = await store.loadTodaySummary()
        XCTAssertEqual(persistedToday.movement.steps, 8_432)
        XCTAssertEqual(sync.uploadedSummaries.first?.movement.steps, 8_432)
        XCTAssertTrue(sync.uploadedMetricSnapshots.first?.contains(where: { $0.id == .steps }) == true)
    }

    @MainActor
    func testConsentedRestoreMergesCloudSleepIntoRicherLocalSummary() async throws {
        let now = Date(timeIntervalSince1970: 9_500)
        let userID = UUID()
        let keychain = MemoryKeychainStore()
        keychain.set(data: try JSONEncoder.whoordan.encode(AuthSession(
            userID: userID,
            email: "approved@example.invalid",
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: now.addingTimeInterval(3_600)
        )), for: "auth.session")
        let auth = SupabaseAuthService(
            config: testSupabaseConfig(),
            keychain: keychain,
            httpClient: StubHTTPClient(data: Data()),
            now: { now }
        )
        let store = testStore()
        await store.saveConsentState(ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true))
        var local = DailyHealthSummary.empty
        local.date = now
        local.movement.steps = 12_345
        local.movement.activeEnergyKilocalories = 640
        local.averageHeartRate = 77
        local.maxHeartRate = 152
        local.hrv = 68
        local.respiratoryRate = 15.5
        local.oxygenSaturation = 98
        local.rawWristTemperatureC = 33.1
        local.source = .wearableBLE
        local.confidence = .medium
        await store.saveTodaySummary(local)

        var restored = DailyHealthSummary.empty
        restored.date = now
        restored.sleepMinutes = 512
        restored.source = .cloudImport
        restored.confidence = .low
        let approval = MutableApprovalService(result: .success(ApprovalState(status: .approved, message: "Approved", checkedAt: now)))
        let sync = CapturingHealthSyncService(resultStatus: .uploaded)
        sync.restoredSummaries = [restored]
        let environment = AppEnvironment(
            authService: auth,
            approvalService: approval,
            localStore: store,
            healthKitService: NoopHealthKitService(),
            healthSyncService: sync,
            bleService: NoopBLEService(),
            hapticService: NoopHapticService(),
            scoringService: WhoordanScoringService(),
            now: { now }
        )

        await environment.restore()

        XCTAssertEqual(environment.todaySnapshot.sleepMinutes, 512)
        XCTAssertEqual(environment.todaySnapshot.movement.steps, 12_345)
        XCTAssertEqual(environment.todaySnapshot.hrv, 68)
        XCTAssertEqual(environment.todaySnapshot.averageHeartRate, 77)
        let persistedToday = await store.loadTodaySummary()
        XCTAssertEqual(persistedToday.sleepMinutes, 512)
        XCTAssertEqual(persistedToday.movement.steps, 12_345)
    }

    @MainActor
    func testRestorePublishesApprovedRouteBeforeCloudSyncFinishes() async throws {
        let now = Date(timeIntervalSince1970: 9_250)
        let userID = UUID()
        let keychain = MemoryKeychainStore()
        keychain.set(data: try JSONEncoder.whoordan.encode(AuthSession(
            userID: userID,
            email: "approved@example.invalid",
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: now.addingTimeInterval(3_600)
        )), for: "auth.session")
        let auth = SupabaseAuthService(
            config: testSupabaseConfig(),
            keychain: keychain,
            httpClient: StubHTTPClient(data: Data()),
            now: { now }
        )
        let store = testStore()
        await store.saveConsentState(ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true))
        let sync = BlockingHealthSyncService()
        let environment = AppEnvironment(
            authService: auth,
            approvalService: MutableApprovalService(
                result: .success(ApprovalState(status: .approved, message: "Approved", checkedAt: now))
            ),
            localStore: store,
            healthKitService: NoopHealthKitService(),
            healthSyncService: sync,
            bleService: NoopBLEService(),
            hapticService: NoopHapticService(),
            scoringService: WhoordanScoringService(),
            now: { now }
        )

        let restore = Task { @MainActor in
            await environment.restore()
        }
        try await waitUntil {
            sync.didEnterCloudRestore
        }

        XCTAssertEqual(environment.approvalState?.status, .approved)
        XCTAssertFalse(environment.isRestoring)
        XCTAssertEqual(environment.route, .approved)

        sync.finish()
        await restore.value
    }

    @MainActor
    func testRestoreTimeoutLeavesSessionRestoreRouteWhenAuthNeverReturns() async throws {
        let environment = AppEnvironment(
            authService: BlockingAuthService(),
            approvalService: MutableApprovalService(result: .failure(ApprovalFetchError.networkUnavailable)),
            localStore: testStore(),
            healthKitService: NoopHealthKitService(),
            healthSyncService: NoopHealthSyncService(),
            bleService: NoopBLEService(),
            hapticService: NoopHapticService(),
            scoringService: WhoordanScoringService(),
            startupRestoreTimeoutNanoseconds: 50_000_000
        )

        await environment.restore()

        XCTAssertFalse(environment.isRestoring)
        XCTAssertEqual(environment.route, AppRoute.signedOut)
        XCTAssertEqual(environment.authMessage, "Session restore timed out. Check connection and try again.")
    }

    @MainActor
    func testBackgroundApprovalRefreshKeepsApprovedRouteWhileCheckIsInFlight() async throws {
        let now = Date(timeIntervalSince1970: 8_750)
        let userID = UUID()
        let keychain = MemoryKeychainStore()
        keychain.set(data: try JSONEncoder.whoordan.encode(AuthSession(
            userID: userID,
            email: "approved@example.invalid",
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: now.addingTimeInterval(3_600)
        )), for: "auth.session")
        let auth = SupabaseAuthService(
            config: testSupabaseConfig(),
            keychain: keychain,
            httpClient: StubHTTPClient(data: Data()),
            now: { now }
        )
        let approval = SequencedApprovalService(results: [
            .success(ApprovalState(status: .approved, message: "Approved", checkedAt: now))
        ])
        let environment = AppEnvironment(
            authService: auth,
            approvalService: approval,
            localStore: testStore(),
            healthKitService: NoopHealthKitService(),
            healthSyncService: NoopHealthSyncService(),
            bleService: NoopBLEService(),
            hapticService: NoopHapticService(),
            scoringService: WhoordanScoringService(),
            now: { now }
        )
        await environment.restore()
        XCTAssertEqual(environment.route, .approved)

        let refresh = Task { @MainActor in
            await environment.refreshApprovalInBackground()
        }
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(environment.route, .approved)

        approval.resume(ApprovalState(status: .revoked, message: "Revoked", checkedAt: now.addingTimeInterval(30)))
        await refresh.value
        XCTAssertNotEqual(environment.route, .approved)
        XCTAssertEqual(environment.approvalState?.status, .revoked)
    }

    @MainActor
    func testRevokedAfterOfflineApprovalLocksAndDoesNotDrainQueue() async throws {
        let now = Date(timeIntervalSince1970: 9_000)
        let userID = UUID()
        let keychain = MemoryKeychainStore()
        keychain.set(data: try JSONEncoder.whoordan.encode(AuthSession(
            userID: userID,
            email: "approved@example.invalid",
            accessToken: "cached-access",
            refreshToken: "refresh-token",
            expiresAt: now.addingTimeInterval(3_600)
        )), for: "auth.session")
        let auth = SupabaseAuthService(
            config: testSupabaseConfig(),
            keychain: keychain,
            httpClient: StubHTTPClient(data: Data()),
            now: { now }
        )
        let store = testStore()
        await store.saveConsentState(ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true))
        await store.saveCachedApprovalState(ApprovalState(status: .approved, message: "Approved", checkedAt: now.addingTimeInterval(-60)))
        try await store.saveHealthSamples(
            [healthSample(sourceRecordID: "revoked-queued-step")],
            queueForSupabase: true,
            syncUserID: userID,
            queueForAppleHealth: false,
            importedAt: now
        )
        let approval = MutableApprovalService(result: .failure(ApprovalFetchError.networkUnavailable))
        let sync = CapturingHealthSyncService(resultStatus: .uploaded)
        let environment = AppEnvironment(
            authService: auth,
            approvalService: approval,
            localStore: store,
            healthKitService: NoopHealthKitService(),
            healthSyncService: sync,
            bleService: NoopBLEService(),
            hapticService: NoopHapticService(),
            scoringService: WhoordanScoringService(),
            now: { now }
        )

        await environment.restore()
        approval.result = .success(ApprovalState(status: .revoked, message: "Revoked", checkedAt: now.addingTimeInterval(30)))
        try await environment.refreshApproval()

        XCTAssertEqual(environment.approvalState?.status, .revoked)
        XCTAssertNotEqual(environment.route, .approved)
        XCTAssertTrue(sync.uploadedSamples.isEmpty)
        let pendingUploads = await store.pendingSupabaseUploads(limit: 10, now: Date())
        XCTAssertEqual(pendingUploads.count, 1)
    }

    func testSignedOutRoutesToAuthOnly() {
        let route = AppRouter.route(session: nil, approval: nil, restoring: false)
        XCTAssertEqual(route, .signedOut)
    }

    func testPendingUserIsLocked() {
        let session = AuthSession(userID: UUID(), email: "test@example.invalid", accessToken: "token", refreshToken: nil, expiresAt: nil)
        let state = ApprovalState.pending()
        let route = AppRouter.route(session: session, approval: state, restoring: false)
        XCTAssertEqual(route, .approvalLocked(state))
    }

    func testApprovedUserUnlocks() {
        let session = AuthSession(userID: UUID(), email: "test@example.invalid", accessToken: "token", refreshToken: nil, expiresAt: nil)
        let route = AppRouter.route(session: session, approval: .approved(), restoring: false)
        XCTAssertEqual(route, .approved)
    }

    func testPrivacyGuardBlocksProtectedDataBeforeApproval() {
        let guarder = PrivacyAccessGuard()
        XCTAssertFalse(guarder.canAccessProtectedData(approval: .pending()))
        XCTAssertFalse(guarder.canStartProtectedService(approval: .error(message: "offline")))
        XCTAssertTrue(guarder.canAccessProtectedData(approval: .approved()))
    }

    func testApprovalGateBlocksBLEProcessingBeforeApproval() {
        let guarder = PrivacyAccessGuard()
        XCTAssertFalse(guarder.canStartProtectedService(approval: nil))
        XCTAssertFalse(guarder.canStartProtectedService(approval: .pending()))
        XCTAssertFalse(guarder.canStartProtectedService(approval: .missing()))
        XCTAssertFalse(guarder.canStartProtectedService(approval: .error(message: "offline")))
        XCTAssertTrue(guarder.canStartProtectedService(approval: .approved()))
    }

    func testCloudUploadRequiresApprovalAndConsent() {
        let guarder = PrivacyAccessGuard()
        XCTAssertFalse(guarder.canUploadHealthData(approval: .approved(), consent: ConsentState()))
        XCTAssertFalse(guarder.canUploadHealthData(approval: .pending(), consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true)))
        XCTAssertTrue(guarder.canUploadHealthData(approval: .approved(), consent: ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true)))

        XCTAssertFalse(guarder.canUploadSettingsData(approval: .approved(), consent: ConsentState()))
        XCTAssertFalse(guarder.canUploadSettingsData(approval: .pending(), consent: ConsentState(cloudSyncEnabled: true)))
        XCTAssertTrue(guarder.canUploadSettingsData(approval: .approved(), consent: ConsentState(cloudSyncEnabled: true)))

        XCTAssertFalse(guarder.canRestoreSettingsData(
            approval: .offlineApproved(lastVerifiedAt: Date()),
            consent: ConsentState(cloudSyncEnabled: true)
        ))
        XCTAssertFalse(guarder.canRestoreSettingsData(approval: .approved(), consent: ConsentState()))
        XCTAssertTrue(guarder.canRestoreSettingsData(approval: .approved(), consent: ConsentState(cloudSyncEnabled: true)))

        let userID = UUID()
        XCTAssertFalse(guarder.canQueueSettingsData(approval: .approved(), consent: ConsentState(), userID: userID))
        XCTAssertTrue(guarder.canQueueSettingsData(approval: .approved(), consent: ConsentState(cloudSyncEnabled: true), userID: userID))
    }

    func testHealthDataCloudConsentStaysExplicit() {
        let settingsOnly = ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: false)
        XCTAssertTrue(settingsOnly.cloudSyncEnabled)
        XCTAssertFalse(settingsOnly.healthDataCloudConsent)
        XCTAssertFalse(settingsOnly.canUploadHealthData)

        var legacy = ConsentState()
        legacy.cloudSyncEnabled = true
        legacy.healthDataCloudConsent = false
        let normalized = legacy.normalizedForCurrentPrivacyModel
        XCTAssertFalse(normalized.healthDataCloudConsent)
        XCTAssertFalse(normalized.canUploadHealthData)

        let disabled = ConsentState(cloudSyncEnabled: false, healthDataCloudConsent: true)
        XCTAssertFalse(disabled.healthDataCloudConsent)
        XCTAssertFalse(disabled.canUploadHealthData)

        let explicit = ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true)
        XCTAssertTrue(explicit.healthDataCloudConsent)
        XCTAssertTrue(explicit.canUploadHealthData)
    }

    func testCloudRestoreRequiresCloudUploadApprovalAndExplicitHealthConsent() {
        let guarder = PrivacyAccessGuard()
        let explicit = ConsentState(cloudSyncEnabled: true, healthDataCloudConsent: true)
        XCTAssertFalse(guarder.canRestoreHealthData(approval: .offlineApproved(lastVerifiedAt: Date()), consent: explicit))
        XCTAssertFalse(guarder.canRestoreHealthData(approval: .approved(), consent: ConsentState(cloudSyncEnabled: true)))
        XCTAssertTrue(guarder.canRestoreHealthData(approval: .approved(), consent: explicit))
    }

    func testHealthSyncBlocksWithoutCloudSyncEnabled() async {
        let service = SupabaseHealthSyncService(config: SupabaseConfig(url: nil, publishableKey: nil, projectID: nil))
        let result = await service.uploadHealthSamples(
            [healthSample()],
            session: AuthSession(userID: UUID(), email: "test@example.invalid", accessToken: "token", refreshToken: nil, expiresAt: nil),
            approval: .approved(),
            consent: ConsentState(cloudSyncEnabled: false)
        )
        XCTAssertEqual(result.status, .blocked)
    }

    func testHealthSyncRowsHashSourceIdentifiers() {
        let userID = UUID()
        let rows = SupabaseHealthSyncService.makeHealthSampleRows([healthSample(sourceRecordID: "private-healthkit-id")], userID: userID)
        XCTAssertEqual(rows.first?.userID, userID)
        XCTAssertEqual(rows.first?.sampleType, HealthSampleType.steps.rawValue)
        XCTAssertNotEqual(rows.first?.sourceRecordID, "private-healthkit-id")
        XCTAssertEqual(rows.first?.sourceRecordID?.count, 64)
        XCTAssertEqual(rows.first?.dedupeKey.count, 64)
    }

    private func healthSample(
        sourceRecordID: String = "sample-1",
        startDate: Date = Date(timeIntervalSince1970: 10)
    ) -> HealthSample {
        HealthSample(
            id: sourceRecordID,
            type: .steps,
            value: 100,
            unit: "count",
            startDate: startDate,
            endDate: nil,
            source: .appleHealth,
            sourceRecordID: sourceRecordID,
            confidence: .high,
            metadata: ["source_label": "Apple Health"]
        )
    }
}

private final class StubHTTPClient: HTTPClienting {
    struct Response {
        var data: Data = Data()
        var statusCode: Int = 200
        var error: Error?
    }

    private var responses: [Response]
    private(set) var requests: [URLRequest] = []

    init(data: Data) {
        self.responses = [Response(data: data)]
    }

    init(responses: [Response]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let stub = responses.isEmpty ? Response() : responses.removeFirst()
        if let error = stub.error {
            throw error
        }
        let httpResponse = HTTPURLResponse(
            url: request.url ?? URL(string: "https://project-ref.supabase.co")!,
            statusCode: stub.statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (stub.data, httpResponse)
    }
}

private func testSupabaseConfig() -> SupabaseConfig {
    SupabaseConfig(
        url: URL(string: "https://project-ref.supabase.co"),
        publishableKey: "publishable-key",
        projectID: "project-ref"
    )
}

private func testStore() -> FileProtectedLocalStore {
    let storeURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("whoordan-test-\(UUID().uuidString).json")
    return FileProtectedLocalStore(fileURL: storeURL)
}

private func sessionJSON(userID: UUID, access: String, refresh: String) -> Data {
    """
    {
      "access_token": "\(access)",
      "refresh_token": "\(refresh)",
      "expires_in": 3600,
      "user": {
        "id": "\(userID.uuidString)",
        "email": "approved@example.invalid"
      }
    }
    """.data(using: .utf8)!
}

@MainActor
private func makeEnvironment(auth: AuthServicing, approval: ApprovalServicing) throws -> AppEnvironment {
    return AppEnvironment(
        authService: auth,
        approvalService: approval,
        localStore: testStore(),
        healthKitService: NoopHealthKitService(),
        healthSyncService: NoopHealthSyncService(),
        bleService: NoopBLEService(),
        hapticService: NoopHapticService(),
        scoringService: WhoordanScoringService()
    )
}

private struct NoopHealthKitService: HealthKitServicing {
    func isAvailable() -> Bool { false }
    func requestAuthorization() async -> HealthKitAuthorizationResult {
        HealthKitAuthorizationResult(status: .unavailable, requestedTypes: [], message: "Unavailable.")
    }
    func requestWriteAuthorization() async -> HealthKitAuthorizationResult {
        HealthKitAuthorizationResult(status: .unavailable, requestedTypes: [], message: "Unavailable.")
    }
    func supportedReadTypes() -> [HealthSampleType] { [] }
    func supportedWriteTypes() -> [HealthSampleType] { [] }
    func importSamples(since start: Date, until end: Date) async -> HealthKitImportResult { .unavailable }
    func importIncremental(checkpoints: [HealthKitCheckpoint], fallbackStart: Date, fallbackEnd: Date) async -> HealthKitIncrementalImportResult { .unavailable }
    func writeSamples(_ samples: [HealthSample]) async -> AppleHealthWriteResult {
        AppleHealthWriteResult(status: .failed, writtenCount: 0, unsupportedCount: samples.count, message: "Unavailable.")
    }
    func registerBackgroundDelivery(_ handler: @escaping @Sendable () async -> Void) async -> HealthKitAuthorizationResult {
        HealthKitAuthorizationResult(status: .unavailable, requestedTypes: [], message: "Unavailable.")
    }
}

private struct NoopHealthSyncService: HealthSyncServicing {
    func uploadHealthSamples(_ samples: [HealthSample], session: AuthSession?, approval: ApprovalState?, consent: ConsentState) async -> HealthSyncResult {
        HealthSyncResult(status: .blocked, sampleCount: 0, message: "Blocked.")
    }

    func uploadDailySummary(
        _ summary: DailyHealthSummary,
        metricSnapshots: [WhoordanMetricSnapshot],
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState
    ) async -> HealthSyncResult {
        HealthSyncResult(status: .blocked, sampleCount: 0, message: "Blocked.")
    }

    func fetchRecentDailySummaries(
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState,
        since: Date,
        limit: Int
    ) async -> HealthSummaryRestoreResult {
        HealthSummaryRestoreResult(status: .blocked, summaries: [], message: "Blocked.")
    }

    func fetchRecentHealthSamples(
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState,
        since: Date,
        limit: Int
    ) async -> HealthSampleRestoreResult {
        HealthSampleRestoreResult(status: .blocked, samples: [], message: "Blocked.")
    }
}

private final class CapturingHealthSyncService: HealthSyncServicing {
    private(set) var uploadedSamples: [HealthSample] = []
    private(set) var uploadedSummaries: [DailyHealthSummary] = []
    private(set) var uploadedMetricSnapshots: [[WhoordanMetricSnapshot]] = []
    private(set) var fetchRecentHealthSamplesCount = 0
    private(set) var fetchRecentDailySummariesCount = 0
    var restoredSamples: [HealthSample] = []
    var restoredSummaries: [DailyHealthSummary] = []
    var resultStatus: HealthSyncStatus

    init(resultStatus: HealthSyncStatus) {
        self.resultStatus = resultStatus
    }

    func uploadHealthSamples(_ samples: [HealthSample], session: AuthSession?, approval: ApprovalState?, consent: ConsentState) async -> HealthSyncResult {
        guard approval?.status == .approved else {
            return HealthSyncResult(status: .blocked, sampleCount: 0, message: "Blocked.")
        }
        uploadedSamples.append(contentsOf: samples)
        return HealthSyncResult(status: resultStatus, sampleCount: samples.count, message: resultStatus == .uploaded ? "Uploaded." : "Failed.")
    }

    func uploadDailySummary(
        _ summary: DailyHealthSummary,
        metricSnapshots: [WhoordanMetricSnapshot],
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState
    ) async -> HealthSyncResult {
        guard approval?.status == .approved else {
            return HealthSyncResult(status: .blocked, sampleCount: 0, message: "Blocked.")
        }
        uploadedSummaries.append(summary)
        uploadedMetricSnapshots.append(metricSnapshots)
        return HealthSyncResult(status: resultStatus, sampleCount: 1, message: resultStatus == .uploaded ? "Uploaded daily summary." : "Failed.")
    }

    func fetchRecentDailySummaries(
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState,
        since: Date,
        limit: Int
    ) async -> HealthSummaryRestoreResult {
        fetchRecentDailySummariesCount += 1
        guard approval?.status == .approved, consent.canUploadHealthData else {
            return HealthSummaryRestoreResult(status: .blocked, summaries: [], message: "Blocked.")
        }
        guard !restoredSummaries.isEmpty else {
            return HealthSummaryRestoreResult(status: .nothingToRestore, summaries: [], message: "No summaries.")
        }
        return HealthSummaryRestoreResult(status: .restored, summaries: restoredSummaries, message: "Restored.")
    }

    func fetchRecentHealthSamples(
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState,
        since: Date,
        limit: Int
    ) async -> HealthSampleRestoreResult {
        fetchRecentHealthSamplesCount += 1
        guard approval?.status == .approved, consent.canUploadHealthData else {
            return HealthSampleRestoreResult(status: .blocked, samples: [], message: "Blocked.")
        }
        guard !restoredSamples.isEmpty else {
            return HealthSampleRestoreResult(status: .nothingToRestore, samples: [], message: "No samples.")
        }
        return HealthSampleRestoreResult(status: .restored, samples: restoredSamples, message: "Restored samples.")
    }
}

private final class BlockingHealthSyncService: HealthSyncServicing {
    private(set) var didEnterCloudRestore = false
    private var continuation: CheckedContinuation<Void, Never>?

    func uploadHealthSamples(
        _ samples: [HealthSample],
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState
    ) async -> HealthSyncResult {
        HealthSyncResult(status: .nothingToSync, sampleCount: 0, message: "No queued samples.")
    }

    func uploadDailySummary(
        _ summary: DailyHealthSummary,
        metricSnapshots: [WhoordanMetricSnapshot],
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState
    ) async -> HealthSyncResult {
        HealthSyncResult(status: .nothingToSync, sampleCount: 0, message: "No summary.")
    }

    func fetchRecentDailySummaries(
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState,
        since: Date,
        limit: Int
    ) async -> HealthSummaryRestoreResult {
        HealthSummaryRestoreResult(status: .nothingToRestore, summaries: [], message: "No summaries.")
    }

    func fetchRecentHealthSamples(
        session: AuthSession?,
        approval: ApprovalState?,
        consent: ConsentState,
        since: Date,
        limit: Int
    ) async -> HealthSampleRestoreResult {
        didEnterCloudRestore = true
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        return HealthSampleRestoreResult(status: .nothingToRestore, samples: [], message: "Released.")
    }

    func finish() {
        continuation?.resume()
        continuation = nil
    }
}

private final class MutableApprovalService: ApprovalServicing {
    var result: Result<ApprovalState, Error>

    init(result: Result<ApprovalState, Error>) {
        self.result = result
    }

    func fetchApproval(for userID: UUID) async throws -> ApprovalState {
        try result.get()
    }
}

private final class BlockingAuthService: AuthServicing {
    func restoreSession() async throws -> AuthSession? {
        try? await Task.sleep(nanoseconds: 30_000_000_000)
        return nil
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        throw AuthError.sessionExpired
    }

    func signUp(email: String, password: String) async throws -> AuthSession {
        throw AuthError.sessionExpired
    }

    func resetPassword(email: String) async throws {}

    func signOut() async {}
}

@MainActor
private func waitUntil(
    timeout: TimeInterval = 1,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: @escaping () -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition(), Date() < deadline {
        try await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTAssertTrue(condition(), file: file, line: line)
}

private final class SequencedApprovalService: ApprovalServicing {
    private var results: [Result<ApprovalState, Error>]
    private var continuation: CheckedContinuation<ApprovalState, Never>?

    init(results: [Result<ApprovalState, Error>]) {
        self.results = results
    }

    func fetchApproval(for userID: UUID) async throws -> ApprovalState {
        if !results.isEmpty {
            return try results.removeFirst().get()
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume(_ state: ApprovalState) {
        continuation?.resume(returning: state)
        continuation = nil
    }
}

private final class NoopBLEService: WearableBLEServicing {
    var currentDeviceState = WearableDeviceState()
    func primeBluetoothPermission() {}
    func startAutoConnect() {}
    func startScanning() {}
    func requestBluetoothAccess() {}
    func connect(to candidate: WearableDeviceCandidate) {}
    func stopAll() {}
    func startRawCapture(scenario: WearableCaptureScenario) {}
    func stopRawCapture() {}
    func finishRawCapture(recordingName: String) -> WearableRawPayloadCaptureSave? { nil }
    func updateRawCaptureScenario(_ scenario: WearableCaptureScenario) {}
    func exportRawCaptureArchive() throws -> URL { FileManager.default.temporaryDirectory }
    func updateSyntheticCalibrationContext(_ context: WearableSyntheticCalibrationContext) {}
    func restoreBLECheckpoints(_ checkpoints: [BLECheckpoint]) {}
    func writeCommand(_ data: Data, requiresResponse: Bool) async throws {}
}

private struct NoopHapticService: VibrationPreviewing {
    func preview(_ pattern: VibrationPattern, approval: ApprovalState?, device: WearableDeviceState) async -> VibrationPreviewResult {
        VibrationPreviewResult(status: .notConnected)
    }
    func cancel() async {}
}
