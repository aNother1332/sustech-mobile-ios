import CampusCore
import MapKit
import SwiftUI

struct BusView: View {
    var body: some View { BusMapView().navigationTitle("校园巴士").navigationBarTitleDisplayMode(.inline) }
}

struct BusMapView: View {
    @Environment(CampusStore.self) private var store
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var location = CampusLocation()
    @State private var camera: MapCameraPosition = .automatic
    @State private var following = true
    @State private var routes: [BusMapRoute] = []
    @State private var stops: [BusStop] = []
    @State private var vehicles: [BusVehicle] = []
    @State private var schedules: [BusScheduleGroup] = []
    @State private var arrivals: [String: [BusArrival]] = [:]
    @State private var selectedStop: String?
    @State private var selectedVehicle: String?
    @State private var manualStop: String?
    @State private var showStops = false
    @State private var showSettings = false
    @State private var routeFilter = ""
    @State private var expanded = false
    @GestureState private var drawerDrag: CGFloat = 0
    @State private var busy = false
    @State private var fetched: Date?
    @State private var scheduleDay = ""
    @State private var message: String?
    @AppStorage("bus-mainland-map-alignment") private var mainlandMap = true
    private let client = BusClient(http: ServiceHTTP(origin: URL(string: "https://buseta.sustcra.com")!))
    private var campus: MKCoordinateRegion { MKCoordinateRegion(center: coordinate(BusCoordinate(latitude: 22.60308, longitude: 113.99373)!), span: MKCoordinateSpan(latitudeDelta: 0.020, longitudeDelta: 0.018)) }
    private var detailKey: String { (selectedStop ?? "") + "|" + (selectedVehicle ?? "") }
    private func coordinate(_ source: BusCoordinate) -> CLLocationCoordinate2D {
        let point = mainlandMap ? source.gcj02 : source
        return CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
    }
    private var ownPoint: BusCoordinate? {
        if store.mode == .demo { return BusCoordinate(latitude: 22.603, longitude: 113.994) }
        guard let point = location.point, abs(point.timestamp.timeIntervalSinceNow) < 120 else { return nil }
        return BusCoordinate(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
    }
    private var nearby: [BusStop] {
        guard referencePoint != nil else { return [] }
        return ["line1_cw", "line2_ccw"].compactMap { direction in
            let ids = Set(routes.flatMap(\.directions).filter { $0.id == direction }.flatMap(\.stopIDs))
            let candidates = stops.filter { ids.contains($0.id) || $0.directionIDs.contains(direction) }
            return candidates.min { distance($0) < distance($1) }
        }
    }
    private var referencePoint: BusCoordinate? {
        if let manualStop, let stop = stops.first(where: { $0.id == manualStop }), let lat = stop.latitude, let lon = stop.longitude { return BusCoordinate(latitude: lat, longitude: lon) }
        return ownPoint
    }
    private func distance(_ stop: BusStop) -> Double {
        guard let ownPoint = referencePoint, let lat = stop.latitude, let lon = stop.longitude else { return .infinity }
        return CLLocation(latitude: ownPoint.latitude, longitude: ownPoint.longitude).distance(from: CLLocation(latitude: lat, longitude: lon))
    }
    var body: some View {
        GeometryReader { geometry in
            let height = min(max((expanded ? min(geometry.size.height * 0.62, 490) : 70) - drawerDrag, 70), geometry.size.height * 0.76)
            ZStack(alignment: .bottom) {
                map
                VStack(alignment: .leading) {
                    HStack(alignment: .top) { nearestCard; Spacer(minLength: 8); Button { showSettings.toggle(); showStops = false } label: { Image(systemName: "slider.horizontal.3").padding(13).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 14)) }.accessibilityLabel("地图设置") }
                    if let message { Text(message).font(.caption).padding(10).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 12)) }
                    Spacer()
                    if !expanded { detailCard }
                    HStack { Spacer(); Button { manualStop = nil; following = true; location.request(continuous: true); centerOnUser() } label: { Image(systemName: "location.fill").padding(14).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 14)) }.accessibilityLabel("回到我的位置") }
                }.padding(14).padding(.bottom, height + 12)
                scheduleDrawer(height: height)
                if showStops { stopChooser }
                if showSettings { settings }
            }
        }
        .onAppear { camera = .region(campus); if store.mode == .live { location.request(continuous: true) } }
        .onChange(of: location.point) { _, _ in if following { centerOnUser() } }
        .onChange(of: mainlandMap) { _, _ in centerOnUser() }
        .onDisappear { location.stop() }
        .task(id: store.mode.rawValue) {
            routes = []; stops = []; vehicles = []; schedules = []; arrivals = [:]
            selectedStop = nil; selectedVehicle = nil; manualStop = nil; fetched = nil
            await load(staticData: true)
            if store.mode == .demo { centerOnUser() }
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(10)) } catch { return }
                if phase == .active, store.mode == .live { await load(staticData: routes.isEmpty || scheduleDay != CampusClock.format(.now)) }
            }
        }
        .task(id: detailKey) { await refreshArrivals() }
        .onChange(of: location.point) { _, _ in Task { await refreshArrivals() } }
        .onChange(of: phase) { _, value in if value == .active { if store.mode == .live { location.request(continuous: true) }; Task { await load(staticData: routes.isEmpty) } } else { location.stop() } }
    }
    private var map: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Map(position: $camera) {
                ForEach(routes) { route in
                    ForEach(route.directions) { direction in
                        if direction.points.count > 1 {
                            MapPolyline(coordinates: direction.points.map { coordinate($0) })
                                .stroke(routeColor(route.id), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        }
                    }
                }
                ForEach(stops) { stop in
                    if let lat = stop.latitude, let lon = stop.longitude, let point = BusCoordinate(latitude: lat, longitude: lon) {
                        Annotation(stop.name, coordinate: coordinate(point)) {
                            Button { selectedStop = stop.id; selectedVehicle = nil; expanded = false } label: {
                                Circle().fill(Color.campusOrange).frame(width: selectedStop == stop.id ? 17 : 11, height: selectedStop == stop.id ? 17 : 11).overlay { Circle().strokeBorder(.white, lineWidth: 2) }.padding(7)
                            }.accessibilityLabel(stop.name)
                        }.annotationTitles(.hidden)
                    }
                }
                ForEach(vehicles.filter(\.operating)) { vehicle in
                    Annotation(vehicle.name, coordinate: coordinate(vehicle.coordinate)) {
                        Button { selectedVehicle = vehicle.id; selectedStop = nil; expanded = false } label: {
                            Group {
                                if vehicle.directionID == "line1_cw" { Text("↻").font(.system(size: 30, weight: .medium)) }
                                else if vehicle.directionID == "line2_ccw" { Text("↺").font(.system(size: 30, weight: .medium)) }
                                else { Image(systemName: "bus").font(.title3) }
                            }.foregroundStyle(vehicle.isFresh(at: context.date) ? routeColor(vehicle.routeID) : .gray)
                                .frame(width: 40, height: 40).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 13))
                                .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(vehicle.isFresh(at: context.date) ? routeColor(vehicle.routeID) : .gray, lineWidth: 2) }
                        }.accessibilityLabel(vehicle.name + (vehicle.isFresh(at: context.date) ? "" : "，位置已过期"))
                    }.annotationTitles(.hidden)
                }
                if let point = ownPoint {
                    Annotation("我的位置", coordinate: coordinate(point)) {
                        Circle().fill(.blue).frame(width: 14, height: 14).overlay { Circle().strokeBorder(.white, lineWidth: 3) }.padding(12).background(.blue.opacity(0.12), in: Circle())
                    }.annotationTitles(.hidden)
                }
            }.mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .onTapGesture { selectedStop = nil; selectedVehicle = nil }
                .simultaneousGesture(DragGesture(minimumDistance: 10).onChanged { _ in following = false })
        }
    }
    private var nearestCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Image(systemName: "mappin"); Text(store.mode == .demo ? "示例站台" : "附近站台") }.font(.caption2).foregroundStyle(.secondary)
            if nearby.isEmpty {
                Button("选择站台") { showStops = true }.font(.subheadline.weight(.semibold))
            } else {
                ForEach(Array(nearby.enumerated()), id: \.offset) { index, stop in
                    let direction = index == 0 ? "line1_cw" : "line2_ccw"
                    Button { selectedStop = stop.id; selectedVehicle = nil; expanded = false } label: {
                        HStack(spacing: 8) {
                            Text(index == 0 ? "↻" : "↺").font(.title3).foregroundStyle(routeColor(index == 0 ? "line1" : "line2"))
                            VStack(alignment: .leading, spacing: 3) { Text(stop.name).font(.caption.weight(.semibold)).foregroundStyle(.primary).lineLimit(2); Text(index == 0 ? "1路 · 内环" : "2路 · 外环").font(.caption2).foregroundStyle(.secondary) }
                            Spacer(minLength: 4)
                            arrivalValue((arrivals[stop.id] ?? []).filter { $0.directionID == direction }.min { arrivalDate($0) < arrivalDate($1) })
                        }
                    }.buttonStyle(.plain)
                }
            }
        }.padding(13).frame(maxWidth: 265).background(Color.campusPaper.opacity(0.97), in: RoundedRectangle(cornerRadius: 19)).shadow(color: .black.opacity(0.07), radius: 10, y: 4)
    }
    @ViewBuilder private var detailCard: some View {
        if let id = selectedVehicle, let vehicle = vehicles.first(where: { $0.id == id }) {
            let arrival = BusExperience.matchedArrival(vehicle: vehicle, arrivals: arrivals[vehicle.nextStopID] ?? [])
            VStack(alignment: .leading, spacing: 12) {
                detailTitle(routeTitle(vehicle.routeID, vehicle.directionID))
                Text("下一站").font(.caption).foregroundStyle(.secondary)
                HStack { Text(vehicle.nextStop.isEmpty ? "—" : vehicle.nextStop).font(.headline); Spacer(); arrivalValue(vehicle.isFresh(at: .now) ? arrival : nil) }
                if !vehicle.isFresh(at: .now) { Text("位置已过期").font(.caption2).foregroundStyle(.secondary) }
            }.padding(17).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 20)).shadow(color: .black.opacity(0.10), radius: 15, y: 5)
        } else if let id = selectedStop, let stop = stops.first(where: { $0.id == id }) {
            VStack(alignment: .leading, spacing: 12) {
                detailTitle(stop.name)
                let values = earliest(arrivals[id] ?? [])
                if values.isEmpty { Text("—").font(.title2) }
                ForEach(values) { value in HStack { Text(routeTitle(value.routeID, value.directionID)).font(.subheadline); Spacer(); arrivalValue(value) } }
            }.padding(17).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 20)).shadow(color: .black.opacity(0.10), radius: 15, y: 5)
        }
    }
    private func detailTitle(_ title: String) -> some View {
        HStack { Text(title).font(.headline); Spacer(); Button { selectedStop = nil; selectedVehicle = nil } label: { Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary) }.accessibilityLabel("关闭详情") }
    }
    @ViewBuilder private func arrivalValue(_ value: BusArrival?) -> some View {
        if let value, value.reason.isEmpty, value.source == "real_time", let minutes = value.minutes, minutes >= 0 {
            HStack(alignment: .firstTextBaseline, spacing: 2) { Text("\(minutes)").font(.title3.bold()).monospacedDigit(); Text("分钟").font(.caption2).foregroundStyle(.secondary) }
        } else if let value, value.reason.isEmpty, value.source == "planned", let date = BusMapParser.date(value.planned) {
            VStack(alignment: .trailing, spacing: 2) { Text(CampusClock.format(date, "HH:mm")).font(.subheadline.weight(.semibold)).monospacedDigit(); Text("计划").font(.caption2).foregroundStyle(.secondary) }
        } else { Text("—").font(.title3).foregroundStyle(.secondary) }
    }
    private func earliest(_ values: [BusArrival]) -> [BusArrival] {
        let available = values.filter { value in
            guard value.reason.isEmpty else { return false }
            if value.source == "real_time" { return (value.minutes ?? -1) >= 0 }
            return value.source == "planned" && (BusMapParser.date(value.planned) ?? .distantPast) >= .now
        }
        let grouped = Dictionary(grouping: available, by: { $0.routeID + "|" + $0.directionID })
        return grouped.keys.sorted().compactMap { grouped[$0]?.min { arrivalDate($0) < arrivalDate($1) } }
    }
    private func arrivalDate(_ value: BusArrival) -> Date {
        if value.source == "real_time", let minutes = value.minutes { return .now.addingTimeInterval(Double(minutes) * 60) }
        return BusMapParser.date(value.planned) ?? .distantFuture
    }
    private func routeTitle(_ route: String, _ direction: String) -> String {
        if direction == "line1_cw" { return "↻ 1路 · 内环" }
        if direction == "line2_ccw" { return "↺ 2路 · 外环" }
        let line = routes.first { $0.id == route }
        return (line?.name ?? route) + " · " + (line?.directions.first { $0.id == direction }?.name ?? "")
    }
    private func routeColor(_ id: String) -> Color {
        var hex = routes.first { $0.id == id }?.color.replacingOccurrences(of: "#", with: "") ?? ""
        if hex.count == 3 { hex = hex.map { "\($0)\($0)" }.joined() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return .campusGreen }
        return Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
    private func scheduleDrawer(height: CGFloat) -> some View {
        VStack(spacing: 14) {
            Button { setExpanded(!expanded) } label: {
                VStack(spacing: 12) {
                    Capsule().fill(.gray.opacity(0.3)).frame(width: 32, height: 4)
                    HStack { Text("发车时刻表").font(.subheadline.weight(.semibold)); Spacer(); Text("今天 · 计划").font(.caption2).foregroundStyle(.secondary); Image(systemName: expanded ? "chevron.down" : "chevron.up").font(.caption).foregroundStyle(Color.campusOrange) }
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityValue(expanded ? "已展开" : "已收起")
            .gesture(DragGesture(minimumDistance: 8).updating($drawerDrag) { value, state, transaction in transaction.disablesAnimations = true; state = value.translation.height }.onEnded { value in setExpanded(value.predictedEndTranslation.height < -30 || (expanded && value.predictedEndTranslation.height < 40)) })
            if expanded || drawerDrag < -20 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack { filterButton("全部", ""); ForEach(routes) { route in filterButton(route.name, route.id) } }
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(schedules.filter { routeFilter.isEmpty || $0.routeID == routeFilter }) { group in
                                Text(routeTitle(group.routeID, group.directionID)).font(.subheadline.weight(.semibold))
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 66))], spacing: 8) {
                                    ForEach(group.times) { time in
                                        let state = time.phase(at: .now)
                                        Text(time.time).font(.subheadline.weight(state == .recent ? .bold : .regular)).monospacedDigit()
                                            .foregroundStyle(state == .recent ? Color.campusOrange : state == .past ? .secondary : Color.campusGreen)
                                            .frame(maxWidth: .infinity).padding(.vertical, 9)
                                            .background(state == .recent ? Color.campusOrange.opacity(0.12) : Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10)).id(time.id)
                                    }
                                }
                            }
                            if schedules.isEmpty { Text("暂无时刻表").font(.subheadline).foregroundStyle(.secondary) }
                        }.padding(.bottom, 20)
                    }.onAppear { if let group = schedules.first(where: { routeFilter.isEmpty || $0.routeID == routeFilter }), let time = group.times.first(where: { $0.phase(at: .now) != .past }) { proxy.scrollTo(time.id, anchor: .top) } }
                }
            }
            Spacer(minLength: 0)
        }.padding(18).frame(maxWidth: .infinity).frame(height: height, alignment: .top)
            .background(Color.campusPaper, in: UnevenRoundedRectangle(topLeadingRadius: 25, topTrailingRadius: 25)).shadow(color: .black.opacity(0.07), radius: 17, y: -3)
    }
    private func filterButton(_ title: String, _ id: String) -> some View {
        Button { routeFilter = id } label: { Text(title).font(.caption).padding(.horizontal, 14).padding(.vertical, 8).foregroundStyle(routeFilter == id ? Color.campusOrange : .secondary).background(routeFilter == id ? Color.campusOrange.opacity(0.12) : Color.primary.opacity(0.04), in: Capsule()) }.buttonStyle(.plain)
    }
    private func setExpanded(_ value: Bool) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.9)) { expanded = value }
        if value { selectedStop = nil; selectedVehicle = nil }
    }
    private var stopChooser: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack { Text("选择站台").font(.headline); Spacer(); Button("关闭") { showStops = false } }
            ScrollView { LazyVStack(alignment: .leading) { ForEach(stops) { stop in Button { manualStop = stop.id; showStops = false; if let lat = stop.latitude, let lon = stop.longitude, let point = BusCoordinate(latitude: lat, longitude: lon) { camera = .region(MKCoordinateRegion(center: coordinate(point), span: MKCoordinateSpan(latitudeDelta: 0.009, longitudeDelta: 0.010))) }; Task { await refreshArrivals() } } label: { Text(stop.name).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 10) } } } }
        }.padding(20).frame(maxWidth: 480).frame(maxHeight: 460).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 24)).padding(16)
    }
    private var settings: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { Text("地图设置").font(.headline); Spacer(); Button("关闭") { showSettings = false } }
            Toggle("国内底图对齐", isOn: $mainlandMap)
            Button("选择站台") { showSettings = false; showStops = true }
            Button("刷新") { showSettings = false; Task { await load(staticData: true) } }
            Link("数据与来源 · SUSTech CRA", destination: URL(string: "https://sustech.online/transport/bustimer.html")!)
            if let fetched { Text("更新于 " + fetched.formatted(date: .omitted, time: .shortened)).font(.caption).foregroundStyle(.secondary) }
        }.padding(22).frame(maxWidth: 440).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 24)).padding(18)
    }
    private func centerOnUser() {
        if let point = ownPoint { camera = .region(MKCoordinateRegion(center: coordinate(point), span: MKCoordinateSpan(latitudeDelta: 0.009, longitudeDelta: 0.010))) }
        else { camera = .region(campus) }
    }
    private func refreshArrivals() async {
        guard store.mode == .live else { return }
        let version = store.sessionRevision
        var ids = Set(nearby.map(\.id))
        if let selectedStop { ids.insert(selectedStop) }
        if let selectedVehicle, let vehicle = vehicles.first(where: { $0.id == selectedVehicle }), !vehicle.nextStopID.isEmpty { ids.insert(vehicle.nextStopID) }
        let api = client
        let values = await withTaskGroup(of: (String, [BusArrival]?).self, returning: [(String, [BusArrival]?)].self) { group in
            for id in ids { group.addTask { (id, try? await api.directArrivals(id)) } }
            var results: [(String, [BusArrival]?)] = []
            for await value in group { results.append(value) }
            return results
        }
        guard version == store.sessionRevision, store.mode == .live, !Task.isCancelled else { return }
        for (id, value) in values { if let value { arrivals[id] = value } else { arrivals[id] = [] } }
    }
    private func load(staticData: Bool) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        if store.mode == .demo { loadDemo(); return }
        let version = store.sessionRevision
        if staticData {
            async let a = try? client.mapRoutes(); async let b = try? client.stops(); async let c = try? client.schedules()
            let (lines, platforms, timetable) = await (a, b, c)
            guard version == store.sessionRevision, store.mode == .live, !Task.isCancelled else { return }
            if let lines { routes = lines }; if let platforms { stops = platforms }; if let timetable { schedules = timetable; scheduleDay = CampusClock.format(.now) }
        }
        do {
            let rows = try await client.vehicles()
            guard version == store.sessionRevision, store.mode == .live, !Task.isCancelled else { return }
            vehicles = rows; fetched = .now; message = nil
        } catch { if !Task.isCancelled { message = "刷新失败，点击设置重试"; arrivals = [:] } }
        await refreshArrivals()
    }
    private func loadDemo() {
        guard let url = Bundle.main.url(forResource: "bus-map-demo", withExtension: "json"), let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(WireValue.self, from: data) else { return }
        routes = (try? BusMapParser.routes(value["routes"])) ?? []
        if let scheduleURL = Bundle.main.url(forResource: "bus-schedules-demo", withExtension: "json"), let bytes = try? Data(contentsOf: scheduleURL), let scheduleValue = try? JSONDecoder().decode(WireValue.self, from: bytes) { schedules = (try? BusExperience.schedules(scheduleValue)) ?? [] }
        stops = value["stops"].rows.compactMap { row in
            guard !row["id"].text.isEmpty else { return nil }
            return BusStop(id: row["id"].text, name: row["group_name_zh"].text + row["name_zh"].text, directions: "示例站点", latitude: Double(row["latitude"].text), longitude: Double(row["longitude"].text))
        }
        let rows = value["vehicles"].rows.enumerated().map { index, row in row.replacing(["source_time": .number(Date.now.timeIntervalSince1970 - (index == 1 ? 300 : 10))]) }
        vehicles = (try? BusMapParser.vehicles(.array(rows))) ?? []; fetched = .now; message = nil
        for stop in nearby {
            let value: WireValue = .object(["arrivals": .array([
                .object(["route_id": .string("line1"), "route_direction_id": .string("line1_cw"), "route_name_zh": .string("1路"), "direction_name_zh": .string("内环"), "source": .string("real_time"), "eta_minutes": .integer(3)]),
                .object(["route_id": .string("line2"), "route_direction_id": .string("line2_ccw"), "route_name_zh": .string("2路"), "direction_name_zh": .string("外环"), "source": .string("real_time"), "eta_minutes": .integer(8)])])])
            arrivals[stop.id] = (try? BusClient.parseArrivals(value)) ?? []
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--smoke-bus-drawer") { expanded = true }
        if ProcessInfo.processInfo.arguments.contains("--smoke-bus-stop") { selectedStop = nearby.first?.id }
        if ProcessInfo.processInfo.arguments.contains("--smoke-bus-vehicle") { selectedVehicle = vehicles.first?.id }
        if ProcessInfo.processInfo.arguments.contains("--smoke-bus"), let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let check: [String: Any] = ["at": Date.now.timeIntervalSince1970, "routes": routes.count, "points": routes.flatMap { $0.directions.flatMap(\.points) }.count, "stops": stops.count, "vehicles": vehicles.count]
            if let data = try? JSONSerialization.data(withJSONObject: check) { try? data.write(to: directory.appendingPathComponent("smoke-bus-map.json"), options: .atomic) }
        }
        #endif
    }
}
