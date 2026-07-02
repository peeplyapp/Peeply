//
// ContactListView.swift
// Peeply
//
// Copyright 2026 Peeply LLC. All rights reserved.
// This software is confidential and proprietary property.
// Unauthorized copying, modification, or distribution is strictly prohibited.
//

import SwiftUI
import SwiftData
import UIKit

struct ContactListView: View {
    @Binding var navigationPath: NavigationPath

    @Query(
        sort: [
            SortDescriptor(\Contact.displaySortKey, order: .forward),
            SortDescriptor(\Contact.firstName, order: .forward)
        ]
    ) private var contacts: [Contact]

    @Query private var users: [PeeplyUser]
    @Environment(\.modelContext) private var modelContext

    @State private var selectedContact: Contact?
    @State private var showDatePicker = false
    @State private var selectedDate = Date()
    @State private var showRandomizer = false
    @State private var randomContacts: [Contact] = []
    @State private var hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    @State private var showStreakDetails = false
    @State private var showStreakCelebration = false
    @State private var showSearch = false
    @State private var searchText = ""
    @FocusState private var isSearchFieldFocused: Bool
    @State private var showSupport = false
    @State private var showNewContactsSheet = false
    @State private var contactToOpenAfterSheetDismiss: Contact?

    // New contact draft state
    @State private var showAddContactSheet = false
    @State private var newContactFirstName = ""
    @State private var newContactLastName = ""
    @State private var newContactPhone = ""
    @State private var newContactEmail = ""
    @State private var newContactCompany = ""

    // Delete confirmation state
    @State private var contactPendingDeletion: Contact?
    @State private var showDeleteConfirmation = false

    // My Card feature state
    @State private var showMyCardSelector = false
    @State private var showMyBusinessCard = false

    private var sortedContacts: [Contact] {
        // Contacts are now sorted at the SwiftData query layer using displaySortKey
        // to preserve the old "last name if present, otherwise first name" behavior
        // without re-sorting the entire list in memory on every view recomputation.
        contacts
    }

    private var filteredContacts: [Contact] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return sortedContacts }

        return sortedContacts.filter { contact in
            contact.firstName.lowercased().contains(query) ||
            (contact.lastName?.lowercased() ?? "").contains(query)
        }
    }

    private func fullName(for contact: Contact) -> String {
        if let lastName = contact.lastName, !lastName.isEmpty {
            return "\(contact.firstName) \(lastName)"
        } else {
            return contact.firstName
        }
    }

    private func formattedDateString(for contact: Contact) -> String {
        if let date = contact.lastOneToOne {
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            formatter.timeStyle = .none
            return formatter.string(from: date)
        } else {
            return "Not set"
        }
    }

    private func initials(for contact: Contact) -> String {
        let firstInitial = contact.firstName.prefix(1).uppercased()
        let lastInitial = contact.lastName?.prefix(1).uppercased() ?? ""
        return "\(firstInitial)\(lastInitial)"
    }

    private func contactPhoto(for contact: Contact) -> UIImage? {
        guard let photoData = contact.photoData else { return nil }
        return UIImage(data: photoData)
    }

    private func openDatePicker(for contact: Contact) {
        selectedContact = contact
        selectedDate = contact.lastOneToOne ?? Date()
        showDatePicker = true
    }

    private var currentUser: PeeplyUser? {
        users.first
    }

    private var myCardContact: Contact? {
        guard let myCardContactId = currentUser?.myCardContactId else { return nil }
        return sortedContacts.first(where: { $0.id == myCardContactId })
    }

    // Extracted My Card sheet content to reduce type-checking complexity
    // in the main body modifier chain and keep the sheet call site lightweight.
    private var myBusinessCardSheetContent: some View {
        Group {
            if let contact = myCardContact,
               let payload = BusinessCardPayload(contact: contact) {
                MyBusinessCardSheet(
                    payload: payload,
                    onChooseDifferentContact: {
                        showMyBusinessCard = false
                        showMyCardSelector = true
                    },
                    onClose: {
                        showMyBusinessCard = false
                    }
                )
            } else {
                invalidMyCardFallbackView
            }
        }
    }

    // Fallback view extracted from the sheet closure so the compiler does not need
    // to resolve a large conditional NavigationStack inline inside the .sheet modifier.
    private var invalidMyCardFallbackView: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Your saved card contact no longer has a phone number or email.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignSystem.SemanticColors.primaryText)

                Button("Choose Contact") {
                    currentUser?.myCardContactId = nil
                    try? modelContext.save()
                    showMyBusinessCard = false
                    showMyCardSelector = true
                }
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.SemanticColors.accent)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DesignSystem.SemanticColors.groupedScreenBackground)
            .navigationTitle("My Card")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var newContactsThisMonth: Int {
        contactsCreatedThisMonth.count
    }

    private var contactsCreatedThisMonth: [Contact] {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now

        return sortedContacts.filter { contact in
            guard let createdAt = contact.createdAt else { return false }
            return createdAt >= startOfMonth
        }
    }

    private func saveDate() {
        guard let contact = selectedContact else { return }

        let wasToday = StreakManager.isToday(selectedDate)
        contact.lastOneToOne = selectedDate
        try? modelContext.save()

        // Update streak if date is today
        if wasToday, let user = currentUser {
            let streakContinued = StreakManager.updateStreak(for: user, in: modelContext)
            if streakContinued {
                // Show celebration
                showStreakCelebration = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showStreakCelebration = false
                }
            }
        }

        showDatePicker = false
        selectedContact = nil
    }

    private func selectRandomContacts() {
        let availableContacts = sortedContacts
        let count = min(5, availableContacts.count)

        if count == 0 {
            return
        }

        // Select random contacts
        var selected: [Contact] = []
        var indices = Set<Int>()

        while selected.count < count && indices.count < availableContacts.count {
            let randomIndex = Int.random(in: 0..<availableContacts.count)
            if !indices.contains(randomIndex) {
                indices.insert(randomIndex)
                selected.append(availableContacts[randomIndex])
            }
        }

        randomContacts = selected
        showRandomizer = true
    }

    private func openContactDetail(_ contact: Contact) {
        showRandomizer = false
        navigationPath.append(AppRoute.contactDetail(contact))
    }

    private func addNewContact() {
        newContactFirstName = ""
        newContactLastName = ""
        newContactPhone = ""
        newContactEmail = ""
        newContactCompany = ""
        showAddContactSheet = true
    }

    private func saveNewContact() {
        let trimmedFirstName = newContactFirstName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFirstName.isEmpty else { return }
        
        let trimmedLastName = newContactLastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = newContactPhone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = newContactEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCompany = newContactCompany.trimmingCharacters(in: .whitespacesAndNewlines)


        let contact = Contact(
                    firstName: trimmedFirstName,
                    lastName: trimmedLastName.isEmpty ? nil : trimmedLastName,
                    phoneNumbers: trimmedPhone.isEmpty ? [] : [trimmedPhone],
                    emails: trimmedEmail.isEmpty ? [] : [trimmedEmail],
                    company: trimmedCompany.isEmpty ? nil : trimmedCompany
                )

        modelContext.insert(contact)
        try? modelContext.save()

        showAddContactSheet = false
    }

    private func discardNewContact() {
        showAddContactSheet = false
        newContactFirstName = ""
        newContactLastName = ""
        newContactPhone = ""
        newContactEmail = ""
        newContactCompany = ""
    }

    private func confirmDelete(_ contact: Contact) {
        contactPendingDeletion = contact
        showDeleteConfirmation = true
    }

    private func deletePendingContact() {
        guard let contact = contactPendingDeletion else { return }

        if currentUser?.myCardContactId == contact.id {
            currentUser?.myCardContactId = nil
        }

        modelContext.delete(contact)
        try? modelContext.save()
        contactPendingDeletion = nil
    }

    private func openMyCard() {
        if myCardContact != nil {
            showMyBusinessCard = true
        } else {
            showMyCardSelector = true
        }
    }

    private func selectMyCardContact(_ contact: Contact) {
        if currentUser == nil {
            let newUser = PeeplyUser(
                email: "",
                subscriptionTier: .gettingStarted
            )
            modelContext.insert(newUser)
            try? modelContext.save()
        }

        currentUser?.myCardContactId = contact.id
        try? modelContext.save()

        showMyCardSelector = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showMyBusinessCard = true
        }
    }

    private func streakCard(user: PeeplyUser?) -> some View {
        Button(action: {
            showStreakDetails = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Top row with icon and arrow
                HStack {
                    // Icon square
                    RoundedRectangle(cornerRadius: 20)
                        .fill(DesignSystem.SemanticColors.secondaryGroupedBackground)
                        .frame(width: 52, height: 52)
                        .overlay(
                            Text("🔥")
                                .font(.system(size: 24))
                        )

                    Spacer()

                    // Arrow icon
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignSystem.SemanticColors.tertiaryText)
                }

                // Number
                if let user = user, user.currentStreak > 0 {
                    Text("\(user.currentStreak)")
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                } else {
                    Text("0")
                        .font(.system(size: 20, weight: .bold, design: .default))
                        .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                }

                // Descriptive text
                Text("Daily one-to-one\nStreak")
                    .font(.system(size: 12, weight: .regular, design: .default))
                    .foregroundStyle(DesignSystem.SemanticColors.secondaryText)
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(DesignSystem.SemanticColors.cardBackground)
            .cornerRadius(20)
        }
        .buttonStyle(.plain)
    }

    private var growthTrackingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row with icon and arrow
            HStack {
                // Icon square
                RoundedRectangle(cornerRadius: 20)
                    .fill(DesignSystem.SemanticColors.secondaryGroupedBackground)
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "arrow.up")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                    )

                Spacer()

                // Arrow icon
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(DesignSystem.SemanticColors.tertiaryText)
            }

            // Number
            Text("\(newContactsThisMonth)")
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(DesignSystem.SemanticColors.primaryText)

            // Descriptive text
            Text("New Contacts Added\nthis Month")
                .font(.system(size: 12, weight: .regular, design: .default))
                .foregroundStyle(DesignSystem.SemanticColors.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.SemanticColors.cardBackground)
        .cornerRadius(20)
    }

    private var celebrationView: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Text("🔥")
                    .font(.system(size: 60))
                    .scaleEffect(showStreakCelebration ? 1.3 : 1.0)

                if let user = currentUser {
                    Text("\(user.currentStreak) Day Streak!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(DesignSystem.SemanticColors.cardBackground)
                                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                        )
                }
            }
            .padding(.horizontal, 40)
            .scaleEffect(showStreakCelebration ? 1.0 : 0.8)
            .opacity(showStreakCelebration ? 1.0 : 0.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showStreakCelebration)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Custom navigation bar
            HStack {
                Button(action: openMyCard) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(DesignSystem.SemanticColors.toolbarIcon)
                        .frame(width: 40, height: 40)
                        .background(DesignSystem.SemanticColors.cardBackground)
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(DesignSystem.SemanticColors.border, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                // Title
                Text("Contacts")
                    .font(.system(size: 20, weight: .medium, design: .default))
                    .foregroundStyle(DesignSystem.SemanticColors.primaryText)

                Spacer()

                // Balance the title visually
                Color.clear
                    .frame(width: 40, height: 40)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DesignSystem.SemanticColors.navigationBackground)

            // Search bar shown when Search tab or nav icon is tapped
            if showSearch {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(DesignSystem.SemanticColors.secondaryText)

                    TextField("Search contacts", text: $searchText)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isSearchFieldFocused)
                        .overlay(alignment: .trailing) {
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(DesignSystem.SemanticColors.secondaryText)
                                }
                                .padding(.trailing, 4)
                            }
                        }
                }
                .padding(12)
                .background(DesignSystem.SemanticColors.inputBackground)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(DesignSystem.SemanticColors.border, lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .background(DesignSystem.SemanticColors.groupedScreenBackground)
                .onAppear {
                    isSearchFieldFocused = true
                }
            }

            // Content
            List {
                // Streak and Growth cards side-by-side
                Section {
                    HStack(spacing: 12) {
                        streakCard(user: currentUser)

                        Button(action: {
                            showNewContactsSheet = true
                        }) {
                            growthTrackingCard
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(DesignSystem.SemanticColors.groupedScreenBackground)
                .listRowSeparator(.hidden)

                // Contact list
                Section {
                    ForEach(filteredContacts, id: \.id) { contact in
                        HStack(spacing: 20) {
                            // Contact photo or initials
                            if let photo = contactPhoto(for: contact) {
                                Image(uiImage: photo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 52, height: 52)
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
                                    .frame(width: 52, height: 52)
                                    .overlay(
                                        Text(initials(for: contact))
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(DesignSystem.SemanticColors.brandOnAccent)
                                    )
                            }

                            // Contact info
                            VStack(alignment: .leading, spacing: 4) {
                                Button(action: {
                                    navigationPath.append(AppRoute.contactDetail(contact))
                                }) {
                                    Text(fullName(for: contact))
                                        .font(.system(size: 16, weight: .medium, design: .default))
                                        .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)

                                Button(action: {
                                    openDatePicker(for: contact)
                                }) {
                                    Text("Last one-to-one: \(formattedDateString(for: contact))")
                                        .font(.system(size: 12, weight: .regular, design: .default))
                                        .foregroundStyle(DesignSystem.SemanticColors.secondaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }

                            Spacer()

                            // Chevron
                            Button(action: {
                                navigationPath.append(AppRoute.contactDetail(contact))
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(DesignSystem.SemanticColors.secondaryText)
                            }
                            .buttonStyle(.plain)
                            .padding(12)
                            .background(DesignSystem.SemanticColors.cardBackground)
                            .cornerRadius(20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(DesignSystem.SemanticColors.border, lineWidth: 1)
                            )
                        }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(DesignSystem.SemanticColors.groupedScreenBackground)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                confirmDelete(contact)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(DesignSystem.SemanticColors.groupedScreenBackground)
        }
        .background(DesignSystem.SemanticColors.groupedScreenBackground)
        .navigationBarHidden(true)
        .safeAreaInset(edge: .bottom) {
            // Bottom tab bar
            HStack(spacing: 0) {
                // Search - left
                Button(action: {
                    showSearch = true
                    isSearchFieldFocused = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(DesignSystem.SemanticColors.toolbarIcon)

                        Text("Search")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                // Add - center
                Button(action: addNewContact) {
                    VStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(DesignSystem.SemanticColors.accent)

                        Text("Add")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                // Support - right
                Button(action: {
                    showSupport = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "headphones")
                            .font(.system(size: 22, weight: .regular))
                            .foregroundStyle(DesignSystem.SemanticColors.toolbarIcon)

                        Text("Support")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 30)
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .overlay {
            // Celebration overlay
            if showStreakCelebration {
                celebrationView
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
        }
        .alert("Connection Streak", isPresented: $showStreakDetails) {
            Button("OK", role: .cancel) { }
        } message: {
            if let user = currentUser, user.currentStreak > 0 {
                Text("You've had a meaningful connection \(user.currentStreak) days in a row. Keep it going!")
            } else {
                Text("Start a new streak today!")
            }
        }
        .alert("Delete Contact", isPresented: $showDeleteConfirmation, presenting: contactPendingDeletion) { _ in
            Button("Delete", role: .destructive) {
                deletePendingContact()
            }

            Button("Cancel", role: .cancel) {
                contactPendingDeletion = nil
            }
        } message: { contact in
            Text("Are you sure you want to delete \(fullName(for: contact))? This action cannot be undone.")
        }
        .onAppear {
            hapticGenerator.prepare()
        }
        .onShake {
            selectRandomContacts()
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(
                selectedDate: $selectedDate,
                onSave: saveDate,
                onCancel: {
                    showDatePicker = false
                    selectedContact = nil
                }
            )
        }
        .sheet(isPresented: $showRandomizer) {
            ContactRandomizerSheet(
                contacts: $randomContacts,
                onContactTap: openContactDetail,
                onShake: selectRandomContacts,
                onClose: {
                    showRandomizer = false
                }
            )
        }
        .sheet(isPresented: $showSupport) {
            SupportView()
        }
        .sheet(isPresented: $showNewContactsSheet, onDismiss: {
            if let contactToOpenAfterSheetDismiss {
                navigationPath.append(AppRoute.contactDetail(contactToOpenAfterSheetDismiss))
                self.contactToOpenAfterSheetDismiss = nil
            }
        }) {
            NavigationStack {
                List(contactsCreatedThisMonth, id: \.id) { contact in
                    Button(action: {
                        contactToOpenAfterSheetDismiss = contact
                        showNewContactsSheet = false
                    }) {
                        Text(fullName(for: contact))
                            .font(.system(size: 16, weight: .regular, design: .default))
                            .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                    }
                }
                .navigationTitle("New Contacts This Month")
                .navigationBarTitleDisplayMode(.inline)
                .scrollContentBackground(.hidden)
                .background(DesignSystem.SemanticColors.groupedScreenBackground)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showNewContactsSheet = false
                        }
                        .fontWeight(.medium)
                        .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                    }
                }
            }
        }
        .sheet(isPresented: $showAddContactSheet) {
            AddContactSheet(
                firstName: $newContactFirstName,
                lastName: $newContactLastName,
                phoneNumber: $newContactPhone,
                email: $newContactEmail,
                company: $newContactCompany,
                onSave: saveNewContact,
                onDiscard: discardNewContact
            )
        }
        .sheet(isPresented: $showMyCardSelector) {
            MyCardSelectorSheet(
                contacts: sortedContacts,
                selectedContactId: currentUser?.myCardContactId,
                onSelect: selectMyCardContact,
                onCancel: {
                    showMyCardSelector = false
                }
            )
        }
        .sheet(isPresented: $showMyBusinessCard) {
            myBusinessCardSheetContent
        }
    }
}

// Shake gesture detection
struct ShakeDetector: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeViewController {
        let controller = ShakeViewController()
        controller.onShake = onShake
        return controller
    }

    func updateUIViewController(_ uiViewController: ShakeViewController, context: Context) {
        uiViewController.onShake = onShake
    }
}

class ShakeViewController: UIViewController {
    var onShake: (() -> Void)?

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            onShake?()
        }
    }
}

extension View {
    func onShake(perform action: @escaping () -> Void) -> some View {
        self.background(ShakeDetector(onShake: action))
    }
}

struct ContactRandomizerSheet: View {
    @Binding var contacts: [Contact]
    let onContactTap: (Contact) -> Void
    let onShake: () -> Void
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Headline
                VStack(spacing: 16) {
                    Text("You have activated the Peeply Randomizer! Here are the lucky people who get to hear from you today!")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(DesignSystem.SemanticColors.accent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 24)
                }

                // Contact list
                if contacts.isEmpty {
                    Spacer()
                    Text("No contacts available")
                        .foregroundStyle(.secondary)
                    Spacer()
                } else {
                    List(contacts, id: \.id) { contact in
                        Button(action: {
                            onContactTap(contact)
                        }) {
                            HStack(spacing: 12) {
                                // Contact photo or initials
                                if let photo = contactPhoto(for: contact) {
                                    Image(uiImage: photo)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                colors: [DesignSystem.rose, DesignSystem.lavender],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Text(initials(for: contact))
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(DesignSystem.SemanticColors.brandOnAccent)
                                        )
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(fullName(for: contact))
                                        .font(.body)
                                        .foregroundStyle(.primary)

                                    if let company = contact.company, !company.isEmpty {
                                        Text(company)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    Text("📸 Take a screenshot! Once you close or navigate away from this unique Randomizer list you will not be able to return to it.")
                        .font(.caption)
                        .foregroundStyle(DesignSystem.SemanticColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("Contact Randomizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Close", action: onClose)
                        .fontWeight(.semibold)
                }
            }
        }
        .onShake {
            onShake()
        }
    }

    private func fullName(for contact: Contact) -> String {
        if let lastName = contact.lastName, !lastName.isEmpty {
            return "\(contact.firstName) \(lastName)"
        } else {
            return contact.firstName
        }
    }

    private func initials(for contact: Contact) -> String {
        let firstInitial = contact.firstName.prefix(1).uppercased()
        let lastInitial = contact.lastName?.prefix(1).uppercased() ?? ""
        return "\(firstInitial)\(lastInitial)"
    }

    private func contactPhoto(for contact: Contact) -> UIImage? {
        guard let photoData = contact.photoData else { return nil }
        return UIImage(data: photoData)
    }
}

struct DatePickerSheet: View {
    @Binding var selectedDate: Date
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var hapticGenerator = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "Select Date",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                .onChange(of: selectedDate) { _, _ in
                    hapticGenerator.prepare()
                    hapticGenerator.impactOccurred()
                }

                Spacer()
            }
            .onAppear {
                hapticGenerator.prepare()
            }
            .navigationTitle("Last One-to-One")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct AddContactSheet: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var phoneNumber: String
    @Binding var email: String
    @Binding var company: String

    let onSave: () -> Void
    let onDiscard: () -> Void

    private var canSave: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("First name", text: $firstName)
                    TextField("Last name", text: $lastName)
                }

                Section("Contact Info") {
                    TextField("Phone", text: $phoneNumber)
                        .keyboardType(.phonePad)

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Company", text: $company)
                }
            }
            .navigationTitle("New Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .destructive, action: onDiscard)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    NavigationStack {
        ContactListView(navigationPath: .constant(NavigationPath()))
            .modelContainer(for: [Contact.self, PeeplyUser.self], inMemory: true)
    }
}
