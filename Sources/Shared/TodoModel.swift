import Foundation
import Observation
import SQLite

@Observable
class TodoStore {
    var todos: [TodoItem] = []
    var currentlyDoing: TodoItem?
    var sortOption: TodoSortOption = .createdDateNewest
    private let storage: TodoStorage
    
    init(storage: TodoStorage? = nil) {
        if let storage = storage {
            self.storage = storage
        } else {
            do {
                self.storage = try SQLiteStorage()
            } catch {
                print("Failed to initialize SQLite storage, falling back to UserDefaults: \(error)")
                self.storage = UserDefaultsStorage()
            }
        }
        loadTodos()
    }
    
    func addTodo(title: String, description: String = "", category: String = "General") {
        let todo = TodoItem(title: title, description: description, category: category.lowercased())
        todos.append(todo)
        saveTodos()
    }
    
    func updateTodo(_ todo: TodoItem, status: TodoStatus) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            let previousStatus = todos[index].status
            todos[index].status = status
            todos[index].updatedAt = Date()
            
            if status == .completed {
                todos[index].completedAt = Date()
            } else if previousStatus == .completed && status != .completed {
                todos[index].completedAt = nil
            }
            
            saveTodos()
        }
    }
    
    func editTodo(_ todo: TodoItem, newTitle: String? = nil, newDescription: String? = nil, newCategory: String? = nil) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            if let title = newTitle {
                todos[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let description = newDescription {
                todos[index].description = description.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let category = newCategory {
                todos[index].category = category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            todos[index].updatedAt = Date()
            saveTodos()
        }
    }
    
    func setCurrentlyDoing(_ todo: TodoItem?) {
        if let current = currentlyDoing {
            updateTodo(current, status: .inProgress)
        }
        currentlyDoing = todo
        saveTodos()
    }
    
    func completeCurrentlyDoing() {
        if let current = currentlyDoing {
            updateTodo(current, status: .completed)
            currentlyDoing = nil
            saveTodos()
        }
    }
    
    func archiveCurrentlyDoing() {
        if let current = currentlyDoing {
            updateTodo(current, status: .archived)
            currentlyDoing = nil
            saveTodos()
        }
    }
    
    func deleteTodo(_ todo: TodoItem) {
        todos.removeAll { $0.id == todo.id }
        if currentlyDoing?.id == todo.id {
            currentlyDoing = nil
        }
        saveTodos()
    }
    
    var inProgressTodos: [TodoItem] {
        sortTodos(todos.filter { $0.status == .inProgress })
    }
    
    var completedTodos: [TodoItem] {
        sortTodos(todos.filter { $0.status == .completed })
    }
    
    var archivedTodos: [TodoItem] {
        sortTodos(todos.filter { $0.status == .archived })
    }
    
    var sortedTodos: [TodoItem] {
        sortTodos(todos)
    }
    
    func sortTodos(_ todosToSort: [TodoItem]) -> [TodoItem] {
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
    
    func setSortOption(_ option: TodoSortOption) {
        sortOption = option
    }
    
    func searchTodos(query: String) -> [TodoItem] {
        guard !query.isEmpty else { return sortedTodos }
        let filtered = todos.filter { 
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query) ||
            $0.category.localizedCaseInsensitiveContains(query)
        }
        return sortTodos(filtered)
    }
    
    var categories: [String] {
        Array(Set(todos.map { $0.category })).sorted()
    }
    
    func todos(inCategory category: String) -> [TodoItem] {
        return sortTodos(todos.filter { $0.category == category })
    }
    
    private func saveTodos() {
        storage.save(TodoData(todos: todos, currentlyDoing: currentlyDoing))
    }
    
    private func loadTodos() {
        if let todoData = storage.load() {
            self.todos = todoData.todos
            self.currentlyDoing = todoData.currentlyDoing
        }
    }
    
    func exportData() -> Data? {
        let exportData = TodoData(todos: todos, currentlyDoing: currentlyDoing)
        return try? JSONEncoder().encode(exportData)
    }
    
    func importData(from data: Data) -> Bool {
        guard let todoData = try? JSONDecoder().decode(TodoData.self, from: data) else {
            return false
        }
        
        self.todos = todoData.todos
        self.currentlyDoing = todoData.currentlyDoing
        saveTodos()
        return true
    }
}

protocol TodoStorage {
    func save(_ data: TodoData)
    func load() -> TodoData?
}

class UserDefaultsStorage: TodoStorage {
    private let key = "todos_v1"
    
    func save(_ data: TodoData) {
        if let encoded = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    
    func load() -> TodoData? {
        // Clear any old data format
        UserDefaults.standard.removeObject(forKey: "todos")
        
        guard let data = UserDefaults.standard.data(forKey: key),
              let todoData = try? JSONDecoder().decode(TodoData.self, from: data) else {
            return nil
        }
        return todoData
    }
}

class SQLiteStorage: TodoStorage {
    private let db: Connection
    private let todos = Table("todos")
    private let id = SQLite.Expression<String>("id")
    private let title = SQLite.Expression<String>("title")
    private let description = SQLite.Expression<String>("description")
    private let category = SQLite.Expression<String>("category")
    private let status = SQLite.Expression<String>("status")
    private let createdAt = SQLite.Expression<Date>("created_at")
    private let updatedAt = SQLite.Expression<Date>("updated_at")
    private let completedAt = SQLite.Expression<Date?>("completed_at")
    private let isCurrentlyDoing = SQLite.Expression<Bool>("is_currently_doing")
    
    init() throws {
        // Use Application Support (no permission prompt) instead of Documents
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("com.htalat.todo")
        
        // Create folder if it doesn't exist
        try FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        let dbPath = appFolder.appendingPathComponent("todos.sqlite3").path
        
        db = try Connection(dbPath)
        try createTable()
    }
    
    private func createTable() throws {
        try db.run(todos.create(ifNotExists: true) { t in
            t.column(id, primaryKey: true)
            t.column(title)
            t.column(description)
            t.column(category)
            t.column(status)
            t.column(createdAt)
            t.column(updatedAt)
            t.column(completedAt)
            t.column(isCurrentlyDoing)
        })
    }
    
    func save(_ data: TodoData) {
        do {
            try db.transaction {
                try db.run(todos.delete())
                
                for todo in data.todos {
                    let isCurrentlyDoingThis = data.currentlyDoing?.id == todo.id
                    try db.run(todos.insert(
                        id <- todo.id.uuidString,
                        title <- todo.title,
                        description <- todo.description,
                        category <- todo.category,
                        status <- todo.status.rawValue,
                        createdAt <- todo.createdAt,
                        updatedAt <- todo.updatedAt,
                        completedAt <- todo.completedAt,
                        isCurrentlyDoing <- isCurrentlyDoingThis
                    ))
                }
            }
        } catch {
            print("Error saving to SQLite: \(error)")
        }
    }
    
    func load() -> TodoData? {
        do {
            var loadedTodos: [TodoItem] = []
            var currentlyDoingTodo: TodoItem?
            
            for row in try db.prepare(todos) {
                let todoId = UUID(uuidString: row[id])!
                let todo = TodoItem(
                    id: todoId,
                    title: row[title],
                    description: row[description],
                    category: row[category],
                    status: TodoStatus(rawValue: row[status])!,
                    createdAt: row[createdAt],
                    updatedAt: row[updatedAt],
                    completedAt: row[completedAt]
                )
                
                loadedTodos.append(todo)
                
                if row[isCurrentlyDoing] {
                    currentlyDoingTodo = todo
                }
            }
            
            return TodoData(todos: loadedTodos, currentlyDoing: currentlyDoingTodo)
        } catch {
            print("Error loading from SQLite: \(error)")
            return nil
        }
    }
}

class MockStorage: TodoStorage {
    private var data: TodoData?
    
    func save(_ data: TodoData) {
        self.data = data
    }
    
    func load() -> TodoData? {
        return data
    }
}

struct TodoData: Codable {
    let todos: [TodoItem]
    let currentlyDoing: TodoItem?
}

struct TodoItem: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var category: String
    var status: TodoStatus
    let createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    
    init(title: String, description: String = "", category: String = "General") {
        self.id = UUID()
        self.title = title
        self.description = description
        self.category = category.lowercased()
        self.status = .inProgress
        self.createdAt = Date()
        self.updatedAt = Date()
        self.completedAt = nil
    }
    
    init(id: UUID, title: String, description: String, category: String, status: TodoStatus, createdAt: Date, updatedAt: Date, completedAt: Date?) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }
}

enum TodoStatus: String, CaseIterable, Codable {
    case inProgress = "in-progress"
    case completed = "completed"
    case archived = "archived"
    
    var displayName: String {
        switch self {
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }
}

enum TodoSortOption: String, CaseIterable, Codable {
    case createdDateNewest = "created-newest"
    case createdDateOldest = "created-oldest"
    case title = "title"
    case category = "category"
    case status = "status"
    
    var displayName: String {
        switch self {
        case .createdDateNewest: return "Newest First"
        case .createdDateOldest: return "Oldest First"
        case .title: return "Title"
        case .category: return "Category"
        case .status: return "Status"
        }
    }
}