import Foundation

public struct ManagedPreferencesSchema: Equatable, Sendable {
    public var domain: String
    public var displayName: String?
    public var preferences: [AnyManagedPreference]

    public init(
        domain: String,
        displayName: String? = nil,
        @ManagedPreferenceBuilder preferences: () -> [AnyManagedPreference]
    ) {
        self.domain = domain
        self.displayName = displayName
        self.preferences = preferences()
    }

    public func preference(named key: String) -> AnyManagedPreference? {
        preferences.first { $0.key == key }
    }

    public var sections: [ManagedPreferenceSection] {
        preferences.reduce(into: []) { sections, preference in
            if let index = sections.firstIndex(where: { $0.name == preference.group }) {
                sections[index].preferences.append(preference)
            } else {
                sections.append(ManagedPreferenceSection(name: preference.group, preferences: [preference]))
            }
        }
    }

    public func reader(store: ManagedPreferenceStore = CFPreferencesManagedPreferenceStore()) -> ManagedPreferenceReader {
        ManagedPreferenceReader(domain: domain, store: store)
    }
}

public struct ManagedPreferenceSection: Equatable, Sendable {
    public var name: String?
    public var preferences: [AnyManagedPreference]

    public init(name: String?, preferences: [AnyManagedPreference]) {
        self.name = name
        self.preferences = preferences
    }
}

public struct PreferenceGroup: Equatable, Sendable {
    public var name: String
    public var preferences: [AnyManagedPreference]

    public init(_ name: String, @ManagedPreferenceBuilder preferences: () -> [AnyManagedPreference]) {
        self.name = name
        self.preferences = preferences().map { $0.grouped(name) }
    }
}

@resultBuilder
public enum ManagedPreferenceBuilder {
    public static func buildBlock(_ components: [AnyManagedPreference]...) -> [AnyManagedPreference] {
        components.flatMap { $0 }
    }

    public static func buildExpression<Value: ManagedPreferenceValue>(_ expression: ManagedPreference<Value>) -> [AnyManagedPreference] {
        [AnyManagedPreference(expression)]
    }

    public static func buildExpression(_ expression: AnyManagedPreference) -> [AnyManagedPreference] {
        [expression]
    }

    public static func buildExpression(_ expression: PreferenceGroup) -> [AnyManagedPreference] {
        expression.preferences
    }

    public static func buildExpression(_ expression: [AnyManagedPreference]) -> [AnyManagedPreference] {
        expression
    }

    public static func buildOptional(_ component: [AnyManagedPreference]?) -> [AnyManagedPreference] {
        component ?? []
    }

    public static func buildEither(first component: [AnyManagedPreference]) -> [AnyManagedPreference] {
        component
    }

    public static func buildEither(second component: [AnyManagedPreference]) -> [AnyManagedPreference] {
        component
    }

    public static func buildArray(_ components: [[AnyManagedPreference]]) -> [AnyManagedPreference] {
        components.flatMap { $0 }
    }

    public static func buildLimitedAvailability(_ component: [AnyManagedPreference]) -> [AnyManagedPreference] {
        component
    }
}
