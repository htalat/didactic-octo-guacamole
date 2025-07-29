import Foundation
import Observation

@Observable
class TodoStore {
    var todos: [TodoItem] = []
    var currentlyDoing: TodoItem?
    private let storage: TodoStorage
    
    init(storage: TodoStorage = UserDefaultsStorage()) {
        self.storage = storage
        loadTodos()
    }
    
    func addTodo(title: String, description: String = "", category: String = "General") {
        let todo = TodoItem(title: title, description: description, category: category.lowercased())
        todos.append(todo)
        saveTodos()
    }
    
    func updateTodo(_ todo: TodoItem, status: TodoStatus) {
        if let index = todos.firstIndex(where: { $0.id == todo.id }) {
            todos[index].status = status
            todos[index].updatedAt = Date()
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
        todos.filter { $0.status == .inProgress }
    }
    
    var completedTodos: [TodoItem] {
        todos.filter { $0.status == .completed }
    }
    
    var archivedTodos: [TodoItem] {
        todos.filter { $0.status == .archived }
    }
    
    func searchTodos(query: String) -> [TodoItem] {
        guard !query.isEmpty else { return todos }
        return todos.filter { 
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.description.localizedCaseInsensitiveContains(query) ||
            $0.category.localizedCaseInsensitiveContains(query)
        }
    }
    
    var categories: [String] {
        Array(Set(todos.map { $0.category })).sorted()
    }
    
    func todos(inCategory category: String) -> [TodoItem] {
        return todos.filter { $0.category == category }
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
    
    init(title: String, description: String = "", category: String = "General") {
        self.id = UUID()
        self.title = title
        self.description = description
        self.category = category.lowercased()
        self.status = .inProgress
        self.createdAt = Date()
        self.updatedAt = Date()
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