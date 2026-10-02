import Testing
import Foundation
@testable import Shared

/// Runs against a real Timmu server. Skipped unless `TIMMU_TEST_URL` is set, for example:
/// `TIMMU_TEST_URL=http://localhost:3000 swift test --filter TimmuIntegration`
@Suite("Timmu integration", .enabled(if: ProcessInfo.processInfo.environment["TIMMU_TEST_URL"] != nil))
struct TimmuIntegrationTests {
    @Test("Create, fetch, complete, edit, and delete an inbox task")
    func roundTrip() async throws {
        let baseURL = try #require(ProcessInfo.processInfo.environment["TIMMU_TEST_URL"].flatMap(URL.init(string:)))
        let email = "todo-integration-\(UUID().uuidString.prefix(8).lowercased())@example.test"
        let password = UUID().uuidString

        // Make a throwaway account, then sign in the same way the app does.
        var register = URLRequest(url: baseURL.appending(path: "auth/register"))
        register.httpMethod = "POST"
        register.setValue("application/json", forHTTPHeaderField: "Content-Type")
        register.httpBody = try JSONEncoder().encode(["email": email, "password": password])
        let (_, registerResponse) = try await URLSession.shared.data(for: register)
        #expect((registerResponse as? HTTPURLResponse)?.statusCode == 201)

        let token = try await TimmuTodoSource.logIn(baseURL: baseURL, email: email, password: password)
        let source = TimmuTodoSource(baseURL: baseURL, token: token)

        let created = try await source.create(TodoItem(title: "Integration task", description: "A note", category: "high", sourceID: source.id))
        #expect(created.title == "Integration task")
        #expect(created.category == "high")

        var fetched = try await source.fetchTodos()
        #expect(fetched.map(\.id) == [created.id])

        var completed = created
        completed.status = .completed
        completed.description = ""
        completed.category = "inbox"
        let updated = try await source.update(completed)
        #expect(updated.status == .completed)
        #expect(updated.description == "")
        #expect(updated.category == TimmuTodoSource.noPriorityCategory)

        try await source.delete(updated)
        fetched = try await source.fetchTodos()
        #expect(fetched.isEmpty)

        await #expect(throws: TimmuError.self) {
            _ = try await TimmuTodoSource(baseURL: baseURL, token: "bad-token").fetchTodos()
        }
    }
}
