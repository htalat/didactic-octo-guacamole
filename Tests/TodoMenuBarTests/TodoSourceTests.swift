import Testing
import Foundation
@testable import Shared

/// A source that keeps todos in memory and records the calls it gets.
actor FakeSource: TodoSource {
    nonisolated let id: String
    nonisolated let displayName: String
    nonisolated let capabilities: SourceCapabilities

    private(set) var todos: [TodoItem]
    private(set) var deletedIDs: [String] = []
    var failWrites = false
    /// When set, `create` gives new todos this ID, as a server does.
    var serverAssignedID: String?

    struct WriteFailed: Error {}

    init(id: String, capabilities: SourceCapabilities = .all, todos: [TodoItem] = []) {
        self.id = id
        self.displayName = id.capitalized
        self.capabilities = capabilities
        self.todos = todos
    }

    func setFailWrites(_ value: Bool) { failWrites = value }
    func setServerAssignedID(_ value: String) { serverAssignedID = value }

    func fetchTodos() -> [TodoItem] { todos }

    func create(_ todo: TodoItem) throws -> TodoItem {
        if failWrites { throw WriteFailed() }
        var created = todo
        if let serverAssignedID {
            created = TodoItem(localID: serverAssignedID, sourceID: id, title: todo.title, description: todo.description, category: todo.category, status: todo.status, createdAt: todo.createdAt, updatedAt: todo.updatedAt, completedAt: todo.completedAt)
        }
        todos.append(created)
        return created
    }

    func update(_ todo: TodoItem) throws -> TodoItem {
        if failWrites { throw WriteFailed() }
        if let index = todos.firstIndex(where: { $0.id == todo.id }) { todos[index] = todo }
        return todo
    }

    func delete(_ todo: TodoItem) throws {
        if failWrites { throw WriteFailed() }
        deletedIDs.append(todo.localID)
        todos.removeAll { $0.id == todo.id }
    }
}

private func makeTodo(_ title: String, id: String, source: String) -> TodoItem {
    TodoItem(localID: id, sourceID: source, title: title, description: "", category: "general", status: .inProgress, createdAt: .now, updatedAt: .now, completedAt: nil)
}

@MainActor
@Suite("TodoStore with multiple sources")
struct MultiSourceStoreTests {
    @Test("Refresh merges the todos of all sources")
    func refreshMergesSources() async {
        let a = FakeSource(id: "a", todos: [makeTodo("From A", id: "1", source: "a")])
        let b = FakeSource(id: "b", todos: [makeTodo("From B", id: "1", source: "b")])
        let store = TodoStore(sources: [a, b])

        await store.refresh()

        #expect(store.todos.count == 2)
        #expect(Set(store.todos.map(\.title)) == ["From A", "From B"])
        // The same local ID in two sources gives two different todos.
        #expect(store.todos[0].id != store.todos[1].id)
    }

    @Test("A new todo goes to the selected source and takes the ID that the source gives")
    func addRoutesToSource() async {
        let local = FakeSource(id: "local")
        let remote = FakeSource(id: "remote")
        await remote.setServerAssignedID("server-1")
        let store = TodoStore(sources: [local, remote])

        await store.addTodo(title: "Remote todo", sourceID: "remote").value

        #expect(await local.todos.isEmpty)
        #expect(await remote.todos.map(\.localID) == ["server-1"])
        #expect(store.todos.map(\.id) == [TodoRef(sourceID: "remote", localID: "server-1")])
    }

    @Test("Edits and deletes go to the source that owns the todo")
    func mutationsRouteToOwner() async throws {
        let a = FakeSource(id: "a", todos: [makeTodo("A", id: "1", source: "a")])
        let b = FakeSource(id: "b", todos: [makeTodo("B", id: "1", source: "b")])
        let store = TodoStore(sources: [a, b])
        await store.refresh()

        let todoB = try #require(store.todos.first { $0.sourceID == "b" })
        await store.editTodo(todoB, newTitle: "B edited").value
        await store.deleteTodo(todoB).value

        #expect(await a.todos.map(\.title) == ["A"])
        #expect(await b.deletedIDs == ["1"])
        #expect(store.todos.map(\.title) == ["A"])
    }

    @Test("A source without the archive capability does not archive todos")
    func archiveNeedsCapability() async throws {
        let remote = FakeSource(id: "remote", capabilities: [.create, .edit, .delete], todos: [makeTodo("Task", id: "1", source: "remote")])
        let store = TodoStore(sources: [remote])
        await store.refresh()
        let todo = try #require(store.todos.first)

        await store.updateTodo(todo, status: .archived).value

        #expect(store.todos.first?.status == .inProgress)
        #expect(store.archivedTodos.isEmpty)
    }

    @Test("A source without the edit capability does not change titles")
    func editNeedsCapability() async throws {
        let readOnly = FakeSource(id: "ro", capabilities: [], todos: [makeTodo("Fixed", id: "1", source: "ro")])
        let store = TodoStore(sources: [readOnly])
        await store.refresh()
        let todo = try #require(store.todos.first)

        await store.editTodo(todo, newTitle: "Changed").value
        await store.deleteTodo(todo).value

        #expect(store.todos.map(\.title) == ["Fixed"])
    }

    @Test("A failed write shows an error and puts back the source's todos")
    func failedWriteRollsBack() async throws {
        let remote = FakeSource(id: "remote", todos: [makeTodo("Original", id: "1", source: "remote")])
        let store = TodoStore(sources: [remote])
        await store.refresh()
        await remote.setFailWrites(true)
        let todo = try #require(store.todos.first)

        await store.editTodo(todo, newTitle: "Changed").value

        #expect(store.todos.map(\.title) == ["Original"])
        #expect(store.sourceErrors["remote"] != nil)
    }

    @Test("Removing a source removes its todos")
    func setSourcesRemovesTodos() async {
        let a = FakeSource(id: "a", todos: [makeTodo("A", id: "1", source: "a")])
        let b = FakeSource(id: "b", todos: [makeTodo("B", id: "1", source: "b")])
        let store = TodoStore(sources: [a, b])
        await store.refresh()

        await store.setSources([a])

        #expect(store.todos.map(\.title) == ["A"])
    }

    @Test("Local todos stay in storage after the store is gone")
    func localPersistence() async {
        let storage = MockStorage()
        let first = TodoStore(storage: storage)
        await first.addTodo(title: "Keep me").value

        let second = TodoStore(storage: storage)
        await second.refresh()

        #expect(second.todos.map(\.title) == ["Keep me"])
    }

    @Test("The currently doing todo from older versions is adopted")
    func legacyCurrentlyDoing() async {
        let storage = MockStorage()
        let todo = TodoItem(title: "Legacy current")
        storage.save(TodoData(todos: [todo], currentlyDoing: todo))
        let store = TodoStore(storage: storage)

        await store.refresh()

        #expect(store.currentlyDoing?.id == todo.id)
    }
}

@Suite("Timmu source")
struct TimmuSourceTests {
    @Test("Inbox tasks map to todos")
    func decodesInbox() throws {
        let json = """
        {"tasks": [
          {"id": "6f1c2c1e-1111-4a4a-9a9a-000000000001", "userId": "u", "title": "Call mum", "note": "Sunday",
           "icon": null, "color": null, "startAt": null, "durationMinutes": 30, "recurrence": null, "timezone": null,
           "priority": "high", "completedAt": null,
           "createdAt": "2026-10-01T09:30:00.123Z", "updatedAt": "2026-10-01T09:30:00.123Z", "completed": false},
          {"id": "6f1c2c1e-1111-4a4a-9a9a-000000000002", "userId": "u", "title": "Tax return", "note": null,
           "priority": null, "completedAt": "2026-10-02T08:00:00Z",
           "createdAt": "2026-09-01T09:30:00Z", "updatedAt": "2026-10-02T08:00:00Z", "completed": true}
        ]}
        """
        let response = try TimmuClient.decoder.decode(InboxResponse.self, from: Data(json.utf8))
        let todos = response.tasks.map(\.todoItem)

        #expect(todos.count == 2)
        #expect(todos[0].sourceID == TimmuTodoSource.sourceID)
        #expect(todos[0].localID == "6f1c2c1e-1111-4a4a-9a9a-000000000001")
        #expect(todos[0].description == "Sunday")
        #expect(todos[0].category == "high")
        #expect(todos[0].status == .inProgress)
        #expect(todos[1].description == "")
        #expect(todos[1].category == TimmuTodoSource.noPriorityCategory)
        #expect(todos[1].status == .completed)
        #expect(todos[1].completedAt != nil)
    }

    @Test("The request body sends nulls and maps the category to a priority")
    func encodesBody() throws {
        var todo = TodoItem(title: "Plan week", category: "inbox", sourceID: TimmuTodoSource.sourceID)
        var body = TimmuActivityBody(todo: todo)
        body.completed = false
        let encoded = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(body)) as? [String: Any])

        #expect(encoded["title"] as? String == "Plan week")
        #expect(encoded["note"] is NSNull)
        #expect(encoded["priority"] is NSNull)
        #expect(encoded["completed"] as? Bool == false)

        todo.category = "medium"
        todo.description = "Before Monday"
        let withPriority = TimmuActivityBody(todo: todo)
        #expect(withPriority.priority == "medium")
        #expect(withPriority.note == "Before Monday")
    }
}

@Test("Exports made before sources existed still import")
func decodesLegacyTodoItem() throws {
    let json = """
    {"id": "1E0D8F7A-0000-0000-0000-000000000000", "title": "Old", "description": "", "category": "general",
     "status": "completed", "createdAt": 0, "updatedAt": 0, "completedAt": 0}
    """
    let todo = try JSONDecoder().decode(TodoItem.self, from: Data(json.utf8))

    #expect(todo.sourceID == LocalTodoSource.sourceID)
    #expect(todo.localID == "1E0D8F7A-0000-0000-0000-000000000000")
    #expect(todo.status == .completed)
}

@Test("A base URL with a path prefix keeps the prefix", arguments: [
    ("https://api.htalat.com/timmu", "https://api.htalat.com/timmu/activities/inbox"),
    ("https://api.htalat.com/timmu/", "https://api.htalat.com/timmu/activities/inbox"),
    ("http://localhost:3000", "http://localhost:3000/activities/inbox"),
])
func requestURLKeepsPrefix(base: String, expected: String) throws {
    let client = TimmuClient(baseURL: try #require(URL(string: base)), token: "htk_timmu_x", session: .shared)
    let request = try client.makeRequest("GET", "activities/inbox", body: Optional<String>.none)

    #expect(request.url?.absoluteString == expected)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer htk_timmu_x")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
}
