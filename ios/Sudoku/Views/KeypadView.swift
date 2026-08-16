import SwiftUI

struct KeypadView: View {
    @EnvironmentObject var store: GameStore
    let size: Int

    /// 4×4 fits on one row; 9×9 reads better as 5 + 4.
    private var columns: [GridItem] {
        let count = size == 4 ? 4 : 5
        return Array(repeating: GridItem(.flexible(), spacing: 8), count: count)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(1...size, id: \.self) { v in
                Button {
                    store.enter(v)
                } label: {
                    Group {
                        if store.displayMode == .colors {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(valueColors[v - 1])
                                .frame(width: 26, height: 26)
                        } else {
                            Text("\(v)")
                                .font(.title3.bold())
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
