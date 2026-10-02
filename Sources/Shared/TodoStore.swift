import Foundation
import Observation

/// Merges the todos of all sources and sends each change to the source that owns the todo.
///
/// Changes show in `todos` immediately. The write to the source runs in the background;
/// each mutating method returns its task so that callers (and tests) can wait for it.
@MainActor
@Observable
public final class TodoStore {
    public private(set) var todos: [TodoItem] = []
    public private(set) var sources: [any TodoSource]
    public private(set) var isRefreshing = false
    /// The last error of each source, keyed by source ID.
    public private(set) var sourceErrors: [String: String] = [:]
    public var sortOption: TodoSortOption = .createdDateNewest

    private var currentlyDoingRef: TodoRef? {
        didSet { saveCurrentlyDoing() }
    }

    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private var pendingWrites: [String: Int] = [:]
    @ObservationIgnored private var didAdoptLegacyCurrentlyDoing = false

    private static let currentlyDoingKey = "currentlyDoing_v2"

    /// - Parameter defaults: Where to keep the "currently doing" todo. `nil` keeps it in memory only.
    public init(sources: [any TodoSource], defaults: UserDefaults? = nil) {
        self.sources = sources
        self.defaults = defaults
        if let data = defaults?.data(forKey: Self.currentlyDoingKey) {
            currentlyDoingRef = try? JSONDecoder().decode(TodoRef.self, from: data)
        }
    }

    public convenience init() {
        self.init(sources: TodoSourceFactory.makeSources(), defaults: .standard)
    }

    convenience init(storage: TodoStorage) {
        self.init(sources: [LocalTodoSource(storage: storage)])
    }

    // MARK: Sources

    public func source(for todo: TodoItem) -> (any TodoSource)? {
        source(withID: todo.sourceID)
    }

    public func capabilities(for todo: TodoItem) -> SourceCapabilities {
        source(for: todo)?.capabilities ?? []
    }

    /// The sources that can create todos, in display order.
    public var creatableSources: [any TodoSource] {
        sources.filter { $0.capabilities.contains(.create) }
    }

    /// Replaces the sources (for example, after the user connects to Timmu) and fetches again.
    public func setSources(_ newSources: [any TodoSource]) async {
        sources = newSources
        let ids = Set(newSources.map(\.id))
        todos.removeAll { !ids.contains($0.sourceID) }
        sourceErrors = sourceErrors.filter { ids.contains($0.key) }
        await refresh()
    }

    /// Fetches the todos of all sources. A source that fails keeps its last todos.
    public func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let results = await withTaskGroup(of: (String, Result<[TodoItem], any Error>).self) { group in
            for source in sources {
                group.addTask {
                    do {
                        return (source.id, .success(try await source.fetchTodos()))
                    } catch {
                        return (source.id, .failure(error))
                    }
                }
            }
            return await group.reduce(into: [(String, Result<[TodoItem], any Error>)]()) { $0.append($1) }
        }

        for (sourceID, result) in results {
            switch result {
            case .success(let fetched):
                sourceErrors[sourceID] = nil
                // A write that is still running would make this result out of date.
                guard pendingWrites[sourceID, default: 0] == 0 else { continue }
                todos = todos.filter { $0.sourceID != sourceID } + fetched
            case .failure(let error):
                sourceErrors[sourceID] = error.localizedDescription
            }
        }

        await adoptLegacyCurrentlyDoing()
    }

    // MARK: Mutations

    @discardableResult
    public func addTodo(title: String, description: String = "", category: String = "General", sourceID: String = LocalTodoSource.sourceID) -> Task<Void, Never> {
        guard let source = source(withID: sourceID), source.capabilities.contains(.create) else { return Task {} }
        let todo = TodoItem(title: title, description: description, category: category.lowercased(), sourceID: sourceID)
        todos.append(todo)
        return write(to: source) { [weak self] source in
            let created = try await source.create(todo)
            self?.replace(todo.id, with: created)
        }
    }

    @discardableResult
    public func updateTodo(_ todo: TodoItem, status: TodoStatus) -> Task<Void, Never> {
        if status == .archived && !capabilities(for: todo).contains(.archive) { return Task {} }
        guard var updated = todos.first(where: { $0.id == todo.id }) else { return Task {} }

        let previousStatus = updated.status
        updated.status = status
        updated.updatedAt = Date()
        if status == .completed {
            updated.completedAt = Date()
        } else if previousStatus == .completed {
            updated.completedAt = nil
        }
        return save(updated)
    }

    @discardableResult
    public func editTodo(_ todo: TodoItem, newTitle: String? = nil, newDescription: String? = nil, newCategory: String? = nil) -> Task<Void, Never> {
        guard capabilities(for: todo).contains(.edit),
              var updated = todos.first(where: { $0.id == todo.id }) else { return Task {} }

        if let title = newTitle {
            updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let description = newDescription {
            updated.description = description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let category = newCategory {
            updated.category = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        updated.updatedAt = Date()
        return save(updated)
    }

    @discardableResult
    public func deleteTodo(_ todo: TodoItem) -> Task<Void, Never> {
        guard let source = source(for: todo), source.capabilities.contains(.delete) else { return Task {} }
        todos.removeAll { $0.id == todo.id }
        if currentlyDoingRef == todo.id {
            currentlyDoingRef = nil
        }
        return write(to: source) { source in
            try await source.delete(todo)
        }
    }

    // MARK: Currently doing

    public var currentlyDoing: TodoItem? {
        guard let currentlyDoingRef else { return nil }
        return todos.first { $0.id == currentlyDoingRef }
    }

    public func setCurrentlyDoing(_ todo: TodoItem?) {
        if let current = currentlyDoing {
            updateTodo(current, status: .inProgress)
        }
        currentlyDoingRef = todo?.id
    }

    public func completeCurrentlyDoing() {
        guard let current = currentlyDoing else { return }
        updateTodo(current, status: .completed)
        currentlyDoingRef = nil
    }

    public func archiveCurrentlyDoing() {
        guard let current = currentlyDoing, capabilities(for: current).contains(.archive) else { return }
        updateTodo(current, status: .archived)
        currentlyDoingRef = nil
    }

    // MARK: Queries

    public var inProgressTodos: [TodoItem] {
        sortTodos(todos.filter { $0.status == .inProgress })
    }

    public var completedTodos: [TodoItem] {
        sortTodos(todos.filter { $0.status == .completed })
    }

    public var archivedTodos: [TodoItem] {
        sortTodos(todos.filter { $0.status == .archived })
    }

    public var sortedTodos: [TodoItem] {
        sortTodos(todos)
    }

    public func sortTodos(_ todosToSort: [TodoItem]) -> [TodoItem] {
        switch sortOption {
        case .createdDateNewest:
            return todosToSort.sorted { $0.createdAt > $1.createdAt }
        case .createdDateOldest:
            return todosToSort.sorted { $0.createdAt < $1.createdAt }
        case .title:
            return todosToSort.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .category:
            return todosToSort.sorted { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending }
        case .status:
            return todosToSort.sorted { $0.status.rawValue.localizedCaseInsensitiveCompare($1.status.rawValue) == .orderedAscending }
        }
    }

    public func setSortOption(_ option: TodoSortOption) {
        sortOption = option
    }

    public func searchTodos(query: String) -> [TodoItem] {
        guard !query.isEmpty else { return sortedTodos }
        let filtered = todos.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query) ||
            $0.category.localizedCaseInsensitiveContains(query)
        }
        return sortTodos(filtered)
    }

    public var categories: [String] {
        Array(Set(todos.map { $0.category })).sorted()
    }

    public func todos(inCategory category: String) -> [TodoItem] {
        sortTodos(todos.filter { $0.category == category })
    }

    // MARK: Import and export (local todos only)

    public func exportData() -> Data? {
        let localTodos = todos.filter { $0.sourceID == LocalTodoSource.sourceID }
        let current = currentlyDoing.flatMap { $0.sourceID == LocalTodoSource.sourceID ? $0 : nil }
        return try? JSONEncoder().encode(TodoData(todos: localTodos, currentlyDoing: current))
    }

    @discardableResult
    public func importData(from data: Data) -> Bool {
        guard let todoData = try? JSONDecoder().decode(TodoData.self, from: data),
              let local = source(withID: LocalTodoSource.sourceID) as? LocalTodoSource else {
            return false
        }

        todos = todos.filter { $0.sourceID != LocalTodoSource.sourceID } + todoData.todos
        currentlyDoingRef = todoData.currentlyDoing?.id
        write(to: local) { _ in
            await local.replaceAll(with: todoData.todos)
        }
        return true
    }

    // MARK: Private

    private func source(withID id: String) -> (any TodoSource)? {
        sources.first { $0.id == id }
    }

    private func save(_ todo: TodoItem) -> Task<Void, Never> {
        guard let source = source(for: todo) else { return Task {} }
        replace(todo.id, with: todo)
        return write(to: source) { [weak self] source in
            let saved = try await source.update(todo)
            self?.replace(todo.id, with: saved)
        }
    }

    private func replace(_ ref: TodoRef, with todo: TodoItem) {
        guard let index = todos.firstIndex(where: { $0.id == ref }) else { return }
        todos[index] = todo
        // A source can give a new todo a different ID.
        if currentlyDoingRef == ref && ref != todo.id {
            currentlyDoingRef = todo.id
        }
    }

    /// Runs a write in the background. If it fails, the error shows and the source is fetched again
    /// so that the list agrees with the source.
    @discardableResult
    private func write(to source: any TodoSource, _ operation: @escaping @MainActor (any TodoSource) async throws -> Void) -> Task<Void, Never> {
        let sourceID = source.id
        pendingWrites[sourceID, default: 0] += 1
        return Task { [weak self] in
            do {
                try await operation(source)
                self?.pendingWrites[sourceID, default: 1] -= 1
                self?.sourceErrors[sourceID] = nil
            } catch {
                guard let self else { return }
                pendingWrites[sourceID, default: 1] -= 1
                await refresh()
                sourceErrors[sourceID] = error.localizedDescription
            }
        }
    }

    private func saveCurrentlyDoing() {
        guard let defaults else { return }
        if let currentlyDoingRef, let data = try? JSONEncoder().encode(currentlyDoingRef) {
            defaults.set(data, forKey: Self.currentlyDoingKey)
        } else {
            defaults.removeObject(forKey: Self.currentlyDoingKey)
        }
    }

    private func adoptLegacyCurrentlyDoing() async {
        guard !didAdoptLegacyCurrentlyDoing,
              let local = source(withID: LocalTodoSource.sourceID) as? LocalTodoSource else { return }
        didAdoptLegacyCurrentlyDoing = true
        let legacy = await local.takeLegacyCurrentlyDoing()
        if currentlyDoingRef == nil, let legacy {
            currentlyDoingRef = legacy
        }
    }
}
