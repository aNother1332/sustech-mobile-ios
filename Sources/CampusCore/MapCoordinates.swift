import Foundation

/// The CRA GeoJSON is WGS-84 (MapLibre). Mainland Apple maps use GCJ-02.
/// Convert only at the presentation boundary; retain source coordinates for APIs/distances.
public extension BusCoordinate {
    var gcj02: BusCoordinate {
        guard (72.004...137.8347).contains(longitude), (0.8293...55.8271).contains(latitude) else { return self }
        let x = longitude - 105, y = latitude - 35, pi = Double.pi
        var lat = -100 + 2*x + 3*y + 0.2*y*y + 0.1*x*y + 0.2*sqrt(abs(x))
        lat += (20*sin(6*x*pi) + 20*sin(2*x*pi))*2/3
        lat += (20*sin(y*pi) + 40*sin(y*pi/3))*2/3
        lat += (160*sin(y*pi/12) + 320*sin(y*pi/30))*2/3
        var lon = 300 + x + 2*y + 0.1*x*x + 0.1*x*y + 0.1*sqrt(abs(x))
        lon += (20*sin(6*x*pi) + 20*sin(2*x*pi))*2/3
        lon += (20*sin(x*pi) + 40*sin(x*pi/3))*2/3
        lon += (150*sin(x*pi/12) + 300*sin(x*pi/30))*2/3
        let rad = latitude / 180 * pi
        let magic = 1 - 0.00669342162296594323 * pow(sin(rad), 2)
        let root = sqrt(magic)
        lat = lat * 180 / ((6378245 * (1 - 0.00669342162296594323)) / (magic * root) * pi)
        lon = lon * 180 / (6378245 / root * cos(rad) * pi)
        return BusCoordinate(latitude: latitude + lat, longitude: longitude + lon) ?? self
    }
}
