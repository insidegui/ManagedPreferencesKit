import ManagedPreferencesKit
import ManagedPreferencesUI
import SwiftUI
import XCTest

final class ManagedPreferencesKitTests: XCTestCase {
    func testResultBuilderBuildsGroupedSchemaWithInlineDocumentation() {
        let schema = VirtualBuddyManagedPreferences.schema

        XCTAssertEqual(schema.preferences.count, 4)
        XCTAssertEqual(schema.sections.map(\.name), ["Security", "Networking"])

        let sharedFolders = schema.preference(named: "DisableSharedFolders")
        XCTAssertEqual(sharedFolders?.valueType, .boolean)
        XCTAssertEqual(sharedFolders?.defaultValue, "false")
        XCTAssertEqual(sharedFolders?.documentation.summary, "Disables Shared Folders globally.")
        XCTAssertEqual(sharedFolders?.documentation.options.count, 2)
    }

    func testMarkdownDocumentationIncludesTypesDefaultsAndOptions() {
        let schema = VirtualBuddyManagedPreferences.schema
        let markdown = schema.markdownDocumentation()

        XCTAssertTrue(markdown.contains("# VirtualBuddy Managed Preferences"))
        XCTAssertTrue(markdown.contains("Preference domain: `codes.rambo.VirtualBuddy`"))
        XCTAssertTrue(markdown.contains("### `DisableSharedFolders`"))
        XCTAssertTrue(markdown.contains("Type: `Boolean`"))
        XCTAssertTrue(markdown.contains("| `true` | Shared Folders are unavailable. |"))
        XCTAssertTrue(markdown.contains("### `AllowedNetworkModes`"))
        XCTAssertTrue(markdown.contains("Default: `[\"NAT\", \"Bridged\"]`"))
    }

    func testProfileManifestIncludesPayloadMetadataAndPreferenceKeys() throws {
        let options = ProfileManifestExportOptions(lastModified: Date(timeIntervalSince1970: 0))
        let data = try VirtualBuddyManagedPreferences.schema.profileManifestData(options: options)
        let manifest = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])

        XCTAssertEqual(manifest["pfm_domain"] as? String, "codes.rambo.VirtualBuddy")
        XCTAssertEqual(manifest["pfm_title"] as? String, "VirtualBuddy")
        XCTAssertEqual(manifest["pfm_description"] as? String, "Configures VirtualBuddy managed preferences.")
        XCTAssertEqual(manifest["pfm_format_version"] as? Int, 1)
        XCTAssertEqual(manifest["pfm_version"] as? Int, 1)
        XCTAssertEqual(manifest["pfm_unique"] as? Bool, true)
        XCTAssertEqual(manifest["pfm_interaction"] as? String, "combined")
        XCTAssertEqual(manifest["pfm_platforms"] as? [String], ["macOS"])
        XCTAssertEqual(manifest["pfm_targets"] as? [String], ["system", "user"])

        let subkeys = try XCTUnwrap(manifest["pfm_subkeys"] as? [[String: Any]])

        let payloadDisplayName = try XCTUnwrap(subkeys.first { $0["pfm_name"] as? String == "PayloadDisplayName" })
        XCTAssertEqual(payloadDisplayName["pfm_default"] as? String, "VirtualBuddy")
        XCTAssertEqual(payloadDisplayName["pfm_require"] as? String, "always")

        let disableSharedFolders = try XCTUnwrap(subkeys.first { $0["pfm_name"] as? String == "DisableSharedFolders" })
        XCTAssertEqual(disableSharedFolders["pfm_type"] as? String, "boolean")
        XCTAssertEqual(disableSharedFolders["pfm_title"] as? String, "DisableSharedFolders")
        XCTAssertEqual(disableSharedFolders["pfm_description"] as? String, "Disables Shared Folders globally.")
        XCTAssertEqual(disableSharedFolders["pfm_default"] as? Bool, false)
        XCTAssertEqual(disableSharedFolders["pfm_range_list"] as? [Bool], [true, false])
        XCTAssertEqual(disableSharedFolders["pfm_range_list_titles"] as? [String], [
            "Shared Folders are unavailable.",
            "Current behavior."
        ])

        let allowedNetworkModes = try XCTUnwrap(subkeys.first { $0["pfm_name"] as? String == "AllowedNetworkModes" })
        XCTAssertEqual(allowedNetworkModes["pfm_type"] as? String, "array")
        XCTAssertEqual(allowedNetworkModes["pfm_default"] as? [String], ["NAT", "Bridged"])

        let allowedNetworkModeSubkeys = try XCTUnwrap(allowedNetworkModes["pfm_subkeys"] as? [[String: Any]])
        XCTAssertEqual(allowedNetworkModeSubkeys.count, 1)
        XCTAssertEqual(allowedNetworkModeSubkeys[0]["pfm_type"] as? String, "string")
        XCTAssertEqual(allowedNetworkModeSubkeys[0]["pfm_range_list"] as? [String], ["NAT", "Bridged"])
    }

    func testProfileManifestRepresentsStringDictionariesWithUserProvidedKeys() throws {
        let options = ProfileManifestExportOptions(lastModified: Date(timeIntervalSince1970: 0), includePayloadMetadata: false)
        let manifest = DictionaryManagedPreferences.schema.profileManifestPropertyList(options: options)
        let subkeys = try XCTUnwrap(manifest["pfm_subkeys"] as? [[String: Any]])
        let labels = try XCTUnwrap(subkeys.first { $0["pfm_name"] as? String == "Labels" })

        XCTAssertEqual(labels["pfm_type"] as? String, "dictionary")
        XCTAssertEqual(labels["pfm_default"] as? [String: String], ["environment": "lab"])

        let dictionarySubkeys = try XCTUnwrap(labels["pfm_subkeys"] as? [[String: Any]])
        XCTAssertEqual(dictionarySubkeys.count, 2)
        XCTAssertEqual(dictionarySubkeys[0]["pfm_name"] as? String, "{{key}}")
        XCTAssertEqual(dictionarySubkeys[0]["pfm_type"] as? String, "string")
        XCTAssertEqual(dictionarySubkeys[1]["pfm_name"] as? String, "{{value}}")
        XCTAssertEqual(dictionarySubkeys[1]["pfm_type"] as? String, "string")
    }

    func testReaderResolvesForcedManagedValue() {
        let reader = VirtualBuddyManagedPreferences.schema.reader(
            store: DictionaryManagedPreferenceStore(
                values: ["DisableSharedFolders": true],
                forcedKeys: ["DisableSharedFolders"]
            )
        )

        let resolution = reader.resolve(.disableSharedFolders)

        XCTAssertEqual(resolution.value, true)
        XCTAssertEqual(resolution.decodedValue, true)
        XCTAssertTrue(resolution.isManaged)
        XCTAssertEqual(resolution.source, .managed)
    }

    func testReaderReadsNamespacedPreferenceShorthand() {
        let reader = VirtualBuddyManagedPreferences.schema.reader(
            store: DictionaryManagedPreferenceStore(
                values: ["DisableSharedFolders": true],
                forcedKeys: ["DisableSharedFolders"]
            )
        )

        XCTAssertTrue(reader.value(for: .disableSharedFolders, default: false))
    }

    func testReaderFallsBackToDefaultForInvalidValue() {
        let reader = VirtualBuddyManagedPreferences.schema.reader(
            store: DictionaryManagedPreferenceStore(
                values: ["AllowedNetworkModes": ["NAT", 42]],
                forcedKeys: ["AllowedNetworkModes"]
            )
        )

        let resolution = reader.resolve(.allowedNetworkModes)

        XCTAssertEqual(resolution.value, ["NAT", "Bridged"])
        XCTAssertNil(resolution.decodedValue)
        XCTAssertEqual(resolution.source, .invalidValue)
    }

    func testReaderFallsBackToDefaultForDisallowedValue() {
        let reader = VirtualBuddyManagedPreferences.schema.reader(
            store: DictionaryManagedPreferenceStore(
                values: ["AllowedNetworkModes": ["NAT", "HostOnly"]],
                forcedKeys: ["AllowedNetworkModes"]
            )
        )

        let resolution = reader.resolve(.allowedNetworkModes)

        XCTAssertEqual(resolution.value, ["NAT", "Bridged"])
        XCTAssertEqual(resolution.decodedValue, ["NAT", "HostOnly"])
        XCTAssertEqual(resolution.source, .invalidValue)
    }

    @MainActor
    func testManagedValueAndShieldPublicAPIsCompile() {
        let schema = VirtualBuddyManagedPreferences.schema

        _ = ManagedValueProbe(schema: schema)

        _ = Text("Shared Folders")
            .managedPreferenceShield(for: .disableSharedFolders, schema: schema) {
                Text("Blocked")
            }

        _ = Text("Networking")
            .managedPreferenceShield(
                for: .allowedNetworkModes,
                schema: schema,
                default: ["NAT"],
                when: { !$0.contains("Bridged") }
            ) {
                Text("Blocked")
            }
    }
}

private struct ManagedValueProbe: View {
    @ManagedValue<VirtualBuddyManagedPreferences, Bool> private var disableSharedFolders: Bool

    init(schema: ManagedPreferencesSchema<VirtualBuddyManagedPreferences>) {
        _disableSharedFolders = ManagedValue(
            for: .disableSharedFolders,
            schema: schema,
            default: false
        )
    }

    var body: some View {
        Text(disableSharedFolders ? "Blocked" : "Allowed")
    }
}

private enum VirtualBuddyManagedPreferences: ManagedPreferencesNamespace {
    static let schema = Schema(
        domain: "codes.rambo.VirtualBuddy",
        displayName: "VirtualBuddy"
    ) {
        Group("Security") {
            Preference<Bool>.disableSharedFolders
        }

        Group("Networking") {
            Preference<[String]>.allowedNetworkModes
            Preference<String>.defaultNetworkMode
            Preference<Bool>.lockNetworkMode
        }
    }
}

private extension ManagedPreference where Namespace == VirtualBuddyManagedPreferences, Value == Bool {
    static let disableSharedFolders = Self("DisableSharedFolders", default: false) {
        Summary("Disables Shared Folders globally.")
        Discussion("When enabled, existing host to guest folder mappings should be ignored at launch and new mappings should be denied.")
        DefaultBehavior("Shared Folders are available unless this key is forced to true by MDM.")
        Behavior("Disable or hide Shared Folder controls in the UI.")
        Behavior("Ignore persisted mappings when building the VM runtime configuration.")
        Options {
            Option(true, "Shared Folders are unavailable.")
            Option(false, "Current behavior.")
        }
        Example(true, "Block Shared Folders for regulated environments.")
    }

    static let lockNetworkMode = Self("LockNetworkMode", default: false) {
        Summary("Prevents users from changing the effective network mode.")
        Options {
            Option(true, "Use the policy-defined network mode.")
            Option(false, "Users may choose any allowed network mode.")
        }
    }
}

private extension ManagedPreference where Namespace == VirtualBuddyManagedPreferences, Value == [String] {
    static let allowedNetworkModes = Self("AllowedNetworkModes", default: ["NAT", "Bridged"]) {
        Summary("Limits the network modes a user may choose.")
        AllowedValues("NAT", "Bridged")
        Example(["NAT"], "Permit NAT and disallow Bridged networking.")
    }
}

private extension ManagedPreference where Namespace == VirtualBuddyManagedPreferences, Value == String {
    static let defaultNetworkMode = Self("DefaultNetworkMode", default: "NAT") {
        Summary("Sets the default network mode for newly created VMs.")
        AllowedValues("NAT", "Bridged")
    }
}

private enum DictionaryManagedPreferences: ManagedPreferencesNamespace {
    static let schema = Schema(domain: "codes.rambo.DictionaryManagedPreferences") {
        Preference<[String: String]>.labels
    }
}

private extension ManagedPreference where Namespace == DictionaryManagedPreferences, Value == [String: String] {
    static let labels = Self("Labels", default: ["environment": "lab"]) {
        Summary("Adds string labels to the managed configuration.")
    }
}

private struct DictionaryManagedPreferenceStore: ManagedPreferenceStore {
    var values: [String: Any]
    var forcedKeys: Set<String>

    func value(forKey key: String, domain: String) -> Any? {
        values[key]
    }

    func valueIsForced(forKey key: String, domain: String) -> Bool {
        forcedKeys.contains(key)
    }
}
