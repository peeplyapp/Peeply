//
//  Contact.swift
//  Peeply
//
//  Copyright 2026 Peeply LLC. All rights reserved.
//  This software is confidential and proprietary property.
//  Unauthorized copying, modification, or distribution is strictly prohibited.

import Foundation
import SwiftData

@Model
final class Contact {
    var id: UUID
    var firstName: String
    var lastName: String?
    var phoneNumbers: [String]
    var emails: [String]
    var company: String?
    var jobTitle: String?
    var notes: String?
    var birthday: Date?
    var addresses: [String]
    var lastOneToOne: Date?
    var photoData: Data?
    var socialMediaLinks: [String: String] // Platform name -> URL/username
    var createdAt: Date?
    var wasPersonOfTheDay: Date?
    var displaySortKey: String // Persisted sort key used to preserve last name if present, otherwise first name ordering at fetch time

    init(
        id: UUID = UUID(),
        firstName: String,
        lastName: String? = nil,
        phoneNumbers: [String] = [],
        emails: [String] = [],
        company: String? = nil,
        jobTitle: String? = nil,
        notes: String? = nil,
        birthday: Date? = nil,
        addresses: [String] = [],
        lastOneToOne: Date? = nil,
        photoData: Data? = nil,
        socialMediaLinks: [String: String] = [:],
        createdAt: Date? = Date(),
        wasPersonOfTheDay: Date? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.phoneNumbers = phoneNumbers
        self.emails = emails
        self.company = company
        self.jobTitle = jobTitle
        self.notes = notes
        self.birthday = birthday
        self.addresses = addresses
        self.lastOneToOne = lastOneToOne
        self.photoData = photoData
        self.socialMediaLinks = socialMediaLinks
        self.createdAt = createdAt
        self.wasPersonOfTheDay = wasPersonOfTheDay
        self.displaySortKey = Contact.makeDisplaySortKey(firstName: firstName, lastName: lastName)
    }

    static func makeDisplaySortKey(firstName: String, lastName: String?) -> String {
        let trimmedLastName = lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedLastName.isEmpty {
            return trimmedLastName.lowercased()
        } else {
            return firstName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    func refreshDisplaySortKey() {
        displaySortKey = Contact.makeDisplaySortKey(firstName: firstName, lastName: lastName)
    }
}

// MARK: - Business Card Helpers
extension Contact {
    /// Full display name used across the app for headings and selection rows.
    var fullName: String {
        let trimmedLastName = lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedLastName.isEmpty {
            return firstName
        } else {
            return "\(firstName) \(trimmedLastName)"
        }
    }

    /// Initials fallback for contacts without a photo.
    var initials: String {
        let firstInitial = firstName.prefix(1).uppercased()
        let lastInitial = lastName?.prefix(1).uppercased() ?? ""
        return firstInitial + lastInitial
    }

    /// Reusable validation rule for features that require a contact to have at least
    /// one reachable professional detail. This mirrors the import-time concept that
    /// a contact should have a phone number or email to be considered usable.
    var hasBusinessCardReachability: Bool {
        !sanitizedPhoneNumbers.isEmpty || !sanitizedEmails.isEmpty
    }

    /// Phone numbers trimmed for business-card use.
    var sanitizedPhoneNumbers: [String] {
        phoneNumbers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Email addresses trimmed for business-card use.
    var sanitizedEmails: [String] {
        emails
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Professional-only payload eligibility check for the MVP QR card.
    var canBeUsedForMyCard: Bool {
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedFirstName.isEmpty && hasBusinessCardReachability
    }
}
