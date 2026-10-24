import CampusCore
import CoreImage.CIFilterBuiltins
import Security
import SwiftUI

enum CredentialVault {
    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        var item: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "cn.sustech.community.daily." + key, kSecReturnData as String: true]
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    static func save<T: Encodable>(_ value: T, key: String) throws {
        let data = try JSONEncoder().encode(value)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "cn.sustech.community.daily." + key]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = data; item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw ServiceFailure("无法安全保存登录态，请解锁设备后重试。") }
        } else if status != errSecSuccess { throw ServiceFailure("登录态保存失败，请解锁设备后重试。") }
    }
    static func delete(_ key: String) { SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "cn.sustech.community.daily." + key] as CFDictionary) }
}

struct CourtReservationView: View {
    @Environment(CampusStore.self) private var store
    @State private var client = CourtClient(credentials: CredentialVault.load(CourtCredentials.self, key: "court"))
    @State private var code = ""
    @State private var gyms: [ReservationItem] = []
    @State private var orders: [ReservationItem] = []
    @State private var busy = false
    @State private var message: String?
    @State private var cancelling: ReservationItem?
    private static var authorization: URL {
        var url = URLComponents(string: "https://open.weixin.qq.com/connect/oauth2/authorize")!
        url.queryItems = [URLQueryItem(name: "appid", value: "wx8839ace7048d181b"),
            URLQueryItem(name: "redirect_uri", value: "https://reservation.sustech.edu.cn/clientMobile.html#/reservation/fastReservation"),
            URLQueryItem(name: "response_type", value: "code"), URLQueryItem(name: "scope", value: "snsapi_base"), URLQueryItem(name: "state", value: "STATE")]
        url.fragment = "wechat_redirect"
        return url.url!
    }
    var body: some View {
        List {
            Section("体育场馆授权") {
                Text("此平台使用企业微信授权，与学校 CAS 不同。授权成功后在本机保留登录态，过期后需重新授权。").font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("首次授权或授权过期") {
                    if let qr = qrImage() { Image(uiImage: qr).interpolation(.none).resizable().scaledToFit().frame(width: 180, height: 180).accessibilityLabel("学校体育场馆企业微信授权二维码") }
                    ShareLink("分享授权链接到企业微信", item: Self.authorization)
                    Text("用企业微信扫描二维码或打开分享的链接，复制带 code 的回调链接并粘贴到下方。code 为一次性凭据，页面可能已使用它；失效时重新获取，不要将链接发到聊天或 Issue。").font(.caption)
                    SecureField("一次性授权链接或 code", text: $code).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("使用此授权连接") { Task { await login() } }.disabled(busy || code.isEmpty || store.mode == .demo)
                }
                Button("刷新全部场馆与我的预约") { Task { await refresh() } }.disabled(busy || store.mode == .demo)
                Button("退出体育场馆账号", role: .destructive) { client = CourtClient(); CredentialVault.delete("court"); gyms = []; orders = []; message = "已清除本机体育场馆授权。" }.disabled(busy)
                if busy { ProgressView() }; ServiceMessage(message: message)
            }
            Section("平台返回的全部场馆") {
                ForEach(gyms) { gym in
                    NavigationLink { CourtGroundsView(gym: gym, client: client) } label: { VStack(alignment: .leading) { Text(gym.title); Text(gym.detail).font(.caption) } }
                }
            }
            Section("我的订单") {
                ForEach(orders) { order in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(order.title).font(.headline); Text(order.detail).font(.caption)
                        if ["1", "2"].contains(order.raw["status"].text) { Button("取消订单", role: .destructive) { cancelling = order }.disabled(busy) }
                    }
                }
            }
        }.navigationTitle("体育场馆")
        .confirmationDialog("确认取消这项场馆预约？", isPresented: Binding(get: { cancelling != nil }, set: { if !$0 { cancelling = nil } }), titleVisibility: .visible) {
            if let order = cancelling { Button("取消 \(order.title)", role: .destructive) { Task { await cancel(order) } } }
        }
    }
    private func qrImage() -> UIImage? {
        let filter = CIFilter.qrCodeGenerator(); filter.message = Data(Self.authorization.absoluteString.utf8)
        guard let output = filter.outputImage, let image = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: image)
    }
    private func save(_ revision: Int) async throws {
        guard revision == store.sessionRevision else { throw CancellationError() }
        if let credentials = await client.currentCredentials() { try CredentialVault.save(credentials, key: "court") }
    }
    private func login() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        let input = code; code = ""; let version = store.sessionRevision
        do { try await client.login(codeOrURL: input); try await save(version); gyms = try await client.gyms(); orders = try await client.orders(); message = "场馆授权已连接。" }
        catch { message = error.localizedDescription }
    }
    private func refresh() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        let version = store.sessionRevision
        do { gyms = try await client.gyms(); orders = try await client.orders(); try await save(version); message = "读取于 \(Date.now.formatted())" }
        catch { message = error.localizedDescription }
    }
    private func cancel(_ order: ReservationItem) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        let version = store.sessionRevision
        do { try await client.cancel(order); orders = try await client.orders(); try await save(version)
            message = orders.first { $0.id == order.id }?.raw["status"].text == "6" ? "已回读确认取消。" : "取消请求已返回，请核对订单状态。"
        } catch { message = "结果需核对：\(error.localizedDescription)" }
    }
}

private struct CourtGroundsView: View {
    let gym: ReservationItem; let client: CourtClient
    @State private var grounds: [ReservationItem] = []
    @State private var message: String?
    var body: some View {
        List {
            ServiceMessage(message: message)
            ForEach(grounds) { ground in
                NavigationLink { CourtBookingView(ground: ground, client: client) } label: {
                    VStack(alignment: .leading) { Text(ground.title); Text(ground.detail).font(.caption) }
                }
            }
        }.navigationTitle(gym.title).task {
            do { grounds = try await client.grounds(gym: gym.id) } catch { message = error.localizedDescription }
        }
    }
}
private struct CourtBookingView: View {
    let ground: ReservationItem; let client: CourtClient
    @Environment(CampusStore.self) private var store
    @State private var day = Date.now
    @State private var slots: [CourtSlot] = []
    @State private var selected: CourtSlot?
    @State private var phone = ""
    @State private var people = 1
    @State private var challenge: WireValue?
    @State private var captchaToken = ""
    @State private var busy = false
    @State private var message: String?
    @State private var confirm = false
    var body: some View {
        List {
            Section {
                DatePicker("日期", selection: $day, displayedComponents: .date)
                Button("刷新当天时段") { Task { await load() } }.disabled(busy)
                Text("仅列出学校实际返回的时段，每次手动预约一个时段。未开放日期不生成可预约占位，不定时提交或循环抢场。").font(.caption).foregroundStyle(.secondary)
                if busy { ProgressView() }; ServiceMessage(message: message)
            }
            Section("时段") {
                ForEach(slots) { slot in
                    Button {
                        selected = slot; captchaToken = ""; challenge = nil
                    } label: {
                        HStack {
                            Text(slot.start + "–" + slot.end); Spacer()
                            Text(slot.available ? "可约" : slot.status == "2" ? "待开放" : slot.status == "3" ? "本人已约" : "不可约").font(.caption)
                            if selected?.id == slot.id { Image(systemName: "checkmark.circle.fill") }
                        }
                    }.disabled(!slot.available || busy)
                }
            }
            if let selected {
                Section("确认预约内容") {
                    Text(ground.title + " · " + selected.day + " " + selected.start + "–" + selected.end)
                    TextField("联系电话", text: $phone).keyboardType(.phonePad)
                    Stepper("使用人数 \(people)", value: $people, in: 1...100)
                    Button("获取手动滑块验证码") { Task { await captcha() } }.disabled(busy)
                    if let challenge {
                        CourtCaptchaView(challenge: challenge, client: client) { token in captchaToken = token; self.challenge = nil }
                    }
                    if !captchaToken.isEmpty { Label("已通过本次验证码", systemImage: "checkmark.shield") }
                    Button("核对并提交一次") { confirm = true }.disabled(busy || captchaToken.isEmpty || phone.isEmpty || store.mode == .demo)
                }
            }
        }.navigationTitle(ground.title)
        .onChange(of: day) { _, _ in slots = []; selected = nil; challenge = nil; captchaToken = "" }
        .confirmationDialog("确认手动预约？", isPresented: $confirm, titleVisibility: .visible) {
            Button("提交一次") { Task { await submit() } }
        } message: { Text("\(ground.title) · \(selected?.day ?? "") \(selected?.start ?? "")–\(selected?.end ?? "") · \(people) 人。以学校订单回读结果为准。") }
    }
    private func load() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { slots = try await client.slots(ground: ground.id, day: day); selected = nil; captchaToken = ""; challenge = nil; message = "读取于 \(Date.now.formatted())" }
        catch { message = error.localizedDescription }
    }
    private func captcha() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { challenge = try await client.captcha(); captchaToken = ""; message = nil } catch { message = error.localizedDescription }
    }
    private func submit() async {
        guard !busy, let selected else { return }; busy = true; defer { busy = false; captchaToken = ""; challenge = nil }
        let version = store.sessionRevision
        do { try await client.book(ground: ground, slot: selected, captchaToken: captchaToken, phone: phone, people: people)
            let orders = try await client.orders()
            let exists = orders.contains { $0.raw["groundId"].text == ground.id && $0.raw["startTime"].text.replacingOccurrences(of: "T", with: " ").hasPrefix(selected.day + " " + (selected.start.count == 4 ? "0" : "") + selected.start) && ["1", "2"].contains($0.raw["status"].text) }
            message = exists ? "已在学校订单中确认预约，请到我的订单核对。" : "学校已接受请求，但未能回读匹配订单，请先到官方页面核对，不要重复预约。"
        } catch { message = "本次未能完整确认结果：\(error.localizedDescription) 请先查看我的订单，勿直接重复提交。" }
        if version == store.sessionRevision, let credentials = await client.currentCredentials() { try? CredentialVault.save(credentials, key: "court") }
    }
}

private struct CourtCaptchaView: View {
    let challenge: WireValue; let client: CourtClient; let completed: (String) -> Void
    @State private var offset: CGFloat = 0
    @State private var started: Date?
    @State private var track: [WireValue] = []
    @State private var busy = false
    @State private var message: String?
    private var cap: WireValue { challenge["captcha"] }
    private func image(_ key: String) -> UIImage? {
        guard let encoded = cap[key].text.split(separator: ",", maxSplits: 1).last,
              let data = Data(base64Encoded: String(encoded)), let image = UIImage(data: data) else { return nil }
        return image
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("手动拖动图片中的滑块到缺口后松手").font(.caption)
            if let background = image("backgroundImage"), let template = image("templateImage") {
                GeometryReader { geometry in
                    let width = CGFloat(cap["backgroundImageWidth"].int ?? 600)
                    let ratio = geometry.size.width / width
                    Image(uiImage: background).resizable().frame(width: geometry.size.width, height: geometry.size.height)
                        .overlay(alignment: .topLeading) {
                            Image(uiImage: template).resizable()
                                .frame(width: CGFloat(cap["templateImageWidth"].int ?? 110) * ratio, height: geometry.size.height)
                                .offset(x: offset * ratio)
                        }
                        .contentShape(Rectangle())
                        .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                            guard !busy else { return }
                            if started == nil { started = .now; track = [point(x: 0, y: 0, type: "down", time: 0)] }
                            let x = max(0, min(width - CGFloat(cap["templateImageWidth"].int ?? 110), value.translation.width / ratio))
                            offset = x
                            track.append(point(x: x, y: value.translation.height / ratio, type: "move", time: Date.now.timeIntervalSince(started ?? .now) * 1000))
                        }.onEnded { value in
                            guard !busy, let started else { return }
                            let stop = Date.now
                            track.append(point(x: offset, y: value.translation.height / ratio, type: "up", time: stop.timeIntervalSince(started) * 1000))
                            Task { await verify(start: started, stop: stop) }
                        })
                        .accessibilityLabel("学校滑块验证码，需要本人拖动；也可使用学校官方页面预约")
                }.aspectRatio(CGFloat(cap["backgroundImageWidth"].int ?? 600) / CGFloat(cap["backgroundImageHeight"].int ?? 360), contentMode: .fit)
            } else { Text("验证码图片无法显示，请重新获取或使用学校页面。") }
            if busy { ProgressView("正在验证") }; ServiceMessage(message: message)
        }.id(challenge["id"].text)
    }
    private func point(x: CGFloat, y: CGFloat, type: String, time: Double) -> WireValue {
        .object(["x": .number(Double(x.rounded())), "y": .number(Double(y.rounded())), "type": .string(type), "t": .number(time.rounded())])
    }
    private func verify(start: Date, stop: Date) async {
        busy = true; defer { busy = false; started = nil; offset = 0; track = [] }
        do { completed(try await client.checkCaptcha(challenge, track: track, start: start, stop: stop)) }
        catch { message = error.localizedDescription }
    }
}
