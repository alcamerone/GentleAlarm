//
//  AudioEngine.swift
//  GentleAlarm
//

import AudioToolbox
import AVFoundation

/// Manages two responsibilities:
///  1. A silent looping heartbeat that keeps the app process alive in the background.
///  2. Alarm playback with a configurable volume ramp and optional vibration.
final class AudioEngine {

    // MARK: - Engine / nodes

    private let engine = AVAudioEngine()
    private let heartbeatNode = AVAudioPlayerNode()
    private let alarmNode     = AVAudioPlayerNode()

    // MARK: - Ramp state

    private var rampTimer: DispatchSourceTimer?
    private var vibrationTimer: DispatchSourceTimer?

    // MARK: - Testability

    /// True while the session is in exclusive (non-mixing) mode. Exposed for unit tests only.
    private(set) var sessionIsExclusive: Bool = false

    // MARK: - Notification observers

    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var mediaServerResetObserver: NSObjectProtocol?

    // MARK: - Init

    init() {
        configureSession()
        buildGraph()
        registerNotificationObservers()
    }

    deinit {
        [interruptionObserver, routeChangeObserver, mediaServerResetObserver]
            .compactMap { $0 }
            .forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Session

    private func configureSession(exclusive: Bool = false) {
        let session = AVAudioSession.sharedInstance()
        do {
            // During heartbeat-only mode, mix with others so YouTube and other audio
            // apps never trigger an interruption. An interruption stops AVAudioEngine,
            // causing the app to lose background audio protection and get jetsam-killed.
            // Exclusive mode is only needed when the alarm is actively firing — at that
            // point we want to interrupt other audio so the user clearly hears the alarm.
            let options: AVAudioSession.CategoryOptions = exclusive ? [] : [.mixWithOthers]
            try session.setCategory(.playback, options: options)
            try session.setActive(true)
            sessionIsExclusive = exclusive
        } catch {
            print("AudioEngine: session setup failed: \(error)")
        }
    }

    // MARK: - Graph

    private func buildGraph() {
        engine.attach(heartbeatNode)
        engine.attach(alarmNode)

        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(heartbeatNode, to: engine.mainMixerNode, format: format)
        engine.connect(alarmNode, to: engine.mainMixerNode, format: format)

        // Near-silent, not literally 0 — AVAudioEngine may optimise a true-zero
        // mixer volume away, which would kill background execution.
        engine.mainMixerNode.outputVolume = 0.0001
    }

    // MARK: - Heartbeat

    /// Start playing a silent loop. Call this once at launch (or when backgrounding).
    func startHeartbeat() {
        guard !engine.isRunning else { return }

        do {
            // Stop the node before scheduling to avoid stacking looping buffers
            // across multiple startHeartbeat() calls (e.g. after interruption cycles).
            heartbeatNode.stop()
            try engine.start()
            scheduleHeartbeatBuffer()
            heartbeatNode.play()
            print("AudioEngine: heartbeat started")
        } catch {
            print("AudioEngine: engine start failed: \(error)")
        }
    }

    private func scheduleHeartbeatBuffer() {
        // Use the node's actual output format so the channel count matches the connection.
        let format = heartbeatNode.outputFormat(forBus: 0)
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * 5)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            preconditionFailure("AVAudioPCMBuffer init failed for silent heartbeat buffer")
        }
        buffer.frameLength = frameCount
        // All PCM samples default to 0.0 — truly silent.
        heartbeatNode.scheduleBuffer(buffer, at: nil, options: .loops)
    }

    /// Stop the heartbeat (call when foregrounding, if desired).
    func stopHeartbeat() {
        heartbeatNode.stop()
        engine.stop()
    }

    // MARK: - Alarm playback

    /// Begin playing `alarm.soundName` with a volume ramp over `alarm.rampDurationSeconds`.
    func startAlarm(soundName: String, rampDurationSeconds: Int, vibrate: Bool) {
        // Switch to exclusive mode so the alarm interrupts YouTube / other audio.
        configureSession(exclusive: true)
        if !engine.isRunning { startHeartbeat() }

        // Restore full mixer volume for audible playback.
        engine.mainMixerNode.outputVolume = 1.0

        loadAndPlayAlarmSound(named: soundName)
        startRamp(durationSeconds: rampDurationSeconds)

        if vibrate {
            startVibration()
        }
    }

    private func loadAndPlayAlarmSound(named soundName: String) {
        guard
            let url = Bundle.main.url(forResource: soundName, withExtension: "caf")
        else {
            print("AudioEngine: sound file '\(soundName).caf' not found in bundle")
            return
        }

        do {
            let file = try AVAudioFile(forReading: url)
            alarmNode.volume = 0
            alarmNode.scheduleFile(file, at: nil, completionHandler: nil)

            // Re-schedule on loop by observing completion.
            scheduleLoopingFile(url: url)

            if !alarmNode.isPlaying { alarmNode.play() }
        } catch {
            print("AudioEngine: failed to load alarm sound: \(error)")
        }
    }

    /// AVAudioPlayerNode doesn't have a native looping option for files,
    /// so we re-schedule the file from its completion handler.
    private func scheduleLoopingFile(url: URL) {
        guard let file = try? AVAudioFile(forReading: url) else { return }
        alarmNode.scheduleFile(file, at: nil) { [weak self] in
            guard let self, self.alarmNode.isPlaying else { return }
            self.scheduleLoopingFile(url: url)
        }
    }

    private func startRamp(durationSeconds: Int) {
        rampTimer?.cancel()

        let step = Float(1.0) / Float(max(durationSeconds, 1) * 50) // 50 ticks/second
        let queue = DispatchQueue.global(qos: .userInteractive)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(20))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let next = min(self.alarmNode.volume + step, 1.0)
            self.alarmNode.volume = next
            if next >= 1.0 {
                self.rampTimer?.cancel()
                self.rampTimer = nil
            }
        }
        timer.resume()
        rampTimer = timer
    }

    // MARK: - Vibration

    private func startVibration() {
        vibrationTimer?.cancel()

        let queue = DispatchQueue.global(qos: .userInteractive)
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .seconds(2))
        timer.setEventHandler {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        }
        timer.resume()
        vibrationTimer = timer
    }

    // MARK: - Audio session resilience

    private func registerNotificationObservers() {
        let session = AVAudioSession.sharedInstance()

        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session, queue: nil
        ) { [weak self] notification in self?.handleInterruption(notification: notification) }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session, queue: nil
        ) { [weak self] notification in self?.handleRouteChange(notification: notification) }

        mediaServerResetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: session, queue: nil
        ) { [weak self] _ in self?.handleMediaServerReset() }
    }

    private func handleInterruption(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else { return }

        switch type {
        case .began:
            // AVAudioEngine stops itself on interruption; nothing to do.
            print("AudioEngine: audio session interrupted — heartbeat paused")
        case .ended:
            // With .mixWithOthers, most interruptions (YouTube etc.) never reach this path.
            // This handles edge cases like phone calls or Siri that interrupt even mixing sessions.
            print("AudioEngine: interruption ended — restarting heartbeat")
            configureSession()  // defaults to mixing mode
            startHeartbeat()
        @unknown default:
            break
        }
    }

    private func handleRouteChange(notification: Notification) {
        guard
            let userInfo = notification.userInfo,
            let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
            AVAudioSession.RouteChangeReason(rawValue: reasonValue) == .oldDeviceUnavailable
        else { return }

        if !engine.isRunning {
            print("AudioEngine: audio route changed (device unavailable) — restarting heartbeat")
            startHeartbeat()
        }
    }

    private func handleMediaServerReset() {
        // All AVAudio* objects are invalid after a media server crash. Rebuild from scratch.
        print("AudioEngine: media server reset — rebuilding audio graph and restarting heartbeat")
        rampTimer?.cancel()
        rampTimer = nil
        vibrationTimer?.cancel()
        vibrationTimer = nil
        configureSession()
        buildGraph()
        startHeartbeat()
    }

    // MARK: - Stop

    /// Stop alarm playback and vibration. Heartbeat continues running.
    func stopAlarm() {
        rampTimer?.cancel()
        rampTimer = nil

        vibrationTimer?.cancel()
        vibrationTimer = nil

        alarmNode.stop()

        // Drop mixer volume back to near-silent for the heartbeat.
        engine.mainMixerNode.outputVolume = 0.0001

        // Return to mixing mode so the heartbeat won't interrupt other audio
        // while waiting for the next alarm.
        configureSession(exclusive: false)
    }
}
