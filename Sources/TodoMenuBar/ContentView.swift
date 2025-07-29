import SwiftUI

struct ContentView: View {
    @State private var todoStore = TodoStore()
    @State private var selectedTab: TodoStatus = .inProgress
    @State private var searchText = ""
    @State private var newTodoTitle = ""
    @State private var newTodoDescription = ""
    @State private var newTodoCategory = "general"
    @State private var showingAddTodo = false
    @State private var selectedCategory: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            currentlyDoingSection
            tabSelector
            categoryFilter
            searchBar
            todoList
            addTodoSection
        }
        .frame(width: 400, height: 600)
        .background(Color(.windowBackgroundColor))
    }
    
    private var headerView: some View {
        HStack {
            Text("Todo Manager")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }
    
    private var currentlyDoingSection: some View {
        Group {
            if let current = todoStore.currentlyDoing {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Currently Doing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        
                        Text(current.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button("Complete") {
                            todoStore.completeCurrentlyDoing()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.green)
                        
                        Button("Archive") {
                            todoStore.archiveCurrentlyDoing()
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.orange)
                        
                        Button("Clear") {
                            todoStore.setCurrentlyDoing(nil)
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
    }
    
    private var tabSelector: some View {
        HStack(spacing: 1) {
            ForEach(TodoStatus.allCases, id: \.self) { status in
                Button(action: {
                    selectedTab = status
                }) {
                    VStack(spacing: 4) {
                        Text(status.displayName)
                            .font(.subheadline)
                            .fontWeight(selectedTab == status ? .semibold : .regular)
                        
                        Text("\(todosForStatus(status).count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedTab == status ? Color(.selectedControlColor) : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundColor(selectedTab == status ? .primary : .secondary)
            }
        }
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search todos...", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background(Color(.textBackgroundColor))
        .cornerRadius(6)
        .padding(.horizontal)
        .padding(.top, 8)
    }
    
    private var todoList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredTodos) { todo in
                    TodoRowView(
                        todo: todo,
                        isCurrentlyDoing: todoStore.currentlyDoing?.id == todo.id,
                        categories: todoStore.categories,
                        onStatusChange: { status in
                            todoStore.updateTodo(todo, status: status)
                        },
                        onSetCurrentlyDoing: {
                            todoStore.setCurrentlyDoing(todo)
                        },
                        onEdit: { newTitle, newDescription, newCategory in
                            todoStore.editTodo(todo, newTitle: newTitle, newDescription: newDescription, newCategory: newCategory)
                        },
                        onDelete: {
                            todoStore.deleteTodo(todo)
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    private var categoryFilter: some View {
        Group {
            if !todoStore.categories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button("All") {
                            selectedCategory = nil
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedCategory == nil ? Color(.selectedControlColor) : Color(.controlBackgroundColor))
                        .cornerRadius(16)
                        .font(.caption)
                        
                        ForEach(todoStore.categories, id: \.self) { category in
                            Button(category) {
                                selectedCategory = category
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedCategory == category ? Color(.selectedControlColor) : Color(.controlBackgroundColor))
                            .cornerRadius(16)
                            .font(.caption)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.top, 8)
            }
        }
    }
    
    private var addTodoSection: some View {
        VStack(spacing: 8) {
            if showingAddTodo {
                VStack(spacing: 8) {
                    TextField("Todo title", text: $newTodoTitle)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Description (optional)", text: $newTodoDescription)
                        .textFieldStyle(.roundedBorder)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category:")
                            .font(.caption)
                        
                        HStack {
                            TextField("Category", text: $newTodoCategory)
                                .textFieldStyle(.roundedBorder)
                            
                            if !todoStore.categories.isEmpty {
                                Menu {
                                    ForEach(todoStore.categories, id: \.self) { category in
                                        Button(category) {
                                            newTodoCategory = category
                                        }
                                    }
                                } label: {
                                    Image(systemName: "chevron.down.circle")
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                                .help("Choose from existing categories")
                            }
                        }
                        
                        if !todoStore.categories.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(todoStore.categories.prefix(5), id: \.self) { category in
                                        Button(category) {
                                            newTodoCategory = category
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(.controlBackgroundColor))
                                        .cornerRadius(12)
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    
                    HStack {
                        Button("Cancel") {
                            showingAddTodo = false
                            resetNewTodoFields()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button("Add Todo") {
                            addTodo()
                        }
                        .disabled(newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
                .background(Color(.controlBackgroundColor).opacity(0.5))
                .cornerRadius(8)
                .padding(.horizontal)
            } else {
                Button("+ Add Todo") {
                    showingAddTodo = true
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
        }
        .padding(.bottom)
        .background(Color(.controlBackgroundColor))
    }
    
    private func todosForStatus(_ status: TodoStatus) -> [TodoItem] {
        switch status {
        case .inProgress: return todoStore.inProgressTodos
        case .completed: return todoStore.completedTodos
        case .archived: return todoStore.archivedTodos
        }
    }
    
    private var filteredTodos: [TodoItem] {
        var statusTodos = todosForStatus(selectedTab)
        
        // Apply category filter
        if let category = selectedCategory {
            statusTodos = statusTodos.filter { $0.category == category }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            statusTodos = statusTodos.filter { 
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.description.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return statusTodos
    }
    
    private func addTodo() {
        let title = newTodoTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        
        todoStore.addTodo(
            title: title,
            description: newTodoDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            category: newTodoCategory.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        )
        
        showingAddTodo = false
        resetNewTodoFields()
    }
    
    private func resetNewTodoFields() {
        newTodoTitle = ""
        newTodoDescription = ""
        newTodoCategory = "general"
    }
}

struct TodoRowView: View {
    let todo: TodoItem
    let isCurrentlyDoing: Bool
    let categories: [String]
    let onStatusChange: (TodoStatus) -> Void
    let onSetCurrentlyDoing: () -> Void
    let onEdit: (String, String, String) -> Void
    let onDelete: () -> Void
    
    @State private var isEditing = false
    @State private var editingTitle = ""
    @State private var editingDescription = ""
    @State private var editingCategory = ""
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack(spacing: 12) {
            statusIndicator
            
            VStack(alignment: .leading, spacing: 2) {
                if isEditing {
                    VStack(spacing: 4) {
                        TextField("Todo title", text: $editingTitle)
                            .textFieldStyle(.roundedBorder)
                            .font(.subheadline)
                        
                        TextField("Description", text: $editingDescription)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                        
                        HStack {
                            TextField("Category", text: $editingCategory)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                            
                            if !categories.isEmpty {
                                Menu {
                                    ForEach(categories, id: \.self) { category in
                                        Button(category) {
                                            editingCategory = category
                                        }
                                    }
                                } label: {
                                    Image(systemName: "chevron.down.circle")
                                        .foregroundColor(.blue)
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .onAppear {
                        editingTitle = todo.title
                        editingDescription = todo.description
                        editingCategory = todo.category
                    }
                } else {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(todo.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .strikethrough(todo.status == .completed)
                            .onTapGesture(count: 2) {
                                startEditing()
                            }
                        
                        if !todo.description.isEmpty {
                            Text(todo.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        HStack {
                            Text(todo.category)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(.controlBackgroundColor))
                                .cornerRadius(4)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(DateFormatter.relative.string(from: todo.updatedAt))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            actionButtons
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isCurrentlyDoing ? Color.green.opacity(0.1) : Color(.controlBackgroundColor))
        .cornerRadius(8)
        .contextMenu {
            contextMenuItems
        }
        .alert("Delete Todo", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete '\(todo.title)'? This action cannot be undone.")
        }
    }
    
    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 10, height: 10)
    }
    
    private var statusColor: Color {
        switch todo.status {
        case .inProgress: return .blue
        case .completed: return .green
        case .archived: return .gray
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 4) {
            if isEditing {
                Button("Save") {
                    saveEdit()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.blue)
                
                Button("Cancel") {
                    cancelEdit()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)
            } else {
                if todo.status != .completed && !isCurrentlyDoing {
                    Button(action: onSetCurrentlyDoing) {
                        Image(systemName: "play.circle")
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: startEditing) {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                
                Button(action: { showingDeleteAlert = true }) {
                    Image(systemName: "trash.circle")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                
                Menu {
                    ForEach(TodoStatus.allCases, id: \.self) { status in
                        Button(status.displayName) {
                            onStatusChange(status)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var contextMenuItems: some View {
        Group {
            if !isCurrentlyDoing {
                Button("Set as Currently Doing") {
                    onSetCurrentlyDoing()
                }
            }
            
            Button("Edit") {
                startEditing()
            }
            
            Menu("Move to") {
                ForEach(TodoStatus.allCases, id: \.self) { status in
                    Button(status.displayName) {
                        onStatusChange(status)
                    }
                }
            }
            
            Divider()
            
            Button("Delete", role: .destructive) {
                showingDeleteAlert = true
            }
        }
    }
    
    private func startEditing() {
        editingTitle = todo.title
        editingDescription = todo.description
        editingCategory = todo.category
        isEditing = true
    }
    
    private func saveEdit() {
        let trimmedTitle = editingTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            onEdit(
                trimmedTitle,
                editingDescription.trimmingCharacters(in: .whitespacesAndNewlines),
                editingCategory.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            )
        }
        isEditing = false
    }
    
    private func cancelEdit() {
        editingTitle = todo.title
        editingDescription = todo.description
        editingCategory = todo.category
        isEditing = false
    }
}

extension DateFormatter {
    static let relative: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .none
        formatter.dateStyle = .medium
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()
}