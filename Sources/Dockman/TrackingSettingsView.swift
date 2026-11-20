import AppKit
import SwiftUI
import ConfigKit
import DockKit

struct TrackingSettingsView: View {
    @ObservedObject var controller: DockCityController
    private func binding<T>(_ key: WritableKeyPath<CitySettings, T>) -> SwiftUI.Binding<T> {
        SwiftUI.Binding(get: { controller.config.city[keyPath: key] }, set: { value in
            var city = controller.config.city; city[keyPath: key] = value; controller.setCity(city)
        })
    }
    var body: some View {
        Form {
            Section("macOS Dock tracking") {
                Text(controller.status).accessibilityLabel("Tracking status: \(controller.status)")
                Text("Dock City decorates your existing Dock. Manage apps, position, size, magnification and auto-hide in macOS Dock settings.")
                    .font(.callout).foregroundStyle(.secondary)
                Button("Allow Accessibility access") { DockAccessibility.requestTrust() }
                Button("Open Accessibility settings…") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") { NSWorkspace.shared.open(url) }
                }
                Text("Accessibility is used to read Dock item positions and app URLs. Mouse input passes through the city to macOS.")
                    .font(.caption).foregroundStyle(.secondary)
                Toggle("Enable city", isOn: binding(\.enabled))
                Toggle("Launch at login", isOn: SwiftUI.Binding(get: { controller.config.global.launchAtLogin }, set: controller.setLaunchAtLogin))
                if let error = controller.saveError { Text(error).foregroundStyle(.red) }
            }
            Section("Appearance") {
                Picker("City background", selection: binding(\.background)) {
                    Text("Translucent sky").tag(CitySettings.Background.sky)
                    Text("Transparent").tag(CitySettings.Background.transparent)
                }
                Toggle("Street decorations", isOn: binding(\.decorations))
                Picker("City size", selection: binding(\.size)) {
                    ForEach(CitySettings.Size.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                Picker("Day / Night", selection: binding(\.timeMode)) {
                    ForEach(CitySettings.TimeMode.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                LabeledContent("Light intensity") { Slider(value: binding(\.lightIntensity), in: 0...1) }
                Picker("Default building", selection: binding(\.defaultStyle)) {
                    ForEach(BuildingStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
            }
            Section("Population") {
                Toggle("Citizens", isOn: binding(\.citizensEnabled))
                Picker("Citizen density", selection: binding(\.citizenDensity)) {
                    ForEach(CitySettings.Density.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                Toggle("Traffic", isOn: binding(\.trafficEnabled))
                Picker("Traffic density", selection: binding(\.trafficDensity)) {
                    ForEach(CitySettings.Density.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
            }
            Section("Performance") {
                Picker("Animation quality", selection: binding(\.quality)) {
                    ForEach(CitySettings.Quality.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                Toggle("Reduce motion", isOn: binding(\.reduceMotion))
                Toggle("Low power mode", isOn: binding(\.lowPower))
                Text("The city pauses while the Dock is hidden or the display is asleep.").font(.caption)
            }
            Section("Buildings in the real Dock") {
                ForEach(controller.tracker.applications.keys.sorted(), id: \.self) { id in
                    building(id)
                }
                Button("Restore building defaults") { var city = controller.config.city; city.buildings = [:]; controller.setCity(city) }
            }
        }.formStyle(.grouped).frame(minWidth: 480, minHeight: 560)
    }

    private func building(_ id: String) -> some View {
        VStack(alignment: .leading) {
            Text(controller.tracker.applications[id].flatMap { $0.isEmpty ? nil : $0 } ?? id)
            Picker("Building", selection: SwiftUI.Binding(get: { controller.config.city.buildings[id]?.style?.rawValue ?? "automatic" }, set: { value in
                var city = controller.config.city
                var entry = city.buildings[id] ?? BuildingOverride()
                entry.style = BuildingStyle(rawValue: value); city.buildings[id] = entry; controller.setCity(city)
            })) {
                Text("Automatic").tag("automatic")
                ForEach(BuildingStyle.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            Picker("Color", selection: SwiftUI.Binding(get: { controller.config.city.buildings[id]?.color ?? "Default" }, set: { value in
                var city = controller.config.city
                var entry = city.buildings[id] ?? BuildingOverride()
                entry.color = value == "Default" ? nil : value; city.buildings[id] = entry; controller.setCity(city)
            })) {
                ForEach(["Default", "#B7978C", "#71A8B7", "#C19A6B", "#BD7E8D", "#9BAA86", "#7F8BA2"], id: \.self) { Text($0).tag($0) }
            }
        }
    }
}
