import Foundation
import ManagedPreferencesKit
import SwiftUI

@propertyWrapper
@MainActor
public struct ManagedValue<Namespace, Value>: @MainActor DynamicProperty where Value: ManagedPreferenceValue {
    @StateObject private var observer: ManagedPreferenceObserver<Namespace, Value>

    @MainActor public var wrappedValue: Value {
        observer.value
    }

    @MainActor public var projectedValue: ManagedPreferenceResolution<Namespace, Value> {
        observer.resolution
    }

    public init(
        for preference: ManagedPreference<Namespace, Value>,
        schema: ManagedPreferencesSchema<Namespace>,
        default fallback: Value
    ) {
        _observer = StateObject(
            wrappedValue: ManagedPreferenceObserver(
                preference: preference,
                reader: schema.reader(),
                fallback: fallback
            )
        )
    }

    @MainActor public mutating func update() {
        observer.startObserving()
        observer.refresh()
    }
}

@MainActor
private final class ManagedPreferenceObserver<Namespace, Value>: ObservableObject where Value: ManagedPreferenceValue {
    @Published private(set) var resolution: ManagedPreferenceResolution<Namespace, Value>

    private let preference: ManagedPreference<Namespace, Value>
    private let reader: ManagedPreferenceReader<Namespace>
    private let fallback: Value
    private var hasStartedObserving = false
    private var observation: ManagedPreferenceObservation?
    private var snapshot: ManagedPreferenceObservationSnapshot

    var value: Value {
        resolution.value ?? fallback
    }

    init(
        preference: ManagedPreference<Namespace, Value>,
        reader: ManagedPreferenceReader<Namespace>,
        fallback: Value
    ) {
        let resolution = reader.resolve(preference)

        self.preference = preference
        self.reader = reader
        self.fallback = fallback
        self.resolution = resolution
        snapshot = ManagedPreferenceObservationSnapshot(resolution)
    }

    isolated deinit {
        observation?.cancel()
    }

    func startObserving() {
        guard !hasStartedObserving else {
            return
        }

        hasStartedObserving = true
        observation = reader.observeChanges(for: preference) { [weak self] in
            self?.refresh()
        }
    }

    func refresh() {
        let nextResolution = reader.resolve(preference)
        let nextSnapshot = ManagedPreferenceObservationSnapshot(nextResolution)

        guard nextSnapshot != snapshot else {
            return
        }

        snapshot = nextSnapshot
        resolution = nextResolution
    }
}

private struct ManagedPreferenceObservationSnapshot: Equatable {
    var rawValueDescription: String?
    var decodedValueDescription: String?
    var valueDescription: String?
    var isForced: Bool
    var source: ManagedPreferenceResolutionSource

    init<Namespace, Value>(_ resolution: ManagedPreferenceResolution<Namespace, Value>) where Value: ManagedPreferenceValue {
        rawValueDescription = Self.describe(resolution.rawValue)
        decodedValueDescription = resolution.decodedValue.map { Value.managedPreferenceLiteral($0) }
        valueDescription = resolution.value.map { Value.managedPreferenceLiteral($0) }
        isForced = resolution.isForced
        source = resolution.source
    }

    private static func describe(_ value: Any?) -> String? {
        guard let value else {
            return nil
        }

        if let dictionary = value as? [String: String] {
            return dictionary
                .sorted { $0.key < $1.key }
                .map { "\(String(reflecting: $0.key)):\(String(reflecting: $0.value))" }
                .joined(separator: ",")
        }

        if let dictionary = value as? [String: Any] {
            return dictionary
                .sorted { $0.key < $1.key }
                .map { "\(String(reflecting: $0.key)):\(String(reflecting: $0.value))" }
                .joined(separator: ",")
        }

        return String(reflecting: value)
    }
}
