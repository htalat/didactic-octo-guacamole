import Foundation

/// The operations a source supports. The UI hides actions that a source does not support.
public struct SourceCapabilities: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let create = SourceCapabilities(rawValue: 1 << 0)
    public static let edit = SourceCapabilities(rawValue: 1 << 1)
    public static let delete = SourceCapabilities(rawValue: 1 << 2)
    /// The source can keep todos with the `.archived` status.
    public static let archive = SourceCapabilities(rawValue: 1 << 3)

    public static let all: SourceCapabilities = [.create, .edit, .delete, .archive]
}

/// A place that todos come from, such as the local database or a Timmu server.
///
/// To add a new data source, conform to this protocol and add the source in
/// `TodoSourceFactory.makeSources()`. `TodoStore` merges the todos of all
/// sources and sends each change to the source that owns the todo.
public protocol TodoSource: AnyObject, Sendable {
    /// A stable, unique ID. It is stored in `TodoItem.sourceID`.
    var id: String { get }
    var displayName: String { get }
    var capabilities: SourceCapabilities { get }

    func fetchTodos() async throws -> [TodoItem]
    /// Saves a new todo. Returns the todo as the source stored it (the source can give it a new ID).
    func create(_ todo: TodoItem) async throws -> TodoItem
    func update(_ todo: TodoItem) async throws -> TodoItem
    func delete(_ todo: TodoItem) async throws
}

/// Todos that are kept on this Mac, in SQLite (or UserDefaults as a fallback).
public actor LocalTodoSource: TodoSource {
    public static let sourceID = "local"

    public nonisolated let id = LocalTodoSource.sourceID
    public nonisolated let displayName = "Local"
    public nonisolated let capabilities = SourceCapabilities.all

    private let storage: TodoStorage
    private var cache: [TodoItem]?
    private var legacyCurrentlyDoing: TodoRef?

    init(storage: TodoStorage) {
        self.storage = storage
    }

    public func fetchTodos() -> [TodoItem] {
        loadedTodos()
    }

    public func create(_ todo: TodoItem) -> TodoItem {
        var todos = loadedTodos()
        todos.append(todo)
        save(todos)
        return todo
    }

    public func update(_ todo: TodoItem) -> TodoItem {
        var todos = loadedTodos()
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index] = todo
            save(todos)
        }
        return todo
    }

    public func delete(_ todo: TodoItem) {
        save(loadedTodos().filter { $0.id != todo.id })
    }

    func replaceAll(with todos: [TodoItem]) {
        save(todos)
    }

    /// Before multiple sources, the local storage kept the "currently doing" todo.
    /// Returns that value one time so that the store can adopt it.
    func takeLegacyCurrentlyDoing() -> TodoRef? {
        _ = loadedTodos()
        defer { legacyCurrentlyDoing = nil }
        return legacyCurrentlyDoing
    }

    private func loadedTodos() -> [TodoItem] {
        if let cache { return cache }
        let data = storage.load()
        let todos = data?.todos ?? []
        legacyCurrentlyDoing = data?.currentlyDoing?.id
        cache = todos
        return todos
    }

    private func save(_ todos: [TodoItem]) {
        cache = todos
        storage.save(TodoData(todos: todos, currentlyDoing: nil))
    }
}
