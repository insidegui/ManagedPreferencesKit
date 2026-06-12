import Foundation

public protocol ManagedPreferencesNamespace {}

public extension ManagedPreferencesNamespace {
    typealias Preference<Value: ManagedPreferenceValue> = ManagedPreference<Self, Value>
    typealias Schema = ManagedPreferencesSchema<Self>
    typealias Reader = ManagedPreferenceReader<Self>
    typealias Group = PreferenceGroup<Self>
}

public struct ManagedPreference<Namespace, Value: ManagedPreferenceValue>: Sendable {
    public var key: String
    public var title: String?
    public var defaultValue: Value?
    public var documentation: PreferenceDocumentation

    public init(
        _ key: String,
        title: String? = nil,
        default defaultValue: Value,
        @PreferenceDocumentationBuilder documentation: () -> [PreferenceDocumentationElement] = { [] }
    ) {
        self.key = key
        self.title = title
        self.defaultValue = defaultValue
        self.documentation = PreferenceDocumentation(documentation())
    }

    public init(
        _ key: String,
        as valueType: Value.Type,
        title: String? = nil,
        default defaultValue: Value? = nil,
        @PreferenceDocumentationBuilder documentation: () -> [PreferenceDocumentationElement] = { [] }
    ) {
        self.key = key
        self.title = title
        self.defaultValue = defaultValue
        self.documentation = PreferenceDocumentation(documentation())
    }

    public var valueType: ManagedPreferenceValueType {
        Value.managedPreferenceValueType
    }

    public func accepts(_ value: Value) -> Bool {
        let allowedValues = Set(documentation.options.map(\.value))

        guard !allowedValues.isEmpty else {
            return true
        }

        if let values = value as? [String] {
            return values.allSatisfy { allowedValues.contains(String.managedPreferenceLiteral($0)) }
        }

        return allowedValues.contains(Value.managedPreferenceLiteral(value))
    }
}

public struct AnyManagedPreference: Equatable, Sendable, Identifiable {
    public var id: String { key }

    public var key: String
    public var title: String?
    public var valueType: ManagedPreferenceValueType
    public var defaultValue: String?
    public var documentation: PreferenceDocumentation
    public var group: String?

    public var displayName: String {
        title ?? key
    }

    public init<Namespace, Value: ManagedPreferenceValue>(_ preference: ManagedPreference<Namespace, Value>, group: String? = nil) {
        key = preference.key
        title = preference.title
        valueType = preference.valueType
        defaultValue = preference.defaultValue.map { Value.managedPreferenceLiteral($0) }
        documentation = preference.documentation
        self.group = group
    }

    public func grouped(_ group: String) -> AnyManagedPreference {
        var copy = self
        copy.group = group
        return copy
    }
}
