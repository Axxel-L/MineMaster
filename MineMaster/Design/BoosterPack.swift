import SwiftUI

/// Illustration de pack booster scellé, avec bande de déchirure.
///
/// - Authors: Axel L.
struct BoosterPackArt: View {
    let booster: Booster
    var kind: BoosterKind? = nil
    var tearProgress: CGFloat = 0
    var title: String? = nil

    private var tint: Color {
        kind?.tint ?? booster.tint
    }

    private var foilColors: [Color] {
        kind?.foilColors ?? booster.foilColors
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
                CrimpedEdge()
                    .frame(height: 22)
                    .offset(y: -tearProgress * 14)
                    .opacity(1 - tearProgress * 0.3)

                packBody

                CrimpedEdge()
                    .frame(height: 22)
            }
            .frame(width: 252, height: 352)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 1.5)
            }

            TearStrip()
                .padding(.top, 24)
                .offset(y: -tearProgress * 18)
        }
        .frame(width: 260, height: 352)
        .rotationEffect(.degrees(-1.5))
        .shadow(color: tint.opacity(0.35), radius: 28, y: 18)
    }

    private var packBody: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: foilColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            PixelFoil()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            LinearGradient(
                colors: [.white.opacity(0.22), .clear, .black.opacity(0.25)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.softLight)

            VStack(spacing: 0) {
                HStack {
                    Text("MINEMASTER")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1.2)
                    Spacer()
                    Text("SÉRIE 01")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1.2)
                }
                .foregroundStyle(.black.opacity(0.52))
                .padding(.horizontal, 20)
                .padding(.top, 44)

                Spacer(minLength: 8)

                PackMotif(systemImage: kind?.systemImage ?? "cube.fill")
                    .frame(height: 108)

                Text("MINE")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.45), radius: 0, x: 3, y: 3)
                    .shadow(color: .black.opacity(0.25), radius: 0, x: 6, y: 6)
                Text("MASTER")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .tracking(2.2)
                    .foregroundStyle(.black.opacity(0.72))
                    .padding(.top, -4)

                if let kind {
                    HStack(spacing: 5) {
                        Image(systemName: kind.systemImage)
                            .font(.system(size: 9, weight: .black))
                        Text(kind.packLabel)
                            .font(.system(size: 9, weight: .black, design: .rounded))
                            .tracking(1.2)
                    }
                    .foregroundStyle(.black.opacity(0.74))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.42), in: Capsule())
                    .overlay(Capsule().strokeBorder(.black.opacity(0.18), lineWidth: 0.6))
                    .padding(.top, 6)
                    .accessibilityLabel("Type \(kind.displayName)")
                }

                Text((title ?? booster.displayName).uppercased())
                    .font(.system(size: 9, weight: .black, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(.black.opacity(0.52))
                    .padding(.top, 2)

                Spacer(minLength: 8)

                HStack {
                    Text("5 CARTES")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(1.1)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.18), in: Capsule())
                    Spacer()
                    Text("SCELLÉ")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .tracking(1.1)
                }
                .foregroundStyle(.black.opacity(0.58))
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}

/// Bande crantée du haut et du bas du pack.
///
/// - Authors: Axel L.
struct CrimpedEdge: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black.opacity(0.24))
            HStack(spacing: 2) {
                ForEach(0..<38, id: \.self) { _ in
                    Capsule()
                        .fill(Color.white.opacity(0.24))
                        .frame(width: 2, height: 12)
                }
            }
        }
        .overlay {
            Rectangle()
                .strokeBorder(Color.black.opacity(0.28), lineWidth: 1)
        }
        .clipped()
    }
}

/// Ligne de perforation et languette de déchirure.
///
/// - Authors: Axel L.
struct TearStrip: View {
    var body: some View {
        ZStack {
            HStack(spacing: 4) {
                ForEach(0..<22, id: \.self) { _ in
                    Circle()
                        .fill(Color.black.opacity(0.34))
                        .frame(width: 3, height: 3)
                }
            }
            HStack {
                Text("TIRE ICI")
                    .font(.system(size: 8, weight: .black, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(.black.opacity(0.62))
                Image(systemName: "arrow.down")
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.black.opacity(0.62))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.58), in: Capsule())
        }
        .frame(width: 196, height: 20)
    }
}

private struct PackMotif: View {
    var systemImage: String = "cube.fill"

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.13))
                .frame(width: 130, height: 130)

            Image(systemName: systemImage)
                .font(.system(size: 52, weight: .bold))
                .foregroundStyle(.white.opacity(0.88))
                .shadow(color: .black.opacity(0.35), radius: 0, x: 3, y: 3)

            Image(systemName: systemImage == "cube.fill" ? "hammer.fill" : "cube.fill")
                .font(.system(size: 25, weight: .bold))
                .foregroundStyle(.black.opacity(0.62))
                .rotationEffect(.degrees(-28))
                .offset(x: 54, y: -26)

            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white.opacity(0.9))
                .offset(x: -54, y: -32)
        }
    }
}

private struct PixelFoil: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 24
            let columns = Int(size.width / step) + 1
            let rows = Int(size.height / step) + 1
            for column in 0..<columns {
                for row in 0..<rows {
                    let seed = (column &* 92821) ^ (row &* 68917)
                    guard seed % 6 == 0 else { continue }
                    let rect = CGRect(
                        x: CGFloat(column) * step,
                        y: CGFloat(row) * step,
                        width: 3,
                        height: 3
                    )
                    context.fill(Path(rect), with: .color(.white.opacity(0.14)))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Pack scellé à déchirer au doigt.
///
/// - Authors: Axel L.
struct InteractiveBoosterPack: View {
    let booster: Booster
    var kind: BoosterKind? = nil
    var title: String? = nil
    let onOpened: () -> Void

    @State private var tear: CGFloat = 0
    @State private var isOpened = false

    var body: some View {
        VStack(spacing: 18) {
            BoosterPackArt(booster: booster, kind: kind, tearProgress: tear, title: title)
                .scaleEffect(isOpened ? 1.04 : 1)
                .opacity(isOpened ? 0 : 1)
                .contentShape(Rectangle())
                .gesture(tearGesture)
                .accessibilityAction(named: "Déchirer le pack") {
                    open()
                }

            Button {
                open()
            } label: {
                HStack(spacing: 9) {
                    Image(systemName: "scissors")
                    Text("Déchirer le pack")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
            }
            .buttonStyle(.glassProminent)
            .tint(kind?.tint ?? booster.tint)
            .accessibilityHint("Ouvre le pack et révèle les cartes")

            Text("GLISSE LE PACK VERS LE BAS POUR DÉCHIRER")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.0)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var tearGesture: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard value.translation.height > 0 else { return }
                tear = min(1, value.translation.height / 130)
            }
            .onEnded { _ in
                if tear >= 0.32 {
                    open()
                } else {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.8)) {
                        tear = 0
                    }
                }
            }
    }

    private func open() {
        guard !isOpened else { return }
        withAnimation(.spring(response: 0.48, dampingFraction: 0.84)) {
            tear = 1
            isOpened = true
        }
        onOpened()
    }
}

/// Particules de célébration proportionnelles à la rareté.
///
/// - Authors: Axel L.
struct ParticleBurst: View {
    let rarity: Rarity

    @State private var start = Date()
    private let particles: [CelebrationParticle]
    private let duration: Double = 1.5

    init(rarity: Rarity) {
        self.rarity = rarity
        particles = CelebrationParticle.make(for: rarity)
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                guard elapsed < duration else { return }
                let center = CGPoint(x: size.width / 2, y: size.height * 0.46)
                for particle in particles {
                    let local = max(0, elapsed - particle.delay)
                    guard local > 0 else { continue }
                    let distance = particle.speed * local
                    let fade = max(0, 1 - local / (duration - particle.delay))
                    let point = CGPoint(
                        x: center.x + cos(particle.angle) * distance,
                        y: center.y + sin(particle.angle) * distance + 24 * local * local
                    )
                    let side = particle.size * (0.5 + fade)
                    let rect = CGRect(
                        x: point.x - side / 2,
                        y: point.y - side / 2,
                        width: side,
                        height: side
                    )
                    context.fill(
                        Path(rect),
                        with: .color(particle.color.opacity(fade))
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CelebrationParticle: Sendable {
    let angle: Double
    let speed: Double
    let size: Double
    let delay: Double
    let color: Color

    static func make(for rarity: Rarity) -> [CelebrationParticle] {
        let count: Int
        switch rarity {
        case .common, .uncommon: count = 0
        case .rare: count = 18
        case .epic: count = 34
        case .legendary: count = 56
        }
        guard count > 0 else { return [] }
        return (0..<count).map { index in
            let seed = UInt64(index + 1) &* 0x9E37_79B9_7F4A_7C15
            let angle = Double(seed % 360) * .pi / 180
            let speed = 55 + Double((seed >> 8) % 110)
            let size = 3 + Double((seed >> 16) % 6)
            let delay = Double((seed >> 24) % 18) / 100
            let palette = [rarity.color, Theme.accent, Color.white]
            let color = palette[Int((seed >> 32) % UInt64(palette.count))]
            return CelebrationParticle(
                angle: angle,
                speed: speed,
                size: size,
                delay: delay,
                color: color
            )
        }
    }
}
