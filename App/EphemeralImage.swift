import CampusCore
import SwiftUI
import ImageIO
import UIKit

struct EphemeralImage: View {
    let url: URL
    @Environment(CampusStore.self) private var store
    @State private var image: UIImage?
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.campusCyan.opacity(0.16), Color.blue.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
            if let image { Image(uiImage: image).resizable().scaledToFill() }
            else { Image(systemName: "globe.europe.africa").font(.largeTitle.weight(.ultraLight)).foregroundStyle(.blue.opacity(0.4)) }
        }.clipped().task(id: url) { await load() }.onDisappear { image = nil }
    }
    private func load() async {
        guard url.scheme == "https", ["ws.sustech.edu.cn", "www.sustech.edu.cn", "newshub.sustech.edu.cn"].contains(url.host ?? "") else { return }
        if url.host == "ws.sustech.edu.cn", store.mode != .live { return }
        let version = store.sessionRevision
        let config = URLSessionConfiguration.ephemeral; config.urlCache = nil; config.requestCachePolicy = .reloadIgnoringLocalCacheData
        let cookies = url.host == "ws.sustech.edu.cn" ? await store.sessions.cookies() : []
        let origin = URL(string: "https://" + (url.host ?? ""))!
        let http = ServiceHTTP(origin: origin, cookies: cookies, configuration: config, recovery: store.recovery(for: origin))
        do {
            let parts = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let path = url.path + (parts?.percentEncodedQuery.map { "?" + $0 } ?? "")
            let data = try await http.data(path)
            guard !Task.isCancelled, version == store.sessionRevision, data.count < 8_000_000,
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 960, kCGImageSourceCreateThumbnailWithTransform: true] as CFDictionary) else { return }
            image = UIImage(cgImage: thumbnail)
        } catch { image = nil }
    }
}
