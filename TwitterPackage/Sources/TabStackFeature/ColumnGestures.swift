import SwiftUI
import UIKit

/// Motion for gestures that hand off to animation, after Apple's fluid-interface guidance (WWDC18 "Designing Fluid
/// Interfaces"): springs described by response and damping rather than duration, carrying the finger's velocity into
/// the animation, decisions made on where a throw would come to rest rather than where the finger let go, and edges felt
/// as resistance rather than a wall.
enum FluidMotion {
    /// UIScrollView's normal deceleration rate, per millisecond.
    static let decelerationRate: CGFloat = 0.998

    /// Where content moving at `velocity` points per second would come to rest under scroll-view friction, as an
    /// offset from where it is now.
    static func projection(of velocity: CGFloat) -> CGFloat {
        velocity / 1000 * decelerationRate / (1 - decelerationRate)
    }

    /// Movement past an edge, resisted the way a scroll view resists overscroll: it follows the finger less and less,
    /// never passing `dimension`.
    static func rubberBand(_ offset: CGFloat, dimension: CGFloat, constant: CGFloat = 0.55) -> CGFloat {
        guard dimension > 0 else { return 0 }
        let resisted = (1 - 1 / (abs(offset) * constant / dimension + 1)) * dimension
        return offset < 0 ? -resisted : resisted
    }

    /// A spring from `value` to `target` that starts at `velocity` (points per second), so the content doesn't stop
    /// and restart when the finger lets go. Critically damped by default: a spring overshoots only when the gesture gave
    /// it momentum worth showing.
    static func spring(
        from value: CGFloat,
        to target: CGFloat,
        velocity: CGFloat,
        response: Double = 0.35,
        dampingFraction: Double = 1
    ) -> Animation {
        let distance = target - value
        let relativeVelocity = abs(distance) > 0.5 ? velocity / distance : 0
        let stiffness = pow(2 * .pi / response, 2)
        let damping = 4 * .pi * dampingFraction / response
        return .interpolatingSpring(mass: 1, stiffness: stiffness, damping: damping, initialVelocity: relativeVelocity)
    }
}

/// A pan that begins only when the finger heads down, clearly more down than sideways (3:1), from within `region` of
/// its view: so it never competes with the column strip's horizontal slide, with scrolling (which it can't start
/// inside), or with taps on the bar's buttons, which it lets through until the finger has moved.
struct DownwardPanGesture: UIGestureRecognizerRepresentable {
    struct Value {
        var translation: CGFloat
        var velocity: CGFloat
    }

    /// The part of the view a pull can start in, in its coordinates.
    var region: CGFloat
    var onChanged: (Value) -> Void
    var onEnded: (Value) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer = UIPanGestureRecognizer()
        recognizer.delegate = context.coordinator
        recognizer.maximumNumberOfTouches = 1
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        context.coordinator.region = region
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let value = Value(
            translation: recognizer.translation(in: recognizer.view).y,
            velocity: recognizer.velocity(in: recognizer.view).y
        )
        switch recognizer.state {
        case .began, .changed: onChanged(value)
        case .ended, .cancelled, .failed: onEnded(value)
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var region: CGFloat = 0

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            touch.location(in: gestureRecognizer.view).y < region
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let translation = pan.translation(in: pan.view)
            return translation.y > 0 && translation.y >= 3 * abs(translation.x)
        }
    }
}
