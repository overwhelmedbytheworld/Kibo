import SwiftUI

/// Represents a single emotion spark particle in the burst effect.
public struct EmotionParticle: Identifiable, Sendable {
    public let id = UUID()
    public var x: Double
    public var y: Double
    public var vx: Double
    public var vy: Double
    public var scale: Double
    public var alpha: Double
    public let color: Color
    public let glyph: String?
}

/// A lightweight GPU-accelerated particle burst emitter for emoji emotion graphics.
public struct EmojiParticleBurstEmitter: View {
    @Binding public var triggerCount: Int
    public let originEmoji: String

    @State private var particles: [EmotionParticle] = []
    @State private var lastTriggerCount: Int = 0

    public init(triggerCount: Binding<Int>, originEmoji: String = "✨") {
        self._triggerCount = triggerCount
        self.originEmoji = originEmoji
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for particle in particles {
                    let point = CGPoint(x: particle.x, y: particle.y)
                    context.opacity = particle.alpha

                    if let glyph = particle.glyph {
                        let text = Text(glyph).font(.system(size: 16 * particle.scale))
                        context.draw(text, at: point)
                    } else {
                        let rect = CGRect(
                            x: particle.x - (6 * particle.scale) / 2,
                            y: particle.y - (6 * particle.scale) / 2,
                            width: 6 * particle.scale,
                            height: 6 * particle.scale
                        )
                        context.fill(Path(ellipseIn: rect), with: .color(particle.color))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: triggerCount) { _, newCount in
            if newCount > lastTriggerCount {
                lastTriggerCount = newCount
                spawnBurst()
            }
        }
        .task(id: particles.count) {
            guard !particles.isEmpty else { return }
            while !particles.isEmpty {
                try? await Task.sleep(for: .milliseconds(16)) // ~60fps step
                updateParticles()
            }
        }
    }

    private func spawnBurst() {
        let colors: [Color] = [.orange, .yellow, .pink, .purple, .cyan, .green]
        let sparkles = ["✨", "⭐️", "💥", "❤️", "🔥", "🎉"]

        var newParticles: [EmotionParticle] = []
        for _ in 0..<20 {
            let angle = Double.random(in: 0...(2 * .pi))
            let speed = Double.random(in: 4.0...10.0)
            let vx = cos(angle) * speed
            let vy = sin(angle) * speed - Double.random(in: 2.0...5.0) // upward bias

            let useGlyph = Bool.random()
            let p = EmotionParticle(
                x: 0,
                y: 0,
                vx: vx,
                vy: vy,
                scale: Double.random(in: 0.6...1.4),
                alpha: 1.0,
                color: colors.randomElement() ?? .yellow,
                glyph: useGlyph ? sparkles.randomElement() : nil
            )
            newParticles.append(p)
        }

        self.particles.append(contentsOf: newParticles)
    }

    private func updateParticles() {
        var alive: [EmotionParticle] = []
        for var p in particles {
            p.x += p.vx
            p.y += p.vy
            p.vy += 0.28 // gravity
            p.vx *= 0.94 // drag
            p.alpha -= 0.035 // fade out
            p.scale *= 0.98

            if p.alpha > 0.05 {
                alive.append(p)
            }
        }
        self.particles = alive
    }
}
