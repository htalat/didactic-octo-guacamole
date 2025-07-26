# TodoMenuBar

A clean and efficient macOS menubar todo application built with SwiftUI.

## Features

- **Menu Bar Integration**: Lives in your system menubar for quick access
- **Three-Tab Organization**: In-Progress, Completed, and Archived todos
- **Rich Todo Details**: Title, description, and category for each todo
- **Currently Doing**: Special section to highlight your active task
- **Smart Search**: Search across title, description, and category
- **Category Filtering**: Filter todos by category with dynamic filter chips
- **Full CRUD Operations**: Create, edit, delete todos with confirmation dialogs
- **Persistent Storage**: All data saved automatically using UserDefaults

## Installation

### Build from Source

1. Clone the repository:
```bash
git clone https://github.com/htalat/didactic-octo-guacamole.git
cd didactic-octo-guacamole
```

2. Build and run:
```bash
swift run
```

### Requirements

- macOS 14.0 or later
- Swift 5.9 or later

## Usage

1. **Launch**: Run the app and look for the checkmark icon in your menubar
2. **Add Todos**: Click "+ Add Todo" to create new todos with title, description, and category
3. **Organize**: Use the three tabs to organize todos by status
4. **Current Focus**: Set any todo as "currently doing" for quick reference
5. **Search & Filter**: Use the search bar and category filters to find specific todos
6. **Edit**: Double-tap any todo title or use the edit button to modify
7. **Delete**: Click the red trash icon or use the context menu (with confirmation)

## Development

### Running Tests

```bash
swift test
```

### Project Structure

- `Sources/TodoMenuBar/main.swift` - App entry point and menubar setup
- `Sources/TodoMenuBar/TodoModel.swift` - Data models and storage logic
- `Sources/TodoMenuBar/ContentView.swift` - SwiftUI interface
- `Tests/TodoMenuBarTests/` - Comprehensive test suite

## License

This project is available under the MIT License.