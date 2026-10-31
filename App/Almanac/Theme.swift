import SwiftUI

/// 宜历设计 token——来源 docs/design/design-system.md
struct Palette {
    let background: Color
    let card: Color
    let ink: Color
    let secondary: Color
    let separator: Color
    let holidayRed: Color    // 朱砂：休/节日/宜
    let makeupGray: Color    // 补班：班角标
    let solarGreen: Color    // 青瓷：节气
    let accent: Color        // 赭金：今日/主题色

    static let light = Palette(
        background: Color(red: 0.980, green: 0.973, blue: 0.961),
        card: .white,
        ink: Color(red: 0.110, green: 0.106, blue: 0.102),
        secondary: Color(red: 0.541, green: 0.529, blue: 0.510),
        separator: Color(red: 0.925, green: 0.914, blue: 0.894),
        holidayRed: Color(red: 0.780, green: 0.243, blue: 0.227),
        makeupGray: Color(red: 0.604, green: 0.588, blue: 0.561),
        solarGreen: Color(red: 0.243, green: 0.486, blue: 0.420),
        accent: Color(red: 0.710, green: 0.537, blue: 0.235)
    )

    static let dark = Palette(
        background: Color(red: 0.078, green: 0.075, blue: 0.067),
        card: Color(red: 0.118, green: 0.114, blue: 0.102),
        ink: Color(red: 0.929, green: 0.918, blue: 0.894),
        secondary: Color(red: 0.608, green: 0.592, blue: 0.557),
        separator: Color(red: 0.165, green: 0.161, blue: 0.145),
        holidayRed: Color(red: 0.878, green: 0.416, blue: 0.369),
        makeupGray: Color(red: 0.478, green: 0.463, blue: 0.431),
        solarGreen: Color(red: 0.435, green: 0.659, blue: 0.576),
        accent: Color(red: 0.831, green: 0.659, blue: 0.325)
    )

    static func forScheme(_ scheme: ColorScheme) -> Palette {
        scheme == .dark ? .dark : .light
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.light
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}

struct PaletteModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content
            .environment(\.palette, .forScheme(scheme))
    }
}

extension View {
    func almanacPalette() -> some View { modifier(PaletteModifier()) }
}
