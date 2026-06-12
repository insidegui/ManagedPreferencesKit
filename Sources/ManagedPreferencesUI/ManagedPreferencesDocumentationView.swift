import Foundation
import ManagedPreferencesKit
import SwiftUI
import UniformTypeIdentifiers

public struct ManagedPreferencesDocumentationView<Namespace>: View {
    private let schema: ManagedPreferencesSchema<Namespace>
    private let exportFilename: String

    @State private var isExportingMarkdown = false
    @State private var markdownDocument = MarkdownDocumentationDocument(markdown: "")
    @State private var exportFailureMessage: String?

    public init(_ schema: ManagedPreferencesSchema<Namespace>, exportFilename: String? = nil) {
        self.schema = schema
        self.exportFilename = exportFilename ?? Self.defaultExportFilename(for: schema)
    }

    public init(schema: ManagedPreferencesSchema<Namespace>, exportFilename: String? = nil) {
        self.init(schema, exportFilename: exportFilename)
    }

    public var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            if schema.preferences.isEmpty {
                emptyState
            } else {
                preferenceList
            }
        }
        .fileExporter(
            isPresented: $isExportingMarkdown,
            document: markdownDocument,
            contentType: .managedPreferencesMarkdown,
            defaultFilename: exportFilename
        ) { result in
            if case let .failure(error) = result {
                exportFailureMessage = error.localizedDescription
            }
        }
        .alert("Export Failed", isPresented: isShowingExportFailure) {
            Button("OK", role: .cancel) {
                exportFailureMessage = nil
            }
        } message: {
            Text(exportFailureMessage ?? "The markdown documentation could not be exported.")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(schema.displayName ?? schema.domain)
                    .font(.title2.weight(.semibold))

                Text(schema.domain)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 16)

            Button {
                markdownDocument = MarkdownDocumentationDocument(markdown: schema.markdownDocumentation())
                isExportingMarkdown = true
            } label: {
                Label("Export Markdown", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var preferenceList: some View {
        List {
            ForEach(Array(schema.sections.enumerated()), id: \.offset) { _, section in
                Section {
                    ForEach(section.preferences) { preference in
                        PreferenceDisclosureView(preference: preference)
                    }
                } header: {
                    Text(section.name ?? "Preferences")
                }
            }
        }
        .listStyle(.inset)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No Preferences")
                .font(.headline)

            Text("This schema does not declare any managed preferences.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var isShowingExportFailure: Binding<Bool> {
        Binding {
            exportFailureMessage != nil
        } set: { isPresented in
            if !isPresented {
                exportFailureMessage = nil
            }
        }
    }

    private static func defaultExportFilename(for schema: ManagedPreferencesSchema<Namespace>) -> String {
        let trimmedDisplayName = schema.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = trimmedDisplayName?.isEmpty == false ? trimmedDisplayName! : schema.domain

        let invalidCharacters = CharacterSet(charactersIn: "/:")
        let sanitizedName = baseName
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")

        return "\(sanitizedName) Managed Preferences.md"
    }
}

private struct PreferenceDisclosureView: View {
    var preference: AnyManagedPreference

    var body: some View {
        DisclosureGroup {
            PreferenceDetailsView(preference: preference)
                .padding(.top, 8)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(preference.displayName)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(preference.key)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Text(preference.valueType.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let summary = preference.documentation.summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

private struct PreferenceDetailsView: View {
    var preference: AnyManagedPreference

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                DetailRow(title: "Key", value: preference.key, isCode: true)
                DetailRow(title: "Type", value: preference.valueType.description, isCode: true)
                DetailRow(title: "Default", value: preference.defaultValue ?? "Not specified", isCode: preference.defaultValue != nil)
            }

            PreferenceDocumentationView(documentation: preference.documentation)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DetailRow: View {
    var title: String
    var value: String
    var isCode: Bool

    var body: some View {
        LabeledContent(title) {
            Text(value)
                .font(isCode ? .body.monospaced() : .body)
                .foregroundStyle(isCode ? .primary : .secondary)
                .textSelection(.enabled)
        }
    }
}

private struct PreferenceDocumentationView: View {
    var documentation: PreferenceDocumentation

    var body: some View {
        if documentation.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 14) {
                if let summary = documentation.summary {
                    DocumentationSection(title: "Summary") {
                        Text(summary)
                    }
                }

                if !documentation.discussion.isEmpty {
                    DocumentationSection(title: "Discussion") {
                        ParagraphList(paragraphs: documentation.discussion)
                    }
                }

                if let defaultBehavior = documentation.defaultBehavior {
                    DocumentationSection(title: "Default Behavior") {
                        Text(defaultBehavior)
                    }
                }

                if !documentation.behavior.isEmpty {
                    DocumentationSection(title: "Behavior") {
                        BulletList(items: documentation.behavior)
                    }
                }

                if !documentation.options.isEmpty {
                    DocumentationSection(title: "Allowed Values") {
                        OptionList(options: documentation.options)
                    }
                }

                if !documentation.examples.isEmpty {
                    DocumentationSection(title: "Examples") {
                        ExampleList(examples: documentation.examples)
                    }
                }

                if !documentation.notes.isEmpty {
                    DocumentationSection(title: "Notes") {
                        BulletList(items: documentation.notes)
                    }
                }
            }
        }
    }
}

private struct DocumentationSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))

            content()
                .font(.body)
                .foregroundStyle(.primary)
        }
    }
}

private struct ParagraphList: View {
    var paragraphs: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph)
            }
        }
    }
}

private struct BulletList: View {
    var items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•")
                        .foregroundStyle(.secondary)

                    Text(item)
                }
            }
        }
    }
}

private struct OptionList: View {
    var options: [PreferenceOption]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                ValueDescriptionRow(value: option.value, description: option.description)
            }
        }
    }
}

private struct ExampleList: View {
    var examples: [PreferenceExample]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(examples.enumerated()), id: \.offset) { _, example in
                ValueDescriptionRow(value: example.value, description: example.description)
            }
        }
    }
}

private struct ValueDescriptionRow: View {
    var value: String
    var description: String?

    var body: some View {
        LabeledContent {
            if let description {
                Text(description)
            } else {
                Text("No description")
                    .foregroundStyle(.secondary)
            }
        } label: {
            Text(value)
                .font(.body.monospaced())
                .textSelection(.enabled)
        }
    }
}

private struct MarkdownDocumentationDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.managedPreferencesMarkdown]
    }

    var markdown: String

    init(markdown: String) {
        self.markdown = markdown
    }

    init(configuration: ReadConfiguration) throws {
        if let contents = configuration.file.regularFileContents,
           let markdown = String(data: contents, encoding: .utf8) {
            self.markdown = markdown
        } else {
            markdown = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(markdown.utf8))
    }
}

private extension UTType {
    static var managedPreferencesMarkdown: UTType {
        if #available(macOS 27.0, *) {
            UTType.markdown
        } else {
            UTType(filenameExtension: "md") ?? .plainText
        }
    }
}
