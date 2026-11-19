import SwiftUI

/// Profil : passeport de collection, raretés et réglages.
///
/// - Authors: Axel L.
struct ProfileView: View {
    @Environment(GameStore.self) private var store

    @State private var showLegal = false
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView {
                    VStack(spacing: Theme.spaceM) {
                        header
                        passport
                        rarityLedger
                        settings
                    }
                    .padding(.horizontal, Theme.spaceM)
                    .padding(.top, Theme.spaceM)
                    .padding(.bottom, 170)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showLegal) {
                LegalView()
            }
            .confirmationDialog(
                "Réinitialiser la collection ?",
                isPresented: $confirmReset,
                titleVisibility: .visible
            ) {
                Button("Tout effacer", role: .destructive) {
                    store.reset()
                }
            } message: {
                Text("Toute la progression et la poussière seront perdues. Cette action est irréversible.")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PASSEPORT")
                    .font(Theme.mono(9, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(Theme.textSecondary)
                Text("Explorateur")
                    .font(Theme.display(34, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                Text("Collectionneur de blocs, de bêtes et de reliques.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            PixelAvatar()
        }
    }

    private var passport: some View {
        HStack(spacing: Theme.spaceL) {
            ZStack {
                Circle()
                    .stroke(Theme.surfaceRaised, lineWidth: 9)
                Circle()
                    .trim(from: 0, to: store.progress)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: store.progress)
                VStack(spacing: 1) {
                    Text("\(Int(store.progress * 100))")
                        .font(Theme.display(25, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                    Text("%")
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 104, height: 104)

            VStack(alignment: .leading, spacing: 12) {
                passportStat("Items uniques", "\(store.uniqueCount) / \(store.catalog.count)")
                passportStat("Ouvertures", "\(store.totalOpened)")
                passportStat("Poussière", "\(store.dust)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Theme.spaceM)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        }
    }

    private func passportStat(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(Theme.mono(8, weight: .bold))
                .tracking(1.0)
                .foregroundStyle(Theme.textSecondary)
            Spacer(minLength: 8)
            Text(value)
                .font(Theme.mono(12, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
        }
    }

    private var rarityLedger: some View {
        VStack(alignment: .leading, spacing: Theme.spaceM) {
            HStack {
                Text("RARETÉS")
                    .font(Theme.mono(9, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("POSSÉDÉ / TOTAL")
                    .font(Theme.mono(8, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.textSecondary.opacity(0.7))
            }

            ForEach(Rarity.allCases) { rarity in
                let total = store.catalog.filter { $0.rarity == rarity }.count
                let owned = store.catalog.filter {
                    $0.rarity == rarity && store.ownedCount(for: $0) > 0
                }.count
                HStack(spacing: 10) {
                    Circle()
                        .fill(rarity.color)
                        .frame(width: 7, height: 7)
                    Text(rarity.displayName)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: 104, alignment: .leading)
                    ProgressView(value: total == 0 ? 0 : Double(owned) / Double(total))
                        .tint(rarity.color)
                    Text("\(owned)/\(total)")
                        .font(Theme.mono(9, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 48, alignment: .trailing)
                }
            }
        }
        .padding(Theme.spaceM)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        }
    }

    private var settings: some View {
        VStack(spacing: 0) {
            settingsRow(title: "Mentions légales et licences", icon: "doc.text.fill") {
                showLegal = true
            }
            divider
            settingsRow(title: "Réinitialiser la collection", icon: "trash.fill", isDestructive: true) {
                confirmReset = true
            }
            divider
            HStack {
                Image(systemName: "info.circle.fill")
                    .frame(width: 24)
                    .foregroundStyle(Theme.textSecondary)
                Text("Version")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    .font(Theme.mono(11, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.stroke)
            .frame(height: 0.5)
            .padding(.leading, 48)
    }

    private func settingsRow(
        title: String,
        icon: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundStyle(isDestructive ? .red : Theme.textSecondary)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(isDestructive ? .red : Theme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct PixelAvatar: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Theme.surfaceRaised)
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(8), spacing: 4), count: 4), spacing: 4) {
                ForEach(0..<16, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(index % 5 == 0 ? Theme.accent : Theme.textSecondary.opacity(0.35))
                        .frame(width: 8, height: 8)
                }
            }
        }
        .frame(width: 62, height: 62)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        }
        .accessibilityHidden(true)
    }
}

struct LegalView: View {
    @Environment(\.dismiss) private var dismiss

    private let dependencies: [LegalDependency] = [
        LegalDependency(
            name: "MineMaster",
            version: "1.0",
            role: "Application",
            license: "Projet pédagogique non commercial",
            icon: "mojang",
            tint: Theme.accent
        ),
        LegalDependency(
            name: "Swift",
            version: "6.0",
            role: "Langage",
            license: "Apache License 2.0 · Apple",
            icon: "swift",
            tint: Theme.copper
        ),
        LegalDependency(
            name: "SwiftUI · SwiftData · Foundation",
            version: "iOS 26 SDK",
            role: "Frameworks système",
            license: "Apple SDK · Apple",
            icon: "apple",
            tint: Theme.textSecondary
        ),
        LegalDependency(
            name: "Heroicons",
            version: "2.2.0",
            role: "Icônes SVG",
            license: "MIT · Tailwind Labs",
            icon: "heroicons",
            tint: Theme.moss
        ),
        LegalDependency(
            name: "Tailwind CSS",
            version: "3.x",
            role: "Source des icônes Heroicons",
            license: "MIT · Tailwind Labs",
            icon: "tailwindcss",
            tint: Color(red: 0.23, green: 0.76, blue: 0.85)
        ),
        LegalDependency(
            name: "minecraft-data",
            version: "1.21.4",
            role: "Métadonnées d'items",
            license: "MIT · PrismarineJS",
            icon: "prismarine",
            tint: Rarity.rare.color
        ),
        LegalDependency(
            name: "minecraft-assets",
            version: "1.21.4",
            role: "Textures chargées depuis le CDN",
            license: "Assets Mojang · InventivetalentDev",
            icon: "mojang",
            tint: Theme.accent
        ),
        LegalDependency(
            name: "Mojang Studios",
            version: "1.21.4",
            role: "Marques et textures Minecraft",
            license: "Mojang · Microsoft",
            icon: "mojang",
            tint: Theme.accent
        ),
        LegalDependency(
            name: "SF Symbols",
            version: "iOS 26",
            role: "Icônes système",
            license: "Apple",
            icon: "apple",
            tint: Theme.textSecondary
        )
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spaceL) {
                        masthead
                        dependenciesSection
                        notice
                    }
                    .padding(Theme.spaceM)
                    .padding(.bottom, Theme.spaceL)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Licences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var masthead: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CRÉDITS & OPEN SOURCE")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.3)
                .foregroundStyle(Theme.textSecondary)
            Text("Sous le capot")
                .font(Theme.display(30, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
            Text("MineMaster est un projet pédagogique non commercial, non affilié à Mojang Studios ni à Microsoft. Aucune bibliothèque tierce n'est liée au binaire.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dependenciesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DÉPENDANCES & VERSIONS")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)

            VStack(spacing: 0) {
                ForEach(Array(dependencies.enumerated()), id: \.element.id) { index, dependency in
                    row(dependency)
                    if index < dependencies.count - 1 {
                        Rectangle()
                            .fill(Theme.stroke)
                            .frame(height: 0.5)
                            .padding(.leading, 60)
                    }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 0.6)
            }
        }
    }

    private func row(_ dependency: LegalDependency) -> some View {
        HStack(spacing: 12) {
            BrandIcon(name: dependency.icon, tint: dependency.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(dependency.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(dependency.role)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
                Text(dependency.license)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary.opacity(0.76))
            }

            Spacer(minLength: 8)

            Text(dependency.version)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(dependency.tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(dependency.tint.opacity(0.10), in: Capsule())
        }
        .padding(12)
        .accessibilityElement(children: .combine)
    }

    private var notice: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MENTIONS")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(Theme.textSecondary)
            Text("Minecraft, les noms d'items et les textures associées appartiennent à Mojang Studios et Microsoft. Les textures sont chargées à l'exécution depuis un CDN public et ne sont pas redistribuées dans l'application. Heroicons est distribué sous licence MIT par Tailwind Labs. Les icônes Apple et SF Symbols sont fournies par le SDK Apple. Aucune donnée personnelle n'est collectée.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.spaceM)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusM, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        }
    }
}

private struct LegalDependency: Identifiable {
    let id = UUID()
    let name: String
    let version: String
    let role: String
    let license: String
    let icon: String
    let tint: Color
}

private struct BrandIcon: View {
    let name: String
    let tint: Color

    var body: some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 22)
            .foregroundStyle(tint)
            .frame(width: 40, height: 40)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
