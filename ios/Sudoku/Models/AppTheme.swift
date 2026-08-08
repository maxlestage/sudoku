import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }
}

/// Background themes — same palette as the web app's data-theme variants.
struct AppTheme: Identifiable, Equatable {
    let id: String
    let isLight: Bool
    let bg: Color
    let surface: Color
    let cell: Color
    let cellGiven: Color
    let text: Color
    let boxBorder: Color
    let accent: Color
    let same: Color

    static let all: [AppTheme] = [
        AppTheme(id: "midnight", isLight: false,
                 bg: Color(hex: 0x1a1a2e), surface: Color(hex: 0x24243e),
                 cell: Color(hex: 0x2e2e4e), cellGiven: Color(hex: 0x3a3a5c),
                 text: Color(hex: 0xeaeaea), boxBorder: Color(hex: 0x8888aa),
                 accent: Color(hex: 0x4895ef), same: Color(hex: 0x35507a)),
        AppTheme(id: "noir", isLight: false,
                 bg: Color(hex: 0x0e0e12), surface: Color(hex: 0x1b1b22),
                 cell: Color(hex: 0x26262e), cellGiven: Color(hex: 0x34343e),
                 text: Color(hex: 0xeaeaea), boxBorder: Color(hex: 0x85858f),
                 accent: Color(hex: 0x4895ef), same: Color(hex: 0x3c3c55)),
        AppTheme(id: "ocean", isLight: false,
                 bg: Color(hex: 0x04263b), surface: Color(hex: 0x0a3a52),
                 cell: Color(hex: 0x0e4a66), cellGiven: Color(hex: 0x14597a),
                 text: Color(hex: 0xeaeaea), boxBorder: Color(hex: 0x7fb3c8),
                 accent: Color(hex: 0x2ec4b6), same: Color(hex: 0x17618a)),
        AppTheme(id: "forest", isLight: false,
                 bg: Color(hex: 0x0f2417), surface: Color(hex: 0x1a3826),
                 cell: Color(hex: 0x224732), cellGiven: Color(hex: 0x2c5940),
                 text: Color(hex: 0xeaeaea), boxBorder: Color(hex: 0x8fbf9f),
                 accent: Color(hex: 0x80b918), same: Color(hex: 0x386a4d)),
        AppTheme(id: "plum", isLight: false,
                 bg: Color(hex: 0x24122e), surface: Color(hex: 0x362045),
                 cell: Color(hex: 0x442a57), cellGiven: Color(hex: 0x543669),
                 text: Color(hex: 0xeaeaea), boxBorder: Color(hex: 0xb195c4),
                 accent: Color(hex: 0xff70a6), same: Color(hex: 0x64407c)),
        AppTheme(id: "light", isLight: true,
                 bg: Color(hex: 0xf2f2f7), surface: Color(hex: 0xffffff),
                 cell: Color(hex: 0xffffff), cellGiven: Color(hex: 0xe4e4ee),
                 text: Color(hex: 0x1a1a2e), boxBorder: Color(hex: 0x55556a),
                 accent: Color(hex: 0x4895ef), same: Color(hex: 0xcfe0f5)),
    ]

    static func named(_ id: String) -> AppTheme {
        all.first { $0.id == id } ?? all[0]
    }
}
