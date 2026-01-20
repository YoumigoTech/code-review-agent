# Go Specific Patterns

Language-specific risk patterns for Go development.

---

## Go A-Class Patterns

### Ignored Error

**Risk Level**: A5 (Error Path Not First-Class)

```go
// BAD - Error ignored
result, _ := doSomething()

// BAD - Error checked but not handled
result, err := doSomething()
if err != nil {
    log.Println(err)
    // continues execution!
}

// GOOD - Error properly handled
result, err := doSomething()
if err != nil {
    return fmt.Errorf("doSomething failed: %w", err)
}
```

### Nil Pointer Dereference

**Risk Level**: A1 (Implicit Assumption)

```go
// BAD - Assumes pointer is not nil
func processUser(user *User) {
    fmt.Println(user.Name)  // Panic if user is nil
}

// GOOD - Check for nil
func processUser(user *User) error {
    if user == nil {
        return errors.New("user cannot be nil")
    }
    fmt.Println(user.Name)
    return nil
}
```

### Goroutine Leak

**Risk Level**: A4 (Complex Async)

```go
// BAD - Goroutine can leak
func startWorker() {
    go func() {
        for {
            processItem(<-itemChan)  // Blocks forever if channel not closed
        }
    }()
}

// GOOD - Use context for cancellation
func startWorker(ctx context.Context) {
    go func() {
        for {
            select {
            case <-ctx.Done():
                return
            case item := <-itemChan:
                processItem(item)
            }
        }
    }()
}
```

### Race Condition

**Risk Level**: A2 (State Modified in Multiple Places)

```go
// BAD - Race condition
var counter int

func increment() {
    counter++  // Not thread-safe
}

// GOOD - Use mutex or atomic
var (
    counter int
    mu      sync.Mutex
)

func increment() {
    mu.Lock()
    defer mu.Unlock()
    counter++
}

// Or use atomic
var counter int64

func increment() {
    atomic.AddInt64(&counter, 1)
}
```

### Unbuffered Channel Deadlock

**Risk Level**: A4 (Complex Async)

```go
// BAD - Potential deadlock
ch := make(chan int)
ch <- 1  // Blocks forever, no receiver

// GOOD - Buffered channel or separate goroutine
ch := make(chan int, 1)
ch <- 1

// Or
ch := make(chan int)
go func() { ch <- 1 }()
```

### Missing Context Timeout

**Risk Level**: A4 (Complex Async)

```go
// BAD - Can hang forever
func fetchData(ctx context.Context) error {
    resp, err := http.Get(url)
    // ...
}

// GOOD - Use context with timeout
func fetchData(ctx context.Context) error {
    ctx, cancel := context.WithTimeout(ctx, 30*time.Second)
    defer cancel()

    req, _ := http.NewRequestWithContext(ctx, "GET", url, nil)
    resp, err := http.DefaultClient.Do(req)
    // ...
}
```

### Defer in Loop

**Risk Level**: A5 (Error Path Not First-Class)

```go
// BAD - Resources accumulate until function returns
func processFiles(files []string) error {
    for _, f := range files {
        file, _ := os.Open(f)
        defer file.Close()  // All defers run at function end!
    }
    return nil
}

// GOOD - Use closure or explicit close
func processFiles(files []string) error {
    for _, f := range files {
        if err := processFile(f); err != nil {
            return err
        }
    }
    return nil
}

func processFile(f string) error {
    file, err := os.Open(f)
    if err != nil {
        return err
    }
    defer file.Close()
    // ...
    return nil
}
```

---

## Go B-Class Patterns

### Magic Numbers/Strings

**Risk Level**: B1 (Type Contracts)

```go
// BAD
if resp.StatusCode == 200 {
    // ...
}
timeout := 30 * time.Second

// GOOD
const (
    HTTPStatusOK        = http.StatusOK
    DefaultTimeout      = 30 * time.Second
)

if resp.StatusCode == HTTPStatusOK {
    // ...
}
```

### String Constants Instead of Enum

**Risk Level**: B1 (Type Contracts)

```go
// BAD
func setStatus(status string) {
    if status == "active" {
        // ...
    }
}

// GOOD
type UserStatus string

const (
    UserStatusActive   UserStatus = "active"
    UserStatusInactive UserStatus = "inactive"
    UserStatusPending  UserStatus = "pending"
)

func setStatus(status UserStatus) {
    if status == UserStatusActive {
        // ...
    }
}
```

### Missing JSON Tags

**Risk Level**: B2 (Serialization)

```go
// BAD - Field names exposed as-is
type User struct {
    UserID   string
    FullName string
}

// GOOD - Explicit JSON tags
type User struct {
    UserID   string `json:"user_id"`
    FullName string `json:"full_name"`
}
```

### Exported Field Without Comment

**Risk Level**: B4 (Maintainability)

```go
// BAD - No documentation
type Config struct {
    MaxRetries int
    Timeout    time.Duration
}

// GOOD - Documented
type Config struct {
    // MaxRetries is the maximum number of retry attempts
    MaxRetries int
    // Timeout is the request timeout duration
    Timeout time.Duration
}
```

### Printf Without Format Verification

**Risk Level**: B5 (Observability)

```go
// BAD - Can panic if args don't match format
log.Printf("User %s has %d items", userId)  // Missing argument

// GOOD - Use structured logging
logger.Info("user has items",
    zap.String("user_id", userId),
    zap.Int("item_count", count),
)
```

### Missing Error Context

**Risk Level**: B5 (Observability)

```go
// BAD - Lost context
if err != nil {
    return err
}

// GOOD - Wrapped with context
if err != nil {
    return fmt.Errorf("failed to fetch user %s: %w", userID, err)
}
```

---

## Concurrency Patterns

### WaitGroup Misuse

```go
// BAD - wg.Add inside goroutine
var wg sync.WaitGroup
for i := 0; i < n; i++ {
    go func() {
        wg.Add(1)  // Race condition!
        defer wg.Done()
        // ...
    }()
}
wg.Wait()

// GOOD - wg.Add before goroutine
var wg sync.WaitGroup
for i := 0; i < n; i++ {
    wg.Add(1)
    go func() {
        defer wg.Done()
        // ...
    }()
}
wg.Wait()
```

### Closure Variable Capture

```go
// BAD - All goroutines use same variable
for i := 0; i < n; i++ {
    go func() {
        fmt.Println(i)  // All print the same value!
    }()
}

// GOOD - Pass as parameter
for i := 0; i < n; i++ {
    go func(i int) {
        fmt.Println(i)
    }(i)
}
```

---

## HTTP Patterns

### Response Body Not Closed

```go
// BAD - Resource leak
resp, err := http.Get(url)
if err != nil {
    return err
}
body, _ := io.ReadAll(resp.Body)  // Body not closed

// GOOD - Always close body
resp, err := http.Get(url)
if err != nil {
    return err
}
defer resp.Body.Close()
body, _ := io.ReadAll(resp.Body)
```

### Missing Request Context

```go
// BAD - No cancellation support
func handler(w http.ResponseWriter, r *http.Request) {
    data, err := fetchData()  // Ignores request context
}

// GOOD - Use request context
func handler(w http.ResponseWriter, r *http.Request) {
    data, err := fetchData(r.Context())
}
```

---

## Detection Keywords Summary

| Pattern | Keywords | Risk |
|---------|----------|------|
| Ignored error | `_, _ :=` or `_ =` | A5 |
| Nil dereference | `.` after pointer without nil check | A1 |
| Goroutine leak | `go func()` without context | A4 |
| Race condition | shared variable without mutex/atomic | A2 |
| Missing timeout | `http.Get` without context | A4 |
| Magic number | numeric literal in condition | B1 |
| Missing JSON tag | struct field without `json:` | B2 |
| Bare error return | `return err` without wrap | B5 |
