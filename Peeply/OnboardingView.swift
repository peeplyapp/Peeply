//
// OnboardingView.swift
// Peeply
//
// Copyright 2026 Peeply LLC. All rights reserved.
// This software is confidential and proprietary property.
// Unauthorized copying, modification, or distribution is strictly prohibited.
//

import SwiftUI
import SwiftData
import UIKit

enum QuestionType {
    case textEntry
    case multipleChoice
}

struct OnboardingQuestion {
    let id: Int
    let question: String
    let subtitle: String?
    let type: QuestionType
    let answers: [String]
}

struct OnboardingView: View {
    @Binding var navigationPath: NavigationPath
    @Query private var users: [PeeplyUser]
    @Environment(\.modelContext) private var modelContext

    @State private var showWelcome = true
    @State private var currentQuestionIndex = 0
    @State private var emailInput = ""
    @State private var showEmailValidationMessage = false

    private var currentUser: PeeplyUser? {
        users.first
    }

    private let questions: [OnboardingQuestion] = [
        OnboardingQuestion(
            id: 1,
            question: "What is your email address?",
            subtitle: "We won't over-communicate, but from time to time we may have something exciting to share!",
            type: .textEntry,
            answers: []
        ),
        OnboardingQuestion(
            id: 2,
            question: "Do you currently own your own business? (Affiliate, Consultant, Direct Sales, Independent Contractor)",
            subtitle: nil,
            type: .multipleChoice,
            answers: ["Yes", "No"]
        ),
        OnboardingQuestion(
            id: 3,
            question: "How many people do you typically speak with in a day about your product or business?",
            subtitle: nil,
            type: .multipleChoice,
            answers: ["0–1", "2–5", "6–10", "Over 10 per day"]
        ),
        OnboardingQuestion(
            id: 4,
            question: "How would you describe your follow-up habits today?",
            subtitle: nil,
            type: .multipleChoice,
            answers: ["I am great at follow-up", "I could definitely improve"]
        ),
        OnboardingQuestion(
            id: 5,
            question: "Which best describes you?",
            subtitle: nil,
            type: .multipleChoice,
            answers: ["Introvert", "Extrovert", "A mix, depending on the situation"]
        ),
        OnboardingQuestion(
            id: 6,
            question: "What communication method do you prefer most?",
            subtitle: nil,
            type: .multipleChoice,
            answers: ["Live, in-person conversation", "Phone conversations", "Voice messages (e.g. WhatsApp)", "Text messages", "FaceTime / video calls"]
        ),
        OnboardingQuestion(
            id: 7,
            question: "How many NEW people do you meet in an average month? Truly new people whom you did not know before.",
            subtitle: nil,
            type: .multipleChoice,
            answers: ["0–1", "2–5", "6–10", "More than 10"]
        ),
        OnboardingQuestion(
            id: 8,
            question: "Think of the 5 people who matter most to you. When did you last reach out to each of them — just to connect, not for a reason.",
            subtitle: nil,
            type: .multipleChoice,
            answers: ["Within the last week", "Within the last month", "I honestly can't remember"]
        ),
        OnboardingQuestion(
            id: 9,
            question: "When you think about your most meaningful relationships, what feels most true?",
            subtitle: nil,
            type: .multipleChoice,
            answers: ["I invest in them consistently", "I feel like I've let some drift"]
        ),
        OnboardingQuestion(
            id: 10,
            question: "If the people in your contacts list were asked if you consistently make them feel remembered and valued, what would they say today?",
            subtitle: nil,
            type: .multipleChoice,
            answers: ["Absolutely, without hesitation", "Mostly yes", "Honestly, probably not enough"]
        )
    ]

    private var currentQuestion: OnboardingQuestion {
        questions[currentQuestionIndex]
    }

    private var isLastQuestion: Bool {
        currentQuestionIndex == questions.count - 1
    }

    // Trimmed email value used for validation and persistence.
    private var trimmedEmailInput: String {
        emailInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // Email is mandatory for the first onboarding question.
    // Keeping this logic centralized makes the UI state and action guard match.
    private var isEmailQuestionValid: Bool {
        isValidEmail(trimmedEmailInput)
    }

    private func startQuestions() {
        if currentUser == nil {
            let newUser = PeeplyUser(email: "", subscriptionTier: .gettingStarted)
            modelContext.insert(newUser)
            try? modelContext.save()
        }

        showWelcome = false
    }

    private func answerQuestion() {
        if currentQuestion.type == .textEntry {
            // Email is mandatory for onboarding question 1.
            // Guard here even though the button is disabled so business logic matches the UI.
            guard isEmailQuestionValid else {
                showEmailValidationMessage = true
                return
            }

            currentUser?.email = trimmedEmailInput
            showEmailValidationMessage = false

            // Submit the captured email to the existing Google Form endpoint.
            let formURL = "https://docs.google.com/forms/d/e/1FAIpQLSfdbkH2r12DaY2mtW4HAh1w3xOisVUT7wHhN89aUE2NtQkt_Q/formResponse"
            let fieldID = "entry.1562517931"

            if let encoded = trimmedEmailInput.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let url = URL(string: formURL) {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.httpBody = "\(fieldID)=\(encoded)".data(using: .utf8)
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                URLSession.shared.dataTask(with: request).resume()
            }
        }

        try? modelContext.save()

        if isLastQuestion {
            navigateToPlanSelection()
        } else {
            currentQuestionIndex += 1
        }
    }

    private func skipQuestion() {
        // The email question is mandatory, so prevent skipping it.
        if currentQuestion.type == .textEntry {
            showEmailValidationMessage = true
            return
        }

        if isLastQuestion {
            navigateToPlanSelection()
        } else {
            currentQuestionIndex += 1
        }
    }

    private func skipOnboarding() {
        navigateToPlanSelection()
    }

    // This onboarding flow ends at the paywall / plan-selection screen.
    // The old name suggested direct routing to contact import, but the app actually
    // requires plan selection first and only routes to contact import after purchase.
    private func navigateToPlanSelection() {
        currentUser?.onboardingCompleted = true
        try? modelContext.save()

        navigationPath = NavigationPath()
        navigationPath.append(AppRoute.planSelection)
    }

    // Lightweight email validation:
    // - mandatory,
    // - trims whitespace,
    // - requires a generally valid address format.
    //
    // This is intentionally simple UI validation rather than a perfect RFC parser.
    private func isValidEmail(_ email: String) -> Bool {
        guard !email.isEmpty else { return false }

        let pattern = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    var body: some View {
        ZStack {
            DesignSystem.SemanticColors.screenBackground
                .ignoresSafeArea()

            if showWelcome {
                welcomeView
            } else {
                questionView
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var welcomeView: some View {
        OnboardingScreenLayout(
            topPadding: 56,
            footerSpacing: 24,
            footer: {
                // Get Started button
                primaryButton(title: "Let's Go", action: startQuestions)
                    .padding(.bottom, 32)
            }
        ) {
            // Welcome content - top third of page
            VStack(spacing: 32) {
                // Welcome text
                Text("We want to get to know you first to customize your experience!")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .frame(maxWidth: .infinity)
        }
        .onAppear {
            // Set navigation title color
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(DesignSystem.SemanticColors.navigationBackground)
            appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(DesignSystem.SemanticColors.primaryText)]
            appearance.titleTextAttributes = [.foregroundColor: UIColor(DesignSystem.SemanticColors.primaryText)]
            UINavigationBar.appearance().standardAppearance = appearance
            UINavigationBar.appearance().scrollEdgeAppearance = appearance
            UINavigationBar.appearance().compactAppearance = appearance
        }
    }

    private var questionView: some View {
        OnboardingScreenLayout(
            topPadding: 16,
            horizontalPadding: 20,
            contentSpacing: 24,
            footerSpacing: 16,
            footer: {
                if currentQuestion.type != .textEntry {
                    // Navigation buttons
                    HStack {
                        // Skip Onboarding button
                        Button(action: skipOnboarding) {
                            Text("Skip Onboarding")
                                .font(.subheadline)
                                .foregroundStyle(DesignSystem.SemanticColors.secondaryText)
                        }

                        Spacer()

                        // Skip Question button
                        Button(action: skipQuestion) {
                            Text("Skip Question")
                                .font(.subheadline)
                                .foregroundStyle(DesignSystem.SemanticColors.secondaryText)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        ) {
            VStack(spacing: 24) {
                // Progress indicator
                HStack {
                    Spacer()

                    Text("Question \(currentQuestionIndex + 1) of \(questions.count)")
                        .font(.subheadline)
                        .foregroundStyle(DesignSystem.SemanticColors.secondaryText)
                }

                if currentQuestion.type == .textEntry {
                    emailQuestionSection
                } else {
                    multipleChoiceQuestionSection
                }
            }
        }
    }

    private var emailQuestionSection: some View {
        VStack(spacing: 20) {
            questionHeader(
                question: currentQuestion.question,
                subtitle: currentQuestion.subtitle,
                topPadding: 0,
                subtitleTopPadding: 8
            )

            HStack(spacing: 12) {
                TextField("Email address", text: $emailInput)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .submitLabel(.next)
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(DesignSystem.SemanticColors.inputBackground)
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                showEmailValidationMessage && !isEmailQuestionValid
                                ? Color.red.opacity(0.7)
                                : DesignSystem.SemanticColors.border,
                                lineWidth: 1
                            )
                    )
                    .onSubmit {
                        answerQuestion()
                    }
                    .onChange(of: emailInput) { _, _ in
                        // Clear the validation state as soon as the user begins correcting input.
                        if isEmailQuestionValid {
                            showEmailValidationMessage = false
                        }
                    }

                Button(action: answerQuestion) {
                    Image(systemName: "arrow.forward.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(
                            isEmailQuestionValid
                            ? DesignSystem.SemanticColors.primaryText
                            : DesignSystem.SemanticColors.tertiaryText
                        )
                }
                .disabled(!isEmailQuestionValid)
            }

            if showEmailValidationMessage && !isEmailQuestionValid {
                Text("Please enter a valid email address to continue.")
                    .font(.footnote)
                    .foregroundStyle(Color.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }

    private var multipleChoiceQuestionSection: some View {
        VStack(spacing: 24) {
            questionHeader(
                question: currentQuestion.question,
                subtitle: currentQuestion.subtitle,
                topPadding: 0,
                subtitleTopPadding: 0
            )

            // Answer buttons
            if currentQuestion.type != .textEntry {
                VStack(spacing: 16) {
                    ForEach(currentQuestion.answers, id: \.self) { answer in
                        Button(action: answerQuestion) {
                            Text(answer)
                                .font(.headline)
                                .foregroundStyle(DesignSystem.SemanticColors.brandOnAccent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(DesignSystem.SemanticColors.accent)
                                .cornerRadius(16)
                        }
                    }
                }
            }
        }
        .padding(.bottom, 24)
    }

    private func questionHeader(
        question: String,
        subtitle: String?,
        topPadding: CGFloat,
        subtitleTopPadding: CGFloat
    ) -> some View {
        VStack(spacing: 12) {
            // Question text
            Text(question)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(DesignSystem.SemanticColors.primaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.top, topPadding)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(DesignSystem.SemanticColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.top, subtitleTopPadding)
            }
        }
    }

    private func primaryButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(DesignSystem.SemanticColors.brandOnAccent)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(DesignSystem.SemanticColors.accent)
                .cornerRadius(16)
        }
        .padding(.horizontal, 20)
    }
}

// Reusable top-anchored onboarding screen shell.
// Use this for welcome, onboarding, import, and lightweight form screens
// where the content should stay visually stable across device sizes.
private struct OnboardingScreenLayout<Content: View, Footer: View>: View {
    let topPadding: CGFloat
    var horizontalPadding: CGFloat = 20
    var contentSpacing: CGFloat = 0
    var footerSpacing: CGFloat = 0
    @ViewBuilder let footer: () -> Footer
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: contentSpacing) {
                content()
            }
            .padding(.top, topPadding)
            .padding(.horizontal, horizontalPadding)
            .frame(maxWidth: .infinity, alignment: .top)

            Spacer(minLength: footerSpacing)

            footer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

#Preview {
    NavigationStack {
        OnboardingView(navigationPath: .constant(NavigationPath()))
    }
}
