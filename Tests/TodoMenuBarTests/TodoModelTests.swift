import Testing
@testable import TodoMenuBar

@Test("TodoStore can add and manage todos")
func testTodoStoreBasicOperations() {
    let store = TodoStore(storage: MockStorage())
    
    store.addTodo(title: "Test Todo")
    #expect(store.todos.count == 1)
    #expect(store.todos.first?.title == "Test Todo")
    #expect(store.todos.first?.status == .inProgress)
}

@Test("TodoStore filters todos by status correctly")
func testTodoStatusFiltering() {
    let store = TodoStore(storage: MockStorage())
    
    store.addTodo(title: "Todo 1")
    store.addTodo(title: "Todo 2")
    store.addTodo(title: "Todo 3")
    
    let firstTodo = store.todos[0]
    let secondTodo = store.todos[1]
    
    store.updateTodo(firstTodo, status: .completed)
    store.updateTodo(secondTodo, status: .archived)
    
    #expect(store.inProgressTodos.count == 1)
    #expect(store.completedTodos.count == 1)
    #expect(store.archivedTodos.count == 1)
    
    #expect(store.inProgressTodos.first?.title == "Todo 3")
    #expect(store.completedTodos.first?.title == "Todo 1")
    #expect(store.archivedTodos.first?.title == "Todo 2")
}

@Test("TodoStore search functionality works")
func testTodoSearch() {
    let store = TodoStore(storage: MockStorage())
    
    store.addTodo(title: "Buy groceries")
    store.addTodo(title: "Walk the dog")
    store.addTodo(title: "Buy books")
    
    let results = store.searchTodos(query: "buy")
    #expect(results.count == 2)
    #expect(results.allSatisfy { $0.title.localizedCaseInsensitiveContains("buy") })
    
    let emptyResults = store.searchTodos(query: "")
    #expect(emptyResults.count == 3)
}

@Test("TodoStore currently doing functionality")
func testCurrentlyDoing() {
    let store = TodoStore(storage: MockStorage())
    
    store.addTodo(title: "Important task")
    let todo = store.todos.first!
    
    store.setCurrentlyDoing(todo)
    #expect(store.currentlyDoing?.id == todo.id)
    
    store.setCurrentlyDoing(nil)
    #expect(store.currentlyDoing == nil)
}

@Test("TodoStore can edit todo titles")
func testEditTodo() {
    let store = TodoStore(storage: MockStorage())
    
    store.addTodo(title: "Original title")
    let todo = store.todos.first!
    
    store.editTodo(todo, newTitle: "Updated title")
    
    #expect(store.todos.first?.title == "Updated title")
    #expect(store.todos.first?.id == todo.id)
}

@Test("TodoStore edit trims whitespace")
func testEditTodoTrimsWhitespace() {
    let store = TodoStore(storage: MockStorage())
    
    store.addTodo(title: "Test todo")
    let todo = store.todos.first!
    
    store.editTodo(todo, newTitle: "  Trimmed title  ")
    
    #expect(store.todos.first?.title == "Trimmed title")
}

@Test("TodoStore can add todos with description and category")
func testAddTodoWithDescriptionAndCategory() {
    let store = TodoStore(storage: MockStorage())
    
    store.addTodo(title: "Work task", description: "Important project", category: "Work")
    
    let todo = store.todos.first!
    #expect(todo.title == "Work task")
    #expect(todo.description == "Important project")
    #expect(todo.category == "Work")
}

@Test("TodoStore search includes description and category")
func testSearchIncludesAllFields() {
    let store = TodoStore(storage: MockStorage())
    
    store.addTodo(title: "Meeting", description: "Weekly standup", category: "Work")
    store.addTodo(title: "Shopping", description: "Buy groceries", category: "Personal")
    
    let titleResults = store.searchTodos(query: "meeting")
    #expect(titleResults.count == 1)
    
    let descriptionResults = store.searchTodos(query: "standup")
    #expect(descriptionResults.count == 1)
    
    let categoryResults = store.searchTodos(query: "work")
    #expect(categoryResults.count == 1)
}

@Test("TodoStore categories are unique and sorted")
func testCategoriesUniqueAndSorted() {
    let store = TodoStore(storage: MockStorage())
    
    store.addTodo(title: "Task 1", category: "Work")
    store.addTodo(title: "Task 2", category: "Personal")
    store.addTodo(title: "Task 3", category: "Work")
    store.addTodo(title: "Task 4", category: "Home")
    store.addTodo(title: "Task 5")  // Uses default "General" category
    
    let categories = store.categories
    #expect(categories == ["General", "Home", "Personal", "Work"])
    #expect(categories.count == 4)
}