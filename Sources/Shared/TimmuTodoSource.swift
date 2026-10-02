import Foundation

/// Todos from the inbox of a Timmu server (activities that have no `startAt`).
///
/// Timmu has no "archived" state. The Timmu priority (high, medium, low) shows as the category.
public final class TimmuTodoSource: TodoSource {
    public static let sourceID = "timmu"
    /// The category of a Timmu todo that has no priority.
    static let noPriorityCategory = "inbox"

    public let id = TimmuTodoSource.sourceID
    public let displayName = "Timmu"
    public let capabilities: SourceCapabilities = [.create, .edit, .delete]

    private let client: TimmuClient

    public init(baseURL: URL, token: String, session: URLSession = .shared) {
        self.client = TimmuClient(baseURL: baseURL, token: token, session: session)
    }

    public func fetchTodos() async throws -> [TodoItem] {
        let response: InboxResponse = try await client.send("GET", "activities/inbox")
        return response.tasks.map(\.todoItem)
    }

    public func create(_ todo: TodoItem) async throws -> TodoItem {
        let body = TimmuActivityBody(todo: todo)
        let response: ActivityResponse = try await client.send("POST", "activities", body: body)
        return response.activity.todoItem
    }

    public func update(_ todo: TodoItem) async throws -> TodoItem {
        var body = TimmuActivityBody(todo: todo)
        body.completed = todo.status == .completed
        let response: ActivityResponse = try await client.send("PATCH", "activities/\(todo.localID)", body: body)
        return response.activity.todoItem
    }

    public func delete(_ todo: TodoItem) async throws {
        try await client.sendWithoutResponse("DELETE", "activities/\(todo.localID)")
    }

    /// Signs in to a Timmu server and returns a JWT for the account.
    public static func logIn(baseURL: URL, email: String, password: String, session: URLSession = .shared) async throws -> String {
        let client = TimmuClient(baseURL: baseURL, token: nil, session: session)
        let response: LoginResponse = try await client.send("POST", "auth/login", body: LoginBody(email: email, password: password))
        return response.token
    }
}

// MARK: - Wire format

struct TimmuTask: Decodable {
    let id: String
    let title: String
    let note: String?
    let priority: String?
    let completedAt: Date?
    let createdAt: Date
    let updatedAt: Date

    var todoItem: TodoItem {
        TodoItem(
            localID: id,
            sourceID: TimmuTodoSource.sourceID,
            title: title,
            description: note ?? "",
            category: priority ?? TimmuTodoSource.noPriorityCategory,
            status: completedAt == nil ? .inProgress : .completed,
            createdAt: createdAt,
            updatedAt: updatedAt,
            completedAt: completedAt
        )
    }
}

struct InboxResponse: Decodable {
    let tasks: [TimmuTask]
}

struct ActivityResponse: Decodable {
    let activity: TimmuTask
}

struct TimmuActivityBody: Encodable {
    static let priorities: Set<String> = ["high", "medium", "low"]

    let title: String
    let note: String?
    let priority: String?
    var completed: Bool?

    init(todo: TodoItem) {
        title = todo.title
        note = todo.description.isEmpty ? nil : todo.description
        // A category that is not a Timmu priority clears the priority.
        priority = Self.priorities.contains(todo.category) ? todo.category : nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        // Send explicit nulls so that a PATCH clears these fields.
        try container.encode(note, forKey: .note)
        try container.encode(priority, forKey: .priority)
        try container.encodeIfPresent(completed, forKey: .completed)
    }

    private enum CodingKeys: String, CodingKey {
        case title, note, priority, completed
    }
}

struct ErrorBody: Decodable {
    let error: String
}

struct LoginBody: Encodable {
    let email: String
    let password: String
}

struct LoginResponse: Decodable {
    let token: String
}

public enum TimmuError: LocalizedError {
    case unauthorized
    case server(status: Int, message: String?)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Timmu rejected the credentials. Connect again in Sources."
        case .server(let status, let message):
            return message ?? "Timmu returned HTTP \(status)."
        case .invalidResponse:
            return "Timmu returned an invalid response."
        }
    }
}

// MARK: - HTTP

struct TimmuClient: Sendable {
    let baseURL: URL
    let token: String?
    let session: URLSession

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            if let date = try? Date(value, strategy: .iso8601.year().month().day().time(includingFractionalSeconds: true)) {
                return date
            }
            if let date = try? Date(value, strategy: .iso8601) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid date: \(value)"))
        }
        return decoder
    }()

    func send<Response: Decodable>(_ method: String, _ path: String, body: (some Encodable)? = Optional<String>.none) async throws -> Response {
        let data = try await perform(method, path, body: body)
        return try Self.decoder.decode(Response.self, from: data)
    }

    func sendWithoutResponse(_ method: String, _ path: String) async throws {
        _ = try await perform(method, path, body: Optional<String>.none)
    }

    private func perform(_ method: String, _ path: String, body: (some Encodable)?) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        // Fastify rejects an empty body that has a JSON content type, so only set it with a body.
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(body)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TimmuError.invalidResponse }
        switch http.statusCode {
        case 200..<300:
            return data
        case 401:
            throw TimmuError.unauthorized
        default:
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
            throw TimmuError.server(status: http.statusCode, message: message)
        }
    }
}
