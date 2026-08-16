import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showStats = false
    @State private var showSaves = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 10) {
            header

            if store.loading || store.game == nil {
                Spacer()
                ProgressView(String(localized: "loading"))
                Spacer()
            } else if let game = store.game {
                gameBar(game)

                ZStack {
                    BoardView(game: game)
                    if game.finished {
                        ConfettiView()
                            .allowsHitTesting(false)
                    }
                }
                // The board is the star: give it the leftover space.
                .layoutPriority(1)

                if game.finished {
                    winBanner(game)
                } else {
                    KeypadView(size: game.puzzle.size)
                    actionsRow
                }

                Spacer(minLength: 0)
                footer
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [store.theme.surface, store.theme.bg, store.theme.bg],
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .tint(store.theme.accent)
        .preferredColorScheme(
            store.themeChoice == "auto" ? nil : (store.theme.isLight ? .light : .dark)
        )
        .onAppear { store.systemIsDark = colorScheme == .dark }
        .onChange(of: colorScheme) { newScheme in
            store.systemIsDark = newScheme == .dark
        }
        .sheet(isPresented: $showStats) { StatsSheet() }
        .sheet(isPresented: $showSaves) { SavesSheet() }
        .sheet(isPresented: $showSettings) { SettingsSheet() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Sudoku")
                .font(.title2.bold())
                .foregroundColor(store.theme.text)
            Spacer()
            iconButton("chart.bar.fill", label: "stats") { showStats = true }
            iconButton("folder.fill", label: "saves", badge: store.saves.count) {
                showSaves = true
            }
            iconButton("gearshape.fill", label: "settings") { showSettings = true }
        }
    }

    private func iconButton(
        _ systemName: String,
        label: String,
        badge: Int = 0,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 22, height: 22)
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text("\(badge)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(3)
                            .background(Circle().fill(store.theme.accent))
                            .offset(x: 10, y: -10)
                    }
                }
        }
        .buttonStyle(.bordered)
        .accessibilityLabel(String(localized: String.LocalizationValue(label)))
    }

    private func gameBar(_ game: GameState) -> some View {
        HStack {
            Label(formatTime(game.elapsedSeconds), systemImage: "timer")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(store.theme.text.opacity(0.75))
            Spacer()
            Text("\(game.puzzle.size)×\(game.puzzle.size) · \(String(localized: String.LocalizationValue(game.puzzle.difficulty.rawValue)))")
                .font(.caption)
                .foregroundColor(store.theme.text.opacity(0.55))
            if game.hintsUsed > 0 {
                Label("\(game.hintsUsed)", systemImage: "lightbulb.fill")
                    .font(.subheadline)
                    .foregroundColor(store.theme.text.opacity(0.75))
            }
        }
        .padding(.horizontal, 2)
    }

    private var actionsRow: some View {
        HStack(spacing: 8) {
            actionButton("pencil", "notes", active: store.notesMode) {
                store.notesMode.toggle()
            }
            actionButton("lightbulb", "hint") { store.hint() }
            actionButton("delete.left", "erase") { store.erase() }
        }
    }

    private func actionButton(
        _ systemName: String,
        _ key: String,
        active: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemName)
                Text(String(localized: String.LocalizationValue(key)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 42)
        }
        .buttonStyle(.bordered)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(active ? store.theme.accent.opacity(0.35) : .clear)
        )
    }

    private func winBanner(_ game: GameState) -> some View {
        VStack(spacing: 10) {
            Text(String(localized: "win"))
                .font(.headline)
                .foregroundColor(store.theme.text)
            HStack(spacing: 14) {
                Label(formatTime(game.elapsedSeconds), systemImage: "timer")
                if game.hintsUsed > 0 {
                    Label("\(game.hintsUsed)", systemImage: "lightbulb.fill")
                }
            }
            .font(.subheadline.monospacedDigit())
            .foregroundColor(store.theme.text.opacity(0.7))
            Button(String(localized: "play_again")) {
                store.newGame()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(store.theme.surface, in: RoundedRectangle(cornerRadius: 12))
        .transition(.scale.combined(with: .opacity))
    }

    private var footer: some View {
        VStack(spacing: 6) {
            Button(String(localized: "new_game")) {
                store.newGame()
            }
            .buttonStyle(.bordered)
            Text("\(String(localized: "credits")) Maxime Nathan Lestage")
                .font(.caption2)
                .foregroundColor(store.theme.text.opacity(0.5))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// All game options live here so the main screen stays focused on the board.
struct SettingsSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(String(localized: "size")) {
                    Picker(String(localized: "size"), selection: sizeBinding) {
                        ForEach(GridSize.allCases) { size in
                            Text("\(size.rawValue)×\(size.rawValue)").tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section(String(localized: "difficulty")) {
                    Picker(String(localized: "difficulty"), selection: difficultyBinding) {
                        Text(String(localized: "easy")).tag(Difficulty.easy)
                        Text(String(localized: "medium")).tag(Difficulty.medium)
                        Text(String(localized: "hard")).tag(Difficulty.hard)
                    }
                    .pickerStyle(.segmented)
                }
                Section(String(localized: "display")) {
                    Picker(String(localized: "display"), selection: displayBinding) {
                        Text(String(localized: "digits")).tag(DisplayMode.digits)
                        Text(String(localized: "colors")).tag(DisplayMode.colors)
                    }
                    .pickerStyle(.segmented)
                }
                Section(String(localized: "background")) {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 38), spacing: 10)],
                        spacing: 10
                    ) {
                        autoSwatch
                        ForEach(AppTheme.all) { theme in
                            swatch(theme)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(String(localized: "settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "close")) { dismiss() }
                }
            }
        }
    }

    private var autoSwatch: some View {
        Button {
            store.themeChoice = "auto"
        } label: {
            Circle()
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: 0x1a1a2e), location: 0.5),
                            .init(color: Color(hex: 0xf2f2f7), location: 0.5),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 32, height: 32)
                .overlay(
                    Text("A")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.85), radius: 2)
                )
                .overlay(selectionRing(active: store.themeChoice == "auto"))
        }
        .buttonStyle(.plain)
    }

    private func swatch(_ theme: AppTheme) -> some View {
        Button {
            store.themeChoice = theme.id
        } label: {
            Circle()
                .fill(theme.bg)
                .frame(width: 32, height: 32)
                .overlay(selectionRing(active: store.themeChoice == theme.id))
        }
        .buttonStyle(.plain)
    }

    private func selectionRing(active: Bool) -> some View {
        Circle().stroke(
            active ? store.theme.accent : store.theme.boxBorder.opacity(0.6),
            lineWidth: active ? 3 : 1.5
        )
    }

    private var displayBinding: Binding<DisplayMode> {
        Binding(get: { store.displayMode }, set: { store.displayMode = $0 })
    }

    private var sizeBinding: Binding<GridSize> {
        Binding(
            get: { store.gridSize },
            set: {
                store.gridSize = $0
                store.newGame()
                dismiss()
            }
        )
    }

    private var difficultyBinding: Binding<Difficulty> {
        Binding(
            get: { store.difficulty },
            set: {
                store.difficulty = $0
                store.newGame()
                dismiss()
            }
        )
    }
}

struct StatsSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    statRow(String(localized: "played"), "\(store.stats.played)")
                    statRow(String(localized: "won"), "\(store.stats.won)")
                    statRow(
                        String(localized: "win_rate"),
                        store.stats.played > 0
                            ? "\(Int((Double(store.stats.won) / Double(store.stats.played) * 100).rounded()))%"
                            : "0%"
                    )
                    statRow(String(localized: "total_time"), formatTime(store.stats.totalSeconds))
                    statRow(String(localized: "hints_used"), "\(store.stats.hints)")
                }
                if !store.stats.best.isEmpty {
                    Section(String(localized: "best")) {
                        ForEach(store.stats.best.keys.sorted(), id: \.self) { key in
                            let secs = store.stats.best[key] ?? 0
                            let parts = key.split(separator: "-")
                            let size = parts.first.map(String.init) ?? "?"
                            let diff = parts.count > 1 ? String(parts[1]) : ""
                            statRow(
                                "\(size)×\(size) · \(String(localized: String.LocalizationValue(diff)))",
                                formatTime(secs)
                            )
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "stats"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "close")) { dismiss() }
                }
            }
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
    }
}

struct SavesSheet: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.saves.isEmpty {
                    Text(String(localized: "no_saves"))
                        .foregroundColor(.secondary)
                } else {
                    List {
                        ForEach(store.saves) { entry in
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    let g = entry.game
                                    Text("\(g.puzzle.size)×\(g.puzzle.size) · \(String(localized: String.LocalizationValue(g.puzzle.difficulty.rawValue)))")
                                        .fontWeight(.semibold)
                                    Text("⏱ \(formatTime(g.elapsedSeconds)) · \(Int((g.progress * 100).rounded()))%")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .monospacedDigit()
                                }
                                Spacer()
                                Button(String(localized: "resume_game")) {
                                    store.resume(entry)
                                    dismiss()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                        .onDelete { indexSet in
                            for i in indexSet {
                                store.deleteSave(store.saves[i])
                            }
                        }
                    }
                }
            }
            .navigationTitle(String(localized: "saves"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "close")) { dismiss() }
                }
            }
        }
    }
}
