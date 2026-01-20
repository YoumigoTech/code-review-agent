# B-Class Risks (Auto-Suggestion)

These risks can be addressed with automated suggestions. The PR is not blocked, but developers receive inline suggestion comments they can accept or reject.

---

## B1: Types and Contracts Need Explicit Definition

### Description
Raw strings, magic numbers, or implicit contracts that should be replaced with explicit types, enums, or constants.

### Blocking Level: **Yes** (should fix before merge)

### Patterns to Detect

#### Magic Numbers
```python
# BAD
if user.age > 18:
    allow_access()
timeout = 30000

# GOOD
ADULT_AGE_THRESHOLD = 18
NETWORK_TIMEOUT_MS = 30000
```

#### Raw Strings → Enum
```swift
// BAD
func setStatus(_ status: String) {
    if status == "active" { ... }
}

// GOOD
enum UserStatus: String {
    case active, inactive, pending
}
func setStatus(_ status: UserStatus) { ... }
```

#### Cache Key Versioning
```python
# BAD
cache.set("user_profile", data)

# GOOD
CACHE_VERSION = "v2"
cache.set(f"user_profile:{CACHE_VERSION}:{user_id}", data)
```

### Suggestion Format
```suggestion
- timeout = 30000
+ NETWORK_TIMEOUT_MS = 30000
+ timeout = NETWORK_TIMEOUT_MS
```

---

## B2: Serialization Robustness

### Description
Manual serialization, implicit deserialization, or default values that mask failures.

### Blocking Level: **Yes** (should fix before merge)

### Patterns to Detect

#### Hand-rolled JSON
```python
# BAD
data = {"name": user.name, "age": user.age}
json_str = json.dumps(data)

# GOOD
@dataclass
class UserDTO:
    name: str
    age: int

user_dto = UserDTO(name=user.name, age=user.age)
json_str = json.dumps(asdict(user_dto))
```

#### Default Values Masking Failures
```swift
// BAD
let count = json["count"] as? Int ?? 0  // masks missing field

// GOOD
guard let count = json["count"] as? Int else {
    throw DecodingError.missingField("count")
}
```

#### Optional Coalescing Hiding Errors
```typescript
// BAD
const userId = response.data?.user?.id ?? "unknown"

// GOOD
if (!response.data?.user?.id) {
    logger.error("Missing user ID in response", { response })
    throw new InvalidResponseError("Missing user ID")
}
const userId = response.data.user.id
```

### Suggestion Format
```suggestion
- let count = json["count"] as? Int ?? 0
+ guard let count = json["count"] as? Int else {
+     throw DecodingError.missingField("count")
+ }
```

---

## B3: Test Completeness

### Description
Missing test coverage for critical paths, especially serialization round-trips and enum completeness.

### Blocking Level: **Conditional** (required for critical paths)

### Patterns to Detect

#### Missing Codable Round-trip Test
```swift
// When a new Codable struct is added, suggest:
func testUserRoundTrip() throws {
    let original = User(id: "123", name: "Test")
    let data = try JSONEncoder().encode(original)
    let decoded = try JSONDecoder().decode(User.self, from: data)
    XCTAssertEqual(original, decoded)
}
```

#### Enum Without Exhaustive Test
```python
# When enum is added/modified, suggest:
def test_status_enum_completeness():
    """Ensure all enum values are handled"""
    for status in UserStatus:
        result = process_status(status)
        assert result is not None, f"Unhandled status: {status}"
```

### Suggestion Format
```suggestion
+ // TODO: Add round-trip test for UserDTO
+ func testUserDTORoundTrip() throws {
+     let original = UserDTO(...)
+     let encoded = try JSONEncoder().encode(original)
+     let decoded = try JSONDecoder().decode(UserDTO.self, from: encoded)
+     XCTAssertEqual(original, decoded)
+ }
```

---

## B4: Maintainability Hygiene

### Description
Code that violates DRY (Don't Repeat Yourself) or has redundant logging/comments.

### Blocking Level: **No** (suggestion only)

### Patterns to Detect

#### Duplicate Code Blocks
```python
# BAD
def create_user():
    logger.info("Starting operation")
    validate_input()
    logger.info("Input validated")
    # ... 20 more lines identical to update_user

# GOOD
def _execute_user_operation(operation_name, operation_fn):
    logger.info(f"Starting {operation_name}")
    validate_input()
    logger.info("Input validated")
    return operation_fn()
```

#### Redundant Logging
```swift
// BAD
func fetchUser() {
    print("Fetching user...")  // Debug log
    logger.debug("Fetching user")  // Also logging
    // ...
    print("User fetched!")  // Debug log
    logger.debug("User fetched")  // Also logging
}

// GOOD
func fetchUser() {
    logger.debug("Fetching user")
    // ...
    logger.debug("User fetched")
}
```

### Suggestion Format
```suggestion
- print("Fetching user...")
- logger.debug("Fetching user")
+ logger.debug("Fetching user")
```

---

## B5: Observability Gaps

### Description
Missing crash reporting, metrics, or logging for important operations.

### Blocking Level: **Conditional** (required for production-critical paths)

### Patterns to Detect

#### Missing Crashlytics/Error Reporting
```swift
// BAD
catch {
    print("Error: \(error)")
}

// GOOD
catch {
    Crashlytics.crashlytics().record(error: error)
    logger.error("Operation failed", error: error)
}
```

#### Cache Failures Only Local Log
```python
# BAD
try:
    cache.set(key, value)
except Exception as e:
    print(f"Cache set failed: {e}")  # Only local log

# GOOD
try:
    cache.set(key, value)
except Exception as e:
    logger.error("Cache set failed", exc_info=e, extra={"key": key})
    metrics.increment("cache.set.failure")
```

### Suggestion Format
```suggestion
- print("Error: \(error)")
+ Crashlytics.crashlytics().record(error: error)
+ logger.error("Operation failed: \(error)")
```

---

## B6: UI/UX Consistency

### Description
Missing standard UI patterns that affect user experience.

### Blocking Level: **No** (suggestion only)

### Patterns to Detect

#### Missing Keyboard Dismissal (iOS)
```swift
// When a view has TextField but no keyboard dismissal
// BAD
struct LoginView: View {
    var body: some View {
        VStack {
            TextField("Email", text: $email)
            TextField("Password", text: $password)
        }
    }
}

// GOOD
struct LoginView: View {
    var body: some View {
        VStack {
            TextField("Email", text: $email)
            TextField("Password", text: $password)
        }
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
}
```

#### Missing Loading States
```swift
// BAD
struct DataView: View {
    @State var data: [Item] = []

    var body: some View {
        List(data) { item in ... }
    }
}

// GOOD
struct DataView: View {
    @State var data: [Item] = []
    @State var isLoading = true

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                List(data) { item in ... }
            }
        }
    }
}
```

### Suggestion Format
```suggestion
+ .onTapGesture {
+     UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
+ }
```

---

## Suggestion Comment Format

B-class suggestions are posted as GitHub suggestion comments:

```markdown
**B[N] Suggestion**: [Brief description]

[Explanation of why this change is recommended]

\```suggestion
[code suggestion that can be accepted with one click]
\```

**Severity**: [Blocking/Non-blocking]
**Category**: [B1-B6]
```

## Auto-Accept Settings

Configure which B-class suggestions should be auto-applied:

```yaml
# In workflow configuration
b_class_settings:
  B1_type_contracts:
    auto_apply: false
    blocking: true
  B2_serialization:
    auto_apply: false
    blocking: true
  B3_test_completeness:
    auto_apply: false
    blocking: conditional  # Blocking for Codable/API types
  B4_maintainability:
    auto_apply: false
    blocking: false
  B5_observability:
    auto_apply: false
    blocking: conditional  # Blocking for error handlers
  B6_ui_consistency:
    auto_apply: false
    blocking: false
```
