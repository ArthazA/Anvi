import SwiftUI
import UIKit

struct CanvasGestureBridge: UIViewRepresentable {
    let onPan: (CanvasGestureUpdate) -> Void
    let onPinch: (CanvasGestureUpdate) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPan: onPan, onPinch: onPinch)
    }

    func makeUIView(context: Context) -> UIView {
        let view = GestureCaptureView(frame: .zero)
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = true

        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        pan.delegate = context.coordinator
        pan.cancelsTouchesInView = false
        view.addGestureRecognizer(pan)
        view.onAttachedToSuperview = { [weak coordinator = context.coordinator] host in
            coordinator?.installMultitouchRecognizers(on: host)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onPan = onPan
        context.coordinator.onPinch = onPinch
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.uninstallMultitouchRecognizers()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onPan: (CanvasGestureUpdate) -> Void
        var onPinch: (CanvasGestureUpdate) -> Void
        private weak var multitouchHost: UIView?
        private var twoFingerPan: UIPanGestureRecognizer?
        private var pinch: UIPinchGestureRecognizer?

        init(
            onPan: @escaping (CanvasGestureUpdate) -> Void,
            onPinch: @escaping (CanvasGestureUpdate) -> Void
        ) {
            self.onPan = onPan
            self.onPinch = onPinch
        }

        func installMultitouchRecognizers(on host: UIView) {
            guard multitouchHost !== host else { return }
            uninstallMultitouchRecognizers()

            let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            twoFingerPan.minimumNumberOfTouches = 2
            twoFingerPan.maximumNumberOfTouches = 2
            twoFingerPan.delegate = self
            twoFingerPan.cancelsTouchesInView = false

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinch.delegate = self
            pinch.cancelsTouchesInView = false

            host.addGestureRecognizer(twoFingerPan)
            host.addGestureRecognizer(pinch)
            multitouchHost = host
            self.twoFingerPan = twoFingerPan
            self.pinch = pinch
        }

        func uninstallMultitouchRecognizers() {
            if let twoFingerPan { multitouchHost?.removeGestureRecognizer(twoFingerPan) }
            if let pinch { multitouchHost?.removeGestureRecognizer(pinch) }
            twoFingerPan = nil
            pinch = nil
            multitouchHost = nil
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let translation = recognizer.translation(in: view)
            let velocity = recognizer.velocity(in: view)
            let focalPoint = recognizer.location(in: view)
            let phase = CanvasGesturePhase(recognizer.state)

            onPan(
                CanvasGestureUpdate(
                    translation: CGSize(width: translation.x, height: translation.y),
                    scale: 1,
                    focalPoint: focalPoint,
                    velocity: CGSize(width: velocity.x, height: velocity.y),
                    phase: phase
                )
            )
            if recognizer.state == .changed { recognizer.setTranslation(.zero, in: view) }
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let view = recognizer.view else { return }
            let phase = CanvasGesturePhase(recognizer.state)
            onPinch(
                CanvasGestureUpdate(
                    translation: .zero,
                    scale: recognizer.scale,
                    focalPoint: recognizer.location(in: view),
                    velocity: .zero,
                    phase: phase
                )
            )
            if recognizer.state == .changed { recognizer.scale = 1 }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

private final class GestureCaptureView: UIView {
    var onAttachedToSuperview: ((UIView) -> Void)?

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard let superview else { return }
        onAttachedToSuperview?(superview)
    }
}

private extension CanvasGesturePhase {
    init(_ state: UIGestureRecognizer.State) {
        switch state {
        case .began: self = .began
        case .changed: self = .changed
        case .ended: self = .ended
        default: self = .cancelled
        }
    }
}
