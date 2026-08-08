import SwiftUI

struct KeypadView: View {
    @EnvironmentObject var store: GameStore
    let size: Int

    private let columns = [GridItem(.adaptive(minimum: 52), spacing: 8)]

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
                                .frame(width: 28, height: 28)
                        } else {
                            Text("\(v)")
                                .font(.title3.bold())
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
            }
            Button {
                store.erase()
            } label: {
                Image(systemName: "delete.left")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.bordered)
        }
    }
}
