import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        VStack(spacing: 12) {
            header
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
        .background(Color(red: 0.10, green: 0.10, blue: 0.18).ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Text("Sudoku")
                .font(.title2.bold())
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
            Button(String(localized: "play_again")) {
                store.newGame()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
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
