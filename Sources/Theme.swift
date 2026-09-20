import SwiftUI
import UIKit

enum Theme {
    static let forest = Color(red: 0.07, green: 0.21, blue: 0.17)
    static let forestDeep = Color(red: 0.05, green: 0.15, blue: 0.12)
    static let ipe = Color(red: 0.90, green: 0.64, blue: 0.24)
    static let ipeSoft = Color(red: 0.97, green: 0.84, blue: 0.58)
    static let terracotta = Color(red: 0.79, green: 0.42, blue: 0.29)
    static let ink = Color(red: 0.10, green: 0.10, blue: 0.08)

    static var canvas: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.08, green: 0.09, blue: 0.08, alpha: 1)
                : UIColor(red: 0.98, green: 0.96, blue: 0.92, alpha: 1)
        })
    }

    static var surface: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.13, green: 0.14, blue: 0.13, alpha: 1)
                : UIColor.white
        })
    }

    static var softSurface: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.16, green: 0.18, blue: 0.16, alpha: 1)
                : UIColor(red: 0.95, green: 0.93, blue: 0.88, alpha: 1)
        })
    }
}

enum CuisineStyle {
    struct Identity { let symbol: String; let tint: Color }

    static func identity(for category: String) -> Identity {
        let key = category.folding(options: .diacriticInsensitive, locale: .current).lowercased()
        return Self.map[key] ?? Self.hashFallback(key)
    }

    static let map: [String: Identity] = [
        "pizzaria": Identity(symbol: "flame.fill", tint: Theme.terracotta),
        "italiana": Identity(symbol: "fork.knife", tint: Color(red: 0.71, green: 0.33, blue: 0.23)),
        "trattoria": Identity(symbol: "fork.knife", tint: Color(red: 0.71, green: 0.33, blue: 0.23)),
        "carnes": Identity(symbol: "flame.fill", tint: Color(red: 0.55, green: 0.23, blue: 0.18)),
        "steakhouse": Identity(symbol: "flame.fill", tint: Color(red: 0.55, green: 0.23, blue: 0.18)),
        "parrilla": Identity(symbol: "flame.fill", tint: Color(red: 0.55, green: 0.23, blue: 0.18)),
        "galeteria": Identity(symbol: "flame.fill", tint: Color(red: 0.55, green: 0.23, blue: 0.18)),
        "hamburgueria": Identity(symbol: "takeoutbag.and.cup.and.straw.fill", tint: Theme.ipe),
        "hot dog": Identity(symbol: "takeoutbag.and.cup.and.straw.fill", tint: Color(red: 0.84, green: 0.52, blue: 0.20)),
        "batataria": Identity(symbol: "takeoutbag.and.cup.and.straw.fill", tint: Color(red: 0.84, green: 0.52, blue: 0.20)),
        "bar": Identity(symbol: "wineglass.fill", tint: Color(red: 0.49, green: 0.29, blue: 0.36)),
        "gastrobar": Identity(symbol: "wineglass.fill", tint: Color(red: 0.49, green: 0.29, blue: 0.36)),
        "wine bar": Identity(symbol: "wineglass.fill", tint: Color(red: 0.42, green: 0.24, blue: 0.32)),
        "cafeteria": Identity(symbol: "cup.and.saucer.fill", tint: Color(red: 0.71, green: 0.49, blue: 0.29)),
        "brunch": Identity(symbol: "cup.and.saucer.fill", tint: Color(red: 0.78, green: 0.55, blue: 0.33)),
        "confeitaria": Identity(symbol: "birthday.cake.fill", tint: Color(red: 0.79, green: 0.42, blue: 0.48)),
        "doces": Identity(symbol: "birthday.cake.fill", tint: Color(red: 0.82, green: 0.46, blue: 0.52)),
        "sorveteria": Identity(symbol: "snowflake", tint: Color(red: 0.88, green: 0.54, blue: 0.42)),
        "gelateria": Identity(symbol: "snowflake", tint: Color(red: 0.88, green: 0.54, blue: 0.42)),
        "saudável": Identity(symbol: "leaf.fill", tint: Color(red: 0.24, green: 0.48, blue: 0.29)),
        "açaí": Identity(symbol: "leaf.fill", tint: Color(red: 0.35, green: 0.24, blue: 0.45)),
        "frutos do mar": Identity(symbol: "fish.fill", tint: Color(red: 0.18, green: 0.43, blue: 0.48)),
        "japonesa": Identity(symbol: "fish.fill", tint: Color(red: 0.29, green: 0.35, blue: 0.55)),
        "mediterrânea": Identity(symbol: "leaf.fill", tint: Color(red: 0.42, green: 0.48, blue: 0.24)),
        "brasileira": Identity(symbol: "fork.knife", tint: Theme.forest),
        "regional": Identity(symbol: "fork.knife", tint: Color(red: 0.18, green: 0.42, blue: 0.26)),
        "nordestina": Identity(symbol: "fork.knife", tint: Color(red: 0.36, green: 0.42, blue: 0.20)),
        "contemporânea": Identity(symbol: "fork.knife", tint: Color(red: 0.35, green: 0.42, blue: 0.42)),
        "internacional": Identity(symbol: "globe.americas.fill", tint: Color(red: 0.30, green: 0.40, blue: 0.42)),
        "variada": Identity(symbol: "fork.knife", tint: Color(red: 0.35, green: 0.42, blue: 0.42)),
        "creperia": Identity(symbol: "fork.knife", tint: Color(red: 0.85, green: 0.63, blue: 0.24)),
        "árabe": Identity(symbol: "fork.knife", tint: Color(red: 0.69, green: 0.54, blue: 0.29)),
        "peruana": Identity(symbol: "fork.knife", tint: Color(red: 0.63, green: 0.35, blue: 0.24)),
        "americana": Identity(symbol: "star.fill", tint: Color(red: 0.30, green: 0.40, blue: 0.60))
    ]

    private static let fallbackTints: [Color] = [
        Theme.forest, Theme.terracotta, Theme.ipe,
        Color(red: 0.29, green: 0.35, blue: 0.55), Color(red: 0.18, green: 0.43, blue: 0.48),
        Color(red: 0.49, green: 0.29, blue: 0.36), Color(red: 0.42, green: 0.48, blue: 0.24)
    ]

    private static func hashFallback(_ key: String) -> Identity {
        let sum = key.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let tint = fallbackTints[sum % fallbackTints.count]
        return Identity(symbol: "fork.knife", tint: tint)
    }
}

func displayDate(_ iso: String) -> String {
    let parts = iso.split(separator: "-")
    guard parts.count == 3, let day = Int(parts[2]), let month = Int(parts[1]) else { return iso }
    let names = ["jan", "fev", "mar", "abr", "mai", "jun", "jul", "ago", "set", "out", "nov", "dez"]
    let m = (month >= 1 && month <= 12) ? names[month - 1] : "?"
    return "\(day) \(m)."
}

func compactCount(_ value: Int) -> String {
    if value >= 1000 {
        let v = Double(value) / 1000.0
        return String(format: "%.1f mil", v).replacingOccurrences(of: ".", with: ",")
    }
    return "\(value)"
}
