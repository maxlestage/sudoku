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
        AppTheme(id: "crimson", isLight: false,
                 bg: Color(hex: 0x2b0f14), surface: Color(hex: 0x3f1a20),
                 cell: Color(hex: 0x4e222a), cellGiven: Color(hex: 0x602b35),
                 text: Color(hex: 0xeaeaea), boxBorder: Color(hex: 0xc48a95),
                 accent: Color(hex: 0xff4d6d), same: Color(hex: 0x7a3644)),
        AppTheme(id: "slate", isLight: false,
                 bg: Color(hex: 0x1c2530), surface: Color(hex: 0x273544),
                 cell: Color(hex: 0x314252), cellGiven: Color(hex: 0x3d5164),
                 text: Color(hex: 0xeaeaea), boxBorder: Color(hex: 0x8fa5b8),
                 accent: Color(hex: 0x58a6ff), same: Color(hex: 0x3f5d7a)),
        AppTheme(id: "sunset", isLight: false,
                 bg: Color(hex: 0x2a1a0a), surface: Color(hex: 0x3d2812),
                 cell: Color(hex: 0x4c3318), cellGiven: Color(hex: 0x5e4020),
                 text: Color(hex: 0xeaeaea), boxBorder: Color(hex: 0xc9a276),
                 accent: Color(hex: 0xf4a261), same: Color(hex: 0x6f4d26)),
        AppTheme(id: "espresso", isLight: false,
                 bg: Color(hex: 0x211712), surface: Color(hex: 0x33251d),
                 cell: Color(hex: 0x402f25), cellGiven: Color(hex: 0x4f3a2e),
                 text: Color(hex: 0xeaeaea), boxBorder: Color(hex: 0xb39b8a),
                 accent: Color(hex: 0xe9c46a), same: Color(hex: 0x5d4436)),
        AppTheme(id: "light", isLight: true,
                 bg: Color(hex: 0xf2f2f7), surface: Color(hex: 0xffffff),
                 cell: Color(hex: 0xffffff), cellGiven: Color(hex: 0xe4e4ee),
                 text: Color(hex: 0x1a1a2e), boxBorder: Color(hex: 0x55556a),
                 accent: Color(hex: 0x4895ef), same: Color(hex: 0xcfe0f5)),
        AppTheme(id: "mint", isLight: true,
                 bg: Color(hex: 0xeaf6ef), surface: Color(hex: 0xffffff),
                 cell: Color(hex: 0xffffff), cellGiven: Color(hex: 0xd8ecdf),
                 text: Color(hex: 0x14281c), boxBorder: Color(hex: 0x4a6a56),
                 accent: Color(hex: 0x2a9d8f), same: Color(hex: 0xbfe3cf)),
        AppTheme(id: "rose", isLight: true,
                 bg: Color(hex: 0xfdf0f4), surface: Color(hex: 0xffffff),
                 cell: Color(hex: 0xffffff), cellGiven: Color(hex: 0xf6dde6),
                 text: Color(hex: 0x33121e), boxBorder: Color(hex: 0x7a4a5a),
                 accent: Color(hex: 0xe63946), same: Color(hex: 0xf3c6d4)),
    ]

    static func named(_ id: String) -> AppTheme {
        all.first { $0.id == id } ?? all[0]
    }
}
