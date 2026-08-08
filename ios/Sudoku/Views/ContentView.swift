import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GameStore

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
                BoardView(game: game)
                if game.finished {
                    winBanner
                } else {
                    KeypadView(size: game.puzzle.size)
                }
                Spacer(minLength: 0)
                Button(String(localized: "new_game")) {
                    store.newGame()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(store.theme.bg.ignoresSafeArea())
        .tint(store.theme.accent)
        .preferredColorScheme(store.theme.isLight ? .light : .dark)
    }

    private var themeRow: some View {
        HStack(spacing: 10) {
            Text(String(localized: "background"))
                .font(.footnote)
                .foregroundColor(store.theme.text.opacity(0.6))
            Spacer()
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

    private var header: some View {
        HStack {
            Text("Sudoku")
                .font(.title2.bold())
                .foregroundColor(store.theme.text)
            Spacer()
            Picker(String(localized: "display"), selection: displayBinding) {
                Text(String(localized: "digits")).tag(DisplayMode.digits)
                Text(String(localized: "colors")).tag(DisplayMode.colors)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 190)
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
        }
    }

    private var winBanner: some View {
        VStack(spacing: 10) {
            Text(String(localized: "win"))
                .font(.headline)
                .foregroundColor(store.theme.text)
            Button(String(localized: "play_again")) {
                store.newGame()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(store.theme.surface, in: RoundedRectangle(cornerRadius: 12))
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
