//
// MyBusinessCardSheet.swift
// Peeply
//
// Copyright 2026 Peeply LLC. All rights reserved.
// This software is confidential and proprietary property.
// Unauthorized copying, modification, or distribution is strictly prohibited.
//

import SwiftUI
import UIKit

struct MyBusinessCardSheet: View {
    let payload: BusinessCardPayload
    let onChooseDifferentContact: () -> Void
    let onClose: () -> Void

    // Share sheet state
    @State private var shareSheetItem: ShareSheetItem?

    // Card configuration state
    @State private var phoneInclusionMode: ContactFieldInclusionMode = .all
    @State private var emailInclusionMode: ContactFieldInclusionMode = .all
    @State private var selectedPhoneNumber: String?
    @State private var selectedEmail: String?

    // New UI state for progressive disclosure:
    // when the user chooses "Choose One", we can either show the full list
    // or collapse it into a compact "Selected + Change" summary row.
    @State private var isChoosingPhoneNumber = false
    @State private var isChoosingEmail = false

    private var configuredPhoneNumbers: [String] {
        if payload.phoneNumbers.count <= 1 {
            return payload.phoneNumbers
        }

        switch phoneInclusionMode {
        case .all:
            return payload.phoneNumbers
        case .selected:
            if let selectedPhoneNumber, payload.phoneNumbers.contains(selectedPhoneNumber) {
                return [selectedPhoneNumber]
            } else {
                return payload.phoneNumbers.prefix(1).map { $0 }
            }
        }
    }

    private var configuredEmails: [String] {
        if payload.emails.count <= 1 {
            return payload.emails
        }

        switch emailInclusionMode {
        case .all:
            return payload.emails
        case .selected:
            if let selectedEmail, payload.emails.contains(selectedEmail) {
                return [selectedEmail]
            } else {
                return payload.emails.prefix(1).map { $0 }
            }
        }
    }

    private var configuredPayload: BusinessCardPayload? {
        // Rebuild the payload from the current UI selections so the QR code
        // and exported vCard always reflect the user's latest sharing choices.
        BusinessCardPayload(
            firstName: payload.firstName,
            lastName: payload.lastName,
            fullName: payload.fullName,
            company: payload.company,
            jobTitle: payload.jobTitle,
            phoneNumbers: configuredPhoneNumbers,
            emails: configuredEmails,
            photoData: payload.photoData
        )
    }

    private var qrCodeImage: UIImage? {
        guard let configuredPayload else { return nil }
        return QRCodeService.makeImage(from: VCardBuilder.build(from: configuredPayload))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerView

                    sharingOptionsView

                    qrCardView

                    detailsView

                    VStack(spacing: 12) {
                        // Primary action: share the digital business card as a .vcf file
                        Button(action: shareCard) {
                            Label("Share Card", systemImage: "square.and.arrow.up")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(DesignSystem.SemanticColors.brandOnAccent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(DesignSystem.SemanticColors.accent)
                                .cornerRadius(16)
                        }
                        .disabled(configuredPayload == nil)

                        Button(action: onChooseDifferentContact) {
                            Text("Choose Different Contact")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(DesignSystem.SemanticColors.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(DesignSystem.SemanticColors.cardBackground)
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(DesignSystem.SemanticColors.border, lineWidth: 1)
                                )
                        }
                    }
                }
                .padding(20)
            }
            .background(DesignSystem.SemanticColors.groupedScreenBackground)
            .navigationTitle("My Card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onClose)
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                }
            }
            .sheet(item: $shareSheetItem, onDismiss: {
                cleanupSharedFile()
            }) { item in
                ActivityViewController(activityItems: [item.url])
                    .presentationDetents([.medium, .large])
            }
            .onAppear {
                // Seed selected values so the "choose one" mode has a sensible default.
                if selectedPhoneNumber == nil {
                    selectedPhoneNumber = payload.phoneNumbers.first
                }

                if selectedEmail == nil {
                    selectedEmail = payload.emails.first
                }

                // Start in the cleaner collapsed state when a default selection exists.
                // The user can reopen the full list with the "Change" action.
                if payload.phoneNumbers.count > 1 {
                    isChoosingPhoneNumber = false
                }

                if payload.emails.count > 1 {
                    isChoosingEmail = false
                }
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            avatarView

            VStack(spacing: 4) {
                Text(payload.fullName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                    .multilineTextAlignment(.center)

                if let company = payload.company, !company.isEmpty {
                    Text(company)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.SemanticColors.secondaryText)
                }

                if let jobTitle = payload.jobTitle, !jobTitle.isEmpty {
                    Text(jobTitle)
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.SemanticColors.secondaryText)
                }
            }
        }
        .padding(.top, 8)
    }

    private var sharingOptionsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if payload.phoneNumbers.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Phone Numbers")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.SemanticColors.secondaryText)

                    Picker("Phone Numbers", selection: $phoneInclusionMode) {
                        Text("Include All").tag(ContactFieldInclusionMode.all)
                        Text("Choose One").tag(ContactFieldInclusionMode.selected)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: phoneInclusionMode) { _, newValue in
                        // When switching to "all", collapse the chooser.
                        // When switching to "choose one", show the compact selected state
                        // if a default already exists; otherwise open the chooser.
                        if newValue == .all {
                            isChoosingPhoneNumber = false
                        } else {
                            if selectedPhoneNumber == nil {
                                selectedPhoneNumber = payload.phoneNumbers.first
                            }
                            isChoosingPhoneNumber = selectedPhoneNumber == nil
                        }
                    }

                    if phoneInclusionMode == .selected {
                        if isChoosingPhoneNumber {
                            // Expanded chooser state shown only while the user is actively selecting.
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Selected Phone Number")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(DesignSystem.SemanticColors.secondaryText)

                                ForEach(payload.phoneNumbers, id: \.self) { phone in
                                    Button {
                                        selectedPhoneNumber = phone

                                        // Collapse immediately after a choice so the sheet stays compact.
                                        isChoosingPhoneNumber = false
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: selectedPhoneNumber == phone ? "largecircle.fill.circle" : "circle")
                                                .foregroundStyle(
                                                    selectedPhoneNumber == phone
                                                    ? DesignSystem.SemanticColors.accent
                                                    : DesignSystem.SemanticColors.secondaryText
                                                )

                                            Text(phone)
                                                .font(.body)
                                                .foregroundStyle(DesignSystem.SemanticColors.primaryText)

                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else if let selectedPhoneNumber {
                            // Collapsed summary state shown after a selection is made.
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Selected Phone Number")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(DesignSystem.SemanticColors.secondaryText)

                                HStack(spacing: 12) {
                                    Text(selectedPhoneNumber)
                                        .font(.body)
                                        .foregroundStyle(DesignSystem.SemanticColors.primaryText)

                                    Spacer()

                                    Button("Change") {
                                        isChoosingPhoneNumber = true
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(DesignSystem.SemanticColors.accent)
                                }
                            }
                        }
                    }
                }
            }

            if payload.emails.count > 1 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Email Addresses")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.SemanticColors.secondaryText)

                    Picker("Email Addresses", selection: $emailInclusionMode) {
                        Text("Include All").tag(ContactFieldInclusionMode.all)
                        Text("Choose One").tag(ContactFieldInclusionMode.selected)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: emailInclusionMode) { _, newValue in
                        // Match the phone-number UX so both fields behave consistently.
                        if newValue == .all {
                            isChoosingEmail = false
                        } else {
                            if selectedEmail == nil {
                                selectedEmail = payload.emails.first
                            }
                            isChoosingEmail = selectedEmail == nil
                        }
                    }

                    if emailInclusionMode == .selected {
                        if isChoosingEmail {
                            // Expanded chooser state shown only while the user is actively selecting.
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Selected Email Address")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(DesignSystem.SemanticColors.secondaryText)

                                ForEach(payload.emails, id: \.self) { email in
                                    Button {
                                        selectedEmail = email

                                        // Collapse immediately after a choice so the sheet stays compact.
                                        isChoosingEmail = false
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: selectedEmail == email ? "largecircle.fill.circle" : "circle")
                                                .foregroundStyle(
                                                    selectedEmail == email
                                                    ? DesignSystem.SemanticColors.accent
                                                    : DesignSystem.SemanticColors.secondaryText
                                                )

                                            Text(email)
                                                .font(.body)
                                                .foregroundStyle(DesignSystem.SemanticColors.primaryText)

                                            Spacer()
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else if let selectedEmail {
                            // Collapsed summary state shown after a selection is made.
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Selected Email Address")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(DesignSystem.SemanticColors.secondaryText)

                                HStack(spacing: 12) {
                                    Text(selectedEmail)
                                        .font(.body)
                                        .foregroundStyle(DesignSystem.SemanticColors.primaryText)

                                    Spacer()

                                    Button("Change") {
                                        isChoosingEmail = true
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(DesignSystem.SemanticColors.accent)
                                }
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(DesignSystem.SemanticColors.cardBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(DesignSystem.SemanticColors.border, lineWidth: 1)
        )
        .opacity(hasConfigurableFields ? 1.0 : 0.0)
        .frame(height: hasConfigurableFields ? nil : 0)
    }

    private var hasConfigurableFields: Bool {
        payload.phoneNumbers.count > 1 || payload.emails.count > 1
    }

    private var qrCardView: some View {
        VStack(spacing: 12) {
            if let qrCodeImage {
                Image(uiImage: qrCodeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300, maxHeight: 300)
            }

            Text("Your contact card is ready to share")
                .font(.caption)
                .foregroundStyle(DesignSystem.SemanticColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(DesignSystem.SemanticColors.cardBackground)
        .cornerRadius(28)
        .overlay(
            RoundedRectangle(cornerRadius: 28)
                .stroke(DesignSystem.SemanticColors.border, lineWidth: 1)
        )
    }

    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !configuredPhoneNumbers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.SemanticColors.secondaryText)

                    ForEach(configuredPhoneNumbers, id: \.self) { phone in
                        Text(phone)
                            .font(.body)
                            .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                    }
                }
            }

            if !configuredEmails.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.SemanticColors.secondaryText)

                    ForEach(configuredEmails, id: \.self) { email in
                        Text(email)
                            .font(.body)
                            .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(DesignSystem.SemanticColors.cardBackground)
        .cornerRadius(24)
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(DesignSystem.SemanticColors.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var avatarView: some View {
        if let photoData = payload.photoData, let image = UIImage(data: photoData) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 84, height: 84)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(DesignSystem.SemanticColors.secondaryGroupedBackground)
                .frame(width: 84, height: 84)
                .overlay(
                    Text(initials)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignSystem.SemanticColors.secondaryText)
                )
        }
    }

    private var initials: String {
        payload.fullName
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
            .uppercased()
    }

    // Build a temporary .vcf file from the configured payload and open the share sheet
    private func shareCard() {
        guard let configuredPayload else { return }

        let vCardString = VCardBuilder.build(from: configuredPayload)
        let fileName = sanitizedFileName(from: configuredPayload.fullName)
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
            .appendingPathExtension("vcf")

        do {
            try vCardString.write(to: temporaryURL, atomically: true, encoding: .utf8)
            shareSheetItem = ShareSheetItem(url: temporaryURL)
        } catch {
            print("Failed to write vCard file for sharing: \(error)")
        }
    }

    // Remove the temporary file after the native share sheet is dismissed
    private func cleanupSharedFile() {
        guard let shareURL = shareSheetItem?.url else { return }

        try? FileManager.default.removeItem(at: shareURL)
        shareSheetItem = nil
    }

    private func sanitizedFileName(from fullName: String) -> String {
        let trimmed = fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = trimmed.isEmpty ? "Peeply-Card" : trimmed

        return fallback
            .replacingOccurrences(of: "[^A-Za-z0-9 _-]", with: "", options: .regularExpression)
            .replacingOccurrences(of: " ", with: "-")
    }

    // Inclusion modes for configurable contact fields in the shared card
    private enum ContactFieldInclusionMode: Hashable {
        case all
        case selected
    }

    // Identifiable wrapper so the share sheet is driven by the actual file being shared
    private struct ShareSheetItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    // UIKit wrapper for the native iOS share sheet
    private struct ActivityViewController: UIViewControllerRepresentable {
        let activityItems: [Any]

        func makeUIViewController(context: Context) -> UIActivityViewController {
            let controller = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )

            // Exclude destinations that do not make sense for sharing a contact card
            controller.excludedActivityTypes = [
                .assignToContact,
                .print,
                .addToReadingList,
                .saveToCameraRoll,
                .openInIBooks,
                .markupAsPDF
            ]

            return controller
        }

        func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
    }
}
