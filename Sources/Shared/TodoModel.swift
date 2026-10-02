import Foundation
import SQLite

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
                        id <- todo.localID,
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
                guard let todoStatus = TodoStatus(rawValue: row[status]) else { continue }
                let todo = TodoItem(
                    localID: row[id],
                    title: row[title],
                    description: row[description],
                    category: row[category],
                    status: todoStatus,
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

/// Identifies a todo across all sources. Two sources can use the same local ID.
public struct TodoRef: Hashable, Codable, Sendable {
    public let sourceID: String
    public let localID: String

    public init(sourceID: String, localID: String) {
        self.sourceID = sourceID
        self.localID = localID
    }
}

public struct TodoItem: Identifiable, Codable, Equatable, Sendable {
    /// The ID the owning source uses for this todo.
    public let localID: String
    /// The `TodoSource.id` of the source that owns this todo.
    public let sourceID: String
    public var title: String
    public var description: String
    public var category: String
    public var status: TodoStatus
    public let createdAt: Date
    public var updatedAt: Date
    public var completedAt: Date?

    public var id: TodoRef { TodoRef(sourceID: sourceID, localID: localID) }

    init(title: String, description: String = "", category: String = "General", sourceID: String = LocalTodoSource.sourceID) {
        self.localID = UUID().uuidString
        self.sourceID = sourceID
        self.title = title
        self.description = description
        self.category = category.lowercased()
        self.status = .inProgress
        self.createdAt = Date()
        self.updatedAt = Date()
        self.completedAt = nil
    }

    init(localID: String, sourceID: String = LocalTodoSource.sourceID, title: String, description: String, category: String, status: TodoStatus, createdAt: Date, updatedAt: Date, completedAt: Date?) {
        self.localID = localID
        self.sourceID = sourceID
        self.title = title
        self.description = description
        self.category = category
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.completedAt = completedAt
    }

    private enum CodingKeys: String, CodingKey {
        case localID = "id"
        case sourceID, title, description, category, status, createdAt, updatedAt, completedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        localID = try container.decode(String.self, forKey: .localID)
        // Exports made before multiple sources existed have no sourceID.
        sourceID = try container.decodeIfPresent(String.self, forKey: .sourceID) ?? LocalTodoSource.sourceID
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        category = try container.decode(String.self, forKey: .category)
        status = try container.decode(TodoStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
    }
}

public enum TodoStatus: String, CaseIterable, Codable, Sendable {
    case inProgress = "in-progress"
    case completed = "completed"
    case archived = "archived"
    
    public var displayName: String {
        switch self {
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .archived: return "Archived"
        }
    }
}

public enum TodoSortOption: String, CaseIterable, Codable, Sendable {
    case createdDateNewest = "created-newest"
    case createdDateOldest = "created-oldest"
    case title = "title"
    case category = "category"
    case status = "status"
    
    public var displayName: String {
        switch self {
        case .createdDateNewest: return "Newest First"
        case .createdDateOldest: return "Oldest First"
        case .title: return "Title"
        case .category: return "Category"
        case .status: return "Status"
        }
    }
}