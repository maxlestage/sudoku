import SwiftUI

/// Lightweight falling-confetti overlay shown when a puzzle is solved.
struct ConfettiView: View {
    private struct Piece: Identifiable {
        let id: Int
        let x: CGFloat        // horizontal position, 0...1
        let delay: Double
        let duration: Double
        let size: CGFloat
        let color: Color
        let spin: Double
    }

    private let pieces: [Piece] = (0..<70).map { i in
        Piece(
            id: i,
            x: CGFloat.random(in: 0...1),
            delay: Double.random(in: 0...1.0),
            duration: Double.random(in: 2.0...3.8),
            size: CGFloat.random(in: 6...12),
            color: valueColors[i % valueColors.count],
            spin: Bool.random() ? 720 : -720
        )
    }

    @State private var falling = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(piece.color)
                        .frame(width: piece.size, height: piece.size * 0.55)
                        .rotationEffect(.degrees(falling ? piece.spin : 0))
                        .position(
                            x: piece.x * geo.size.width,
                            y: falling ? geo.size.height + 30 : -30
                        )
                        .animation(
                            .linear(duration: piece.duration).delay(piece.delay),
                            value: falling
                        )
                }
            }
        }
        .onAppear { falling = true }
    }
}
