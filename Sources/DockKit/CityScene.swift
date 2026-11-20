import AppKit
import QuartzCore
import ConfigKit
import CityKit

private func color(_ hex: String) -> CGColor { (NSColor(hex: hex) ?? .systemTeal).cgColor }

@discardableResult
private func pixel(_ parent: CALayer, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ hex: String) -> CALayer {
    let layer = CALayer()
    layer.frame = CGRect(x: x, y: y, width: max(0, w), height: max(0, h))
    layer.backgroundColor = color(hex)
    layer.magnificationFilter = .nearest
    parent.addSublayer(layer)
    return layer
}

/// Cached vector pixel art. Only lights/clock and actor positions change over time.
final class CityScene {
    let root = CALayer()
    private let sky = CAGradientLayer()
    private let street = CALayer()
    private let buildings = CALayer()
    private let population = CALayer()
    private var nodes: [String: BuildingNode] = [:]
    private var citizenLayers: [CALayer] = []
    private var carLayers: [CALayer] = []
    private var simulation = CitySimulation()
    private var settings = CitySettings()
    private var night = false
    private var streetKey = ""
    private var hoveredID: String?

    init() {
        root.masksToBounds = true
        sky.name = "sky"; buildings.name = "buildings"
        root.addSublayer(sky)
        root.addSublayer(street); root.addSublayer(buildings); root.addSublayer(population)
    }

    func configure(tiles: [CityTile], settings: CitySettings, night: Bool, scale: CGFloat, plazas: [ClosedRange<Double>] = []) {
        let themeChanged = self.night != night
        self.settings = settings; self.night = night
        if settings.reduceMotion { root.removeAnimation(forKey: "theme") }
        let w = root.bounds.width, h = root.bounds.height
        sky.frame = root.bounds; sky.isHidden = settings.background == .transparent
        let opacity: CGFloat = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency ? 1 : 0.86
        sky.colors = (night ? ["#263856", "#5B6C84"] : ["#B9DEEA", "#E1EAD9"]).map {
            (NSColor(hex: $0) ?? .windowBackgroundColor).withAlphaComponent(opacity).cgColor
        }
        let key = "\(w):\(h):\(night):\(settings.decorations):\(plazas)"
        if streetKey != key {
            if themeChanged && !streetKey.isEmpty && !settings.reduceMotion {
                let fade = CATransition(); fade.type = .fade; fade.duration = 0.4
                root.add(fade, forKey: "theme")
            }
            streetKey = key; street.sublayers?.forEach { $0.removeFromSuperlayer() }
            pixel(street, 0, 0, w, 10, night ? "#39485D" : "#687785")
            pixel(street, 0, 10, w, 6, night ? "#586171" : "#D5C6AA")
            pixel(street, 0, 15, w, 1, "#F1DEB5")
            for x in stride(from: CGFloat(6), to: w, by: 19) { pixel(street, x, 4, 8, 1, "#E7DDBD") }
            for plaza in plazas {
                pixel(street, CGFloat(plaza.lowerBound), 0, CGFloat(plaza.upperBound - plaza.lowerBound), 16, night ? "#747B87" : "#D4C9B5")
            }
            if settings.decorations {
                for x in stride(from: CGFloat(10), to: w, by: 115) {
                    pixel(street, x, 15, 2, 19, "#475568")
                    pixel(street, x - 3, 32, 8, 2, "#475568")
                    let lamp = pixel(street, x - 2, 29, 6, 4, night ? "#FFE5A0" : "#DBD6BB")
                    if night { lamp.shadowColor = color("#FFD287"); lamp.shadowOpacity = 0.6; lamp.shadowRadius = 4 }
                    pixel(street, x + 11, 15, 5, 5, "#AD7354")
                    pixel(street, x + 9, 20, 9, 8, "#5E8E64")
                    pixel(street, x + 11, 27, 5, 4, "#81A875")
                }
            }
        }
        let valid = Set(tiles.map(\.id))
        for (id, node) in nodes where !valid.contains(id) { node.layer.removeFromSuperlayer(); nodes[id] = nil }
        let ordered = tiles.sorted { $0.center < $1.center }
        for (i, tile) in ordered.enumerated() {
            let override = tile.bundleID.flatMap { settings.buildings[$0] }
            let mapped = BuildingStyle.defaultStyle(bundleID: tile.bundleID)
            let style = override?.style ?? (mapped == .office ? settings.defaultStyle : mapped)
            let variation = mapped == .office && override?.style == nil ? BuildingVariation(identity: tile.bundleID ?? tile.id) : nil
            let nodeKey = "\(style.rawValue):\(override?.color ?? ""): \(night):\(String(describing: variation))"
            let node: BuildingNode
            if let old = nodes[tile.id], old.key == nodeKey { node = old }
            else {
                nodes[tile.id]?.layer.removeFromSuperlayer()
                node = BuildingNode(style: style, tint: override?.color ?? variation?.color, night: night, key: nodeKey, variation: variation)
                node.layer.name = tile.id
                nodes[tile.id] = node; buildings.addSublayer(node.layer)
            }
            let leftGap = i > 0 ? tile.center - ordered[i - 1].center : tile.width + 8
            let rightGap = i + 1 < ordered.count ? ordered[i + 1].center - tile.center : tile.width + 8
            let width = max(1, min(tile.width, leftGap - 3, rightGap - 3))
            node.layer.contentsScale = scale
            let sx = CGFloat(width) / 60
            let sy = max(0.01, (h - 25) / 78)
            node.layer.setAffineTransform(CGAffineTransform(scaleX: sx, y: sy))
            let target = CGPoint(x: CGFloat(tile.center), y: 16)
            if node.layer.position != target && !settings.reduceMotion {
                let move = CABasicAnimation(keyPath: "position")
                move.fromValue = node.layer.presentation()?.position ?? node.layer.position
                move.toValue = target; move.duration = 0.08
                node.layer.add(move, forKey: "reorder")
            }
            node.layer.position = target
            node.setActivity(tile.activity, intensity: settings.lightIntensity, reduceMotion: settings.reduceMotion)
            node.setHovered(tile.id == hoveredID, reduced: settings.reduceMotion)
        }
        simulation.configure(width: Double(w), settings: settings, night: night)
        simulation.activate(tiles.first { $0.activity == .active })
        resizeActors()
        update(seconds: 0, date: Date(), animate: false)
    }

    func launch(tileIDs: Set<String>) {
        guard !settings.reduceMotion else { return }
        for id in tileIDs { nodes[id]?.launch() }
    }
    func hover(tileID: String?) {
        hoveredID = tileID
        for (id, node) in nodes { node.setHovered(id == tileID, reduced: settings.reduceMotion) }
    }
    private func resizeActors() {
        while citizenLayers.count > simulation.citizens.count { citizenLayers.removeLast().removeFromSuperlayer() }
        while carLayers.count > simulation.vehicles.count { carLayers.removeLast().removeFromSuperlayer() }
        while citizenLayers.count < simulation.citizens.count {
            let layer = CALayer(); population.addSublayer(layer)
            let i = citizenLayers.count
            pixel(layer, -2, 5, 4, 4, "#E9B48F")
            pixel(layer, -2, 8, 4, 2, i % 2 == 0 ? "#554050" : "#D0A276")
            pixel(layer, -2, 1, 4, 4, ["#7CA7BA", "#DE967B", "#9BA873"][i % 3])
            pixel(layer, -2, -2, 1, 3, "#35445B"); pixel(layer, 1, -2, 1, 3, "#35445B")
            citizenLayers.append(layer)
            layer.setAffineTransform(CGAffineTransform(scaleX: 1.25, y: 1.25))
        }
        while carLayers.count < simulation.vehicles.count {
            let layer = CALayer(); population.addSublayer(layer)
            let delivery = simulation.vehicles[carLayers.count].delivery
            pixel(layer, -8, 0, 16, 5, delivery ? "#DFA263" : "#C57C89")
            pixel(layer, -5, 5, delivery ? 10 : 8, delivery ? 6 : 4, delivery ? "#F0D5A4" : "#83B5C4")
            pixel(layer, 5, 2, 3, 4, "#8AB3C0")
            pixel(layer, -6, -2, 3, 3, "#253348"); pixel(layer, 4, -2, 3, 3, "#253348")
            pixel(layer, 7, 1, 2, 2, night ? "#FFF0AF" : "#E2C794")
            carLayers.append(layer)
        }
        // Headlights update when daylight changes without rebuilding the car bodies.
        for car in carLayers { car.sublayers?.last?.backgroundColor = color(night ? "#FFF0AF" : "#E2C794") }
    }

    func update(seconds: Double, date: Date, animate: Bool) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        simulation.step(seconds: night ? seconds * 0.65 : seconds)
        for (actor, layer) in zip(simulation.citizens, citizenLayers) {
            let entering = actor.state == .enterBuilding ? 1 - actor.remaining / 0.5 : actor.state == .exitBuilding ? actor.remaining / 0.4 : 0
            layer.position = CGPoint(x: CGFloat(actor.x), y: 16 + CGFloat(max(0, entering)) * 5)
            layer.opacity = actor.state == .idle ? 0 : actor.state == .enterBuilding ? 0.4 : 1
            if let legs = layer.sublayers?.suffix(2), legs.count == 2 {
                for (i, leg) in legs.enumerated() {
                    leg.position.y = actor.state == .walk && Int(actor.phase * 7) % 2 == i ? -1 : 0
                }
            }
        }
        for (actor, layer) in zip(simulation.vehicles, carLayers) {
            layer.position = CGPoint(x: CGFloat(actor.x), y: 4)
            layer.opacity = actor.state == .idle ? 0 : 1
            layer.setAffineTransform(CGAffineTransform(scaleX: CGFloat(actor.direction) * 1.15, y: 1.15))
        }
        for node in nodes.values { node.tick(date: date, animate: animate) }
        CATransaction.commit()
    }
}

private final class BuildingNode {
    let layer = CALayer()
    let key: String
    private let style: BuildingStyle
    private let night: Bool
    private var windows: [CALayer] = []
    private var signal: CALayer?
    private var clockHands: [CALayer] = []
    private var state: BuildingActivity = .inactive
    private var initialized = false
    private var entrance: CALayer!
    private var truck: CALayer?
    private var hovered = false
    private var hoverStart = 0.0

    init(style: BuildingStyle, tint: String?, night: Bool, key: String, variation: BuildingVariation?) {
        self.key = key; self.style = style; self.night = night
        layer.bounds = CGRect(x: 0, y: 0, width: 60, height: 78)
        layer.anchorPoint = CGPoint(x: 0.5, y: 0)
        let colors: [BuildingStyle: String] = [.office: "#B7978C", .glassTower: "#71A8B7", .warehouse: "#C19A6B",
            .concertHall: "#BD7E8D", .clockTower: "#C6AD7B", .library: "#9BAA86", .shop: "#D5A180",
            .serverCenter: "#7F8BA2", .postOffice: "#B58279", .communications: "#8DA2B9", .gallery: "#C6B5A2"]
        let base = tint ?? colors[style] ?? "#B7978C"
        let body = night ? Self.nightColor(base) : base
        let tower = style == .glassTower || style == .clockTower || style == .communications
        let width: CGFloat = (tower ? 34 : 52) * CGFloat(variation?.width ?? 1)
        let x = (60 - width) / 2
        let height: CGFloat = (tower ? 65 : style == .warehouse || style == .shop ? 40 : 52) * CGFloat(variation?.height ?? 1)
        if let variation {
            for step in 0...variation.roof { pixel(layer, 18 + CGFloat(step * 4), height + CGFloat(step * 3), CGFloat(24 - step * 6), 3, "#73899A") }
        }
        pixel(layer, x + 2, 0, width, height, "#3F4D63")
        pixel(layer, x, 0, width, height, body).name = "facade"
        pixel(layer, x, height - 3, width, 3, "#E9CFA9")
        pixel(layer, x + 3, 0, 2, height - 3, night ? "#65738A" : "#E5CDB4")
        switch style {
        case .warehouse, .shop:
            for step in 0..<4 { pixel(layer, x + CGFloat(step * 5), height + CGFloat(step * 3), width - CGFloat(step * 10), 3, "#8B6869") }
            pixel(layer, 41, height + 5, 5, 13, "#735D60")
        case .glassTower:
            pixel(layer, 20, height, 20, 5, "#B7D0CF")
            pixel(layer, 29, height + 5, 2, 7, "#7999AC")
            signal = pixel(layer, 28, height + 11, 4, 2, "#DFA780")
        case .clockTower:
            pixel(layer, 19, height, 22, 6, "#7D7079")
            pixel(layer, 24, height + 6, 12, 4, "#7D7079")
            pixel(layer, 28, height + 10, 4, 3, "#D8B881")
            pixel(layer, 21, height - 21, 18, 18, "#F4E4C4")
            for length in [CGFloat(5), 7] {
                let hand = pixel(layer, 29, height - 12, 1, length, "#4C5365")
                hand.anchorPoint = CGPoint(x: 0.5, y: 0); hand.position = CGPoint(x: 30, y: height - 12)
                clockHands.append(hand)
            }
        case .concertHall:
            for i in 0..<5 { pixel(layer, 7 + CGFloat(i * 10), height, 7, CGFloat(5 + (i % 2) * 4), "#805C7B") }
            signal = pixel(layer, 15, height - 14, 30, 7, "#E5B985")
        case .library, .gallery:
            for step in 0..<4 { pixel(layer, x + CGFloat(step * 6), height + CGFloat(step * 2), width - CGFloat(step * 12), 2, "#D9C9AE") }
            for column in 0..<4 { pixel(layer, 8 + CGFloat(column * 13), 3, 3, height - 8, "#E5D7BC") }
        case .communications:
            pixel(layer, 28, height, 3, 11, "#A8C0C1")
            pixel(layer, 21, height + 5, 17, 2, "#DAB887")
        case .serverCenter:
            pixel(layer, 7, height, 14, 6, "#46526C")
            signal = pixel(layer, 45, height - 10, 3, 3, "#99D4B0")
        case .postOffice:
            pixel(layer, 20, height, 20, 5, "#D9B08C")
            pixel(layer, 25, height - 13, 10, 6, "#D9B08C")
        case .office:
            pixel(layer, 12, height, 36, 4, "#6D7285")
            pixel(layer, 39, height + 4, 7, 6, "#8C98A5")
        }
        let rows = style == .clockTower ? 3 : tower ? 5 : 3
        for row in 0..<rows {
            for col in 0..<3 {
                let wx = x + 6 + CGFloat(col) * (width - 10) / 3
                let wy = CGFloat(16 + row * 8)
                pixel(layer, wx - 1, wy - 1, 6, 6, "#46516A")
                windows.append(pixel(layer, wx, wy, 4, 4, "#6B8394"))
            }
        }
        pixel(layer, 24, 0, 12, 13, "#3D4A5F")
        entrance = pixel(layer, 26, 2, 8, 9, "#74848C")
        pixel(layer, 24, 13, 12, 2, "#D5BD98")
        if style == .warehouse {
            let vehicle = CALayer(); layer.addSublayer(vehicle); vehicle.position = CGPoint(x: 10, y: 1)
            pixel(vehicle, 0, 0, 12, 6, "#D7AE74"); pixel(vehicle, 9, 2, 5, 4, "#A2C2C9")
            pixel(vehicle, 1, -2, 3, 3, "#354258"); pixel(vehicle, 10, -2, 3, 3, "#354258")
            truck = vehicle
        }
    }

    private static func nightColor(_ hex: String) -> String {
        let digits = hex.replacingOccurrences(of: "#", with: "")
        guard var rgb = UInt32(digits, radix: 16), digits.count == 6 || digits.count == 8 else { return "#52617B" }
        if digits.count == 8 { rgb >>= 8 }
        return String(format: "#%02X%02X%02X", Int(Double((rgb >> 16) & 255) * 0.65),
                      Int(Double((rgb >> 8) & 255) * 0.65), Int(Double(rgb & 255) * 0.7))
    }
    func launch() {
        let bounce = CAKeyframeAnimation(keyPath: "transform.translation.y")
        bounce.values = [0, 7, 2, 0]; bounce.keyTimes = [0, 0.3, 0.65, 1]
        bounce.duration = 0.65; bounce.isAdditive = true
        layer.add(bounce, forKey: "launch")
    }
    func setHovered(_ value: Bool, reduced: Bool) {
        let next = value && !reduced
        if reduced {
            layer.removeAnimation(forKey: "launch"); layer.removeAnimation(forKey: "reorder")
            layer.removeAnimation(forKey: "hoverReturn")
        }
        guard next != hovered else { return }
        let localTime = layer.convertTime(CACurrentMediaTime(), from: nil)
        let phase = (max(0, localTime - hoverStart).truncatingRemainder(dividingBy: 0.9)) / 0.45
        let currentLift = hovered ? 2 * (phase <= 1 ? phase : 2 - phase) : 0
        hovered = next; layer.removeAnimation(forKey: "hover")
        if next {
            layer.removeAnimation(forKey: "hoverReturn")
            let lift = CABasicAnimation(keyPath: "transform.translation.y")
            lift.fromValue = 0; lift.toValue = 2; lift.duration = 0.45
            hoverStart = localTime; lift.beginTime = localTime
            lift.timingFunction = CAMediaTimingFunction(name: .linear)
            lift.autoreverses = true; lift.repeatCount = .infinity; lift.isAdditive = true
            layer.add(lift, forKey: "hover")
        } else if !reduced {
            let settle = CABasicAnimation(keyPath: "transform.translation.y")
            settle.fromValue = currentLift; settle.toValue = 0; settle.duration = 0.15; settle.isAdditive = true
            layer.add(settle, forKey: "hoverReturn")
        }
        layer.shadowOpacity = hovered ? 0.45 : state == .active ? 0.35 : 0
    }
    func setActivity(_ activity: BuildingActivity, intensity: Double, reduceMotion: Bool) {
        let changed = initialized && state != activity
        state = activity; initialized = true
        for (i, window) in windows.enumerated() {
            if reduceMotion { window.removeAnimation(forKey: "activity") }
            let lit = activity == .active || (activity == .running && i % 3 != 0)
            let target = lit ? color(night ? "#FFE2A0" : "#F5D7A1") : color(night ? "#344159" : "#6F98AB")
            if changed && !reduceMotion {
                let anim = CABasicAnimation(keyPath: "backgroundColor")
                anim.fromValue = window.presentation()?.backgroundColor ?? window.backgroundColor
                anim.toValue = target; anim.duration = activity == .inactive ? 0.5 : 0.3
                anim.beginTime = CACurrentMediaTime() + (activity == .inactive ? 0 : Double(i) * 0.025)
                anim.fillMode = .backwards
                window.add(anim, forKey: "activity")
            }
            window.backgroundColor = target
            window.opacity = lit ? Float(min(1, max(0.2, intensity))) : 1
        }
        entrance.backgroundColor = color(activity == .active ? "#FFE2A0" : activity == .running ? "#C5AA7A" : "#526477")
        layer.shadowColor = color("#FFD999"); layer.shadowOpacity = hovered ? 0.45 : activity == .active ? 0.35 : 0
        layer.shadowRadius = 3; layer.shadowOffset = .zero
        truck?.isHidden = activity == .inactive
    }

    func tick(date: Date, animate: Bool) {
        if style == .clockTower, clockHands.count == 2 {
            let c = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
            let minute = Double(c.minute ?? 0) + Double(c.second ?? 0) / 60
            let hour = Double((c.hour ?? 0) % 12) + minute / 60
            clockHands[0].setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(-hour / 12 * 2 * .pi)))
            clockHands[1].setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(-minute / 60 * 2 * .pi)))
        }
        if let signal {
            let pulse = animate && state != .inactive
            signal.opacity = state == .inactive ? 0.2 : pulse ? (Int(date.timeIntervalSince1970 * (state == .active ? 4 : 2)) % 2 == 0 ? 1 : 0.6) : 1
        }
        if let truck, animate, state != .inactive {
            truck.position.x = 8 + CGFloat(sin(date.timeIntervalSince1970)) * 3
        }
    }
}
