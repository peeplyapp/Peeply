//
// AboutView.swift
// Peeply
//
//  Copyright 2026 Peeply LLC. All rights reserved.
//  This software is confidential and proprietary property.
//  Unauthorized copying, modification, or distribution is strictly prohibited.

import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text("About Peeply")
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                    .padding(.top, 20)

                // Body text
                Text("Peeply was built on a simple truth: Relationships aren't just something, they are Everything. In fact, our relationships with others are the most important thing we have in life. Over time they can strengthen or they can fade. It is with intentional Consistency, a quick call, a simple text, showing up to check-in or even just to say hello that we foster the best relationships.\n\nWe're not here to manage your network or optimize your connections. We're here to help you be consistent in your relationships and have fun while doing it! Peeply is your daily helper to be the friend, family member, or colleague you want to be — the one who stays in touch, even when life gets busy or complicated.\n\nBecause at the end of the day, the people in your contacts aren't just names and numbers. They're your people. And they're worth keeping close.")
                    .font(.system(size: 16, weight: .regular, design: .default))
                    .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(DesignSystem.SemanticColors.screenBackground)
        .navigationTitle("About Peeply")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
