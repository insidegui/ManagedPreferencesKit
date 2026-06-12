import Foundation
import ManagedPreferencesKit
import SwiftUI

private struct ManagedPreferenceShield<Namespace, Value, BlockedLabel>: ViewModifier where Value: ManagedPreferenceValue, BlockedLabel: View {
    @ManagedValue<Namespace, Value> private var value: Value

    private let isShielded: (Value) -> Bool
    private let blockedLabel: () -> BlockedLabel

    init(
        preference: ManagedPreference<Namespace, Value>,
        schema: ManagedPreferencesSchema<Namespace>,
        default fallback: Value,
        isShielded: @escaping (Value) -> Bool,
        @ViewBuilder blockedLabel: @escaping () -> BlockedLabel
    ) {
        _value = ManagedValue(
            for: preference,
            schema: schema,
            default: fallback
        )
        self.isShielded = isShielded
        self.blockedLabel = blockedLabel
    }

    func body(content: Content) -> some View {
        let isShielded = isShielded(value)

        content
            .disabled(isShielded)
            .allowsHitTesting(!isShielded)
            .overlay {
                if isShielded {
                    blockedLabel()
                }
            }
    }
}

public extension View {
    func managedPreferenceShield<Namespace, Value, BlockedLabel>(
        for preference: ManagedPreference<Namespace, Value>,
        schema: ManagedPreferencesSchema<Namespace>,
        default fallback: Value,
        when isShielded: @escaping (Value) -> Bool,
        @ViewBuilder blockedLabel: @escaping () -> BlockedLabel
    ) -> some View where Value: ManagedPreferenceValue, BlockedLabel: View {
        modifier(
            ManagedPreferenceShield(
                preference: preference,
                schema: schema,
                default: fallback,
                isShielded: isShielded,
                blockedLabel: blockedLabel
            )
        )
    }

    func managedPreferenceShield<Namespace, BlockedLabel>(
        for preference: ManagedPreference<Namespace, Bool>,
        schema: ManagedPreferencesSchema<Namespace>,
        default fallback: Bool = false,
        @ViewBuilder _ blockedLabel: @escaping () -> BlockedLabel
    ) -> some View where BlockedLabel: View {
        managedPreferenceShield(
            for: preference,
            schema: schema,
            default: fallback,
            when: { $0 },
            blockedLabel: blockedLabel
        )
    }
}
