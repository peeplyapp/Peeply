//
//  SupportView.swift
//  Peeply
//
//  Copyright 2026 Peeply LLC. All rights reserved.
//  This software is confidential and proprietary property.
//  Unauthorized copying, modification, or distribution is strictly prohibited.

import SwiftUI
import SwiftData

struct SupportView: View {
    @Query private var users: [PeeplyUser]
    @Query private var contacts: [Contact]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false
    @State private var navigationPath = NavigationPath()

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section {
                    // Contact Support
                    NavigationRow(title: "Contact Support") {
                        if let url = URL(string: "mailto:support@peeplyapp.com") {
                            openURL(url)
                        }
                    }

                    // About Peeply
                    NavigationRow(title: "About Peeply") {
                        navigationPath.append(AppRoute.about)
                    }

                    // Privacy Policy
                    NavigationRow(title: "Privacy Policy") {
                        navigationPath.append(AppRoute.privacyPolicy)
                    }

                    // Terms of Service
                    NavigationRow(title: "Terms of Service") {
                        navigationPath.append(AppRoute.termsOfService)
                    }

                    // App Version
                    HStack {
                        Text("App Version")
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .foregroundStyle(.primary)

                        Spacer()

                        Text(appVersion)
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    // Delete Account
                    NavigationRow(
                        title: "Delete Account",
                        titleColor: .red,
                        chevronColor: .secondary
                    ) {
                        showDeleteConfirmation = true
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Support")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationDestination(for: AppRoute.self) { route in
                destinationView(for: route)
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to delete your account? This will permanently delete all your data and cannot be undone.")
            }
        }
    }

    @ViewBuilder
    private func destinationView(for route: AppRoute) -> some View {
        switch route {
        case .about:
            AboutView()
        case .privacyPolicy:
            PrivacyPolicyView()
        case .termsOfService:
            TermsOfServiceView()
        default:
            EmptyView()
        }
    }

    private func deleteAccount() {
        // Delete all contacts
        for contact in contacts {
            modelContext.delete(contact)
        }

        // Delete user
        for user in users {
            modelContext.delete(user)
        }

        // Save changes
        try? modelContext.save()

        // Dismiss the sheet
        dismiss()
    }
}

private struct NavigationRow: View {
    let title: String
    var titleColor: Color = .primary
    var chevronColor: Color = .secondary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundStyle(titleColor)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(chevronColor)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        SupportView()
            .modelContainer(for: [Contact.self, PeeplyUser.self], inMemory: true)
    }
}
