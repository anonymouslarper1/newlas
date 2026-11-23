import CoreMedia
import ImageIO
import QuartzCore
import ReplayKit

/// Runs while the user's screen broadcast is on. Reads each sampled frame with on-device OCR,
/// detects Spark offer cards, scores them against the user's rules and alerts instantly.
/// It never taps or accepts anything — the driver always makes the final decision.
final class SampleHandler: RPBroadcastSampleHandler {
    private let lock = NSLock()
    private var busy = false
    private var lastRun: CFTimeInterval = 0
    private var lastHeartbeat: CFTimeInterval = 0

    private var rules = SharedStore.loadRules()
    private var rulesLoadedAt: CFTimeInterval = 0

    private var lastSignature = ""
    private var lastOfferSeen: CFTimeInterval = 0

    /// ~4 reads per second: fast enough to catch an offer immediately, light enough for the 50 MB extension limit.
    private let interval: CFTimeInterval = 0.25

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        SharedStore.setMonitor(active: true)
        Notifier.postInfo("Spark Intelligence is on", "Open Spark — offers will be checked against your rules.")
    }

    override func broadcastFinished() {
        SharedStore.setMonitor(active: false)
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        let now = CACurrentMediaTime()

        lock.lock()
        if busy || now - lastRun < interval { lock.unlock(); return }
        busy = true
        lastRun = now
        lock.unlock()
        defer { lock.lock(); busy = false; lock.unlock() }

        if now - lastHeartbeat > 2 { SharedStore.heartbeat(); lastHeartbeat = now }
        if now - rulesLoadedAt > 1.5 { rules = SharedStore.loadRules(); rulesLoadedAt = now }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var orientation = CGImagePropertyOrientation.up
        if let o = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber,
           let parsed = CGImagePropertyOrientation(rawValue: o.uint32Value) {
            orientation = parsed
        }

        autoreleasepool {
            let lines = TextRecognizer.lines(pixelBuffer: pixelBuffer, orientation: orientation,
                                             accurate: rules.highAccuracyReading)
            handle(lines: lines, now: now)
        }
    }

    private func handle(lines: [String], now: CFTimeInterval) {
        guard let offer = OfferParser.parse(lines: lines) else {
            // Offer left the screen; allow the same offer to alert again if it comes back later.
            if now - lastOfferSeen > 3 { lastSignature = "" }
            return
        }
        lastOfferSeen = now
        guard offer.signature != lastSignature else { return }
        lastSignature = offer.signature

        let evaluation = RulesEngine.evaluate(offer, rules: rules)
        if evaluation.isMatch || rules.notifyOnReject { Notifier.post(evaluation) }
        SharedStore.appendHistory(evaluation)
    }
}
