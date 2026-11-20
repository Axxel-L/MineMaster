import SwiftUI

/// Profil : collection, titres, raretés et réglages.
struct ProfileView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var showLegal = false
    @State private var showTitles = false
    @State private var showTutorial = false
    @State private var confirmRebirth = false
    @State private var revealed = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView {
                    VStack(spacing: Theme.spaceM) {
                        header
                        passport
                        titleCard
                        rebirthCard
                        categoryChart
                        rarityLedger
                        marketLedger
                        settings
                    }
                    .padding(.horizontal, Theme.spaceM)
                    .padding(.top, Theme.spaceM)
                    .padding(.bottom, 170)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.7), value: revealed)
                    .animation(reduceMotion ? nil : .snappy, value: store.uniqueCount)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                guard !revealed else { return }
                revealed = true
            }
            .sheet(isPresented: $showLegal) {
                LegalView()
            }
            .sheet(isPresented: $showTitles) {
                TitlesView()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Theme.background)
            }
            .sheet(isPresented: $showTutorial) {
                TutorialView {
                    showTutorial = false
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.background)
            }
            .confirmationDialog(
                "Renaître ?",
                isPresented: $confirmRebirth,
                titleVisibility: .visible
            ) {
                Button("Renaître", role: .destructive) {
                    try? store.rebirth()
                }
            } message: {
                Text("La collection et la poussière seront remises à zéro. Tes boosts de renaissance restent acquis.")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Profil")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    Text(store.explorerTitle.displayName)
                        .font(Theme.display(34, weight: .heavy))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .contentTransition(.interpolate)
                    Button {
                        showTitles = true
                    } label: {
                        Image(systemName: "questionmark")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .frame(width: 28, height: 28)
                            .background(Theme.surfaceRaised, in: Circle())
                            .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 0.6))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.textSecondary)
                    .accessibilityLabel("Expliquer les titres")
                }
                Text(store.explorerTitle.subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .contentTransition(.opacity)
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
                    .trim(from: 0, to: revealed ? store.progress : 0)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.9, dampingFraction: 0.85),
                        value: revealed
                    )
                    .animation(
                        reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.8),
                        value: store.progress
                    )
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

    private var titleCard: some View {
        let current = store.explorerTitle
        let next = store.nextExplorerTitle
        let base = current.requiredItems
        let target = next?.requiredItems ?? max(store.catalog.count, base)
        let span = max(target - base, 1)
        let filled = min(max(Double(store.uniqueCount - base) / Double(span), 0), 1)

        return HStack(spacing: 12) {
            Image(systemName: current.systemImage)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(current.tint)
                .frame(width: 42, height: 42)
                .background(current.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Titre")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Text("\(store.uniqueCount) items")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary.opacity(0.7))
                }
                Text(current.displayName)
                    .font(.headline)
                    .foregroundStyle(current.tint)
                if let next {
                    ProgressView(value: revealed ? filled : 0)
                        .tint(current.tint)
                    Text("Plus que \(next.requiredItems - store.uniqueCount) items pour devenir \(next.displayName)")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    Text("Tous les titres sont débloqués.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .padding(Theme.spaceM)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                .strokeBorder(current.tint.opacity(0.28), lineWidth: 0.6)
        }
    }

    private var rebirthCard: some View {
        let boost = store.rebirthBoost
        let progress = Rebirth.progress(uniqueCount: store.uniqueCount)
        let remaining = Rebirth.remaining(uniqueCount: store.uniqueCount)

        return VStack(alignment: .leading, spacing: Theme.spaceM) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.copper)
                    .frame(width: 42, height: 42)
                    .background(Theme.copper.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Renaissance")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text("Niveau \(store.rebirthLevel)")
                        .font(.headline)
                        .foregroundStyle(Theme.textPrimary)
                        .contentTransition(.numericText())
                }
                Spacer()
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 88), spacing: 8)],
                spacing: 8
            ) {
                boostPill("Légendaire", boost.legendaryBonus, tint: Rarity.legendary.color)
                boostPill("Épique", boost.epicBonus, tint: Rarity.epic.color)
                boostPill("Poussière", boost.dustBonus, tint: Theme.accent)
            }

            if store.canRebirth {
                Button {
                    confirmRebirth = true
                } label: {
                    Label("Renaître", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.copper)
            } else {
                ProgressView(value: progress)
                    .tint(Theme.copper)
                Text("Encore \(remaining) items différents pour renaître")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Theme.spaceM)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                .strokeBorder(Theme.copper.opacity(0.28), lineWidth: 0.6)
        }
    }

    private func boostPill(_ title: String, _ bonus: Double, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(Theme.mono(8, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(String(format: "+%.0f %%", bonus * 100))
                .font(Theme.mono(11, weight: .bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: Theme.radiusS, style: .continuous))
    }

    private var categoryChart: some View {
        let stats = categoryStats

        return VStack(alignment: .leading, spacing: Theme.spaceM) {
            HStack {
                Text("Par catégorie")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("Possédés")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.7))
            }

            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                HStack(spacing: 10) {
                    Image(systemName: stat.category.systemImage)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(stat.category.tint)
                        .frame(width: 16)
                    Text(stat.category.displayName)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: 92, alignment: .leading)
                    ProgressView(value: revealed ? stat.fraction : 0)
                        .tint(stat.category.tint)
                        .animation(
                            reduceMotion ? nil : .easeOut(duration: 0.55).delay(Double(index) * 0.045),
                            value: revealed
                        )
                    Text("\(stat.owned)/\(stat.total)")
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

    private var categoryStats: [CategoryStat] {
        var totals: [ItemCategory: Int] = [:]
        var owned: [ItemCategory: Int] = [:]
        for item in store.catalog {
            totals[item.category, default: 0] += 1
            if (store.owned[item.id] ?? 0) > 0 {
                owned[item.category, default: 0] += 1
            }
        }
        return ItemCategory.allCases.map { category in
            let total = totals[category] ?? 0
            let count = owned[category] ?? 0
            return CategoryStat(
                category: category,
                owned: count,
                total: total,
                fraction: total == 0 ? 0 : Double(count) / Double(total)
            )
        }
    }

    private var rarityStats: [RarityStat] {
        var totals: [Rarity: Int] = [:]
        var owned: [Rarity: Int] = [:]
        for item in store.catalog {
            totals[item.rarity, default: 0] += 1
            if (store.owned[item.id] ?? 0) > 0 {
                owned[item.rarity, default: 0] += 1
            }
        }
        return Rarity.allCases.map { rarity in
            let total = totals[rarity] ?? 0
            let count = owned[rarity] ?? 0
            return RarityStat(
                rarity: rarity,
                owned: count,
                total: total,
                fraction: total == 0 ? 0 : Double(count) / Double(total)
            )
        }
    }

    private var rarityLedger: some View {
        let stats = rarityStats

        return VStack(alignment: .leading, spacing: Theme.spaceM) {
            HStack {
                Text("Par rareté")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("Possédés")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.7))
            }

            ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                HStack(spacing: 10) {
                    Circle()
                        .fill(stat.rarity.color)
                        .frame(width: 7, height: 7)
                    Text(stat.rarity.displayName)
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(width: 104, alignment: .leading)
                    ProgressView(value: revealed ? stat.fraction : 0)
                        .tint(stat.rarity.color)
                        .animation(
                            reduceMotion ? nil : .easeOut(duration: 0.55).delay(Double(index) * 0.05),
                            value: revealed
                        )
                    Text("\(stat.owned)/\(stat.total)")
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

    private var marketLedger: some View {
        return VStack(alignment: .leading, spacing: Theme.spaceM) {
            HStack {
                Text("Marché")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                Text("Transactions")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary.opacity(0.7))
            }

            HStack(spacing: 10) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 16)
                Text("Achats")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .frame(width: 92, alignment: .leading)
                Text("\(store.marketPurchases)")
                    .font(Theme.mono(9, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 48, alignment: .trailing)
            }

            HStack(spacing: 10) {
                Image(systemName: "cart.badge.plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.danger)
                    .frame(width: 16)
                Text("Ventes")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .frame(width: 92, alignment: .leading)
                Text("\(store.marketSales)")
                    .font(Theme.mono(9, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .frame(width: 48, alignment: .trailing)
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
            settingsRow(title: "Revoir le tutoriel", icon: "questionmark.circle.fill") {
                showTutorial = true
            }
            divider
            settingsRow(title: "Licences et crédits", icon: "doc.text.fill") {
                showLegal = true
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
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 24)
                    .foregroundStyle(Theme.textSecondary)
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.textPrimary)
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

private struct CategoryStat: Identifiable {
    let category: ItemCategory
    let owned: Int
    let total: Int
    let fraction: Double

    var id: ItemCategory { category }
}

private struct RarityStat: Identifiable {
    let rarity: Rarity
    let owned: Int
    let total: Int
    let fraction: Double

    var id: Rarity { rarity }
}

/// Explication des titres d'explorateur et de leurs seuils.
struct TitlesView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spaceM) {
                        intro
                        titleList
                        note
                    }
                    .padding(Theme.spaceM)
                    .padding(.bottom, Theme.spaceL)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Titres")
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

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Comment ça marche")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("Les titres")
                .font(Theme.display(27, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
            Text("Chaque titre se débloque avec un nombre d'items différents dans ta collection. Les doublons donnent de la poussière, mais ne font pas avancer le titre.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var titleList: some View {
        VStack(spacing: 0) {
            ForEach(Array(ExplorerTitle.allCases.enumerated()), id: \.element.id) { index, title in
                row(title)
                if index < ExplorerTitle.allCases.count - 1 {
                    Rectangle()
                        .fill(Theme.stroke)
                        .frame(height: 0.5)
                        .padding(.leading, 64)
                }
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.radiusL, style: .continuous)
                .strokeBorder(Theme.stroke, lineWidth: 0.6)
        }
    }

    private func row(_ title: ExplorerTitle) -> some View {
        let isCurrent = title == store.explorerTitle
        let isUnlocked = store.uniqueCount >= title.requiredItems
        let tint = isUnlocked ? title.tint : Theme.textSecondary

        return HStack(spacing: 12) {
            Image(systemName: isUnlocked ? title.systemImage : "lock.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isUnlocked ? Theme.textPrimary : Theme.textSecondary)
                Text(title.requiredItems == 0 ? "Dès le premier item" : "\(title.requiredItems) items différents")
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 8)

            if isCurrent {
                Text("Actuel")
                    .font(Theme.mono(8, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.background)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(title.tint, in: Capsule())
            } else if isUnlocked {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(title.tint)
            }
        }
        .padding(12)
        .background(isCurrent ? title.tint.opacity(0.08) : .clear)
        .accessibilityElement(children: .combine)
        .accessibilityValue(isCurrent ? "Titre actuel" : isUnlocked ? "Débloqué" : "Verrouillé")
    }

    private var note: some View {
        Text("Les titres restent enregistrés sur cet appareil.")
            .font(.caption2)
            .foregroundStyle(Theme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
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
            name: "Minecraft Wiki",
            version: "1.21.4",
            role: "Rendus de créatures",
            license: "CC BY-NC-SA 3.0 · Minecraft Wiki",
            icon: "mojang",
            tint: Theme.moss
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
            Text("Crédits")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("Licences")
                .font(Theme.display(30, weight: .heavy))
                .foregroundStyle(Theme.textPrimary)
            Text("MineMaster est un projet étudiant, sans lien avec Mojang ou Microsoft. L'application n'embarque aucune bibliothèque tierce.")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dependenciesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Composants")
                .font(.footnote.weight(.semibold))
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
            Text("Mentions")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("Les noms et textures Minecraft appartiennent à Mojang et Microsoft. Les textures sont chargées depuis un CDN public, jamais copiées dans l'application. Heroicons est sous licence MIT. Aucune donnée personnelle n'est collectée.")
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
