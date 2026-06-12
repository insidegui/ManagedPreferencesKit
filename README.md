# ManagedPreferencesKit

ManagedPreferencesKit is a Swift 6 package for declaring custom managed preferences with a type-safe, result-builder API. It is designed for Mac apps that expose enterprise controls through MDM-delivered managed preferences.

## Example

```swift
import ManagedPreferencesKit

enum VirtualBuddyManagedPreferences: ManagedPreferencesNamespace {
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

extension ManagedPreference where Namespace == VirtualBuddyManagedPreferences, Value == Bool {
    static let disableSharedFolders = Self("DisableSharedFolders", default: false) {
        Summary("Disables Shared Folders globally.")
        Discussion("When enabled, existing host to guest mappings should be ignored at launch and new mappings should be denied.")
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

extension ManagedPreference where Namespace == VirtualBuddyManagedPreferences, Value == [String] {
    static let allowedNetworkModes = Self("AllowedNetworkModes", default: ["NAT", "Bridged"]) {
        Summary("Limits the network modes a user may choose.")
        AllowedValues("NAT", "Bridged")
        Example(["NAT"], "Permit NAT and disallow Bridged networking.")
    }
}

extension ManagedPreference where Namespace == VirtualBuddyManagedPreferences, Value == String {
    static let defaultNetworkMode = Self("DefaultNetworkMode", default: "NAT") {
        Summary("Sets the default network mode for newly created VMs.")
        AllowedValues("NAT", "Bridged")
    }
}
```

## Reading Policy

```swift
let reader = VirtualBuddyManagedPreferences.schema.reader()

if reader.value(for: .disableSharedFolders, default: false) {
    logger.notice("Shared Folders blocked by managed preference DisableSharedFolders")
    vmConfiguration.sharedFolders = []
}
```

The default reader uses `CFPreferencesCopyAppValue` and `CFPreferencesAppValueIsForced`, so it works with MDM-managed values in the app's preference domain. `UserDefaultsManagedPreferenceStore` is also available when an app wants to read from an existing `UserDefaults` instance.

`AllowedValues` and `Options` are used for both documentation and reader-level validation. If MDM provides a value with the wrong property-list type or a value outside the declared options, the resolution is marked as `.invalidValue` and falls back to the declaration's default value.

## Generating Documentation

```swift
let markdown = VirtualBuddyManagedPreferences.schema.markdownDocumentation()
```

The generated Markdown includes the preference domain, keys, value types, defaults, allowed values, examples, and inline behavior notes from the declaration.

## Showing Documentation in SwiftUI

Add the `ManagedPreferencesUI` product to an app target, then render the same schema with a native SwiftUI view:

```swift
import ManagedPreferencesUI
import SwiftUI

struct ManagedPreferencesHelpView: View {
    var body: some View {
        ManagedPreferencesDocumentationView(VirtualBuddyManagedPreferences.schema)
    }
}
```

The view renders the schema's native Swift types directly and includes an export button that writes the generated Markdown documentation to disk.
