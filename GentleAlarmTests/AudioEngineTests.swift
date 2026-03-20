//
//  AudioEngineTests.swift
//  GentleAlarmTests
//

import AVFoundation
import Testing
@testable import GentleAlarm

// Session-mode tests mutate AVAudioSession.sharedInstance() — a process-level singleton —
// so they must not run in parallel with each other.
@Suite(.serialized)
struct AudioEngineTests {

    // MARK: - Session mode after init

    @Test func testSessionMixingAfterInit() {
        let engine = AudioEngine()
        // sessionIsExclusive is updated synchronously by configureSession — it is the
        // reliable observable for session state. Reading AVAudioSession.sharedInstance()
        // directly would be racy: other test suites run in parallel and may create
        // AudioEngine instances whose startAlarm() calls flip the global singleton to
        // exclusive between our configureSession() call and the assertion.
        #expect(!engine.sessionIsExclusive)
    }

    // MARK: - Session mode during alarm
    //
    // The three tests below use engine.sessionIsExclusive (an internal flag updated
    // synchronously inside configureSession) rather than reading AVAudioSession.sharedInstance()
    // for the exclusive/restore assertions.  Reading the singleton directly would be racy:
    // AlarmManagerTests runs in a separate suite and creates its own AudioEngine instances
    // whose inits call configureSession(exclusive: false), potentially overwriting our
    // exclusive state between the startAlarm call and the assertion.

    @Test func testSessionExclusiveAfterStartAlarm() {
        let engine = AudioEngine()
        engine.startAlarm(soundName: "", rampDurationSeconds: 0, vibrate: false)
        #expect(engine.sessionIsExclusive)
        engine.stopAlarm()
    }

    @Test func testSessionMixingRestoredAfterStopAlarm() {
        let engine = AudioEngine()
        engine.startAlarm(soundName: "", rampDurationSeconds: 0, vibrate: false)
        engine.stopAlarm()
        #expect(!engine.sessionIsExclusive)
    }

    // MARK: - Notification-driven resilience paths

    @Test func testMediaServerResetLeavesEngineInMixingMode() {
        let engine = AudioEngine()
        // Drive into exclusive mode first.
        engine.startAlarm(soundName: "", rampDurationSeconds: 0, vibrate: false)
        #expect(engine.sessionIsExclusive)

        // Simulate a media server reset; the observer calls configureSession() (mixing)
        // then startHeartbeat(), leaving sessionIsExclusive = false.
        NotificationCenter.default.post(
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance()
        )

        #expect(!engine.sessionIsExclusive)
        engine.stopHeartbeat()
    }

    @Test func testInterruptionEndedRestoresMixingMode() {
        let engine = AudioEngine()
        // Drive into exclusive mode first.
        engine.startAlarm(soundName: "", rampDurationSeconds: 0, vibrate: false)
        #expect(engine.sessionIsExclusive)

        // Simulate an interruption-ended notification; the handler calls
        // configureSession() (mixing) then startHeartbeat().
        let userInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue
        ]
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: userInfo
        )

        #expect(!engine.sessionIsExclusive)
        engine.stopHeartbeat()
    }

    @Test func testRouteChangeOldDeviceUnavailableDoesNotCrash() {
        let engine = AudioEngine()
        engine.stopHeartbeat()  // ensure engine is stopped before the route change fires

        let userInfo: [AnyHashable: Any] = [
            AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue
        ]
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: userInfo
        )
        // Handler conditionally restarts heartbeat when engine is stopped — must not crash.
        engine.stopHeartbeat()
    }

    // MARK: - Stability / no-crash guarantees

    @Test func testStartHeartbeatIdempotent() {
        let engine = AudioEngine()
        engine.startHeartbeat()
        engine.startHeartbeat()  // must not crash or stack buffers
        engine.stopHeartbeat()
    }

    @Test func testStopHeartbeatWithoutStartDoesNotCrash() {
        let engine = AudioEngine()
        engine.stopHeartbeat()  // must not crash on fresh engine
    }

    @Test func testStopAlarmWithoutStartDoesNotCrash() {
        let engine = AudioEngine()
        engine.stopAlarm()  // must not crash on fresh engine
    }
}
