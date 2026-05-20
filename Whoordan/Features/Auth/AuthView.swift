import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var email = ""
    @State private var password = ""
    @State private var mode: Mode = .signIn
    @State private var isLoading = false

    enum Mode: String, CaseIterable {
        case signIn = "Sign In"
        case signUp = "Sign Up"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WScreenBackground()
                ScrollView {
                    VStack(spacing: WSpacing.xl) {
                        Image("WhoordanW")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 116, height: 116)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .accessibilityLabel("Whoordan W mark")

                        VStack(spacing: WSpacing.s) {
                            Text("Whoordan")
                                .font(WTypography.hero)
                                .foregroundStyle(WColors.text)
                            Text("Private recovery, sleep, strain, and heart tracking by W4rd2.")
                                .font(WTypography.body)
                                .foregroundStyle(WColors.secondary)
                                .multilineTextAlignment(.center)
                        }

                        WCard {
                            VStack(spacing: WSpacing.l) {
                                Picker("Mode", selection: $mode) {
                                    ForEach(Mode.allCases, id: \.self) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .pickerStyle(.segmented)

                                TextField("Email", text: $email)
                                    .textContentType(.emailAddress)
                                    .keyboardType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding()
                                    .background(WColors.elevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                SecureField("Password", text: $password)
                                    .textContentType(mode == .signIn ? .password : .newPassword)
                                    .padding()
                                    .background(WColors.elevated)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                WPrimaryButton(
                                    title: isLoading ? "Working" : mode.rawValue,
                                    systemImage: mode == .signIn ? "person.crop.circle" : "person.badge.plus",
                                    action: submit
                                )
                                .disabled(isLoading)

                                Button("Reset Password") {
                                    Task { await environment.resetPassword(email: email) }
                                }
                                .foregroundStyle(WColors.secondary)

                                if let message = environment.authMessage {
                                    Text(message)
                                        .font(WTypography.caption)
                                        .foregroundStyle(WColors.warning)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }

                        Text("Health data, local mode, Apple Health, Bluetooth, and cloud sync stay locked until account approval. Turning on cloud sync backs up health data to your account.")
                            .font(WTypography.caption)
                            .foregroundStyle(WColors.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(WSpacing.xl)
                }
            }
        }
    }

    private func submit() {
        Task {
            isLoading = true
            defer { isLoading = false }
            switch mode {
            case .signIn:
                await environment.signIn(email: email, password: password)
            case .signUp:
                await environment.signUp(email: email, password: password)
            }
        }
    }
}
