import SwiftUI

/// Shows the active sources and connects or disconnects Timmu.
struct SourcesSettingsView: View {
    enum AuthMethod: String, CaseIterable {
        case apiKey = "API key"
        case password = "Password"
    }

    let store: TodoStore
    let onDone: () -> Void

    @State private var isTimmuConnected = TimmuSettings.isConnected
    @State private var serverURL = TimmuSettings.baseURL.absoluteString
    @State private var authMethod = AuthMethod.apiKey
    @State private var apiKey = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isConnecting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Sources")
                    .font(.headline)
                Spacer()
                Button("Done", action: onDone)
            }

            sourceSection(title: "Local", subtitle: "Todos kept on this Mac.") {
                Label("Always on", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }

            sourceSection(title: "Timmu", subtitle: "Inbox tasks (to-dos with no time) from a Timmu server.") {
                if isTimmuConnected {
                    connectedTimmu
                } else {
                    timmuLoginForm
                }
            }

            Spacer()
        }
        .padding()
    }

    private func sourceSection(title: String, subtitle: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var connectedTimmu: some View {
        HStack {
            Label("Connected to \(TimmuSettings.baseURL.absoluteString)", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.green)
            Spacer()
            Button("Disconnect") {
                TimmuSettings.disconnect()
                isTimmuConnected = false
                Task { await store.setSources(TodoSourceFactory.makeSources(reusing: store.sources)) }
            }
            .font(.caption)
        }
    }

    private var timmuLoginForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Server URL", text: $serverURL)
                .textFieldStyle(.roundedBorder)

            Picker("Sign in with", selection: $authMethod) {
                ForEach(AuthMethod.allCases, id: \.self) { method in
                    Text(method.rawValue).tag(method)
                }
            }
            .pickerStyle(.segmented)
            .font(.caption)

            switch authMethod {
            case .apiKey:
                SecureField("htk_timmu_…", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(connect)
                Text("Use a key with the scopes timmu:read, timmu:write, and timmu:delete.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            case .password:
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .textContentType(.username)
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(connect)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Text("The app keeps the key or sign-in token in the Keychain. It does not store the password.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                if isConnecting {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Connect", action: connect)
                    .disabled(!canConnect)
            }
        }
    }

    private var canConnect: Bool {
        guard !isConnecting, parsedURL != nil else { return false }
        switch authMethod {
        case .apiKey: return !trimmedAPIKey.isEmpty
        case .password: return !email.isEmpty && !password.isEmpty
        }
    }

    private var trimmedAPIKey: String {
        apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedURL: URL? {
        let trimmed = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme == "http" || url.scheme == "https", url.host() != nil else {
            return nil
        }
        return url
    }

    private func connect() {
        guard canConnect, let url = parsedURL else { return }
        isConnecting = true
        errorMessage = nil
        Task {
            defer { isConnecting = false }
            do {
                switch authMethod {
                case .apiKey:
                    try await TimmuSettings.connect(baseURL: url, apiKey: trimmedAPIKey)
                case .password:
                    try await TimmuSettings.connect(baseURL: url, email: email, password: password)
                }
                apiKey = ""
                password = ""
                isTimmuConnected = true
                await store.setSources(TodoSourceFactory.makeSources(reusing: store.sources))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
