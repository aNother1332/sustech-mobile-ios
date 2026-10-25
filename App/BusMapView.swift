import CampusCore
import MapKit
import SwiftUI

struct BusView: View {
    @State private var tab = 0
    var body: some View {
        VStack(spacing: 0) {
            Picker("校车视图", selection: $tab) { Text("实时地图").tag(0); Text("站点与到站").tag(1) }.pickerStyle(.segmented).padding(.horizontal, 12).padding(.vertical, 8)
            if tab == 0 { BusMapView() } else { BusStopsView() }
        }.navigationTitle("校园巴士").navigationBarTitleDisplayMode(.inline)
    }
}

struct BusMapView: View {
    @Environment(CampusStore.self) private var store
    @Environment(\.scenePhase) private var phase
    @State private var routes: [BusMapRoute] = []
    @State private var stops: [BusStop] = []
    @State private var vehicles: [BusVehicle] = []
    @State private var routeID = ""
    @State private var includeInactive = false
    @State private var selectedVehicle: String?
    @State private var selectedStop: BusStop?
    @State private var camera: MapCameraPosition = .region(Self.campus)
    @State private var busy = false
    @State private var fetched: Date?
    @State private var message: String?
    private let client = BusClient(http: ServiceHTTP(origin: URL(string: "https://buseta.sustcra.com")!))
    private static let campus = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: 22.60308, longitude: 113.99373), span: MKCoordinateSpan(latitudeDelta: 0.020, longitudeDelta: 0.018))
    private var shownRoutes: [BusMapRoute] { routes.filter { routeID.isEmpty || $0.id == routeID } }
    private var shownVehicles: [BusVehicle] { vehicles.filter { (routeID.isEmpty || $0.routeID == routeID) && (includeInactive || $0.operating) } }
    private var shownStops: [BusStop] {
        let valid = stops.filter { stop in guard let lat = stop.latitude, let lon = stop.longitude else { return false }; return BusCoordinate(latitude: lat, longitude: lon) != nil }
        if routeID.isEmpty { return valid }
        let ids = Set(shownRoutes.flatMap { $0.directions.flatMap(\.stopIDs) }); return valid.filter { ids.contains($0.id) }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("线路", selection: $routeID) { Text("全部线路").tag(""); ForEach(routes) { Text($0.name).tag($0.id) } }.labelsHidden()
                Spacer()
                Button { camera = .region(Self.campus) } label: { Image(systemName: "viewfinder") }.accessibilityLabel("返回校园范围")
                Button { Task { await load(staticData: true) } } label: { if busy { ProgressView() } else { Image(systemName: "arrow.clockwise") } }.disabled(busy).accessibilityLabel("刷新地图与车辆")
            }.padding(.horizontal, 12).padding(.vertical, 5)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Map(position: $camera) {
                    ForEach(shownRoutes) { route in
                        ForEach(route.directions) { direction in
                            if direction.points.count > 1 { MapPolyline(coordinates: direction.points.map(\.mapCoordinate)).stroke(routeColor(route.id), lineWidth: 4) }
                        }
                    }
                    ForEach(shownStops) { stop in
                        if let lat = stop.latitude, let lon = stop.longitude {
                            Annotation(stop.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                                Button { selectedStop = stop } label: { Image(systemName: "mappin.circle.fill").font(.title3).foregroundStyle(Color.campusGreen).background(.background, in: Circle()) }
                                    .accessibilityLabel("站点：" + stop.name)
                            }.annotationTitles(.hidden)
                        }
                    }
                    ForEach(shownVehicles) { vehicle in
                        Annotation(vehicle.name, coordinate: vehicle.coordinate.mapCoordinate) {
                            Button { selectedVehicle = vehicle.id } label: {
                                VStack(spacing: 0) {
                                    Image(systemName: "arrowtriangle.up.fill").font(.caption2).rotationEffect(.degrees(vehicle.heading ?? 0))
                                    Image(systemName: vehicle.type == "SHUTTLE" ? "car.side.fill" : "bus.fill").font(.body.bold()).padding(7).background(.background, in: Circle()).overlay { Circle().strokeBorder(vehicle.isFresh(at: context.date) ? routeColor(vehicle.routeID) : .gray, lineWidth: 3) }
                                }.foregroundStyle(vehicle.isFresh(at: context.date) ? routeColor(vehicle.routeID) : .gray)
                            }.accessibilityLabel(vehicle.name + (vehicle.isFresh(at: context.date) ? "，位置正常上报" : "，位置已过期或时间未知"))
                        }.annotationTitles(.hidden)
                    }
                }.mapStyle(.standard(elevation: .flat)).mapControls { MapCompass(); MapScaleView() }
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 4) {
                            if store.mode == .demo { Label("示例车辆位置（虚构）", systemImage: "sparkles").foregroundStyle(Color.campusGreen) }
                            Text("\(shownVehicles.count) 辆 · 前台每 10 秒刷新").fontWeight(.semibold)
                            if let fetched { Text("接口读取 " + fetched.formatted(date: .omitted, time: .standard)).foregroundStyle(.secondary) }
                            Text("灰色标记：上报超过 2 分钟或时间未知").foregroundStyle(.secondary)
                        }.font(.caption2).padding(8).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10)).padding(8)
                    }
                    .frame(minHeight: 260)
                if let id = selectedVehicle, let vehicle = vehicles.first(where: { $0.id == id }) {
                    vehicleCard(vehicle, now: context.date)
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                Toggle("包含暂停服务车辆", isOn: $includeInactive).font(.caption)
                ScrollView(.horizontal, showsIndicators: false) { HStack { ForEach(shownRoutes) { route in Label { Text(route.name) } icon: { Circle().fill(routeColor(route.id)).frame(width: 8, height: 8) }.font(.caption2) } } }
                if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
                if !busy, fetched != nil, shownVehicles.isEmpty { Text("本次没有返回符合条件的车辆位置。").font(.caption).foregroundStyle(.secondary) }
                Link("数据与实现参考：SUSTech CRA · 校园巴士", destination: URL(string: "https://sustech.online/transport/bustimer.html")!).font(.caption2)
                Text("车辆位置以上报时间为准，读取成功不代表 GPS 刚刚更新。底图由 Apple 地图提供。").font(.caption2).foregroundStyle(.secondary)
            }.padding(10).background(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .task(id: store.mode.rawValue + String(includeInactive)) {
            await load(staticData: routes.isEmpty)
            while !Task.isCancelled { do { try await Task.sleep(for: .seconds(10)) } catch { return }; if phase == .active, store.mode == .live { await load(staticData: false) } }
        }
        .onChange(of: phase) { _, value in if value == .active, store.mode == .live { Task { await load(staticData: false) } } }
        .sheet(item: $selectedStop) { stop in NavigationStack {
            if store.mode == .live { BusStopView(stop: stop, client: client).toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { selectedStop = nil } } } }
            else { List { Text(stop.name); Text("示例模式：切换学校服务后查询实际到站信息。") }.navigationTitle("示例站点").toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { selectedStop = nil } } } }
        } }
    }
    private func vehicleCard(_ vehicle: BusVehicle, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack { Text(vehicle.name).font(.subheadline.bold()); Spacer(); Button("收起") { selectedVehicle = nil }.font(.caption) }
            let route = routes.first { $0.id == vehicle.routeID }
            Text((route?.name ?? "线路未匹配") + " · " + (route?.directions.first { $0.id == vehicle.directionID }?.name ?? "方向未提供")).font(.caption)
            HStack { Label(vehicle.operating ? "运营中" : "暂停服务", systemImage: vehicle.operating ? "bus.fill" : "pause.circle"); if let speed = vehicle.speed { Text("\(speed.formatted(.number.precision(.fractionLength(0)))) km/h") }; if !vehicle.nextStop.isEmpty { Text("下一站 " + vehicle.nextStop) } }.font(.caption)
            Label(vehicle.isFresh(at: now) ? "位置正常上报" : "上报已过期／时间未知，请勿视为当前位置", systemImage: vehicle.isFresh(at: now) ? "checkmark.circle" : "clock.badge.exclamationmark").font(.caption).foregroundStyle(vehicle.isFresh(at: now) ? Color.campusGreen : .secondary)
            if let date = vehicle.updatedAt { Text("车辆上报：" + date.formatted(date: .abbreviated, time: .standard)).font(.caption2).foregroundStyle(.secondary) }
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color(uiColor: .secondarySystemGroupedBackground))
    }
    private func routeColor(_ id: String) -> Color {
        var hex = routes.first { $0.id == id }?.color.replacingOccurrences(of: "#", with: "") ?? ""
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return .campusGreen }
        return Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
    private func load(staticData: Bool) async {
        guard !busy, phase == .active else { return }; busy = true; defer { busy = false }
        if store.mode == .demo { loadDemo(); return }
        let all = includeInactive
        do {
            if staticData {
                async let a = client.mapRoutes(); async let b = client.stops()
                let (newRoutes, newStops) = try await (a, b)
                guard !Task.isCancelled, store.mode == .live else { return }; routes = newRoutes; stops = newStops
            }
            let rows = try await client.vehicles(includeInactive: all)
            guard !Task.isCancelled, store.mode == .live, all == includeInactive else { return }
            vehicles = rows; fetched = .now; message = nil
        } catch { if !Task.isCancelled { message = "刷新失败，当前保留上次上报位置；请核对时间后重试。" } }
    }
    private func loadDemo() {
        guard let url = Bundle.main.url(forResource: "bus-map-demo", withExtension: "json"), let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(WireValue.self, from: data) else { return }
        routes = (try? BusMapParser.routes(value["routes"])) ?? []
        stops = value["stops"].rows.compactMap { row in
            guard !row["id"].text.isEmpty else { return nil }
            return BusStop(id: row["id"].text, name: row["group_name_zh"].text + row["name_zh"].text, directions: "示例站点", latitude: Double(row["latitude"].text), longitude: Double(row["longitude"].text))
        }
        let rows = value["vehicles"].rows.enumerated().map { index, row in row.replacing(["source_time": .number(Date.now.timeIntervalSince1970 - (index == 1 ? 300 : 10))]) }
        vehicles = (try? BusMapParser.vehicles(.array(rows))) ?? []; fetched = .now; message = "线路与站点为公开数据快照，车辆均为虚构示例。"
    }
}

private extension BusCoordinate { var mapCoordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) } }
