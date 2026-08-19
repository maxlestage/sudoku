import SwiftUI

@main
struct SudokuApp: App {
    @StateObject private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

/// Holds the splash screen over the game until the launch animation has
/// played out and the first puzzle is ready.
struct RootView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var showSplash = true

    var body: some View {
        ZStack {
            ContentView()
            if showSplash {
                SplashView(theme: store.theme)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .onAppear { store.systemIsDark = colorScheme == .dark }
        .task {
            // Let the animation breathe, then wait for the first puzzle.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            while store.loading || store.game == nil {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
            withAnimation(.easeOut(duration: 0.45)) { showSplash = false }
        }
    }
}
