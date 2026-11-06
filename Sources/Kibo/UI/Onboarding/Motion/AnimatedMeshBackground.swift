import SwiftUI

/// A 120Hz harmonic animated mesh gradient background for macOS 15+, with graceful fallback.
public struct AnimatedMeshBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        if #available(macOS 15.0, *), !reduceMotion {
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let (points, colors) = computeHarmonicMesh(at: time)

                MeshGradient(
                    width: 3,
                    height: 3,
                    points: points,
                    colors: colors,
                    smoothsColors: true
                )
                .ignoresSafeArea()
            }
        } else {
            // Graceful fallback: deep dark glass gradient
            LinearGradient(
                colors: [
                    Color(nsColor: NSColor(calibratedRed: 0.05, green: 0.06, blue: 0.12, alpha: 1.0)),
                    Color(nsColor: NSColor(calibratedRed: 0.08, green: 0.04, blue: 0.16, alpha: 1.0)),
                    Color(nsColor: NSColor(calibratedRed: 0.02, green: 0.02, blue: 0.04, alpha: 1.0))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    @available(macOS 15.0, *)
    private func computeHarmonicMesh(at time: Double) -> ([SIMD2<Float>], [Color]) {
        // Subtle orbital frequency: ~0.35 rad/sec for liquid elegance
        let speed = 0.35
        let t = time * speed

        // Normalized sinusoidal displacements for internal control points
        let p11_x: Float = Float(0.33 + 0.06 * sin(t * 1.1 + 0.4))
        let p11_y: Float = Float(0.33 + 0.05 * cos(t * 0.9 + 1.2))

        let p21_x: Float = Float(0.66 + 0.05 * cos(t * 1.3 + 2.1))
        let p21_y: Float = Float(0.33 + 0.06 * sin(t * 0.8 + 0.5))

        let p12_x: Float = Float(0.33 + 0.05 * cos(t * 1.0 + 3.4))
        let p12_y: Float = Float(0.66 + 0.05 * sin(t * 1.2 + 1.8))

        let p22_x: Float = Float(0.66 + 0.06 * sin(t * 0.7 + 4.0))
        let p22_y: Float = Float(0.66 + 0.05 * cos(t * 1.4 + 2.7))

        let points: [SIMD2<Float>] = [
            // Row 0
            SIMD2<Float>(0.0, 0.0), SIMD2<Float>(0.5, 0.0), SIMD2<Float>(1.0, 0.0),
            // Row 1
            SIMD2<Float>(0.0, 0.5), SIMD2<Float>(p11_x, p11_y), SIMD2<Float>(p21_x, p21_y),
            // Row 2
            SIMD2<Float>(0.0, 1.0), SIMD2<Float>(p12_x, p12_y), SIMD2<Float>(p22_x, p22_y)
        ]

        // Display P3 vibrant color stops with subtle, non-distracting opacity
        let cBase = Color(.displayP3, red: 0.04, green: 0.05, blue: 0.09, opacity: 0.92)
        let cIndigo = Color(.displayP3, red: 0.16, green: 0.10, blue: 0.38, opacity: 0.55)
        let cCyan = Color(.displayP3, red: 0.00, green: 0.55, blue: 0.75, opacity: 0.40)
        let cViolet = Color(.displayP3, red: 0.38, green: 0.05, blue: 0.60, opacity: 0.45)
        let cRose = Color(.displayP3, red: 0.65, green: 0.10, blue: 0.42, opacity: 0.35)

        let colors: [Color] = [
            cBase,   cIndigo, cBase,
            cViolet, cCyan,   cViolet,
            cBase,   cRose,   cBase
        ]

        return (points, colors)
    }
}
