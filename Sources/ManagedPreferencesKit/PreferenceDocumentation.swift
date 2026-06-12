import Foundation

public protocol PreferenceDocumentationFragment: Sendable {
    var preferenceDocumentationElements: [PreferenceDocumentationElement] { get }
}

public enum PreferenceDocumentationElement: Equatable, Sendable {
    case summary(String)
    case discussion(String)
    case defaultBehavior(String)
    case behavior(String)
    case note(String)
    case option(PreferenceOption)
    case example(PreferenceExample)
}

public struct PreferenceDocumentation: Equatable, Sendable {
    public var summary: String?
    public var discussion: [String]
    public var defaultBehavior: String?
    public var behavior: [String]
    public var notes: [String]
    public var options: [PreferenceOption]
    public var examples: [PreferenceExample]

    public init(_ elements: [PreferenceDocumentationElement] = []) {
        summary = nil
        discussion = []
        defaultBehavior = nil
        behavior = []
        notes = []
        options = []
        examples = []

        for element in elements {
            switch element {
            case .summary(let value):
                if summary == nil {
                    summary = value
                } else {
                    discussion.append(value)
                }

            case .discussion(let value):
                discussion.append(value)

            case .defaultBehavior(let value):
                defaultBehavior = value

            case .behavior(let value):
                behavior.append(value)

            case .note(let value):
                notes.append(value)

            case .option(let value):
                options.append(value)

            case .example(let value):
                examples.append(value)
            }
        }
    }

    public var isEmpty: Bool {
        summary == nil
            && discussion.isEmpty
            && defaultBehavior == nil
            && behavior.isEmpty
            && notes.isEmpty
            && options.isEmpty
            && examples.isEmpty
    }
}

public struct Summary: PreferenceDocumentationFragment {
    public var text: String

    public init(_ text: String) {
        self.text = text
    }

    public var preferenceDocumentationElements: [PreferenceDocumentationElement] {
        [.summary(text)]
    }
}

public struct Discussion: PreferenceDocumentationFragment {
    public var text: String

    public init(_ text: String) {
        self.text = text
    }

    public var preferenceDocumentationElements: [PreferenceDocumentationElement] {
        [.discussion(text)]
    }
}

public struct DefaultBehavior: PreferenceDocumentationFragment {
    public var text: String

    public init(_ text: String) {
        self.text = text
    }

    public var preferenceDocumentationElements: [PreferenceDocumentationElement] {
        [.defaultBehavior(text)]
    }
}

public struct Behavior: PreferenceDocumentationFragment {
    public var text: String

    public init(_ text: String) {
        self.text = text
    }

    public var preferenceDocumentationElements: [PreferenceDocumentationElement] {
        [.behavior(text)]
    }
}

public struct Note: PreferenceDocumentationFragment {
    public var text: String

    public init(_ text: String) {
        self.text = text
    }

    public var preferenceDocumentationElements: [PreferenceDocumentationElement] {
        [.note(text)]
    }
}

public struct PreferenceOption: Equatable, Sendable {
    public var value: String
    public var description: String?

    public init<Value: ManagedPreferenceValue>(_ value: Value, _ description: String? = nil) {
        self.value = Value.managedPreferenceLiteral(value)
        self.description = description
    }
}

public struct Option<Value: ManagedPreferenceValue>: Sendable {
    public var value: PreferenceOption

    public init(_ value: Value, _ description: String? = nil) {
        self.value = PreferenceOption(value, description)
    }
}

public struct PreferenceExample: Equatable, Sendable {
    public var value: String
    public var description: String?

    public init<Value: ManagedPreferenceValue>(_ value: Value, _ description: String? = nil) {
        self.value = Value.managedPreferenceLiteral(value)
        self.description = description
    }
}

public struct Example<Value: ManagedPreferenceValue>: PreferenceDocumentationFragment {
    public var example: PreferenceExample

    public init(_ value: Value, _ description: String? = nil) {
        example = PreferenceExample(value, description)
    }

    public var preferenceDocumentationElements: [PreferenceDocumentationElement] {
        [.example(example)]
    }
}

public struct Options: PreferenceDocumentationFragment {
    public var options: [PreferenceOption]

    public init(@PreferenceOptionBuilder _ options: () -> [PreferenceOption]) {
        self.options = options()
    }

    public var preferenceDocumentationElements: [PreferenceDocumentationElement] {
        options.map(PreferenceDocumentationElement.option)
    }
}

public struct AllowedValues<Value: ManagedPreferenceValue>: PreferenceDocumentationFragment {
    public var options: [PreferenceOption]

    public init(_ values: Value...) {
        options = values.map { PreferenceOption($0) }
    }

    public var preferenceDocumentationElements: [PreferenceDocumentationElement] {
        options.map(PreferenceDocumentationElement.option)
    }
}

@resultBuilder
public enum PreferenceDocumentationBuilder {
    public static func buildBlock(_ components: [PreferenceDocumentationElement]...) -> [PreferenceDocumentationElement] {
        components.flatMap { $0 }
    }

    public static func buildExpression<Fragment: PreferenceDocumentationFragment>(_ expression: Fragment) -> [PreferenceDocumentationElement] {
        expression.preferenceDocumentationElements
    }

    public static func buildExpression(_ expression: [PreferenceDocumentationElement]) -> [PreferenceDocumentationElement] {
        expression
    }

    public static func buildOptional(_ component: [PreferenceDocumentationElement]?) -> [PreferenceDocumentationElement] {
        component ?? []
    }

    public static func buildEither(first component: [PreferenceDocumentationElement]) -> [PreferenceDocumentationElement] {
        component
    }

    public static func buildEither(second component: [PreferenceDocumentationElement]) -> [PreferenceDocumentationElement] {
        component
    }

    public static func buildArray(_ components: [[PreferenceDocumentationElement]]) -> [PreferenceDocumentationElement] {
        components.flatMap { $0 }
    }

    public static func buildLimitedAvailability(_ component: [PreferenceDocumentationElement]) -> [PreferenceDocumentationElement] {
        component
    }
}

@resultBuilder
public enum PreferenceOptionBuilder {
    public static func buildBlock(_ components: [PreferenceOption]...) -> [PreferenceOption] {
        components.flatMap { $0 }
    }

    public static func buildExpression<Value: ManagedPreferenceValue>(_ expression: Option<Value>) -> [PreferenceOption] {
        [expression.value]
    }

    public static func buildExpression(_ expression: PreferenceOption) -> [PreferenceOption] {
        [expression]
    }

    public static func buildOptional(_ component: [PreferenceOption]?) -> [PreferenceOption] {
        component ?? []
    }

    public static func buildEither(first component: [PreferenceOption]) -> [PreferenceOption] {
        component
    }

    public static func buildEither(second component: [PreferenceOption]) -> [PreferenceOption] {
        component
    }

    public static func buildArray(_ components: [[PreferenceOption]]) -> [PreferenceOption] {
        components.flatMap { $0 }
    }

    public static func buildLimitedAvailability(_ component: [PreferenceOption]) -> [PreferenceOption] {
        component
    }
}
