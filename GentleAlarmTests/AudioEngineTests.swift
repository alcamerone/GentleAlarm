//
//  AudioEngineTests.swift
//  GentleAlarmTests
//

import AVFoundation
import Testing
@testable import GentleAlarm

// Session-mode tests mutate AVAudioSession.sharedInstance() — a process-level singleton
// (one shared instance for the entire test process) — so they must not run in parallel
// with each other. Without serialisation, concurrent configureSession() calls from
// different AudioEngine instances would race and flip sessionIsExclusive unexpectedly.
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
    // The tests below use engine.sessionIsExclusive (an internal flag updated
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

    @Test func testStopAlarmClearsActiveAlarmParamsSoInterruptionResumesHeartbeat() {
        let engine = AudioEngine()
        engine.startAlarm(soundName: "", rampDurationSeconds: 0, vibrate: false)
        engine.stopAlarm()
        // After stopAlarm, activeAlarmParams must be nil. An interruption-ended
        // notification should therefore take the heartbeat path (mixing mode),
        // not resume the alarm (exclusive mode).
        let userInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
        ]
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: userInfo
        )
        #expect(!engine.sessionIsExclusive)
        engine.stopHeartbeat()
    }

    // MARK: - Heartbeat engine state

    @Test func testStartHeartbeatRunsEngine() {
        let engine = AudioEngine()
        engine.startHeartbeat()
        #expect(engine.isRunning)
        engine.stopHeartbeat()
    }

    @Test func testStopHeartbeatStopsEngine() {
        let engine = AudioEngine()
        engine.startHeartbeat()
        engine.stopHeartbeat()
        #expect(!engine.isRunning)
    }

    @Test func testStopHeartbeatWhenAlreadyStoppedDoesNotCrash() {
        let engine = AudioEngine()
        engine.stopHeartbeat()  // must not crash on a never-started engine
        #expect(!engine.isRunning)
    }

    @Test func testStartHeartbeatDoesNotSetExclusiveMode() {
        let engine = AudioEngine()
        engine.startHeartbeat()
        #expect(!engine.sessionIsExclusive)
        engine.stopHeartbeat()
    }

    // MARK: - Notification-driven resilience paths

    @Test func testMediaServerResetLeavesEngineInMixingMode() {
        let engine = AudioEngine()
        // Drive into exclusive mode first.
        engine.startAlarm(soundName: "", rampDurationSeconds: 0, vibrate: false)
        #expect(engine.sessionIsExclusive)

        // Simulate a media server reset; the observer calls configureSession() (mixing)
        // then startHeartbeat(), leaving sessionIsExclusive = false and engine running.
        NotificationCenter.default.post(
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance()
        )

        #expect(!engine.sessionIsExclusive)
        #expect(engine.isRunning)
        engine.stopHeartbeat()
    }

    @Test func testInterruptionEndedRestoresAlarmWhenAlarmWasPlaying() {
        let engine = AudioEngine()
        // Drive into exclusive mode first (alarm playing).
        engine.startAlarm(soundName: "", rampDurationSeconds: 0, vibrate: false)
        #expect(engine.sessionIsExclusive)

        // Simulate interruption ended while alarm was playing; the handler should
        // resume the alarm (not just the heartbeat), keeping the session exclusive.
        let userInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
        ]
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: userInfo
        )

        #expect(engine.sessionIsExclusive)
        engine.stopAlarm()
    }

    @Test func testInterruptionEndedRestoresMixingModeWhenNoAlarmWasPlaying() {
        let engine = AudioEngine()
        // Heartbeat only — no alarm playing. Interruption ended should restore mixing mode.
        engine.startHeartbeat()
        #expect(!engine.sessionIsExclusive)

        let userInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue,
            AVAudioSessionInterruptionOptionKey: AVAudioSession.InterruptionOptions.shouldResume.rawValue
        ]
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: userInfo
        )

        #expect(!engine.sessionIsExclusive)
        engine.stopHeartbeat()
    }

    @Test func testInterruptionEndedWithoutShouldResumeIsIgnored() {
        let engine = AudioEngine()
        engine.startHeartbeat()
        // Post .ended without shouldResume — handler must not restart audio.
        let userInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.ended.rawValue
        ]
        NotificationCenter.default.post(
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: userInfo
        )
        // Engine was running before the notification — state must be unchanged.
        #expect(!engine.sessionIsExclusive)
        engine.stopHeartbeat()
    }

    @Test func testInterruptionBeganDoesNotChangeSessionMode() {
        let engine = AudioEngine()
        engine.startHeartbeat()
        #expect(!engine.sessionIsExclusive)

        // .began is a no-op in the handler — must not flip session mode.
        let userInfo: [AnyHashable: Any] = [
            AVAudioSessionInterruptionTypeKey: AVAudioSession.InterruptionType.began.rawValue
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
        // Handler restarts heartbeat when engine was stopped — verify it is running.
        #expect(engine.isRunning)
        engine.stopHeartbeat()
    }

    @Test func testRouteChangeNewDeviceAvailableIsIgnored() {
        let engine = AudioEngine()
        engine.stopHeartbeat()  // engine stopped

        let userInfo: [AnyHashable: Any] = [
            AVAudioSessionRouteChangeReasonKey: AVAudioSession.RouteChangeReason.newDeviceAvailable.rawValue
        ]
        NotificationCenter.default.post(
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            userInfo: userInfo
        )
        // Only .oldDeviceUnavailable triggers a restart — engine must remain stopped.
        #expect(!engine.isRunning)
    }

    @Test func testStartAlarmSetsExclusiveModeEvenIfEngineAlreadyRunning() {
        let engine = AudioEngine()
        engine.startHeartbeat()
        #expect(!engine.sessionIsExclusive)
        // Engine is already running; startAlarm must still switch to exclusive mode.
        engine.startAlarm(soundName: "", rampDurationSeconds: 0, vibrate: false)
        #expect(engine.sessionIsExclusive)
        engine.stopAlarm()
    }

    // MARK: - Stability / no-crash guarantees

    @Test func testStartHeartbeatIdempotent() {
        let engine = AudioEngine()
        engine.startHeartbeat()
        engine.startHeartbeat()  // must not crash or stack buffers
        #expect(engine.isRunning)
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
