import SwiftUI

struct CampusNavigation: View {
    @Binding var selection: CampusPage
    @GestureState private var drag: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        GeometryReader { geometry in
            let count = CGFloat(CampusPage.allCases.count)
            let width = (geometry.size.width - 12) / count
            let selected = CGFloat(CampusPage.allCases.firstIndex(of: selection) ?? 0)
            let position = min(max((drag ?? ((selected + 0.5) * width + 6)) - width / 2, 6), geometry.size.width - width - 6)
            ZStack(alignment: .leading) {
                Capsule().fill(Color.campusOrange.opacity(0.15)).frame(width: width, height: 54)
                    .overlay { Capsule().strokeBorder(.white.opacity(0.6), lineWidth: 1) }
                    .offset(x: position)
                    .animation(reduceMotion || drag != nil ? nil : .spring(response: 0.34, dampingFraction: 0.78), value: position)
                HStack(spacing: 0) {
                    ForEach(CampusPage.allCases) { page in
                        Button { selection = page } label: {
                            VStack(spacing: 3) { Image(systemName: page.symbol).font(.system(size: 21, weight: .regular)); Text(page.rawValue).font(.caption2.weight(.medium)) }
                                .foregroundStyle(selection == page ? Color.campusOrange : .secondary)
                                .frame(maxWidth: .infinity).frame(height: 58).contentShape(Capsule())
                        }.buttonStyle(.plain).accessibilityAddTraits(selection == page ? .isSelected : [])
                    }
                }.padding(.horizontal, 6)
            }.frame(height: 66).modifier(CampusGlass(opaque: reduceTransparency))
                .overlay { Capsule().strokeBorder(Color.primary.opacity(0.07), lineWidth: 1) }
                .shadow(color: .black.opacity(0.08), radius: 18, y: 5)
                .simultaneousGesture(DragGesture(minimumDistance: 8).updating($drag) { value, state, transaction in transaction.disablesAnimations = true; state = value.location.x }.onEnded { value in
                    let index = min(max(Int((value.location.x - 6) / width), 0), CampusPage.allCases.count - 1)
                    selection = CampusPage.allCases[index]
                })
        }.frame(maxWidth: 510).frame(height: 66).padding(.horizontal, 16).padding(.bottom, 8)
    }
}

private struct CampusGlass: ViewModifier {
    let opaque: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if opaque { content.background(Color.campusPaper, in: Capsule()) }
        else if #available(iOS 26.0, *) { content.glassEffect(.regular, in: Capsule()) }
        else { content.background(.ultraThinMaterial, in: Capsule()) }
    }
}
