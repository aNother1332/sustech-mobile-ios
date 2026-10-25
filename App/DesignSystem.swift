import SwiftUI

struct CampusHero: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    var symbol: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow).font(.caption.bold()).tracking(1.2).foregroundStyle(Color.campusCyan)
                Text(title).font(.title2.bold()).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(.white.opacity(0.82))
            }
            Spacer(minLength: 0)
            Image(systemName: symbol).font(.title).foregroundStyle(Color.campusOrange)
                .padding(12).background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 15))
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [.campusInk, Color(red: 0.01, green: 0.35, blue: 0.36)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 22))
    }
}

struct ServiceTile<Destination: View>: View {
    let title: String
    let detail: String
    let symbol: String
    let color: Color
    @ViewBuilder var destination: Destination
    var body: some View {
        NavigationLink { destination } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack { Image(systemName: symbol).font(.title3).foregroundStyle(color).frame(width: 38, height: 38).background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 11)); Spacer(); Image(systemName: "chevron.right").font(.caption2.bold()).foregroundStyle(.tertiary) }
                Text(title).font(.subheadline.bold()).foregroundStyle(.primary)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }.frame(maxWidth: .infinity, minHeight: 106, alignment: .leading).padding(13)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(color.opacity(0.17), lineWidth: 1) }
                .contentShape(RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(CampusPressStyle())
    }
}

struct CampusPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.78 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 1), value: configuration.isPressed)
    }
}
