//
//  MemberLoginView.swift
//  StoneBC
//

import SwiftUI

struct MemberLoginView: View {
    @Environment(AppState.self) var appState
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var isSending = false
    @State private var resultMessage: String?
    @State private var didSend = false

    var body: some View {
        NavigationStack {
            VStack(spacing: BCSpacing.lg) {
                Spacer()

                VStack(spacing: BCSpacing.md) {
                    Image(systemName: "bicycle.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(BCColors.brandGreen)

                    Text("Co-op Member Login")
                        .font(.system(size: 22, weight: .bold))

                    Text("Enter your email and we'll send a sign-in link. No password needed.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, BCSpacing.lg)
                }

                if didSend {
                    VStack(spacing: BCSpacing.sm) {
                        Image(systemName: "envelope.badge.fill")
                            .font(.system(size: 32))
                            .foregroundColor(BCColors.brandGreen)
                        Text("Check your email")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Tap the link in the email to sign in. It expires in 15 minutes.")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, BCSpacing.lg)
                    }
                    .padding(BCSpacing.lg)
                    .background(BCColors.cardBackground)
                    .clipShape(Rectangle())
                    .padding(.horizontal, BCSpacing.md)
                } else {
                    VStack(spacing: BCSpacing.sm) {
                        TextField("your@email.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(BCSpacing.md)
                            .background(BCColors.cardBackground)
                            .clipShape(Rectangle())

                        if let msg = resultMessage {
                            Text(msg)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                        }

                        Button {
                            Task { await sendLink() }
                        } label: {
                            Group {
                                if isSending {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Send Sign-In Link")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(BCSpacing.md)
                            .background(isValidEmail ? BCColors.brandGreen : BCColors.brandGreen.opacity(0.4))
                            .foregroundColor(.white)
                            .clipShape(Rectangle())
                        }
                        .disabled(!isValidEmail || isSending)
                    }
                    .padding(.horizontal, BCSpacing.md)
                }

                Spacer()
            }
            .padding(BCSpacing.md)
            .background(BCColors.background)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var isValidEmail: Bool {
        email.contains("@") && email.contains(".")
    }

    private func sendLink() async {
        isSending = true
        resultMessage = nil
        let result = await MemberAuthService.requestMagicLink(email: email.trimmingCharacters(in: .whitespaces).lowercased())
        isSending = false
        switch result {
        case .success:
            didSend = true
        case .failure(let error):
            resultMessage = error.localizedDescription
        }
    }
}
