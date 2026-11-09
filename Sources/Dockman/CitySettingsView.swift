import AppKit
import SwiftUI
import ConfigKit

/// Uses the same mutate → JSON store → reconcile pipeline as upstream settings.
struct CitySettingsSection: View {
    @ObservedObject var controller: DockmanController
    let dockID: UUID

    private func binding<T>(_ key: WritableKeyPath<CitySettings, T>) -> SwiftUI.Binding<T> {
        SwiftUI.Binding(get: { (controller.dock(dockID)?.city ?? CitySettings())[keyPath: key] }, set: { value in
            guard var settings = controller.dock(dockID)?.city else { return }
            settings[keyPath: key] = value; controller.setCity(dockID, settings)
        })
    }

    var body: some View {
        Section("Dock City · Pixel Town") {
            Toggle("Enable Dock City", isOn: binding(\.enabled))
            Toggle("Show city decorations", isOn: binding(\.decorations))
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
            Toggle("Citizens enabled", isOn: binding(\.citizensEnabled))
            Picker("Citizen density", selection: binding(\.citizenDensity)) {
                ForEach(CitySettings.Density.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            Toggle("Traffic enabled", isOn: binding(\.trafficEnabled))
            Picker("Traffic density", selection: binding(\.trafficDensity)) {
                ForEach(CitySettings.Density.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
        }
        Section("City performance") {
            Picker("Animation quality", selection: binding(\.quality)) {
                ForEach(CitySettings.Quality.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            Toggle("Reduce motion", isOn: binding(\.reduceMotion))
            Toggle("Low power mode", isOn: binding(\.lowPower))
            Toggle("Pause when not visible", isOn: binding(\.pauseWhenNotVisible))
        }
        Section("Buildings") {
            ForEach(apps, id: \.id) { app in
                BuildingSettingsRow(name: app.name, bundleID: app.id, settings: binding(\.buildings))
            }
            Button("Restore building defaults") { binding(\.buildings).wrappedValue = [:] }
        }
    }

    private var apps: [(id: String, name: String)] {
        let pinned = controller.dock(dockID)?.items.compactMap(\.appPath) ?? []
        let running = controller.activity.snapshot().compactMap(\.bundlePath)
        var seen = Set<String>()
        return (pinned + running).compactMap { path in
            guard let id = Bundle(path: path)?.bundleIdentifier, seen.insert(id).inserted else { return nil }
            return (id, (path as NSString).lastPathComponent.replacingOccurrences(of: ".app", with: ""))
        }.sorted { $0.name < $1.name }
    }
}

private struct BuildingSettingsRow: View {
    let name: String
    let bundleID: String
    @SwiftUI.Binding var settings: [String: BuildingOverride]
    private let palette = ["Default", "#B7978C", "#71A8B7", "#C19A6B", "#BD7E8D", "#9BAA86", "#7F8BA2"]

    var body: some View {
        VStack(alignment: .leading) {
            Text(name)
            HStack {
                Picker("Building", selection: SwiftUI.Binding(
                    get: { settings[bundleID]?.style?.rawValue ?? "automatic" },
                    set: { value in
                        var entry = settings[bundleID] ?? BuildingOverride()
                        entry.style = BuildingStyle(rawValue: value); settings[bundleID] = entry
                    })) {
                    Text("Automatic").tag("automatic")
                    ForEach(BuildingStyle.allCases, id: \.self) { Text($0.rawValue).tag($0.rawValue) }
                }
                Picker("Color", selection: SwiftUI.Binding(
                    get: { settings[bundleID]?.color ?? "Default" },
                    set: { value in
                        var entry = settings[bundleID] ?? BuildingOverride()
                        entry.color = value == "Default" ? nil : value; settings[bundleID] = entry
                    })) {
                    ForEach(palette, id: \.self) { Text($0).tag($0) }
                }
            }
        }
    }
}
