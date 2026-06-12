import Foundation

public protocol ManagedPreferenceStore {
    func value(forKey key: String, domain: String) -> Any?
    func valueIsForced(forKey key: String, domain: String) -> Bool
}

public struct CFPreferencesManagedPreferenceStore: ManagedPreferenceStore {
    public init() {}

    public func value(forKey key: String, domain: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, domain as CFString)
    }

    public func valueIsForced(forKey key: String, domain: String) -> Bool {
        CFPreferencesAppValueIsForced(key as CFString, domain as CFString)
    }
}

public struct UserDefaultsManagedPreferenceStore: ManagedPreferenceStore {
    public var defaults: UserDefaults

    public init(_ defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func value(forKey key: String, domain: String) -> Any? {
        defaults.object(forKey: key)
    }

    public func valueIsForced(forKey key: String, domain: String) -> Bool {
        defaults.objectIsForced(forKey: key)
    }
}

public enum ManagedPreferenceResolutionSource: String, Equatable, Sendable {
    case managed
    case unmanaged
    case defaultValue
    case missing
    case invalidValue
}

public struct ManagedPreferenceResolution<Namespace, Value: ManagedPreferenceValue> {
    public var preference: ManagedPreference<Namespace, Value>
    public var rawValue: Any?
    public var decodedValue: Value?
    public var value: Value?
    public var isForced: Bool
    public var source: ManagedPreferenceResolutionSource

    public var isManaged: Bool {
        isForced
    }
}

public struct ManagedPreferenceReader<Namespace> {
    public var domain: String
    public var store: ManagedPreferenceStore

    public init(domain: String, store: ManagedPreferenceStore = CFPreferencesManagedPreferenceStore()) {
        self.domain = domain
        self.store = store
    }

    public func resolve<Value: ManagedPreferenceValue>(_ preference: ManagedPreference<Namespace, Value>) -> ManagedPreferenceResolution<Namespace, Value> {
        let rawValue = store.value(forKey: preference.key, domain: domain)
        let isForced = store.valueIsForced(forKey: preference.key, domain: domain)

        guard let rawValue else {
            return ManagedPreferenceResolution(
                preference: preference,
                rawValue: nil,
                decodedValue: nil,
                value: preference.defaultValue,
                isForced: isForced,
                source: preference.defaultValue == nil ? .missing : .defaultValue
            )
        }

        guard let decodedValue = Value.decodeManagedPreferenceValue(rawValue) else {
            return ManagedPreferenceResolution(
                preference: preference,
                rawValue: rawValue,
                decodedValue: nil,
                value: preference.defaultValue,
                isForced: isForced,
                source: .invalidValue
            )
        }

        guard preference.accepts(decodedValue) else {
            return ManagedPreferenceResolution(
                preference: preference,
                rawValue: rawValue,
                decodedValue: decodedValue,
                value: preference.defaultValue,
                isForced: isForced,
                source: .invalidValue
            )
        }

        return ManagedPreferenceResolution(
            preference: preference,
            rawValue: rawValue,
            decodedValue: decodedValue,
            value: decodedValue,
            isForced: isForced,
            source: isForced ? .managed : .unmanaged
        )
    }

    public func value<Value: ManagedPreferenceValue>(
        for preference: ManagedPreference<Namespace, Value>,
        default fallback: @autoclosure () -> Value
    ) -> Value {
        resolve(preference).value ?? fallback()
    }
}
