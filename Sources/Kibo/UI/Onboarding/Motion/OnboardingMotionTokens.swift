import AppKit
import SwiftUI

// MARK: - Mandated Spring Physics Tokens

public extension Animation {
    /// Mandated for step morphs, card expansion, and structural layout transformations.
    /// Settles in ~380ms with zero lingering wobble.
    static let spatialMorph = Animation.interpolatingSpring(mass: 1.0, stiffness: 180, damping: 22)

    /// Mandated for cursor hover states, button presses, and micro-interactions.
    /// Punchy, responsive, and tactile.
    static let tactileSnappy = Animation.snappy(duration: 0.35, extraBounce: 0.08)

    /// Mandated for continuous cursor tracking and real-time hover interpolation.
    static let cursorFollow = Animation.interactiveSpring(response: 0.22, dampingFraction: 0.72)

    /// Mandated for keypress downstroke feedback.
    static let keypressDown = Animation.easeOut(duration: 0.09)
}

// MARK: - Native NSVisualEffectView Wrapper

public struct VisualEffectView: NSViewRepresentable {
    public let material: NSVisualEffectView.Material
    public let blendingMode: NSVisualEffectView.BlendingMode
    public let state: NSVisualEffectView.State

    public init(
        material: NSVisualEffectView.Material = .hudWindow,
        blendingMode: NSVisualEffectView.BlendingMode = .withinWindow,
        state: NSVisualEffectView.State = .active
    ) {
        self.material = material
        self.blendingMode = blendingMode
        self.state = state
    }

    public func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = state
        visualEffectView.isEmphasized = true
        return visualEffectView
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
    }
}

// MARK: - 3D Hover Parallax Modifier

public struct HoverParallaxModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var normalizedOffset: CGPoint = .zero
    @State private var isHovering: Bool = false

    public let maxTiltDegrees: Double
    public let specularBorder: Bool
    public let cornerRadius: CGFloat

    public init(maxTiltDegrees: Double = 5.0, specularBorder: Bool = true, cornerRadius: CGFloat = 16) {
        self.maxTiltDegrees = min(maxTiltDegrees, 6.0) // Strictly clamped to max 6 degrees per HIG
        self.specularBorder = specularBorder
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        GeometryReader { proxy in
            let size = proxy.size

            content
                .overlay {
                    if specularBorder {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        Color.white.opacity(isHovering ? 0.45 : 0.12),
                                        Color.white.opacity(0.04),
                                        Color.clear
                                    ]),
                                    center: UnitPoint(
                                        x: (normalizedOffset.x + 1.0) / 2.0,
                                        y: (normalizedOffset.y + 1.0) / 2.0
                                    ),
                                    startRadius: 0,
                                    endRadius: max(size.width, size.height) * 0.7
                                ),
                                lineWidth: 1.0
                            )
                            .blendMode(.overlay)
                    }
                }
                .rotation3DEffect(
                    .degrees(reduceMotion ? 0 : -normalizedOffset.y * maxTiltDegrees),
                    axis: (x: 1, y: 0, z: 0)
                )
                .rotation3DEffect(
                    .degrees(reduceMotion ? 0 : normalizedOffset.x * maxTiltDegrees),
                    axis: (x: 0, y: 1, z: 0)
                )
                .scaleEffect(isHovering && !reduceMotion ? 1.015 : 1.0)
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        withAnimation(.cursorFollow) {
                            isHovering = true
                            let nx = min(max((location.x - size.width / 2.0) / (size.width / 2.0), -1.0), 1.0)
                            let ny = min(max((location.y - size.height / 2.0) / (size.height / 2.0), -1.0), 1.0)
                            normalizedOffset = CGPoint(x: nx, y: ny)
                        }
                    case .ended:
                        withAnimation(.tactileSnappy) {
                            isHovering = false
                            normalizedOffset = .zero
                        }
                    }
                }
        }
    }
}

public extension View {
    func hoverParallax(maxTiltDegrees: Double = 5.0, specularBorder: Bool = true, cornerRadius: CGFloat = 16) -> some View {
        modifier(HoverParallaxModifier(maxTiltDegrees: maxTiltDegrees, specularBorder: specularBorder, cornerRadius: cornerRadius))
    }
}
