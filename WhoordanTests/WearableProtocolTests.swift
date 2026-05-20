import XCTest
@testable import Whoordan

final class WearableProtocolTests: XCTestCase {
    func testCRC8KnownLength() {
        XCTAssertEqual(WearableProtocol.crc8(Data([0x08, 0x00])), 0xA8)
    }

    func testInitSequenceMatchesPublicReferenceVectors() {
        let hex = WearableProtocol.initSequence().map { $0.hexString }
        XCTAssertEqual(hex[0], "aa0800a823002300ada86a2d")
        XCTAssertEqual(hex[1], "aa0800a823014c00f2b5cdce")
        XCTAssertEqual(hex[2], "aa0800a823022200824df537")
        XCTAssertEqual(hex[3], "aa0800a823034301c54dd63d")
        XCTAssertEqual(hex[4], "aa0800a823041600c7c25288")
    }

    func testDecodeRejectsBadCRC() {
        var frame = WearableProtocol.initSequence()[0]
        frame[frame.count - 1] = 0
        XCTAssertThrowsError(try WearableProtocol.decodeFrame(frame)) { error in
            XCTAssertEqual(error as? WearableProtocolError, .invalidContentCRC)
        }
    }

    func testReassemblerHandlesSplitFrameAndPadding() {
        let frame = WearableProtocol.initSequence()[0]
        var reassembler = FrameReassembler()
        XCTAssertTrue(reassembler.append(frame.prefix(4)).isEmpty)
        let frames = reassembler.append(Data(frame.dropFirst(4)) + Data([0, 0]))
        XCTAssertEqual(frames, [frame])
    }

    func testReassemblerRecoversWhenStalePartialIsFollowedByNewFrame() {
        let firstFrame = WearableProtocol.initSequence()[0]
        let secondFrame = WearableProtocol.initSequence()[1]
        var reassembler = FrameReassembler()

        XCTAssertTrue(reassembler.append(firstFrame.prefix(4)).isEmpty)
        let frames = reassembler.append(secondFrame)

        XCTAssertEqual(frames, [secondFrame])
        XCTAssertEqual(reassembler.droppedFragmentCount, 1)
    }

    func testBatchAckUsesBatchToken() {
        let token = Data([1, 2, 3, 4, 5, 6, 7, 8])
        let ack = WearableProtocol.buildBatchAck(counter: 5, batchToken: token)
        let inner = try! WearableProtocol.decodeFrame(ack)
        XCTAssertEqual(inner.prefix(4), Data([0x23, 0x05, 0x17, 0x01]))
        XCTAssertEqual(inner.suffix(8), token)
    }

    func testBatchAckGateDefersUntilDurableStoreCompletes() {
        var gate = WearableBatchAckGate()

        gate.beginDurableSampleStore()
        XCTAssertTrue(gate.shouldDeferBatchAck)
        gate.markBatchAckDeferred()
        XCTAssertEqual(gate.pendingDurableSampleStores, 1)
        XCTAssertEqual(gate.deferredBatchAckCount, 1)
        XCTAssertFalse(gate.canFlushDeferredBatchAck)

        gate.finishDurableSampleStore(succeeded: true)

        XCTAssertTrue(gate.canFlushDeferredBatchAck)
        gate.markDeferredBatchAckFlushed()
        XCTAssertEqual(gate.deferredBatchAckCount, 0)
        XCTAssertFalse(gate.shouldDeferBatchAck)
    }

    func testBatchAckGateWithholdsAckAfterDurableStoreFailure() {
        var gate = WearableBatchAckGate()

        gate.beginDurableSampleStore()
        gate.markBatchAckDeferred()
        gate.finishDurableSampleStore(succeeded: false)

        XCTAssertTrue(gate.shouldDeferBatchAck)
        XCTAssertFalse(gate.canFlushDeferredBatchAck)
        XCTAssertEqual(gate.deferredBatchAckCount, 1)
    }

    func testGapClassifierSeparatesResubscribeFromBackgroundLimit() {
        let resubscribe = WearableGapClassifier.classify(
            gapSeconds: 180,
            previousConnection: .realtime,
            currentConnection: .subscribing,
            previousAppState: "background",
            currentAppState: "foreground",
            isOnWrist: true,
            batteryPercent: 60
        )
        let background = WearableGapClassifier.classify(
            gapSeconds: 180,
            previousConnection: .realtime,
            currentConnection: .realtime,
            previousAppState: "background",
            currentAppState: "background",
            isOnWrist: true,
            batteryPercent: 60
        )

        XCTAssertEqual(resubscribe, .resubscribing)
        XCTAssertEqual(background, .iosBackgroundLimited)
    }

    func testRealtimeCommandsUseExpectedCommandBytes() {
        let commands = WearableProtocol.realtimeEnableCommands(startSequence: 0xA0).map { try! WearableProtocol.decodeFrame($0) }
        XCTAssertEqual(commands.map { $0[2] }, [0x03, 0x3F, 0x9A, 0x6C])
        XCTAssertEqual(commands.map { $0[3] }, [1, 1, 1, 1])
    }

    func testStandardHeartRateMeasurementParsesUInt8AndContact() {
        let parsed = WearableStandardParser.parseHeartRateMeasurement(Data([0x06, 72]))
        XCTAssertEqual(parsed?.bpm, 72)
        XCTAssertEqual(parsed?.contactDetected, true)
        XCTAssertEqual(parsed?.rrIntervalsMS, [])
    }

    func testStandardHeartRateServiceIsCompatibleReconnectFallback() {
        XCTAssertTrue(
            WearableServiceCompatibility.isConnectable(
                advertisedServiceUUIDs: [StandardBLEUUIDs.heartRateService]
            )
        )
        XCTAssertTrue(
            WearableServiceCompatibility.isConnectable(
                advertisedServiceUUIDs: [WearableUUIDs.service]
            )
        )
        XCTAssertFalse(
            WearableServiceCompatibility.isConnectable(
                advertisedServiceUUIDs: [StandardBLEUUIDs.batteryService]
            )
        )
    }

    func testStandardHeartRateServiceIsNotTreatedAsProtocolService() {
        XCTAssertFalse(
            WearableServiceCompatibility.isProtocolCapable(
                advertisedServiceUUIDs: [StandardBLEUUIDs.heartRateService]
            )
        )
        XCTAssertTrue(
            WearableServiceCompatibility.isProtocolCapable(
                advertisedServiceUUIDs: [WearableUUIDs.service]
            )
        )
    }

    func testStandardHeartRateMeasurementParsesRRIntervalsForHRV() throws {
        let parsed = try XCTUnwrap(WearableStandardParser.parseHeartRateMeasurement(Data([
            0x16,
            70,
            0x00, 0x04,
            0x66, 0x04,
            0xCD, 0x03
        ])))

        XCTAssertEqual(parsed.bpm, 70)
        XCTAssertEqual(parsed.contactDetected, true)
        XCTAssertEqual(parsed.rrIntervalsMS.count, 3)
        XCTAssertNotNil(WearableHRVCalculator.sdnnMS(from: parsed.rrIntervalsMS))
        XCTAssertNotNil(WearableHRVCalculator.rmssdMS(from: parsed.rrIntervalsMS))
    }

    func testRMSSDUsesDirectRRIntervalsWithProductionCount() throws {
        let intervals = (0..<16).map { index in
            index.isMultiple(of: 2) ? 1_000.0 : 1_100.0
        }

        let rmssd = try XCTUnwrap(WearableHRVCalculator.rmssdMS(from: intervals))

        XCTAssertEqual(rmssd, 100, accuracy: 0.0001)
    }

    func testRespiratoryRateEstimatorUsesDirectRRIntervals() throws {
        let intervals = (0..<72).map { index -> Double in
            let phase = Double(index) / 4.0 * 2.0 * Double.pi
            return 1_000.0 + sin(phase) * 55.0
        }

        let estimate = try XCTUnwrap(WearableRespiratoryRateEstimator.estimateFromRRIntervals(intervals))

        XCTAssertEqual(estimate, 15, accuracy: 0.8)
    }

    func testStandardHeartRateMeasurementParsesUInt16() {
        let parsed = WearableStandardParser.parseHeartRateMeasurement(Data([0x01, 180, 0]))
        XCTAssertEqual(parsed?.bpm, 180)
        XCTAssertNil(
            WearableStandardParser.parseHeartRateMeasurement(Data([0x01, 0x2C, 0x01])),
            "Out-of-range heart-rate values must be rejected instead of displayed."
        )
    }

    func testStandardBatteryRejectsOutOfRange() {
        XCTAssertEqual(WearableStandardParser.parseBatteryLevel(Data([87])), 87)
        XCTAssertNil(WearableStandardParser.parseBatteryLevel(Data([101])))
    }

    func testBatteryDisplayPolicyOnlyPromotesProtocolHelloBattery() {
        XCTAssertFalse(WearableBatteryDisplayPolicy.shouldPromoteToDisplay(.standardGattBatteryLevel))
        XCTAssertTrue(WearableBatteryDisplayPolicy.shouldPromoteToDisplay(.proprietaryHelloCandidate))
        XCTAssertFalse(WearableBatteryDisplayPolicy.shouldPromoteToDisplay(.proprietaryEventCandidate))

        var state = WearableDeviceState()
        state.applyDisplayedBatteryPercent(10, source: .standardGattBatteryLevel)
        XCTAssertNil(state.batteryPercent)

        state.applyDisplayedBatteryPercent(48, source: .proprietaryHelloCandidate)
        state.applyDisplayedBatteryPercent(8, source: .proprietaryEventCandidate)
        XCTAssertEqual(state.batteryPercent, 48)
    }

    func testRawRealtimeR10FrameProducesHeartRateAndImuCount() {
        var inner = Data(repeating: 0, count: 1_928)
        inner[0] = WearablePacketType.rawRealtimeData.rawValue
        inner[1] = 10
        inner.replaceSubrange(7..<11, with: littleEndianUInt32(1_735_689_600))
        inner[17] = 74
        writeInt16Sequence(into: &inner, offset: 85, values: Array(0..<100))
        writeInt16Sequence(into: &inner, offset: 285, values: Array(100..<200))
        writeInt16Sequence(into: &inner, offset: 485, values: Array((-50)..<50))
        writeInt16Sequence(into: &inner, offset: 688, values: Array((-100)..<0))
        writeInt16Sequence(into: &inner, offset: 888, values: Array(200..<300))
        writeInt16Sequence(into: &inner, offset: 1_088, values: Array(300..<400))
        let frame = WearableProtocol.frame(inner: inner)

        let decoded = WearablePacketDecoder.decode(frame: frame)

        XCTAssertEqual(decoded?.packetType, .rawRealtimeData)
        XCTAssertEqual(decoded?.recordType, 10)
        XCTAssertEqual(decoded?.heartRateBPM, 74)
        XCTAssertEqual(decoded?.imuSampleCount, 100)
        XCTAssertEqual(decoded?.dataRecord?.rawTimestamp, 1_735_689_600)
        XCTAssertEqual(WearablePacketDecoder.r10HeartRate(frame: frame), 74)
        XCTAssertEqual(decoded?.dataRecord?.r10?.accelerometer?.x.sampleCount, 100)
        XCTAssertEqual(decoded?.dataRecord?.r10?.accelerometer?.x.minimum, 0)
        XCTAssertEqual(decoded?.dataRecord?.r10?.accelerometer?.x.maximum, 99)
        XCTAssertEqual(decoded?.dataRecord?.r10?.gyroscope?.x.minimum, -100)
        XCTAssertEqual(decoded?.dataRecord?.r10?.gyroscope?.z.maximum, 399)
    }

    func testR10HealthSamplesUseVerifiedDeviceTimestampWhenAvailable() throws {
        let deviceTimestamp: UInt32 = 1_735_689_600
        let receivedAt = Date(timeIntervalSince1970: TimeInterval(deviceTimestamp) + 4 * 60 * 60)
        var inner = Data(repeating: 0, count: 1_928)
        inner[0] = WearablePacketType.rawRealtimeData.rawValue
        inner[1] = 10
        inner.replaceSubrange(7..<11, with: littleEndianUInt32(deviceTimestamp))
        inner[17] = 68

        let decoded = try XCTUnwrap(WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner)))
        let heartRate = try XCTUnwrap(
            decoded.safeHealthSamples(
                deviceID: "device",
                characteristicUUID: WearableUUIDs.sensorData,
                receivedAt: receivedAt
            ).first { $0.type == .heartRate }
        )

        XCTAssertEqual(heartRate.startDate.timeIntervalSince1970, TimeInterval(deviceTimestamp), accuracy: 0.001)
        XCTAssertEqual(heartRate.metadata["sample_time_basis"], "device_timestamp")
        XCTAssertEqual(heartRate.metadata["received_at_unix"], String(Int(receivedAt.timeIntervalSince1970)))
        XCTAssertEqual(heartRate.metadata["sample_at_unix"], String(Int(deviceTimestamp)))
    }

    func testPartialR10FrameDoesNotClaimFullIMUSamples() {
        var inner = Data(repeating: 0, count: 24)
        inner[0] = WearablePacketType.rawRealtimeData.rawValue
        inner[1] = 10
        inner[17] = 74

        let decoded = WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner))

        XCTAssertNil(decoded?.heartRateBPM)
        XCTAssertNil(decoded?.dataRecord?.r10?.heartRateBPM)
        XCTAssertFalse(decoded?.dataRecord?.r10?.isCompleteChunk ?? true)
        XCTAssertNil(WearablePacketDecoder.r10HeartRate(frame: WearableProtocol.frame(inner: inner)))
        XCTAssertEqual(decoded?.imuSampleCount, 0)
        XCTAssertTrue(decoded?.safeHealthSamples(deviceID: "device", characteristicUUID: WearableUUIDs.sensorData, receivedAt: Date()).isEmpty ?? false)
        XCTAssertNil(decoded?.imuSampleBatch(deviceID: "device", characteristicUUID: WearableUUIDs.sensorData, receivedAt: Date()))
    }

    func testR10FrameEmitsRawWristTemperatureWithoutBaselineClaim() throws {
        var inner = Data(repeating: 0, count: 1_928)
        inner[0] = WearablePacketType.rawRealtimeData.rawValue
        inner[1] = 10
        inner.replaceSubrange(44..<46, with: littleEndianInt16(Int16(34.5 * 512)))

        let decoded = try XCTUnwrap(WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner)))
        let samples = decoded.safeHealthSamples(deviceID: "device", characteristicUUID: WearableUUIDs.sensorData, receivedAt: Date())

        XCTAssertEqual(decoded.dataRecord?.r10?.skinTemperatureC ?? 0, 34.5, accuracy: 0.001)
        XCTAssertEqual(samples.map(\.type), [.wristTemperature])
        XCTAssertEqual(samples.first?.metadata["metric_policy"], "raw_device_contact_temperature_not_baseline_delta")
        XCTAssertEqual(samples.first?.metadata["formula"], "int16_le(r10_inner_bytes[44:46]) / 512")
    }

    func testR21FrameProducesOpticalSampleSummaryWithoutMedicalClaim() {
        var inner = Data(repeating: 0, count: 1_244)
        inner[0] = WearablePacketType.rawRealtimeData.rawValue
        inner[1] = 21
        inner[14] = 7
        inner[16] = 12
        inner[622] = 10
        writeUInt16Sequence(into: &inner, offset: 20, values: Array(10..<110))
        writeUInt16Sequence(into: &inner, offset: 220, values: Array(20..<120))
        writeUInt16Sequence(into: &inner, offset: 420, values: Array(30..<130))
        writeUInt16Sequence(into: &inner, offset: 632, values: Array(40..<140))
        writeUInt16Sequence(into: &inner, offset: 832, values: Array(50..<150))
        writeUInt16Sequence(into: &inner, offset: 1_032, values: Array(60..<160))
        let decoded = WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner))

        XCTAssertEqual(decoded?.recordType, 21)
        XCTAssertEqual(decoded?.ppgSampleCount, 12)
        XCTAssertEqual(decoded?.ppgChannelCount, 6)
        XCTAssertEqual(decoded?.dataRecord?.r21?.ledDriveLevel, 7)
        XCTAssertEqual(decoded?.dataRecord?.r21?.secondarySampleCount, 10)
        XCTAssertEqual(decoded?.dataRecord?.r21?.channelSummaries["chA"]?.minimum, 10)
        XCTAssertEqual(decoded?.dataRecord?.r21?.channelSummaries["chF"]?.maximum, 159)
        XCTAssertNil(decoded?.heartRateBPM)
        XCTAssertTrue(
            decoded?.safeHealthSamples(deviceID: "device", characteristicUUID: WearableUUIDs.sensorData, receivedAt: Date()).isEmpty ?? false,
            "R21 optical summaries are diagnostic only until a validated health-metric transform exists."
        )
    }

    func testR24SpO2CandidateEmitsCalculatedOxygenSample() throws {
        var inner = Data(repeating: 0, count: 120)
        inner[0] = WearablePacketType.historicalData.rawValue
        inner[1] = 24
        let raw = UInt16(97.5 * 32)
        inner[79] = UInt8((raw >> 8) & 0xFF)
        inner[80] = UInt8(raw & 0xFF)

        let decoded = try XCTUnwrap(WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner)))

        XCTAssertEqual(decoded.dataRecord?.r24?.spo2CandidatePercent ?? 0, 97.5, accuracy: 0.001)
        let sample = try XCTUnwrap(
            decoded.safeHealthSamples(
                deviceID: "device",
                characteristicUUID: WearableUUIDs.sensorData,
                receivedAt: Date()
            ).first { $0.type == .oxygenSaturation }
        )
        XCTAssertEqual(sample.source, .whoordanEstimate)
        XCTAssertEqual(sample.confidence, .low)
        XCTAssertEqual(sample.metadata["device_only_derivation"], "true")
        XCTAssertEqual(sample.metadata["metric_policy"], "r24_candidate_ble_derived_spo2")
        XCTAssertEqual(sample.metadata["verification_basis"], "crc_valid_r24_frames")
    }

    func testR24OutOfRangeSpO2CandidateIsNotEmitted() throws {
        var inner = Data(repeating: 0, count: 120)
        inner[0] = WearablePacketType.historicalData.rawValue
        inner[1] = 24
        let raw = UInt16(101 * 32)
        inner[79] = UInt8((raw >> 8) & 0xFF)
        inner[80] = UInt8(raw & 0xFF)

        let decoded = try XCTUnwrap(WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner)))
        let samples = decoded.safeHealthSamples(
            deviceID: "device",
            characteristicUUID: WearableUUIDs.sensorData,
            receivedAt: Date()
        )

        XCTAssertNil(decoded.dataRecord?.r24?.spo2CandidatePercent)
        XCTAssertTrue(samples.allSatisfy { $0.type != .oxygenSaturation })
    }

    func testR10FrameEmitsCalculatedStepsFromMotionSummary() throws {
        var inner = Data(repeating: 0, count: 1_928)
        inner[0] = WearablePacketType.rawRealtimeData.rawValue
        inner[1] = 10
        inner[17] = 96
        writeInt16Sequence(into: &inner, offset: 85, values: Array(repeating: 0, count: 100))
        writeInt16Sequence(into: &inner, offset: 285, values: Array(repeating: 0, count: 100))
        writeInt16Sequence(into: &inner, offset: 485, values: Self.recurrentStepWaveform(peakIndexes: [15, 40, 65, 90]))
        writeInt16Sequence(into: &inner, offset: 688, values: Array(repeating: 0, count: 100))
        writeInt16Sequence(into: &inner, offset: 888, values: Array(repeating: 0, count: 100))
        writeInt16Sequence(into: &inner, offset: 1_088, values: Array(repeating: 0, count: 100))

        let decoded = try XCTUnwrap(WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner)))
        let sample = try XCTUnwrap(
            decoded.safeHealthSamples(
                deviceID: "device",
                characteristicUUID: WearableUUIDs.sensorData,
                receivedAt: Date()
            ).first { $0.type == .steps }
        )

        XCTAssertEqual(sample.value, 4)
        XCTAssertEqual(sample.source, .whoordanEstimate)
        XCTAssertEqual(sample.confidence, .low)
        XCTAssertEqual(sample.metadata["device_only_derivation"], "true")
        XCTAssertEqual(sample.metadata["metric_policy"], "r10_imu_motion_step_estimate")
        XCTAssertEqual(sample.metadata["algorithm"], "wrist_vm_peak_detector_v1")
        XCTAssertEqual(sample.metadata["formula"], "median-normalized R10 accelerometer VM recurrent peak count")
        XCTAssertEqual(sample.metadata["local_accuracy"], "needs_labeled_step_ground_truth")
    }

    func testR10StepEstimatorRejectsNonRecurrentHighRangeMotion() throws {
        var inner = Data(repeating: 0, count: 1_928)
        inner[0] = WearablePacketType.rawRealtimeData.rawValue
        inner[1] = 10
        inner[17] = 96
        writeInt16Sequence(into: &inner, offset: 85, values: stride(from: -4_000, to: 6_000, by: 100).map { $0 })
        writeInt16Sequence(into: &inner, offset: 285, values: stride(from: 3_500, to: -6_500, by: -100).map { $0 })
        writeInt16Sequence(into: &inner, offset: 485, values: stride(from: -2_000, to: 8_000, by: 100).map { $0 })
        writeInt16Sequence(into: &inner, offset: 688, values: Array(repeating: 0, count: 100))
        writeInt16Sequence(into: &inner, offset: 888, values: Array(repeating: 0, count: 100))
        writeInt16Sequence(into: &inner, offset: 1_088, values: Array(repeating: 0, count: 100))

        let decoded = try XCTUnwrap(WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner)))
        let samples = decoded.safeHealthSamples(
            deviceID: "device",
            characteristicUUID: WearableUUIDs.sensorData,
            receivedAt: Date()
        )

        XCTAssertTrue(samples.allSatisfy { $0.type != .steps })
    }

    func testR10StepEstimatorRejectsDrivingLikeLowAmplitudeVibration() throws {
        var inner = Data(repeating: 0, count: 1_928)
        inner[0] = WearablePacketType.rawRealtimeData.rawValue
        inner[1] = 10
        inner[17] = 80
        let vibration = (0..<100).map { index in
            4_096 + (index.isMultiple(of: 2) ? 40 : -40)
        }
        writeInt16Sequence(into: &inner, offset: 85, values: vibration)
        writeInt16Sequence(into: &inner, offset: 285, values: Array(repeating: 0, count: 100))
        writeInt16Sequence(into: &inner, offset: 485, values: Array(repeating: 0, count: 100))
        writeInt16Sequence(into: &inner, offset: 688, values: Array(repeating: 0, count: 100))
        writeInt16Sequence(into: &inner, offset: 888, values: Array(repeating: 0, count: 100))
        writeInt16Sequence(into: &inner, offset: 1_088, values: Array(repeating: 0, count: 100))

        let decoded = try XCTUnwrap(WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner)))
        let samples = decoded.safeHealthSamples(
            deviceID: "device",
            characteristicUUID: WearableUUIDs.sensorData,
            receivedAt: Date()
        )

        XCTAssertTrue(samples.allSatisfy { $0.type != .steps })
    }

    func testR10FrameEmitsCalculatedSleepSegmentFromLowMotionLowHeartRate() throws {
        var inner = Data(repeating: 0, count: 1_928)
        inner[0] = WearablePacketType.rawRealtimeData.rawValue
        inner[1] = 10
        inner[17] = 52
        writeInt16Sequence(into: &inner, offset: 85, values: Array(repeating: 20, count: 100))
        writeInt16Sequence(into: &inner, offset: 285, values: Array(repeating: -15, count: 100))
        writeInt16Sequence(into: &inner, offset: 485, values: Array(repeating: 1_000, count: 100))
        writeInt16Sequence(into: &inner, offset: 688, values: Array(repeating: 0, count: 100))
        writeInt16Sequence(into: &inner, offset: 888, values: Array(repeating: 0, count: 100))
        writeInt16Sequence(into: &inner, offset: 1_088, values: Array(repeating: 0, count: 100))

        let decoded = try XCTUnwrap(WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner)))
        let sample = try XCTUnwrap(
            decoded.safeHealthSamples(
                deviceID: "device",
                characteristicUUID: WearableUUIDs.sensorData,
                receivedAt: Date()
            ).first { $0.type == .sleepAnalysis }
        )

        XCTAssertEqual(sample.source, .whoordanEstimate)
        XCTAssertEqual(sample.metadata["sleep_category"], "4")
        XCTAssertEqual(sample.metadata["device_only_derivation"], "true")
        XCTAssertEqual(sample.metadata["metric_policy"], "r10_hr_imu_sleep_stage_estimate")
        XCTAssertEqual(sample.metadata["algorithm"], WearableR10DerivedMetricEstimator.sleepStageClassifierVersion)
        XCTAssertEqual(sample.metadata["heart_rate_bpm"], "52")
        XCTAssertEqual(sample.metadata["stage_context_refinement"], "session_hr_motion_hypnogram_prior")
        XCTAssertNotNil(sample.metadata["sleep_motion_normalized_range"])
    }

    func testR10EstimatedSleepIDsUseReceivedMinuteWhenDeviceTimestampIsInvalid() throws {
        let receivedAt = Date(timeIntervalSince1970: 1_779_030_000)
        var inner = Data(repeating: 0, count: 1_928)
        inner[0] = WearablePacketType.rawRealtimeData.rawValue
        inner[1] = 10
        inner[17] = 52
        writeInt16Sequence(into: &inner, offset: 85, values: Array(repeating: 20, count: 100))
        writeInt16Sequence(into: &inner, offset: 285, values: Array(repeating: -15, count: 100))
        writeInt16Sequence(into: &inner, offset: 485, values: Array(repeating: 1_000, count: 100))
        writeInt16Sequence(into: &inner, offset: 688, values: Array(repeating: 0, count: 100))
        writeInt16Sequence(into: &inner, offset: 888, values: Array(repeating: 0, count: 100))
        writeInt16Sequence(into: &inner, offset: 1_088, values: Array(repeating: 0, count: 100))

        let decoded = try XCTUnwrap(WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner)))
        let first = try XCTUnwrap(
            decoded.safeHealthSamples(
                deviceID: "device",
                characteristicUUID: WearableUUIDs.sensorData,
                receivedAt: receivedAt
            ).first { $0.type == .sleepAnalysis }
        )
        let sameMinuteDuplicate = try XCTUnwrap(
            decoded.safeHealthSamples(
                deviceID: "device",
                characteristicUUID: WearableUUIDs.sensorData,
                receivedAt: receivedAt.addingTimeInterval(30)
            ).first { $0.type == .sleepAnalysis }
        )
        let nextMinute = try XCTUnwrap(
            decoded.safeHealthSamples(
                deviceID: "device",
                characteristicUUID: WearableUUIDs.sensorData,
                receivedAt: receivedAt.addingTimeInterval(60)
            ).first { $0.type == .sleepAnalysis }
        )

        XCTAssertEqual(first.sourceRecordID, sameMinuteDuplicate.sourceRecordID)
        XCTAssertNotEqual(first.sourceRecordID, nextMinute.sourceRecordID)
        XCTAssertEqual(first.metadata["sample_time_basis"], "received_at")
        XCTAssertEqual(nextMinute.startDate.timeIntervalSince1970, receivedAt.addingTimeInterval(60).timeIntervalSince1970, accuracy: 0.001)
    }

    func testEventFrameProducesEventType() {
        let inner = Data([WearablePacketType.event.rawValue, 0, 9, 0, 0, 0, 0, 0])
        let decoded = WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner))

        XCTAssertEqual(decoded?.packetType, .event)
        XCTAssertEqual(decoded?.eventType, 9)
    }

    func testBase64DevFixtureParserReassemblesFrames() throws {
        let frame = commandResponseFrame(command: .getAdvertisingName, sequence: 7, payload: Data([0, 0]) + Data("TEST WEARABLE".utf8))
        let split = frame.index(frame.startIndex, offsetBy: 5)
        let jsonLines = [
            fixtureLine(Data(frame[..<split])),
            fixtureLine(Data(frame[split...]))
        ].joined(separator: "\n")

        let frames = try WearableDevPayloadFixtureParser.frames(fromJSONLines: jsonLines)

        XCTAssertEqual(frames, [frame])
    }

    func testDeveloperCaptureRecordCarriesScenarioDirectionAndNoPlainDeviceIdentifier() throws {
        let record = WearableRawPayloadCaptureRecord(
            capturedAt: "2026-05-12T10:00:00Z",
            characteristicUUID: WearableUUIDs.sensorData,
            byteCount: 4,
            payloadLength: 4,
            direction: .notify,
            payloadBase64: Data([0xAA, 0x01, 0x02, 0x03]).base64EncodedString(),
            packetType: "rawRealtimeData",
            decodedPacketType: "rawRealtimeData",
            connectionState: .realtime,
            rssi: -51,
            batteryPercent: 87,
            isCharging: false,
            deviceTimeUnix: 1_735_689_600,
            appState: "foreground",
            scenario: .walking,
            appVersion: "1.0",
            deviceModel: "iPhone",
            sessionLabel: "walking validation"
        )

        let data = try JSONEncoder().encode(record)
        let decoded = try JSONDecoder().decode(WearableRawPayloadCaptureRecord.self, from: data)
        let text = String(data: data, encoding: .utf8) ?? ""

        XCTAssertEqual(decoded.scenario, .walking)
        XCTAssertEqual(decoded.direction, .notify)
        XCTAssertEqual(decoded.decodedPacketType, "rawRealtimeData")
        XCTAssertEqual(decoded.payloadLength, 4)
        XCTAssertEqual(decoded.packetType, "rawRealtimeData")
        XCTAssertEqual(decoded.batteryPercent, 87)
        XCTAssertEqual(decoded.isCharging, false)
        XCTAssertEqual(decoded.appVersion, "1.0")
        XCTAssertEqual(decoded.deviceModel, "iPhone")
        XCTAssertEqual(decoded.sessionLabel, "walking validation")
        XCTAssertFalse(text.contains("private-device-id"))
        XCTAssertFalse(text.lowercased().contains("token"))
    }

    func testRawPayloadCaptureWritesLocalJSONLinesWithScenarioMetadata() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("whoordan-capture-test-\(UUID().uuidString)", isDirectory: true)
        let capture = try XCTUnwrap(WearableRawPayloadCapture(
            scenario: .hapticPreview,
            maxRecords: 2,
            directoryURL: tempDirectory
        ))
        let frame = WearableProtocol.initSequence()[0]

        let count = capture.record(
            data: frame,
            characteristicUUID: WearableUUIDs.commandWrite,
            direction: .write,
            decodedPacketType: "command",
            connectionState: .initializing,
            rssi: -45,
            batteryPercent: 44,
            isCharging: true,
            deviceTime: nil,
            appState: "foreground",
            appVersion: "1.0-test",
            deviceModel: "UnitTestPhone",
            sessionLabel: "haptic preview"
        )

        XCTAssertEqual(count, 1)
        let jsonLines = try String(contentsOfFile: capture.filePath, encoding: .utf8)
        let decoded = try JSONDecoder().decode(
            WearableRawPayloadCaptureRecord.self,
            from: Data(try XCTUnwrap(jsonLines.split(whereSeparator: \.isNewline).first).utf8)
        )
        XCTAssertEqual(decoded.scenario, .hapticPreview)
        XCTAssertEqual(decoded.direction, .write)
        XCTAssertEqual(decoded.characteristicUUID, WearableUUIDs.commandWrite)
        XCTAssertEqual(decoded.payloadBase64, frame.base64EncodedString())
        XCTAssertEqual(decoded.payloadLength, frame.count)
        XCTAssertEqual(decoded.batteryPercent, 44)
        XCTAssertEqual(decoded.isCharging, true)
        XCTAssertEqual(decoded.appVersion, "1.0-test")
        XCTAssertEqual(decoded.deviceModel, "UnitTestPhone")
        XCTAssertEqual(decoded.sessionLabel, "haptic preview")
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testRawPayloadCaptureExportsDebugDirectoryAsZipArchive() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("whoordan-export-test-\(UUID().uuidString)", isDirectory: true)
        let capture = try XCTUnwrap(WearableRawPayloadCapture(
            scenario: .overnight,
            maxRecords: 2,
            directoryURL: tempDirectory,
            sessionLabel: "overnight"
        ))
        _ = capture.record(
            data: WearableProtocol.initSequence()[0],
            characteristicUUID: WearableUUIDs.commandWrite,
            direction: .write,
            decodedPacketType: "command",
            connectionState: .historicalSync,
            rssi: -48,
            batteryPercent: 91,
            isCharging: false,
            deviceTime: nil,
            appState: "background",
            appVersion: "1.0-test",
            deviceModel: "UnitTestPhone",
            sessionLabel: "overnight"
        )
        _ = try capture.save(named: "Overnight")
        let continuousCapture = try XCTUnwrap(WearableContinuousRawPayloadCapture(
            directoryURL: tempDirectory,
            maxRecordsPerFile: 2,
            maxFiles: 2,
            dateProvider: { Date(timeIntervalSince1970: 1_735_689_600) }
        ))
        _ = continuousCapture.record(
            data: WearableProtocol.initSequence()[1],
            characteristicUUID: WearableUUIDs.commandWrite,
            direction: .write,
            decodedPacketType: "command",
            connectionState: .initializing,
            rssi: -49,
            batteryPercent: 48,
            isCharging: true,
            deviceTime: nil,
            appState: "foreground",
            appVersion: "1.0-test",
            deviceModel: "UnitTestPhone"
        )

        let archive = try WearableRawPayloadCapture.makeExportArchive(
            directoryURL: tempDirectory.appendingPathComponent("whoordan-ble-debug", isDirectory: true),
            createdAt: Date(timeIntervalSince1970: 1_735_689_600)
        )
        let archiveData = try Data(contentsOf: archive)

        XCTAssertTrue(archive.lastPathComponent.hasSuffix(".zip"))
        XCTAssertEqual(archiveData.prefix(2), Data([0x50, 0x4B]))
        XCTAssertGreaterThan(archiveData.count, 32)
        XCTAssertNotNil(archiveData.range(of: Data("continuous_raw-payloads".utf8)))
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testContinuousRawPayloadCaptureRotatesAndPrunesJSONLFiles() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("whoordan-continuous-capture-test-\(UUID().uuidString)", isDirectory: true)
        var tick = 0
        let capture = try XCTUnwrap(WearableContinuousRawPayloadCapture(
            directoryURL: tempDirectory,
            maxRecordsPerFile: 2,
            maxFiles: 2,
            dateProvider: {
                defer { tick += 1 }
                return Date(timeIntervalSince1970: 1_735_689_600 + TimeInterval(tick))
            }
        ))

        for index in 0..<5 {
            let count = capture.record(
                data: Data([UInt8(index)]),
                characteristicUUID: WearableUUIDs.sensorData,
                direction: .notify,
                decodedPacketType: "test",
                connectionState: .realtime,
                rssi: -50,
                batteryPercent: 48,
                isCharging: false,
                deviceTime: nil,
                appState: "foreground",
                appVersion: "1.0-test",
                deviceModel: "UnitTestPhone"
            )
            XCTAssertEqual(count, index + 1)
        }

        let debugDirectory = tempDirectory.appendingPathComponent("whoordan-ble-debug", isDirectory: true)
        let fileNames = try FileManager.default.contentsOfDirectory(atPath: debugDirectory.path)
            .filter { $0.hasPrefix("continuous_raw-payloads-") && $0.hasSuffix(".jsonl") }
            .sorted()
        let calibrationFileNames = try FileManager.default.contentsOfDirectory(atPath: debugDirectory.path)
            .filter { $0.hasPrefix("continuous_synthetic-calibration-") && $0.hasSuffix(".jsonl") }
            .sorted()

        XCTAssertEqual(fileNames.count, 2)
        XCTAssertEqual(calibrationFileNames.count, 2)
        XCTAssertEqual(
            calibrationFileNames.map(Self.linkedRawPayloadFileName(forCalibrationFileName:)),
            fileNames
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: debugDirectory.appendingPathComponent("README_DO_NOT_COMMIT.txt").path))
        let latestContents = try String(contentsOf: URL(fileURLWithPath: capture.filePath), encoding: .utf8)
        XCTAssertEqual(latestContents.split(whereSeparator: \.isNewline).count, 1)
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testContinuousRawPayloadCaptureDefaultRetentionKeepsMultiDayBuffer() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("whoordan-continuous-multiday-retention-test-\(UUID().uuidString)", isDirectory: true)
        var tick = 0
        let capture = try XCTUnwrap(WearableContinuousRawPayloadCapture(
            directoryURL: tempDirectory,
            maxRecordsPerFile: 1,
            dateProvider: {
                defer { tick += 1 }
                return Date(timeIntervalSince1970: 1_735_689_600 + TimeInterval(tick))
            }
        ))

        for index in 0..<400 {
            _ = capture.record(
                data: Data([UInt8(index % 256)]),
                characteristicUUID: WearableUUIDs.sensorData,
                direction: .notify,
                decodedPacketType: "test",
                connectionState: .realtime,
                rssi: -50,
                batteryPercent: 48,
                isCharging: false,
                deviceTime: nil,
                appState: "background",
                appVersion: "1.0-test",
                deviceModel: "UnitTestPhone"
            )
        }

        let debugDirectory = tempDirectory.appendingPathComponent("whoordan-ble-debug", isDirectory: true)
        let fileNames = try FileManager.default.contentsOfDirectory(atPath: debugDirectory.path)
            .filter { $0.hasPrefix("continuous_raw-payloads-") && $0.hasSuffix(".jsonl") }
        let calibrationFileNames = try FileManager.default.contentsOfDirectory(atPath: debugDirectory.path)
            .filter { $0.hasPrefix("continuous_synthetic-calibration-") && $0.hasSuffix(".jsonl") }

        XCTAssertEqual(fileNames.count, 384)
        XCTAssertEqual(calibrationFileNames.count, 384)
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testContinuousRawPayloadCaptureWritesSyntheticCalibrationSidecarLinkedToJSONL() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("whoordan-calibration-sidecar-test-\(UUID().uuidString)", isDirectory: true)
        let capturedAt = Date(timeIntervalSince1970: 1_735_689_600)
        let capture = try XCTUnwrap(WearableContinuousRawPayloadCapture(
            directoryURL: tempDirectory,
            maxRecordsPerFile: 4,
            maxFiles: 2,
            dateProvider: { capturedAt }
        ))
        var inner = Data(repeating: 0, count: 1_928)
        inner[0] = WearablePacketType.rawRealtimeData.rawValue
        inner[1] = 10
        inner[17] = 82
        writeInt16Sequence(into: &inner, offset: 85, values: stride(from: -4_000, to: 6_000, by: 100).map { $0 })
        writeInt16Sequence(into: &inner, offset: 285, values: stride(from: 3_500, to: -6_500, by: -100).map { $0 })
        writeInt16Sequence(into: &inner, offset: 485, values: stride(from: -2_000, to: 8_000, by: 100).map { $0 })
        let frame = WearableProtocol.frame(inner: inner)

        _ = capture.record(
            data: frame,
            characteristicUUID: WearableUUIDs.sensorData,
            direction: .notify,
            decodedPacketType: "rawRealtimeData",
            connectionState: .realtime,
            rssi: -48,
            batteryPercent: 50,
            isCharging: false,
            deviceTime: capturedAt,
            appState: "background",
            appVersion: "1.0-test",
            deviceModel: "UnitTestPhone"
        )

        let debugDirectory = tempDirectory.appendingPathComponent("whoordan-ble-debug", isDirectory: true)
        let rawFileName = URL(fileURLWithPath: capture.filePath).lastPathComponent
        let calibrationFileName = try XCTUnwrap(
            try FileManager.default.contentsOfDirectory(atPath: debugDirectory.path)
                .first { $0.hasPrefix("continuous_synthetic-calibration-") && $0.hasSuffix(".jsonl") }
        )
        let calibrationURL = debugDirectory.appendingPathComponent(calibrationFileName)
        let text = try String(contentsOf: calibrationURL, encoding: .utf8)
        let firstLine = try XCTUnwrap(text.split(whereSeparator: \.isNewline).first)
        let record = try JSONDecoder().decode(WearableSyntheticCalibrationRecord.self, from: Data(firstLine.utf8))

        XCTAssertEqual(record.provenance, .syntheticCalibrationShadow)
        XCTAssertEqual(record.linkedRawPayloadFileName, rawFileName)
        XCTAssertEqual(record.linkedRawPayloadRecordIndex, 1)
        XCTAssertEqual(record.personID, "person_1")
        XCTAssertEqual(record.profile.heightCentimeters, 167)
        XCTAssertEqual(record.profile.weightKilograms, 69)
        XCTAssertEqual(record.profile.ageYears, 22)
        XCTAssertEqual(record.packetAnchor.heartRateBPM, 82)
        XCTAssertGreaterThan(record.packetAnchor.motionIntensity, 0)
        XCTAssertGreaterThan(record.metrics.recoveryPercent, 0)
        XCTAssertGreaterThan(record.metrics.sleepNeedMinutes, 0)
        XCTAssertFalse(text.contains(frame.base64EncodedString()))
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testUnknownFrameTrendStatsAggregateByFrameClass() {
        let now = Date(timeIntervalSince1970: 1_735_689_600)
        var stats: [WearableFrameTrendStat] = []
        let first = WearableFrameObservation(
            id: "r7-a",
            packetType: "historicalData",
            recordType: 7,
            label: "R7 raw",
            observationKind: "unknown",
            byteCount: 44,
            sampleCount: nil,
            candidateValue: nil,
            caveat: "Unknown",
            observedAt: now
        )
        let second = WearableFrameObservation(
            id: "r7-b",
            packetType: "historicalData",
            recordType: 7,
            label: "R7 raw",
            observationKind: "unknown",
            byteCount: 46,
            sampleCount: nil,
            candidateValue: nil,
            caveat: "Unknown",
            observedAt: now.addingTimeInterval(60)
        )

        WearableFrameTrendStat.upsert(observation: first, into: &stats)
        WearableFrameTrendStat.upsert(observation: second, into: &stats)

        XCTAssertEqual(stats.count, 1)
        XCTAssertEqual(stats.first?.frameClass, "historicalData:R7:unknown")
        XCTAssertEqual(stats.first?.count, 2)
        XCTAssertEqual(stats.first?.lastObservedAt, now.addingTimeInterval(60))
    }

    func testRawPayloadCaptureCanBeSavedWithSluggedSequentialRecordingName() throws {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("whoordan-named-capture-test-\(UUID().uuidString)", isDirectory: true)
        let existing = tempDirectory
            .appendingPathComponent("whoordan-ble-debug", isDirectory: true)
            .appendingPathComponent("idle_no_tap_01.jsonl")
        try FileManager.default.createDirectory(at: existing.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: existing)
        let capture = try XCTUnwrap(WearableRawPayloadCapture(
            scenario: .idle,
            maxRecords: 2,
            directoryURL: tempDirectory
        ))
        let originalPath = capture.filePath
        let frame = WearableProtocol.initSequence()[1]

        _ = capture.record(
            data: frame,
            characteristicUUID: WearableUUIDs.commandResponse,
            direction: .notify,
            decodedPacketType: "commandResponse",
            connectionState: .historicalSync,
            rssi: -51,
            deviceTime: nil,
            appState: "foreground"
        )

        let saved = try capture.save(named: "Idle No Tap")

        XCTAssertEqual(saved.recordingName, "Idle No Tap")
        XCTAssertEqual(saved.recordCount, 1)
        XCTAssertEqual(saved.fileName, "idle_no_tap_02.jsonl")
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: capture.filePath))
        XCTAssertTrue(capture.filePath.hasSuffix(saved.fileName))
        try? FileManager.default.removeItem(at: tempDirectory)
    }

    func testRecordingNameSlugUsesUnderscoresAndTwoDigitSequence() {
        let examples = [
            "idle no tap": "idle_no_tap",
            "double tap once": "double_tap_once",
            "wrist off": "wrist_off",
            "wrist on transition": "wrist_on_transition",
            "charger plug": "charger_plug",
            "charger unplug": "charger_unplug",
            "walking": "walking"
        ]

        for (recordingName, expected) in examples {
            XCTAssertEqual(WearableRawPayloadCapture.fileNameBase(for: recordingName), expected)
        }
    }

    private static func linkedRawPayloadFileName(forCalibrationFileName fileName: String) -> String {
        fileName.replacingOccurrences(
            of: "continuous_synthetic-calibration-",
            with: "continuous_raw-payloads-"
        )
    }

    func testCommandResponseFrameParsesCommandStatusAndPayload() {
        let frame = commandResponseFrame(command: .getHelloHarvard, sequence: 8, payload: Data("SERIAL123 firmware-token".utf8))
        let decoded = WearablePacketDecoder.decode(frame: frame)

        XCTAssertEqual(decoded?.commandResponse?.kind, "helloHarvard")
        XCTAssertEqual(decoded?.commandResponse?.sequence, 8)
        XCTAssertEqual(decoded?.commandResponse?.command, .getHelloHarvard)
        XCTAssertEqual(decoded?.commandResponse?.statusByte, 1)
        XCTAssertEqual(decoded?.commandResponse?.payloadByteCount, 24)
    }

    func testDeviceNameParsesFromAdvertisingNameResponse() {
        let frame = commandResponseFrame(command: .getAdvertisingName, sequence: 9, payload: Data([1, 1, 10]) + Data("TEST WEARABLE".utf8))

        let decoded = WearablePacketDecoder.decode(frame: frame)

        XCTAssertEqual(decoded?.commandResponse?.advertisingName, "TEST WEARABLE")
    }

    func testSerialLikeValueProducesFingerprintWithoutExposingRawPayload() {
        let frame = commandResponseFrame(command: .getHelloHarvard, sequence: 10, payload: Data("SERIAL123 long-fingerprint-value".utf8))

        let response = WearablePacketDecoder.decode(frame: frame)?.commandResponse

        XCTAssertEqual(response?.serialLikeValue, "SERIAL123")
        XCTAssertEqual(response?.deviceFingerprint, WearablePrivacy.fingerprint("SERIAL123"))
        XCTAssertNotEqual(response?.deviceFingerprint, "SERIAL123")
    }

    func testDataRangeResponseExtractsPlausibleDateCandidates() {
        var payload = Data([0, 0, 0, 0])
        payload.append(littleEndianUInt32(1_735_689_600))
        let frame = commandResponseFrame(command: .getDataRange, sequence: 11, payload: payload)

        let response = WearablePacketDecoder.decode(frame: frame)?.commandResponse

        let candidateSeconds = response?.dataRange?.dateCandidates.map { Int($0.timeIntervalSince1970) } ?? []
        XCTAssertTrue(candidateSeconds.contains(1_735_689_600))
    }

    func testAlarmAndHistoricalSyncResponsesParseHonestStatus() {
        let alarm = WearablePacketDecoder.decode(
            frame: commandResponseFrame(command: .getAlarmTime, sequence: 12, payload: Data([0]))
        )?.commandResponse
        let sync = WearablePacketDecoder.decode(
            frame: commandResponseFrame(command: .sendHistoricalData, sequence: 13, status: 2, payload: Data([11]))
        )?.commandResponse

        XCTAssertEqual(alarm?.alarm?.isConfigured, false)
        XCTAssertEqual(sync?.historicalSync?.statusByte, 2)
        XCTAssertEqual(sync?.historicalSync?.payloadByteCount, 1)
    }

    func testMetadataPacketParsesEndOfSyncCandidate() {
        let frame = WearableProtocol.frame(inner: Data([WearablePacketType.metadata.rawValue, 42, 1, 2, 3, 4]))

        let metadata = WearablePacketDecoder.decode(frame: frame)?.metadata

        XCTAssertEqual(metadata?.sequence, 42)
        XCTAssertEqual(metadata?.isBatchMarker, false)
        XCTAssertEqual(metadata?.isEndOfSync, true)
    }

    func testRealtimeFrameParsesRecordTypeWithoutFakeHealthMetric() {
        let frame = WearableProtocol.frame(inner: Data([WearablePacketType.realtimeData.rawValue, 2, 1, 2, 3, 4, 5, 6]))

        let decoded = WearablePacketDecoder.decode(frame: frame)

        XCTAssertEqual(decoded?.packetType, .realtimeData)
        XCTAssertEqual(decoded?.recordType, 2)
        XCTAssertEqual(decoded?.dataRecord?.label, "record 2")
        XCTAssertTrue(decoded?.safeHealthSamples(deviceID: "device", characteristicUUID: WearableUUIDs.sensorData, receivedAt: Date()).isEmpty ?? false)
    }

    func testFragmentedRawRealtimeR10FrameReassemblesAndEmitsOnlyHeartRateAndIMUSummary() {
        var inner = Data(repeating: 0, count: 1920)
        inner[0] = WearablePacketType.rawRealtimeData.rawValue
        inner[1] = 10
        inner[17] = 68
        let frame = WearableProtocol.frame(inner: inner)
        var reassembler = FrameReassembler()

        XCTAssertTrue(reassembler.append(frame.prefix(100)).isEmpty)
        let frames = reassembler.append(Data(frame.dropFirst(100)))
        let decoded = frames.first.flatMap(WearablePacketDecoder.decode(frame:))

        XCTAssertEqual(frames, [frame])
        XCTAssertEqual(decoded?.dataRecord?.r10?.heartRateBPM, 68)
        XCTAssertEqual(decoded?.dataRecord?.r10?.accelerometerSampleCount, 100)
        XCTAssertEqual(decoded?.dataRecord?.r10?.gyroscopeSampleCount, 100)
        XCTAssertEqual(decoded?.safeHealthSamples(deviceID: "device", characteristicUUID: WearableUUIDs.sensorData, receivedAt: Date()).first?.type, .heartRate)
        XCTAssertNotNil(decoded?.imuSampleBatch(deviceID: "device", characteristicUUID: WearableUUIDs.sensorData, receivedAt: Date()))
    }

    func testR11RecordIsIdentifiedAsUnsupportedScaffold() {
        var inner = Data(repeating: 0, count: 1924)
        inner[0] = WearablePacketType.rawRealtimeData.rawValue
        inner[1] = 11

        let decoded = WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner))

        XCTAssertEqual(decoded?.dataRecord?.r11?.payloadByteCount, 1922)
        XCTAssertNil(decoded?.heartRateBPM)
        XCTAssertTrue(decoded?.safeHealthSamples(deviceID: "device", characteristicUUID: WearableUUIDs.sensorData, receivedAt: Date()).isEmpty ?? false)
    }

    func testEvent14IsKeptAsUnverifiedTapCandidate() {
        let inner = Data([WearablePacketType.event.rawValue, 98, 14, 0, 0, 0, 0, 0, 0, 0, 0, 0])

        let event = WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner))?.event

        XCTAssertEqual(event?.eventType, 14)
        XCTAssertEqual(event?.kind, .unknown)
    }

    func testHapticEventsAreScaffolded() {
        let fired = WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: Data([WearablePacketType.event.rawValue, 1, 60, 0])))?.event
        let terminated = WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: Data([WearablePacketType.event.rawValue, 1, 100, 0])))?.event

        XCTAssertEqual(fired?.kind, .hapticsFired)
        XCTAssertEqual(terminated?.kind, .hapticsTerminated)
    }

    func testAlarmAndRealtimeEventsAreClassified() {
        XCTAssertEqual(
            WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: eventInner(type: 33)))?.event?.kind,
            .realtimeHeartRateStarted
        )
        XCTAssertEqual(
            WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: eventInner(type: 34)))?.event?.kind,
            .realtimeHeartRateStopped
        )
        XCTAssertEqual(
            WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: eventInner(type: 56)))?.event?.kind,
            .alarmSet
        )
        XCTAssertEqual(
            WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: eventInner(type: 57)))?.event?.kind,
            .alarmFired
        )
        XCTAssertEqual(
            WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: eventInner(type: 59)))?.event?.kind,
            .alarmDisabled
        )
    }

    func testBatteryTemperatureAndWristEventsParseStructuredPayloads() throws {
        let battery = try XCTUnwrap(WearablePacketDecoder.decode(
            frame: WearableProtocol.frame(inner: eventInner(type: 3, payload: littleEndianUInt32(850)))
        )?.event)
        XCTAssertEqual(battery.kind, .batteryLevel)
        XCTAssertEqual(battery.numericValue ?? 0, 85, accuracy: 0.001)
        XCTAssertEqual(Int(battery.timestamp?.timeIntervalSince1970 ?? 0), 1_735_689_600)

        let temperature = try XCTUnwrap(WearablePacketDecoder.decode(
            frame: WearableProtocol.frame(inner: eventInner(type: 17, payload: littleEndianInt16(367)))
        )?.event)
        XCTAssertEqual(temperature.kind, .temperature)
        XCTAssertEqual(temperature.numericValue ?? 0, 36.7, accuracy: 0.001)
        XCTAssertEqual(
            WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: eventInner(type: 9)))?.event?.kind,
            .wristOn
        )
    }

    func testTemperatureEventEmitsTemperatureEventOnly() {
        let decoded = WearablePacketDecoder.decode(
            frame: WearableProtocol.frame(inner: eventInner(type: 17, payload: littleEndianInt16(366)))
        )

        let samples = decoded?.safeHealthSamples(deviceID: "device", characteristicUUID: WearableUUIDs.events, receivedAt: Date()) ?? []

        XCTAssertEqual(samples.map(\.type), [.temperatureEvent])
        XCTAssertEqual(samples.first?.unit, "degC")
        XCTAssertEqual(samples.first?.metadata["metric_policy"], "device_temperature_event_not_body_temperature")
    }

    func testHelloHarvardParsesBatteryChargingWristWithoutRawSerial() throws {
        var payload = Data(repeating: 0, count: 114)
        payload[1] = 48
        payload[2] = 0x03
        payload[5] = 1
        payload.replaceSubrange(6..<10, with: littleEndianUInt32(1_735_689_600))
        payload.replaceSubrange(14..<23, with: Data([1, 2, 3, 4, 5, 6, 7, 8, 9]))
        payload[113] = 1

        let response = try XCTUnwrap(WearablePacketDecoder.decode(
            frame: commandResponseFrame(command: .getHelloHarvard, sequence: 22, payload: payload)
        )?.commandResponse)

        XCTAssertEqual(response.hello?.batteryPercent ?? 0, 48, accuracy: 0.001)
        XCTAssertEqual(response.hello?.isCharging, true)
        XCTAssertEqual(response.hello?.rtcSeconds, 1_735_689_600)
        XCTAssertEqual(response.hello?.isOnWrist, true)
        XCTAssertNotNil(response.hello?.serialFingerprint)
        XCTAssertNotEqual(response.hello?.serialFingerprint, "010203040506070809")
    }

    func testHelloHarvardPrefersScaledBatteryWhenFirstByteIsLowByte() throws {
        var payload = Data(repeating: 0, count: 114)
        payload.replaceSubrange(1..<5, with: littleEndianUInt32(770))
        payload[5] = 0
        payload.replaceSubrange(6..<10, with: littleEndianUInt32(1_735_689_600))
        payload[113] = 1

        let response = try XCTUnwrap(WearablePacketDecoder.decode(
            frame: commandResponseFrame(command: .getHelloHarvard, sequence: 23, payload: payload)
        )?.commandResponse)

        XCTAssertEqual(response.hello?.batteryPercent ?? 0, 77, accuracy: 0.001)
        XCTAssertEqual(response.hello?.isCharging, false)
        XCTAssertEqual(response.hello?.isOnWrist, true)
    }

    func testHelloHarvardDoesNotParseStatusByteAsBatteryFallback() throws {
        var payload = Data(repeating: 0, count: 112)
        payload[111] = 1

        let response = try XCTUnwrap(WearablePacketDecoder.decode(
            frame: commandResponseFrame(command: .getHelloHarvard, sequence: 24, status: 2, payload: payload)
        )?.commandResponse)

        XCTAssertNil(response.hello?.batteryPercent)
        XCTAssertNil(response.hello?.isOnWrist)
    }

    func testFirmwareLogStringParsesWithoutRawPayloadFixture() {
        let inner = Data([WearablePacketType.firmwareLog.rawValue, 99]) + Data("Sensors: Accel double tap".utf8)

        let log = WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner))?.firmwareLog

        XCTAssertEqual(log?.category, "Sensors")
        XCTAssertTrue(log?.message.contains("Accel double tap") ?? false)
    }

    func testFirmwareLogPrefersNullTerminatedASCIIMessage() {
        var inner = Data(repeating: 0, count: 13)
        inner[0] = WearablePacketType.firmwareLog.rawValue
        inner[1] = 99
        inner.append(Data("7323790: CAPSENSE: Strap returned".utf8))
        inner.append(0)
        inner.append(Data("ignored tail".utf8))

        let log = WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner))?.firmwareLog

        XCTAssertEqual(log?.message, "7323790: CAPSENSE: Strap returned")
        XCTAssertFalse(log?.message.contains("ignored tail") ?? true)
    }

    func testMalformedAndOrphanFragmentsAreRejected() {
        var reassembler = FrameReassembler()
        XCTAssertTrue(reassembler.append(Data([1, 2, 3, 4])).isEmpty)
        XCTAssertEqual(reassembler.droppedFragmentCount, 1)

        var badFrame = WearableProtocol.frame(inner: Data([WearablePacketType.event.rawValue, 1, 14, 0]))
        badFrame[3] = 0
        XCTAssertThrowsError(try WearableProtocol.decodeFrame(badFrame))
    }

    func testUnavailableSignalsAreExplicitlyNotEmitted() {
        var inner = Data(repeating: 0, count: 24)
        inner[0] = WearablePacketType.rawRealtimeData.rawValue
        inner[1] = 10
        inner[17] = 72

        let decoded = WearablePacketDecoder.decode(frame: WearableProtocol.frame(inner: inner))

        XCTAssertTrue(decoded?.unavailableSignals.contains(.heartRateVariability) ?? false)
        XCTAssertTrue(decoded?.unavailableSignals.contains(.oxygenSaturation) ?? false)
        XCTAssertTrue(decoded?.unavailableSignals.contains(.steps) ?? false)
        XCTAssertTrue(decoded?.safeHealthSamples(deviceID: "device", characteristicUUID: WearableUUIDs.sensorData, receivedAt: Date()).isEmpty ?? false)
    }

    func testUnknownPacketObservationIsSanitized() {
        let observation = WearableFrameObservation.unknownPacket(
            packetByte: 0xFE,
            byteCount: 42,
            observedAt: Date(timeIntervalSince1970: 1_735_689_600)
        )

        XCTAssertEqual(observation.packetType, "unknown packet")
        XCTAssertEqual(observation.observationKind, "unknown")
        XCTAssertEqual(observation.byteCount, 42)
        XCTAssertNil(observation.candidateValue)
        XCTAssertFalse(observation.id.contains("FE"))
        XCTAssertFalse(observation.label.lowercased().contains("payload"))
        XCTAssertFalse(observation.caveat.lowercased().contains("payload bytes"))
    }

    func testDedupeIDIsStableAndDoesNotIncludeRawIdentifiers() {
        let id = WearableDedupe.id(
            deviceID: "private-device-id",
            characteristicUUID: WearableUUIDs.sensorData,
            packetType: .rawRealtimeData,
            recordType: 10,
            sequence: 2,
            rawTimestamp: 1234,
            payloadByteCount: 1920
        )

        XCTAssertTrue(id.hasPrefix("wearable_ble:"))
        XCTAssertFalse(id.contains("private-device-id"))
        XCTAssertEqual(
            id,
            WearableDedupe.id(
                deviceID: "private-device-id",
                characteristicUUID: WearableUUIDs.sensorData,
                packetType: .rawRealtimeData,
                recordType: 10,
                sequence: 2,
                rawTimestamp: 1234,
                payloadByteCount: 1920
            )
        )
    }

    private func commandResponseFrame(
        command: WearableCommand,
        sequence: UInt8,
        status: UInt8 = 1,
        payload: Data
    ) -> Data {
        var inner = Data([WearablePacketType.commandResponse.rawValue, sequence, command.rawValue, 1, status])
        inner.append(payload)
        return WearableProtocol.frame(inner: inner)
    }

    private func fixtureLine(_ data: Data) -> String {
        #"{"characteristicUUID":"\#(WearableUUIDs.sensorData)","payloadBase64":"\#(data.base64EncodedString())"}"#
    }

    private func littleEndianUInt32(_ value: UInt32) -> Data {
        Data([
            UInt8(value & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 24) & 0xFF)
        ])
    }

    private func littleEndianInt16(_ value: Int16) -> Data {
        let raw = UInt16(bitPattern: value)
        return Data([
            UInt8(raw & 0xFF),
            UInt8((raw >> 8) & 0xFF)
        ])
    }

    private func writeInt16Sequence(into data: inout Data, offset: Int, values: [Int]) {
        for (index, value) in values.enumerated() {
            data.replaceSubrange(offset + index * 2..<(offset + index * 2 + 2), with: littleEndianInt16(Int16(value)))
        }
    }

    private func writeUInt16Sequence(into data: inout Data, offset: Int, values: [Int]) {
        for (index, value) in values.enumerated() {
            let raw = UInt16(value)
            data.replaceSubrange(offset + index * 2..<(offset + index * 2 + 2), with: Data([
                UInt8(raw & 0xFF),
                UInt8((raw >> 8) & 0xFF)
            ]))
        }
    }

    private static func recurrentStepWaveform(peakIndexes: [Int]) -> [Int] {
        (0..<100).map { sampleIndex in
            let pulse = peakIndexes.reduce(0) { current, peakIndex in
                let distance = abs(sampleIndex - peakIndex)
                guard distance <= 2 else { return current }
                return max(current, (3 - distance) * 450)
            }
            return 4_096 + pulse
        }
    }

    private func eventInner(type: UInt16, payload: Data = Data()) -> Data {
        var inner = Data([
            WearablePacketType.event.rawValue,
            7,
            UInt8(type & 0xFF),
            UInt8((type >> 8) & 0xFF)
        ])
        inner.append(littleEndianUInt32(1_735_689_600))
        inner.append(contentsOf: [0, 0, 0, 0])
        inner.append(payload)
        return inner
    }
}

private extension Data {
    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
