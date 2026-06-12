import Foundation

public enum ManagedPreferenceValueType: String, Equatable, Hashable, Sendable, CustomStringConvertible {
    case boolean = "Boolean"
    case string = "String"
    case integer = "Integer"
    case double = "Double"
    case stringArray = "Array<String>"
    case stringDictionary = "Dictionary<String, String>"

    public var description: String { rawValue }
}

public protocol ManagedPreferenceValue: Sendable {
    static var managedPreferenceValueType: ManagedPreferenceValueType { get }

    static func decodeManagedPreferenceValue(_ rawValue: Any) -> Self?
    static func managedPreferenceLiteral(_ value: Self) -> String
}

extension Bool: ManagedPreferenceValue {
    public static var managedPreferenceValueType: ManagedPreferenceValueType { .boolean }

    public static func decodeManagedPreferenceValue(_ rawValue: Any) -> Bool? {
        rawValue as? Bool
    }

    public static func managedPreferenceLiteral(_ value: Bool) -> String {
        value ? "true" : "false"
    }
}

extension String: ManagedPreferenceValue {
    public static var managedPreferenceValueType: ManagedPreferenceValueType { .string }

    public static func decodeManagedPreferenceValue(_ rawValue: Any) -> String? {
        rawValue as? String
    }

    public static func managedPreferenceLiteral(_ value: String) -> String {
        "\"\(value.escapedManagedPreferenceLiteral)\""
    }
}

extension Int: ManagedPreferenceValue {
    public static var managedPreferenceValueType: ManagedPreferenceValueType { .integer }

    public static func decodeManagedPreferenceValue(_ rawValue: Any) -> Int? {
        if let value = rawValue as? Int {
            return value
        }

        return (rawValue as? NSNumber)?.intValue
    }

    public static func managedPreferenceLiteral(_ value: Int) -> String {
        String(value)
    }
}

extension Double: ManagedPreferenceValue {
    public static var managedPreferenceValueType: ManagedPreferenceValueType { .double }

    public static func decodeManagedPreferenceValue(_ rawValue: Any) -> Double? {
        if let value = rawValue as? Double {
            return value
        }

        return (rawValue as? NSNumber)?.doubleValue
    }

    public static func managedPreferenceLiteral(_ value: Double) -> String {
        String(value)
    }
}

extension Array: ManagedPreferenceValue where Element == String {
    public static var managedPreferenceValueType: ManagedPreferenceValueType { .stringArray }

    public static func decodeManagedPreferenceValue(_ rawValue: Any) -> [String]? {
        rawValue as? [String]
    }

    public static func managedPreferenceLiteral(_ value: [String]) -> String {
        "[" + value.map { String.managedPreferenceLiteral($0) }.joined(separator: ", ") + "]"
    }
}

extension Dictionary: ManagedPreferenceValue where Key == String, Value == String {
    public static var managedPreferenceValueType: ManagedPreferenceValueType { .stringDictionary }

    public static func decodeManagedPreferenceValue(_ rawValue: Any) -> [String: String]? {
        rawValue as? [String: String]
    }

    public static func managedPreferenceLiteral(_ value: [String: String]) -> String {
        let pairs = value
            .sorted { $0.key < $1.key }
            .map { "\(String.managedPreferenceLiteral($0.key)): \(String.managedPreferenceLiteral($0.value))" }

        return "[" + pairs.joined(separator: ", ") + "]"
    }
}

private extension String {
    var escapedManagedPreferenceLiteral: String {
        replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
