import ManagedPreferencesKit
import XCTest

final class ManagedPreferencesKitTests: XCTestCase {
    func testResultBuilderBuildsGroupedSchemaWithInlineDocumentation() {
        let schema = ManagedPreferencesSchema(domain: "codes.rambo.VirtualBuddy", displayName: "VirtualBuddy") {
            PreferenceGroup("Security") {
                Self.disableSharedFolders
            }

            PreferenceGroup("Networking") {
                Self.allowedNetworkModes
                Self.defaultNetworkMode
                Self.lockNetworkMode
            }
        }

        XCTAssertEqual(schema.preferences.count, 4)
        XCTAssertEqual(schema.sections.map(\.name), ["Security", "Networking"])

        let sharedFolders = schema.preference(named: "DisableSharedFolders")
        XCTAssertEqual(sharedFolders?.valueType, .boolean)
        XCTAssertEqual(sharedFolders?.defaultValue, "false")
        XCTAssertEqual(sharedFolders?.documentation.summary, "Disables Shared Folders globally.")
        XCTAssertEqual(sharedFolders?.documentation.options.count, 2)
    }

    func testMarkdownDocumentationIncludesTypesDefaultsAndOptions() {
        let schema = ManagedPreferencesSchema(domain: "codes.rambo.VirtualBuddy", displayName: "VirtualBuddy") {
            PreferenceGroup("Security") {
                Self.disableSharedFolders
            }

            PreferenceGroup("Networking") {
                Self.allowedNetworkModes
            }
        }

        let markdown = schema.markdownDocumentation()

        XCTAssertTrue(markdown.contains("# VirtualBuddy Managed Preferences"))
        XCTAssertTrue(markdown.contains("Preference domain: `codes.rambo.VirtualBuddy`"))
        XCTAssertTrue(markdown.contains("### `DisableSharedFolders`"))
        XCTAssertTrue(markdown.contains("Type: `Boolean`"))
        XCTAssertTrue(markdown.contains("| `true` | Shared Folders are unavailable. |"))
        XCTAssertTrue(markdown.contains("### `AllowedNetworkModes`"))
        XCTAssertTrue(markdown.contains("Default: `[\"NAT\", \"Bridged\"]`"))
    }

    func testReaderResolvesForcedManagedValue() {
        let reader = ManagedPreferenceReader(
            domain: "codes.rambo.VirtualBuddy",
            store: DictionaryManagedPreferenceStore(
                values: ["DisableSharedFolders": true],
                forcedKeys: ["DisableSharedFolders"]
            )
        )

        let resolution = reader.resolve(Self.disableSharedFolders)

        XCTAssertEqual(resolution.value, true)
        XCTAssertEqual(resolution.decodedValue, true)
        XCTAssertTrue(resolution.isManaged)
        XCTAssertEqual(resolution.source, .managed)
    }

    func testReaderFallsBackToDefaultForInvalidValue() {
        let reader = ManagedPreferenceReader(
            domain: "codes.rambo.VirtualBuddy",
            store: DictionaryManagedPreferenceStore(
                values: ["AllowedNetworkModes": ["NAT", 42]],
                forcedKeys: ["AllowedNetworkModes"]
            )
        )

        let resolution = reader.resolve(Self.allowedNetworkModes)

        XCTAssertEqual(resolution.value, ["NAT", "Bridged"])
        XCTAssertNil(resolution.decodedValue)
        XCTAssertEqual(resolution.source, .invalidValue)
    }

    func testReaderFallsBackToDefaultForDisallowedValue() {
        let reader = ManagedPreferenceReader(
            domain: "codes.rambo.VirtualBuddy",
            store: DictionaryManagedPreferenceStore(
                values: ["AllowedNetworkModes": ["NAT", "HostOnly"]],
                forcedKeys: ["AllowedNetworkModes"]
            )
        )

        let resolution = reader.resolve(Self.allowedNetworkModes)

        XCTAssertEqual(resolution.value, ["NAT", "Bridged"])
        XCTAssertEqual(resolution.decodedValue, ["NAT", "HostOnly"])
        XCTAssertEqual(resolution.source, .invalidValue)
    }

    private static let disableSharedFolders = ManagedPreference("DisableSharedFolders", default: false) {
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

    private static let allowedNetworkModes = ManagedPreference("AllowedNetworkModes", default: ["NAT", "Bridged"]) {
        Summary("Limits the network modes a user may choose.")
        AllowedValues("NAT", "Bridged")
        Example(["NAT"], "Permit NAT and disallow Bridged networking.")
    }

    private static let defaultNetworkMode = ManagedPreference("DefaultNetworkMode", default: "NAT") {
        Summary("Sets the default network mode for newly created VMs.")
        AllowedValues("NAT", "Bridged")
    }

    private static let lockNetworkMode = ManagedPreference("LockNetworkMode", default: false) {
        Summary("Prevents users from changing the effective network mode.")
        Options {
            Option(true, "Use the policy-defined network mode.")
            Option(false, "Users may choose any allowed network mode.")
        }
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
