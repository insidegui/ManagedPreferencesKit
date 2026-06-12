import Foundation

public enum ProfileManifestInteraction: String, Equatable, Sendable {
    case combined
    case exclusive
    case undefined
}

public struct ProfileManifestExportOptions: Equatable, Sendable {
    public var formatVersion: Int
    public var manifestVersion: Int
    public var lastModified: Date
    public var platforms: [String]
    public var targets: [String]
    public var unique: Bool
    public var interaction: ProfileManifestInteraction?
    public var includePayloadMetadata: Bool

    public init(
        formatVersion: Int = 1,
        manifestVersion: Int = 1,
        lastModified: Date = Date(),
        platforms: [String] = ["macOS"],
        targets: [String] = ["system", "user"],
        unique: Bool = true,
        interaction: ProfileManifestInteraction? = .combined,
        includePayloadMetadata: Bool = true
    ) {
        self.formatVersion = formatVersion
        self.manifestVersion = manifestVersion
        self.lastModified = lastModified
        self.platforms = platforms
        self.targets = targets
        self.unique = unique
        self.interaction = interaction
        self.includePayloadMetadata = includePayloadMetadata
    }
}

public extension ManagedPreferencesSchema {
    func profileManifestPropertyList(options: ProfileManifestExportOptions = ProfileManifestExportOptions()) -> [String: Any] {
        let title = profileManifestTitle
        let description = "Configures \(title) managed preferences."

        var subkeys: [[String: Any]] = []

        if options.includePayloadMetadata {
            subkeys.append(contentsOf: Self.profileManifestPayloadSubkeys(
                domain: domain,
                title: title,
                description: description
            ))
        }

        subkeys.append(contentsOf: preferences.map(\.profileManifestSubkey))

        var manifest: [String: Any] = [
            "pfm_description": description,
            "pfm_domain": domain,
            "pfm_format_version": options.formatVersion,
            "pfm_last_modified": options.lastModified,
            "pfm_platforms": options.platforms,
            "pfm_subkeys": subkeys,
            "pfm_targets": options.targets,
            "pfm_title": title,
            "pfm_unique": options.unique,
            "pfm_version": options.manifestVersion
        ]

        if let interaction = options.interaction {
            manifest["pfm_interaction"] = interaction.rawValue
        }

        return manifest
    }

    func profileManifestData(options: ProfileManifestExportOptions = ProfileManifestExportOptions()) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: profileManifestPropertyList(options: options),
            format: .xml,
            options: 0
        )
    }
}

private extension ManagedPreferencesSchema {
    var profileManifestTitle: String {
        let trimmedDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)

        if let trimmedDisplayName, !trimmedDisplayName.isEmpty {
            return trimmedDisplayName
        }

        return domain
    }

    static func profileManifestPayloadSubkeys(domain: String, title: String, description: String) -> [[String: Any]] {
        [
            [
                "pfm_default": description,
                "pfm_description": "The human-readable description of this payload.",
                "pfm_name": "PayloadDescription",
                "pfm_title": "Payload Description",
                "pfm_type": "string"
            ],
            [
                "pfm_default": title,
                "pfm_description": "The human-readable name for the payload.",
                "pfm_name": "PayloadDisplayName",
                "pfm_require": "always",
                "pfm_title": "Payload Display Name",
                "pfm_type": "string"
            ],
            [
                "pfm_default": domain,
                "pfm_description": "The reverse-DNS-style identifier for the payload.",
                "pfm_name": "PayloadIdentifier",
                "pfm_require": "always",
                "pfm_title": "Payload Identifier",
                "pfm_type": "string"
            ],
            [
                "pfm_default": domain,
                "pfm_description": "The payload type.",
                "pfm_name": "PayloadType",
                "pfm_require": "always",
                "pfm_title": "Payload Type",
                "pfm_type": "string"
            ],
            [
                "pfm_default": "",
                "pfm_description": "The globally unique identifier for the payload.",
                "pfm_format": "^[0-9A-Za-z]{8}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}-[0-9A-Za-z]{4}-[0-9A-Za-z]{12}$",
                "pfm_name": "PayloadUUID",
                "pfm_require": "always",
                "pfm_title": "Payload UUID",
                "pfm_type": "string"
            ],
            [
                "pfm_default": 1,
                "pfm_description": "The version of this specific payload.",
                "pfm_name": "PayloadVersion",
                "pfm_range_list": [1],
                "pfm_require": "always",
                "pfm_title": "Payload Version",
                "pfm_type": "integer"
            ],
            [
                "pfm_description": "The human-readable name of the organization that provides the profile.",
                "pfm_name": "PayloadOrganization",
                "pfm_title": "Payload Organization",
                "pfm_type": "string"
            ]
        ]
    }
}

private extension AnyManagedPreference {
    var profileManifestSubkey: [String: Any] {
        var subkey: [String: Any] = [
            "pfm_name": key,
            "pfm_title": displayName,
            "pfm_type": valueType.profileManifestType
        ]

        subkey["pfm_description"] = documentation.summary ?? "\(displayName) preference."

        if let defaultValue = defaultValue,
           let propertyListValue = ManagedPreferenceLiteralParser.propertyListValue(from: defaultValue, for: valueType) {
            subkey["pfm_default"] = propertyListValue
        }

        switch valueType {
        case .boolean, .string, .integer, .double:
            addOptions(to: &subkey, optionValueType: valueType)

        case .stringArray:
            var itemSubkey: [String: Any] = [
                "pfm_title": "Value",
                "pfm_type": "string"
            ]

            addOptions(to: &itemSubkey, optionValueType: .string)
            subkey["pfm_subkeys"] = [itemSubkey]

        case .stringDictionary:
            var valueSubkey: [String: Any] = [
                "pfm_description": "Preference value.",
                "pfm_name": "{{value}}",
                "pfm_title": "Value",
                "pfm_type": "string"
            ]

            addOptions(to: &valueSubkey, optionValueType: .string)

            subkey["pfm_subkeys"] = [
                [
                    "pfm_description": "Preference key name.",
                    "pfm_name": "{{key}}",
                    "pfm_title": "Key",
                    "pfm_type": "string"
                ],
                valueSubkey
            ]
        }

        return subkey
    }

    func addOptions(to subkey: inout [String: Any], optionValueType: ManagedPreferenceValueType) {
        guard !documentation.options.isEmpty else {
            return
        }

        let rangeList = documentation.options.compactMap {
            ManagedPreferenceLiteralParser.propertyListValue(from: $0.value, for: optionValueType)
        }

        guard rangeList.count == documentation.options.count else {
            return
        }

        subkey["pfm_range_list"] = rangeList

        if documentation.options.contains(where: { $0.description != nil }) {
            subkey["pfm_range_list_titles"] = documentation.options.map {
                $0.description ?? ManagedPreferenceLiteralParser.displayValue(from: $0.value, for: optionValueType)
            }
        }
    }
}

private extension ManagedPreferenceValueType {
    var profileManifestType: String {
        switch self {
        case .boolean:
            return "boolean"
        case .string:
            return "string"
        case .integer:
            return "integer"
        case .double:
            return "real"
        case .stringArray:
            return "array"
        case .stringDictionary:
            return "dictionary"
        }
    }
}

private enum ManagedPreferenceLiteralParser {
    static func propertyListValue(from literal: String, for valueType: ManagedPreferenceValueType) -> Any? {
        switch valueType {
        case .boolean:
            switch literal {
            case "true":
                return true
            case "false":
                return false
            default:
                return nil
            }

        case .string:
            return parseQuotedString(literal)

        case .integer:
            return Int(literal)

        case .double:
            return Double(literal)

        case .stringArray:
            return parseStringArray(literal)

        case .stringDictionary:
            return parseStringDictionary(literal)
        }
    }

    static func displayValue(from literal: String, for valueType: ManagedPreferenceValueType) -> String {
        if let value = propertyListValue(from: literal, for: valueType) {
            String(describing: value)
        } else {
            literal
        }
    }

    private static func parseQuotedString(_ literal: String) -> String? {
        var index = literal.startIndex
        return parseQuotedString(in: literal, at: &index).flatMap { value in
            literal[index...].allSatisfy(\.isWhitespace) ? value : nil
        }
    }

    private static func parseStringArray(_ literal: String) -> [String]? {
        var index = literal.startIndex
        guard consume("[", in: literal, at: &index) else {
            return nil
        }

        var values: [String] = []

        while true {
            skipWhitespace(in: literal, at: &index)

            if consume("]", in: literal, at: &index) {
                return literal[index...].allSatisfy(\.isWhitespace) ? values : nil
            }

            guard let value = parseQuotedString(in: literal, at: &index) else {
                return nil
            }

            values.append(value)
            skipWhitespace(in: literal, at: &index)

            if consume(",", in: literal, at: &index) {
                continue
            }

            guard consume("]", in: literal, at: &index) else {
                return nil
            }

            return literal[index...].allSatisfy(\.isWhitespace) ? values : nil
        }
    }

    private static func parseStringDictionary(_ literal: String) -> [String: String]? {
        var index = literal.startIndex
        guard consume("[", in: literal, at: &index) else {
            return nil
        }

        var values: [String: String] = [:]

        while true {
            skipWhitespace(in: literal, at: &index)

            if consume("]", in: literal, at: &index) {
                return literal[index...].allSatisfy(\.isWhitespace) ? values : nil
            }

            guard let key = parseQuotedString(in: literal, at: &index) else {
                return nil
            }

            skipWhitespace(in: literal, at: &index)

            guard consume(":", in: literal, at: &index) else {
                return nil
            }

            skipWhitespace(in: literal, at: &index)

            guard let value = parseQuotedString(in: literal, at: &index) else {
                return nil
            }

            values[key] = value
            skipWhitespace(in: literal, at: &index)

            if consume(",", in: literal, at: &index) {
                continue
            }

            guard consume("]", in: literal, at: &index) else {
                return nil
            }

            return literal[index...].allSatisfy(\.isWhitespace) ? values : nil
        }
    }

    private static func parseQuotedString(in literal: String, at index: inout String.Index) -> String? {
        skipWhitespace(in: literal, at: &index)

        guard index < literal.endIndex, literal[index] == "\"" else {
            return nil
        }

        literal.formIndex(after: &index)

        var result = ""

        while index < literal.endIndex {
            let character = literal[index]
            literal.formIndex(after: &index)

            if character == "\"" {
                return result
            }

            if character == "\\" {
                guard index < literal.endIndex else {
                    return nil
                }

                result.append(literal[index])
                literal.formIndex(after: &index)
            } else {
                result.append(character)
            }
        }

        return nil
    }

    private static func skipWhitespace(in literal: String, at index: inout String.Index) {
        while index < literal.endIndex, literal[index].isWhitespace {
            literal.formIndex(after: &index)
        }
    }

    private static func consume(_ character: Character, in literal: String, at index: inout String.Index) -> Bool {
        skipWhitespace(in: literal, at: &index)

        guard index < literal.endIndex, literal[index] == character else {
            return false
        }

        literal.formIndex(after: &index)
        return true
    }
}
