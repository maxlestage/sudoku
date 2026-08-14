import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GameStore
    @State private var showStats = false
    @State private var showSaves = false

    var body: some View {
        VStack(spacing: 12) {
            header
            themeRow
            controls
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
                if game.finished {
                    winBanner(game)
                } else {
                    KeypadView(size: game.puzzle.size)
                    actionsRow
                }
                Spacer(minLength: 0)
                Button(String(localized: "new_game")) {
                    store.newGame()
                }
                .buttonStyle(.bordered)
                Text("\(String(localized: "credits")) Maxime Nathan Lestage")
                    .font(.caption2)
                    .foregroundColor(store.theme.text.opacity(0.55))
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [store.theme.surface, store.theme.bg, store.theme.bg],
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .tint(store.theme.accent)
        .preferredColorScheme(store.theme.isLight ? .light : .dark)
        .sheet(isPresented: $showStats) { StatsSheet() }
        .sheet(isPresented: $showSaves) { SavesSheet() }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Sudoku")
                .font(.title2.bold())
                .foregroundColor(store.theme.text)
            Spacer()
            Button {
                showStats = true
            } label: {
                Image(systemName: "chart.bar.fill")
            }
            .buttonStyle(.bordered)
            Button {
                showSaves = true
            } label: {
                Image(systemName: "folder.fill")
                    .overlay(alignment: .topTrailing) {
                        if !store.saves.isEmpty {
                            Text("\(store.saves.count)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(3)
                                .background(Circle().fill(store.theme.accent))
                                .offset(x: 10, y: -10)
                        }
                    }
            }
            .buttonStyle(.bordered)
        }
    }

    private func gameBar(_ game: GameState) -> some View {
        HStack {
            Label(formatTime(game.elapsedSeconds), systemImage: "timer")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundColor(store.theme.text.opacity(0.7))
            Spacer()
            if game.hintsUsed > 0 {
                Label("\(game.hintsUsed)", systemImage: "lightbulb.fill")
                    .font(.subheadline)
                    .foregroundColor(store.theme.text.opacity(0.7))
            }
        }
        .padding(.horizontal, 4)
    }

    private var actionsRow: some View {
        HStack(spacing: 8) {
            Button {
                store.notesMode.toggle()
            } label: {
                Label(String(localized: "notes"), systemImage: "pencil")
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.bordered)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(store.notesMode ? store.theme.accent.opacity(0.35) : .clear)
            )
            Button {
                store.hint()
            } label: {
                Label(String(localized: "hint"), systemImage: "lightbulb")
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.bordered)
            Button {
                store.erase()
            } label: {
                Label(String(localized: "erase"), systemImage: "delete.left")
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .buttonStyle(.bordered)
        }
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

    private var themeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "background"))
                .font(.footnote)
                .foregroundColor(store.theme.text.opacity(0.6))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 30), spacing: 8)], spacing: 8) {
                ForEach(AppTheme.all) { theme in
                    Button {
                        store.theme = theme
                    } label: {
                        Circle()
                            .fill(theme.bg)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle().stroke(
                                    theme.id == store.theme.id
                                        ? store.theme.accent
                                        : store.theme.boxBorder.opacity(0.6),
                                    lineWidth: theme.id == store.theme.id ? 3 : 1.5
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            Picker(String(localized: "size"), selection: sizeBinding) {
                ForEach(GridSize.allCases) { size in
                    Text("\(size.rawValue)×\(size.rawValue)").tag(size)
                }
            }
            .pickerStyle(.segmented)

            Picker(String(localized: "difficulty"), selection: difficultyBinding) {
                Text(String(localized: "easy")).tag(Difficulty.easy)
                Text(String(localized: "medium")).tag(Difficulty.medium)
                Text(String(localized: "hard")).tag(Difficulty.hard)
            }
            .pickerStyle(.segmented)

            Picker(String(localized: "display"), selection: displayBinding) {
                Text(String(localized: "digits")).tag(DisplayMode.digits)
                Text(String(localized: "colors")).tag(DisplayMode.colors)
            }
            .pickerStyle(.segmented)
        }
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
            }
        )
    }

    private var difficultyBinding: Binding<Difficulty> {
        Binding(
            get: { store.difficulty },
            set: {
                store.difficulty = $0
                store.newGame()
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
