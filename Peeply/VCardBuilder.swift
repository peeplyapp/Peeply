//
// VCardBuilder.swift
// Peeply
//
// Copyright 2026 Peeply LLC. All rights reserved.
// This software is confidential and proprietary property.
// Unauthorized copying, modification, or distribution is strictly prohibited.
//

import Foundation

enum VCardBuilder {
    /// Build a compact vCard payload for the QR code.
    /// The MVP intentionally includes only professional sharing fields.
    static func build(from payload: BusinessCardPayload) -> String {
        let escapedFirstName = escape(payload.firstName)
        let escapedLastName = escape(payload.lastName ?? "")
        let escapedFullName = escape(payload.fullName)

        var lines: [String] = [
            "BEGIN:VCARD",
            "VERSION:3.0",
            "N:\(escapedLastName);\(escapedFirstName);;;",
            "FN:\(escapedFullName)"
        ]

        if let company = payload.company, !company.isEmpty {
            lines.append("ORG:\(escape(company))")
        }

        if let jobTitle = payload.jobTitle, !jobTitle.isEmpty {
            lines.append("TITLE:\(escape(jobTitle))")
        }

        for phone in payload.phoneNumbers.map(cleanPhone).filter({ !$0.isEmpty }) {
            lines.append("TEL;TYPE=CELL:\(phone)")
        }

        for email in payload.emails {
            lines.append("EMAIL;TYPE=INTERNET:\(escape(email))")
        }

        lines.append("END:VCARD")
        return lines.joined(separator: "\r\n")
    }

    private static func cleanPhone(_ phone: String) -> String {
        phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
