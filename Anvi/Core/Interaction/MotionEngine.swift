import Combine
import QuartzCore

@MainActor
final class MotionEngine: ObservableObject {
    private var displayLink: CADisplayLink?
    private var velocity: CGVector = .zero
    private var retention: CGFloat = 0.96
    private var stopSpeed: CGFloat = 8
    private var lastTimestamp: CFTimeInterval?
    private var onStep: ((CGVector) -> Void)?
    private var onFinished: (() -> Void)?

    var isRunning: Bool { displayLink != nil }

    func start(
        velocity: CGVector,
        retention: CGFloat,
        stopSpeed: CGFloat,
        onStep: @escaping (CGVector) -> Void,
        onFinished: @escaping () -> Void = {}
    ) {
        stop(callCompletion: false)
        guard hypot(velocity.dx, velocity.dy) > stopSpeed else {
            onFinished()
            return
        }

        self.velocity = velocity
        self.retention = retention
        self.stopSpeed = stopSpeed
        self.onStep = onStep
        self.onFinished = onFinished
        lastTimestamp = nil

        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop(callCompletion: Bool = false) {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = nil
        let completion = onFinished
        onStep = nil
        onFinished = nil
        if callCompletion { completion?() }
    }

    @objc private func tick(_ link: CADisplayLink) {
        defer { lastTimestamp = link.timestamp }
        guard let lastTimestamp else { return }

        let rawDelta = link.timestamp - lastTimestamp
        let deltaTime = min(
            max(rawDelta, AnviCustomization.Developer.minimumFrameDuration),
            AnviCustomization.Developer.maximumFrameDuration
        )
        onStep?(CGVector(dx: velocity.dx * deltaTime, dy: velocity.dy * deltaTime))

        let decay = pow(retention, CGFloat(deltaTime * 60))
        velocity.dx *= decay
        velocity.dy *= decay

        if hypot(velocity.dx, velocity.dy) <= stopSpeed {
            stop(callCompletion: true)
        }
    }

    deinit { displayLink?.invalidate() }
}
