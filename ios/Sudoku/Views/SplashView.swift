import SwiftUI

/// Launch screen: the app-icon grid builds itself tile by tile, then the
/// title and the author credit fade in.
struct SplashView: View {
    let theme: AppTheme

    @State private var tilesIn = false
    @State private var textIn = false
    @State private var pulse = false

    private let tile: CGFloat = 52
    private let gap: CGFloat = 8

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.surface, theme.bg, theme.bg],
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                grid
                    .shadow(color: .black.opacity(0.35), radius: 24, y: 12)

                Text("Sudoku")
                    .font(.system(size: 42, weight: .heavy, design: .rounded))
                    .foregroundColor(theme.text)
                    .padding(.top, 32)
                    .opacity(textIn ? 1 : 0)
                    .offset(y: textIn ? 0 : 10)

                dots
                    .padding(.top, 24)
                    .opacity(textIn ? 1 : 0)

                Spacer()

                VStack(spacing: 3) {
                    Text(String(localized: "credits"))
                        .font(.caption)
                        .foregroundColor(theme.text.opacity(0.5))
                    Text("Maxime Nathan Lestage")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(theme.text.opacity(0.85))
                }
                .opacity(textIn ? 1 : 0)
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 24)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                tilesIn = true
            }
            withAnimation(.easeOut(duration: 0.45).delay(0.55)) {
                textIn = true
            }
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var grid: some View {
        VStack(spacing: gap) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0..<3, id: \.self) { col in
                        let i = row * 3 + col
                        RoundedRectangle(cornerRadius: tile * 0.24)
                            .fill(valueColors[i])
                            .frame(width: tile, height: tile)
                            .scaleEffect(tilesIn ? 1 : 0.2)
                            .opacity(tilesIn ? 1 : 0)
                            .animation(
                                .spring(response: 0.5, dampingFraction: 0.6)
                                    .delay(Double(i) * 0.055),
                                value: tilesIn
                            )
                    }
                }
            }
        }
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(theme.accent)
                    .frame(width: 8, height: 8)
                    .opacity(pulse ? 1 : 0.25)
                    .animation(
                        .easeInOut(duration: 0.7)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.18),
                        value: pulse
                    )
            }
        }
    }
}
