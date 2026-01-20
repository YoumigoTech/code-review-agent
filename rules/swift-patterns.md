# Swift/iOS Specific Patterns

Language-specific risk patterns for Swift and iOS development.

---

## Swift A-Class Patterns

### Force Unwrap (`!`)

**Risk Level**: A1 (Implicit Assumption)

```swift
// BAD - Crash if nil
let user = users.first!
let name = json["name"] as! String

// GOOD - Safe unwrap
guard let user = users.first else {
    throw EmptyUsersError()
}

guard let name = json["name"] as? String else {
    throw DecodingError.missingField("name")
}
```

### Force Try (`try!`)

**Risk Level**: A5 (Error Path Not First-Class)

```swift
// BAD - Crash on error
let data = try! JSONEncoder().encode(user)

// GOOD - Handle error
do {
    let data = try JSONEncoder().encode(user)
} catch {
    logger.error("Encoding failed: \(error)")
    throw EncodingError.failed(error)
}
```

### Implicitly Unwrapped Optionals

**Risk Level**: A1 (Implicit Assumption)

```swift
// BAD - Assumes always set
class ViewController: UIViewController {
    var coordinator: Coordinator!  // Crash if accessed before set
}

// GOOD - Explicit optional or proper initialization
class ViewController: UIViewController {
    weak var coordinator: Coordinator?

    // Or use dependency injection
    init(coordinator: Coordinator) {
        self.coordinator = coordinator
    }
}
```

### @MainActor Missing

**Risk Level**: A4 (Complex Async)

```swift
// BAD - UI update from background thread
class ViewModel: ObservableObject {
    @Published var items: [Item] = []

    func loadItems() async {
        let items = await api.fetchItems()
        self.items = items  // May crash: UI update from background
    }
}

// GOOD - Explicit main actor
@MainActor
class ViewModel: ObservableObject {
    @Published var items: [Item] = []

    func loadItems() async {
        let items = await api.fetchItems()
        self.items = items  // Safe: on main actor
    }
}
```

### Task Without Cancellation Handling

**Risk Level**: A4 (Complex Async)

```swift
// BAD - No cancellation check
func processItems() async {
    for item in items {
        await process(item)  // Continues even if cancelled
    }
}

// GOOD - Check for cancellation
func processItems() async throws {
    for item in items {
        try Task.checkCancellation()
        await process(item)
    }
}
```

### Unowned References in Closures

**Risk Level**: A1 (Implicit Assumption)

```swift
// BAD - Crash if self is deallocated
api.fetch { [unowned self] result in
    self.handleResult(result)
}

// GOOD - Weak reference with guard
api.fetch { [weak self] result in
    guard let self else { return }
    self.handleResult(result)
}
```

---

## Swift B-Class Patterns

### Raw String for State/Type

**Risk Level**: B1 (Type Contracts)

```swift
// BAD
func updateStatus(_ status: String) {
    switch status {
    case "active": ...
    case "inactive": ...
    }
}

// GOOD
enum UserStatus: String, Codable {
    case active, inactive, pending
}

func updateStatus(_ status: UserStatus) { ... }
```

### Manual Codable Implementation

**Risk Level**: B2 (Serialization)

```swift
// BAD - Manual encoding
func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(age, forKey: .age)
    // Easy to miss a field
}

// GOOD - Auto-synthesized
struct User: Codable {
    let name: String
    let age: Int
    // Compiler synthesizes encode/decode
}
```

### Missing Equatable/Hashable

**Risk Level**: B3 (Test Completeness)

```swift
// BAD - Can't easily compare in tests
struct User {
    let id: String
    let name: String
}

// GOOD - Testable
struct User: Equatable, Hashable {
    let id: String
    let name: String
}
```

### Print Instead of Logger

**Risk Level**: B5 (Observability)

```swift
// BAD
print("User logged in: \(userId)")

// GOOD
import OSLog
let logger = Logger(subsystem: "com.app", category: "auth")
logger.info("User logged in: \(userId, privacy: .private)")
```

### Missing Error Recording

**Risk Level**: B5 (Observability)

```swift
// BAD
catch {
    print("Error: \(error)")
}

// GOOD
import FirebaseCrashlytics

catch {
    Crashlytics.crashlytics().record(error: error)
    logger.error("Operation failed: \(error.localizedDescription)")
}
```

### View Without Preview

**Risk Level**: B6 (UI Consistency)

```swift
// BAD - No preview
struct ProfileView: View {
    var body: some View { ... }
}

// GOOD - With preview
struct ProfileView: View {
    var body: some View { ... }
}

#Preview {
    ProfileView()
}
```

### TextField Without Keyboard Dismissal

**Risk Level**: B6 (UI Consistency)

```swift
// BAD
struct FormView: View {
    @State var text = ""
    var body: some View {
        TextField("Input", text: $text)
    }
}

// GOOD
struct FormView: View {
    @State var text = ""
    @FocusState var isFocused: Bool

    var body: some View {
        TextField("Input", text: $text)
            .focused($isFocused)
            .onTapGesture {
                isFocused = false
            }
    }
}
```

---

## SwiftUI-Specific Patterns

### ObservableObject Without @Published

```swift
// BAD - Changes won't trigger UI update
class ViewModel: ObservableObject {
    var items: [Item] = []  // Missing @Published
}

// GOOD
class ViewModel: ObservableObject {
    @Published var items: [Item] = []
}
```

### StateObject vs ObservedObject

```swift
// BAD - Object recreated on every view update
struct ParentView: View {
    var body: some View {
        ChildView(viewModel: ViewModel())  // New instance each time
    }
}

// GOOD - Single instance
struct ParentView: View {
    @StateObject var viewModel = ViewModel()

    var body: some View {
        ChildView(viewModel: viewModel)
    }
}
```

### Missing Loading/Error States

```swift
// BAD
struct DataView: View {
    @StateObject var viewModel = DataViewModel()

    var body: some View {
        List(viewModel.items) { item in ... }
    }
}

// GOOD
struct DataView: View {
    @StateObject var viewModel = DataViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .error(let message):
                ErrorView(message: message)
            case .loaded:
                List(viewModel.items) { item in ... }
            }
        }
    }
}
```

---

## Detection Keywords Summary

| Pattern | Keywords | Risk |
|---------|----------|------|
| Force unwrap | `!` after variable | A1 |
| Force try | `try!` | A5 |
| Implicitly unwrapped | `var x: Type!` | A1 |
| Missing @MainActor | `@Published` without `@MainActor` | A4 |
| Unowned in closure | `[unowned self]` | A1 |
| Raw status string | `status == "active"` | B1 |
| Print statement | `print(` | B5 |
| Missing Crashlytics | `catch {` without `Crashlytics` | B5 |
