# A-Class Risks (Human-in-the-Loop Required)

These risks require human review and approval before PR merge. When detected, the PR will be blocked until a senior engineer reviews and approves.

---

## A1: Implicit Assumptions Not Validated

### Description
Code that makes assumptions about input, state, or environment without explicit validation.

### Keywords to Detect
- `assume`, `assumes`, `assuming`
- `should`, `should be`, `should have`
- `normally`, `usually`, `typically`
- `by default`, `expected to`, `supposed to`
- `// assume`, `# assume`, `/* assume`

### Code Patterns
```python
# BAD: Implicit assumption
def process_user(user_id):
    user = get_user(user_id)  # assumes user exists
    return user.name  # will crash if user is None

# GOOD: Explicit validation
def process_user(user_id):
    user = get_user(user_id)
    if user is None:
        raise UserNotFoundError(user_id)
    return user.name
```

### Output Format
> **A1 Risk Detected**: If `[assumption]` is not true, it will cause `[consequence]` risk.
>
> - Location: `file:line`
> - Assumption: [what is being assumed]
> - Consequence: [what happens if assumption fails]
> - Recommendation: Add explicit validation for [assumption]

---

## A2: State Modified in Multiple Places

### Description
Shared state (cache, global variables, user session) that can be modified from multiple locations, leading to potential race conditions or inconsistencies.

### Keywords to Detect
- `set`, `update`, `modify`, `mutate`
- `cache`, `cached`, `caching`
- `sync`, `synchronize`, `refresh`
- `local state`, `shared state`, `global`
- `@State`, `@Published`, `@ObservedObject` (Swift)
- `useState`, `useReducer`, `setState` (React)

### Code Patterns
```swift
// BAD: State modified in multiple places
class UserManager {
    static var currentUser: User?  // global mutable state

    func login() { Self.currentUser = fetchedUser }
    func logout() { Self.currentUser = nil }
    func refresh() { Self.currentUser = refreshedUser }
}

// GOOD: Single source of truth
class UserManager {
    private(set) var currentUser: User?

    func updateUser(_ action: UserAction) {
        // Single point of mutation
    }
}
```

### Output Format
> **A2 Risk Detected**: If `[state]` is modified by `[multiple locations]`, it will cause `[inconsistency]` risk.
>
> - Location: `file:line`
> - State: [name of shared state]
> - Modifiers: [list of places that modify this state]
> - Recommendation: Centralize state mutations or add synchronization

---

## A3: Incomplete Conditional Branches

### Description
if-else chains or switch statements that don't exhaustively handle all cases, especially edge cases.

### Keywords to Detect
- `if` without `else`
- `switch` without `default` (in languages that allow it)
- `guard` without complete coverage
- `when` without `else` (Kotlin)
- `match` without exhaustive patterns (Rust)

### Code Patterns
```python
# BAD: Missing edge case
def get_discount(user_type):
    if user_type == "premium":
        return 0.2
    elif user_type == "regular":
        return 0.1
    # What if user_type is "trial" or unknown?

# GOOD: Exhaustive handling
def get_discount(user_type):
    if user_type == "premium":
        return 0.2
    elif user_type == "regular":
        return 0.1
    else:
        logger.warning(f"Unknown user type: {user_type}")
        return 0.0
```

### Output Format
> **A3 Risk Detected**: If `[edge case]` occurs, it will cause `[undefined behavior]` risk.
>
> - Location: `file:line`
> - Missing Cases: [list of unhandled cases]
> - Recommendation: Add explicit handling for [cases] or add a default case with logging

---

## A4: Complex Async Without Guarantees

### Description
Asynchronous operations (network calls, database queries, background tasks) without proper handling for delays, retries, ordering, or cancellation.

### Keywords to Detect
- `async`, `await`, `asyncio`
- `callback`, `completion`, `handler`
- `queue`, `dispatch`, `worker`
- `retry`, `timeout`, `deadline`
- `Task`, `DispatchQueue` (Swift)
- `Promise`, `Observable`, `Future`

### Code Patterns
```swift
// BAD: No ordering guarantee
func loadData() async {
    async let users = fetchUsers()
    async let posts = fetchPosts()
    // What if posts depend on users?
    // What if one fails?
}

// GOOD: Explicit ordering and error handling
func loadData() async throws {
    let users = try await fetchUsers()
    let posts = try await fetchPosts(for: users)
}
```

### Output Format
> **A4 Risk Detected**: If `[operation]` becomes slow/repeated/out-of-order, it will cause `[consequence]` risk.
>
> - Location: `file:line`
> - Async Operation: [description]
> - Missing Guarantee: [timeout/retry/ordering/cancellation]
> - Recommendation: Add [specific guarantee mechanism]

---

## A5: Error Paths Not First-Class Citizens

### Description
Error handling that swallows errors, logs and continues, or leaves the system in an undefined state.

### Keywords to Detect
- `catch(e) { console.error`, `catch(e) { print`
- `try?`, `try!` (Swift)
- `except: pass`, `except Exception:`
- `|| true`, `|| null`, `?? fallback`
- `// ignore`, `// TODO: handle`
- `.catch(() => {})` (JavaScript)

### Code Patterns
```swift
// BAD: Error swallowed
func loadConfig() -> Config {
    let data = try? Data(contentsOf: configURL)  // silently fails
    return Config(data: data ?? Data())  // uses empty data
}

// GOOD: Error propagated or handled explicitly
func loadConfig() throws -> Config {
    do {
        let data = try Data(contentsOf: configURL)
        return try Config(data: data)
    } catch {
        logger.error("Config load failed: \(error)")
        throw ConfigError.loadFailed(underlying: error)
    }
}
```

### Output Format
> **A5 Risk Detected**: If `[operation]` fails, the system will be in `[undefined state]` risk.
>
> - Location: `file:line`
> - Error Handling: [how error is currently handled]
> - Undefined State: [what state the system would be in]
> - Recommendation: Propagate error or implement explicit recovery

---

## A6: Ambiguous Function Responsibilities

### Description
Functions with vague names or multiple responsibilities that make it unclear what they do and hard to maintain.

### Keywords to Detect
- `handle`, `process`, `manage`
- `do`, `doSomething`, `execute`
- `submit`, `run`, `perform`
- Functions > 50 lines
- Functions with > 3 side effects

### Code Patterns
```python
# BAD: Ambiguous responsibility
def handle_user_action(action):
    validate_action(action)
    update_database(action)
    send_notification(action)
    update_cache(action)
    log_analytics(action)
    # What exactly does "handle" mean?

# GOOD: Clear, single responsibility
def validate_user_action(action) -> ValidationResult: ...
def persist_user_action(action) -> PersistResult: ...
def notify_user_action(action) -> NotifyResult: ...
```

### Output Format
> **A6 Risk Detected**: If `[function]` needs modification, it will cause `[maintainability]` risk.
>
> - Location: `file:line`
> - Function: [name]
> - Responsibilities: [list of things this function does]
> - Recommendation: Split into focused functions with clear names

---

## Review Process for A-Class Risks

When an A-class risk is detected:

1. **PR is blocked** from merging
2. **Risk report** is posted as a PR comment
3. **Required reviewer** must acknowledge the risk
4. **Resolution options**:
   - Fix the code to eliminate the risk
   - Document why the risk is acceptable (with `// RISK-ACCEPTED: A1 - [reason]`)
   - Request exemption from a senior engineer

## Approved Risk Patterns

Some patterns are intentionally allowed despite matching A-class keywords:

```python
# RISK-ACCEPTED: A1 - User existence validated by auth middleware
user = get_current_user()  # assume user exists post-auth
```

Use `RISK-ACCEPTED: A[N]` comments to mark intentionally accepted risks.
