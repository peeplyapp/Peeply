//
// BusinessCardPayload.swift
// Peeply
//
// Copyright 2026 Peeply LLC. All rights reserved.
// This software is confidential and proprietary property.
// Unauthorized copying, modification, or distribution is strictly prohibited.
//

import Foundation

struct BusinessCardPayload: Equatable {
    let firstName: String
    let lastName: String?
    let fullName: String
    let company: String?
    let jobTitle: String?
    let phoneNumbers: [String]
    let emails: [String]
    let photoData: Data?

    init?(
        firstName: String,
        lastName: String?,
        fullName: String,
        company: String?,
        jobTitle: String?,
        phoneNumbers: [String],
        emails: [String],
        photoData: Data?
    ) {
        let trimmedFirstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLastName = lastName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let trimmedFullName = fullName.trimmingCharacters(in: .whitespacesAndNewlines)

        let cleanedPhones = phoneNumbers
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let cleanedEmails = emails
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !trimmedFirstName.isEmpty,
              !trimmedFullName.isEmpty,
              !cleanedPhones.isEmpty || !cleanedEmails.isEmpty else {
            return nil
        }

        self.firstName = trimmedFirstName
        self.lastName = trimmedLastName
        self.fullName = trimmedFullName
        self.company = company?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.jobTitle = jobTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.phoneNumbers = cleanedPhones
        self.emails = cleanedEmails
        self.photoData = photoData
    }

    init?(contact: Contact) {
        guard contact.canBeUsedForMyCard else { return nil }

        self.init(
            firstName: contact.firstName,
            lastName: contact.lastName,
            fullName: contact.fullName,
            company: contact.company,
            jobTitle: contact.jobTitle,
            phoneNumbers: contact.sanitizedPhoneNumbers,
            emails: contact.sanitizedEmails,
            photoData: contact.photoData
        )
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
