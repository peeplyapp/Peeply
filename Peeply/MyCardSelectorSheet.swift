//
// MyCardSelectorSheet.swift
// Peeply
//
// Copyright 2026 Peeply LLC. All rights reserved.
// This software is confidential and proprietary property.
// Unauthorized copying, modification, or distribution is strictly prohibited.
//

import SwiftUI

struct MyCardSelectorSheet: View {
    let contacts: [Contact]
    let selectedContactId: UUID?
    let onSelect: (Contact) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List(contacts, id: \.id) { contact in
                Button {
                    guard contact.canBeUsedForMyCard else { return }
                    onSelect(contact)
                } label: {
                    HStack(spacing: 12) {
                        avatarView(for: contact)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(contact.fullName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(DesignSystem.SemanticColors.primaryText)

                                if selectedContactId == contact.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(DesignSystem.SemanticColors.accent)
                                }
                            }

                            if let company = contact.company,
                               !company.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(company)
                                    .font(.caption)
                                    .foregroundStyle(DesignSystem.SemanticColors.secondaryText)
                            }

                            if !contact.canBeUsedForMyCard {
                                Text("Needs at least one phone number or email")
                                    .font(.caption2)
                                    .foregroundStyle(DesignSystem.SemanticColors.destructiveText)
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .opacity(contact.canBeUsedForMyCard ? 1.0 : 0.55)
                }
                .buttonStyle(.plain)
                .disabled(!contact.canBeUsedForMyCard)
                .listRowBackground(DesignSystem.SemanticColors.groupedScreenBackground)
            }
            .scrollContentBackground(.hidden)
            .background(DesignSystem.SemanticColors.groupedScreenBackground)
            .navigationTitle("Choose My Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                }
            }
        }
    }

    @ViewBuilder
    private func avatarView(for contact: Contact) -> some View {
        if let photoData = contact.photoData, let image = UIImage(data: photoData) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 232 / 255, green: 180 / 255, blue: 184 / 255),
                            DesignSystem.cream
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 48, height: 48)
                .overlay(
                    Text(contact.initials)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DesignSystem.SemanticColors.brandOnAccent)
                )
        }
    }
}
