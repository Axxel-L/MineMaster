import SwiftUI

/// Présentation « spécimen » d'une créature, à partir de sa texture 2D.
struct MobSpecimen: View {
    let item: CatalogItem
    var size: CGFloat = 220

    @State private var tilt: CGSize = .zero

    var body: some View {
        ZStack {
            Ellipse()
                .fill(.black.opacity(0.42))
                .frame(width: size * 0.68, height: size * 0.16)
                .blur(radius: 10)
                .offset(y: size * 0.37)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [item.rarity.color.opacity(0.24), .clear],
                        center: .center,
                        startRadius: 4,
                        endRadius: size * 0.52
                    )
                )
                .frame(width: size, height: size)

            Circle()
                .strokeBorder(item.rarity.color.opacity(0.28), lineWidth: 1)
                .frame(width: size * 0.82, height: size * 0.82)

            ItemImageView(item: item, size: size * 0.86)
                .rotation3DEffect(
                    .degrees(Double(tilt.width) / 9),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.45
                )
                .rotation3DEffect(
                    .degrees(Double(-tilt.height) / 11),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.45
                )
                .shadow(color: item.rarity.color.opacity(0.35), radius: 20)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            tilt = value.translation
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                                tilt = .zero
                            }
                        }
                )
        }
        .frame(width: size, height: size)
        .accessibilityLabel(item.displayName)
        .accessibilityHint("Fais glisser pour incliner le spécimen")
    }
}
