import Foundation

public extension ManagedPreferencesSchema {
    func markdownDocumentation() -> String {
        var lines: [String] = []
        lines.append("# \((displayName ?? domain)) Managed Preferences")
        lines.append("")
        lines.append("Preference domain: `\(domain)`")

        for section in sections {
            lines.append("")

            if let name = section.name {
                lines.append("## \(name)")
            } else {
                lines.append("## Preferences")
            }

            for preference in section.preferences {
                append(preference, to: &lines)
            }
        }

        return lines.joined(separator: "\n")
    }

    private func append(_ preference: AnyManagedPreference, to lines: inout [String]) {
        lines.append("")
        lines.append("### `\(preference.key)`")
        lines.append("")

        if let title = preference.title {
            lines.append("Name: \(title)")
        }

        lines.append("Type: `\(preference.valueType.description)`")

        if let defaultValue = preference.defaultValue {
            lines.append("Default: `\(defaultValue)`")
        } else {
            lines.append("Default: not specified")
        }

        let documentation = preference.documentation

        if let summary = documentation.summary {
            lines.append("")
            lines.append(summary)
        }

        for paragraph in documentation.discussion {
            lines.append("")
            lines.append(paragraph)
        }

        if let defaultBehavior = documentation.defaultBehavior {
            lines.append("")
            lines.append("Default behavior: \(defaultBehavior)")
        }

        if !documentation.behavior.isEmpty {
            lines.append("")
            lines.append("Behavior:")
            for item in documentation.behavior {
                lines.append("- \(item)")
            }
        }

        if !documentation.options.isEmpty {
            lines.append("")
            lines.append("Allowed values:")
            lines.append("")
            lines.append("| Value | Description |")
            lines.append("| --- | --- |")

            for option in documentation.options {
                lines.append("| `\(option.value.escapedMarkdownTableCell)` | \(option.description?.escapedMarkdownTableCell ?? "") |")
            }
        }

        if !documentation.examples.isEmpty {
            lines.append("")
            lines.append("Examples:")
            for example in documentation.examples {
                if let description = example.description {
                    lines.append("- `\(example.value)`: \(description)")
                } else {
                    lines.append("- `\(example.value)`")
                }
            }
        }

        if !documentation.notes.isEmpty {
            lines.append("")
            lines.append("Notes:")
            for note in documentation.notes {
                lines.append("- \(note)")
            }
        }
    }
}

private extension String {
    var escapedMarkdownTableCell: String {
        replacingOccurrences(of: "|", with: "\\|")
    }
}
