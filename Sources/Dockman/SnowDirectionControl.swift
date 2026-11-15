import SwiftUI
import ConfigKit

/// The preview updates during a drag; releasing commits one settings write.
struct SnowDirectionControl: View {
    @SwiftUI.Binding var vector: SnowFallVector
    var paused = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draft: SnowFallVector?
    private var current: SnowFallVector { draft ?? vector }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Snow direction & speed").font(.headline)
            HStack(spacing: 16) {
                TimelineView(.animation(minimumInterval: 1 / 30, paused: paused || reduceMotion || current.speed < 0.01)) { timeline in
                    Canvas { context, size in
                        let center = CGPoint(x: size.width / 2, y: size.height / 2)
                        let radius = min(size.width, size.height) / 2 - 12
                        let circle = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                        context.fill(Path(ellipseIn: circle), with: .color(.primary.opacity(0.06)))
                        context.stroke(Path(ellipseIn: circle), with: .color(.secondary.opacity(0.5)), lineWidth: 1)
                        var axes = Path()
                        axes.move(to: CGPoint(x: center.x - radius, y: center.y)); axes.addLine(to: CGPoint(x: center.x + radius, y: center.y))
                        axes.move(to: CGPoint(x: center.x, y: center.y - radius)); axes.addLine(to: CGPoint(x: center.x, y: center.y + radius))
                        context.stroke(axes, with: .color(.secondary.opacity(0.25)), lineWidth: 1)
                        var snowContext = context; snowContext.clip(to: Path(ellipseIn: circle))
                        let time = paused || reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 3600)
                        func wrapped(_ value: Double, span: Double) -> Double {
                            let r = value.truncatingRemainder(dividingBy: span); return r >= 0 ? r : r + span
                        }
                        for i in 0..<16 {
                            let x = circle.minX + wrapped(Double(i * 47) + time * current.x * 0.4, span: Double(circle.width))
                            let y = circle.minY + wrapped(Double(i * 73) + time * current.y * 0.4, span: Double(circle.height))
                            snowContext.fill(Path(ellipseIn: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3)), with: .color(.cyan.opacity(0.7)))
                        }
                        let end = CGPoint(x: center.x + current.x / SnowFallVector.maximumSpeed * radius,
                                          y: center.y + current.y / SnowFallVector.maximumSpeed * radius)
                        if current.speed > 0.01 {
                            var arrow = Path(); arrow.move(to: center); arrow.addLine(to: end)
                            let angle = atan2(end.y - center.y, end.x - center.x)
                            let headLength = min(10, hypot(end.x - center.x, end.y - center.y) * 0.6)
                            for delta in [-0.5, 0.5] {
                                arrow.move(to: CGPoint(x: end.x - cos(angle + delta) * headLength, y: end.y - sin(angle + delta) * headLength))
                                arrow.addLine(to: end)
                            }
                            context.stroke(arrow, with: .color(.accentColor), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        }
                        context.fill(Path(ellipseIn: CGRect(x: end.x - 4, y: end.y - 4, width: 8, height: 8)), with: .color(.accentColor))
                    }
                }
                .frame(width: 180, height: 180)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    draft = SnowFallVector.fromControl(x: value.location.x - 90, y: value.location.y - 90, radius: 78)
                }.onEnded { value in
                    vector = SnowFallVector.fromControl(x: value.location.x - 90, y: value.location.y - 90, radius: 78)
                    draft = nil
                })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Snow direction arrow")
                .accessibilityValue(Text("Horizontal \(current.x, specifier: "%.0f"), vertical \(current.y, specifier: "%.0f"), speed \(current.speed, specifier: "%.0f") points per second"))
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment: vector = vector.rotated(degrees: 15)
                    case .decrement: vector = vector.rotated(degrees: -15)
                    @unknown default: break
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Drag the arrow. Direction sets travel; length sets speed. Release to apply.").font(.caption)
                    Text("X \(current.x, specifier: "%.0f") · Y \(current.y, specifier: "%.0f") pt/s").monospacedDigit()
                    HStack {
                        preset("←", label: "Snow to the left", x: -1, y: 0)
                        preset("↓", label: "Snow downward", x: 0, y: 1)
                        preset("→", label: "Snow to the right", x: 1, y: 0)
                        preset("↑", label: "Snow upward", x: 0, y: -1)
                    }
                    HStack {
                        preset("↙", label: "Snow down and left", x: -1, y: 1)
                        preset("↘", label: "Snow down and right", x: 1, y: 1)
                        Button("Reset") { vector = SnowFallVector() }
                    }
                }
            }
            LabeledContent("Travel speed") {
                Slider(value: SwiftUI.Binding(get: { vector.speed }, set: { vector = vector.withSpeed($0) }), in: 0...SnowFallVector.maximumSpeed)
            }
            Text("Top edges collect downward snow. Sideways/upward flow is supported; detached snow still falls under gravity.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func preset(_ symbol: String, label: String, x: Double, y: Double) -> some View {
        Button(symbol) { vector = SnowFallVector(x: x, y: y).withSpeed(vector.speed > 0.01 ? vector.speed : 32) }
            .accessibilityLabel(label)
    }
}
