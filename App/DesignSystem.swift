import SwiftUI

struct CampusHero: View {
    var eyebrow: String
    var title: String
    var subtitle: String
    var symbol: String
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(title).font(.system(.title2, design: .default).bold())
                if !subtitle.isEmpty { Text(subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.95)) }
            }
            Spacer(minLength: 0)
            Image(systemName: symbol.replacingOccurrences(of: ".fill", with: "")).font(.title2).symbolRenderingMode(.hierarchical)
        }.foregroundStyle(.white).padding(20).frame(maxWidth: .infinity, alignment: .leading)
            .background { CampusHeaderBackground().clipShape(RoundedRectangle(cornerRadius: 20)) }
    }
}

struct ServiceTile<Destination: View>: View {
    let title: String
    let detail: String
    let symbol: String
    let color: Color
    @ViewBuilder var destination: Destination
    var body: some View {
        NavigationLink { destination.toolbar(.visible, for: .navigationBar) } label: {
            VStack(alignment: .leading, spacing: 11) {
                Image(systemName: symbol.replacingOccurrences(of: ".fill", with: "")).font(.system(size: 28, weight: .regular)).foregroundStyle(Color.campusOrange)
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
            }.frame(maxWidth: .infinity, minHeight: 88, alignment: .leading).padding(17)
                .background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 17))
                .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(Color.primary.opacity(0.07), lineWidth: 1) }
                .contentShape(RoundedRectangle(cornerRadius: 17))
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


enum CampusPalette {
    static let header = LinearGradient(colors: [Color(red: 0.98, green: 0.57, blue: 0.30), .campusOrange], startPoint: .leading, endPoint: .trailing)
}
extension Color { static let campusPaper = Color(uiColor: .systemBackground) }

struct CampusSectionTitle: View {
    let title: String
    var body: some View {
        HStack(spacing: 7) { Capsule().fill(Color.campusOrange).frame(width: 3, height: 14); Text(title).font(.headline) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 8)
    }
}

struct CampusFold<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content
    @State private var expanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.95)) { expanded.toggle() } } label: {
                HStack(spacing: 12) {
                    Image(systemName: symbol).foregroundStyle(Color.campusOrange).font(.title3).frame(width: 27)
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down").font(.caption.weight(.semibold)).rotationEffect(.degrees(expanded ? 180 : 0)).foregroundStyle(.secondary)
                }.padding(17).contentShape(Rectangle())
            }.buttonStyle(CampusPressStyle()).accessibilityValue(expanded ? "已展开" : "已折叠")
            if expanded { content.padding(14).transition(.opacity) }
        }.background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 17))
            .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(Color.primary.opacity(0.07), lineWidth: 1) }
    }
}

struct CampusConfirmModifier<Actions: View, Message: View>: ViewModifier {
    let title: String
    @Binding var presented: Bool
    var onDismiss: (() -> Void)? = nil
    @ViewBuilder let actions: () -> Actions
    @ViewBuilder let message: () -> Message
    func body(content: Content) -> some View {
        content.fullScreenCover(isPresented: $presented, onDismiss: onDismiss) {
                ZStack(alignment: .bottom) {
                    Color.black.opacity(0.25).ignoresSafeArea().onTapGesture { presented = false }
                    VStack(alignment: .leading, spacing: 16) {
                        HStack { Text(title).font(.headline); Spacer(); Button { presented = false } label: { Image(systemName: "xmark").font(.subheadline) }.accessibilityLabel("关闭") }
                        message().font(.subheadline).foregroundStyle(.secondary)
                        VStack(spacing: 12) { actions() }
                            .buttonStyle(CampusConfirmActionStyle { presented = false }).tint(.campusOrange)
                    }.padding(22).frame(maxWidth: 540).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 25)).padding(12)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).presentationBackground(.clear)
        }
    }
}
extension View {
    func campusConfirmation<A: View, M: View>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, onDismiss: (() -> Void)? = nil,
        @ViewBuilder actions: @escaping () -> A, @ViewBuilder message: @escaping () -> M) -> some View {
        modifier(CampusConfirmModifier(title: title, presented: isPresented, onDismiss: onDismiss, actions: actions, message: message))
    }
    func campusConfirmation<A: View>(_ title: String, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, onDismiss: (() -> Void)? = nil,
        @ViewBuilder actions: @escaping () -> A) -> some View {
        campusConfirmation(title, isPresented: isPresented, titleVisibility: titleVisibility, onDismiss: onDismiss, actions: actions, message: { EmptyView() })
    }
}

private struct CampusConfirmActionStyle: PrimitiveButtonStyle {
    let dismiss: () -> Void
    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role) { configuration.trigger(); dismiss() } label: { configuration.label.frame(maxWidth: .infinity) }
            .buttonStyle(.borderedProminent).tint(configuration.role == .destructive ? .red : .campusOrange)
    }
}

/// Unmodified official school wordmark; template tint is applied only at render time.
struct CampusHeaderBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .trailing) {
                CampusPalette.header
                Circle().stroke(.white.opacity(0.10), lineWidth: 30).frame(width: 220, height: 220).offset(x: 95, y: 30)
                Image("SchoolWordmark").renderingMode(.template).resizable().scaledToFit()
                    .foregroundStyle(.white).opacity(0.17).frame(width: min(proxy.size.width * 0.70, 320))
                    .rotationEffect(.degrees(-10)).offset(x: 22, y: 0)
            }.frame(width: proxy.size.width, height: proxy.size.height)
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}
