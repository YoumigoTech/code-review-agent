# Python/FastAPI Specific Patterns

Language-specific risk patterns for Python and FastAPI development.

---

## Python A-Class Patterns

### Bare Except

**Risk Level**: A5 (Error Path Not First-Class)

```python
# BAD - Catches everything including KeyboardInterrupt
try:
    do_something()
except:
    pass

# GOOD - Specific exception
try:
    do_something()
except ValueError as e:
    logger.error(f"Validation failed: {e}")
    raise
```

### Mutable Default Arguments

**Risk Level**: A2 (State Modified in Multiple Places)

```python
# BAD - Shared mutable default
def add_item(item, items=[]):
    items.append(item)
    return items

# GOOD - None default
def add_item(item, items=None):
    if items is None:
        items = []
    items.append(item)
    return items
```

### Global Mutable State

**Risk Level**: A2 (State Modified in Multiple Places)

```python
# BAD - Global mutable state
_cache = {}

def get_user(user_id):
    if user_id not in _cache:
        _cache[user_id] = fetch_user(user_id)
    return _cache[user_id]

# GOOD - Dependency injection or class
class UserCache:
    def __init__(self):
        self._cache = {}

    def get_user(self, user_id):
        if user_id not in self._cache:
            self._cache[user_id] = self._fetch_user(user_id)
        return self._cache[user_id]
```

### Async Without Timeout

**Risk Level**: A4 (Complex Async)

```python
# BAD - Can hang forever
async def fetch_data():
    response = await client.get(url)
    return response.json()

# GOOD - With timeout
async def fetch_data():
    async with asyncio.timeout(30):
        response = await client.get(url)
        return response.json()
```

### SQLAlchemy Session Leak

**Risk Level**: A4 (Complex Async)

```python
# BAD - Session not properly closed
def get_user(user_id):
    session = Session()
    user = session.query(User).get(user_id)
    return user  # Session leak!

# GOOD - Context manager
def get_user(user_id):
    with Session() as session:
        return session.query(User).get(user_id)
```

### FastAPI Dependency Without Cleanup

**Risk Level**: A5 (Error Path Not First-Class)

```python
# BAD - Resource leak on error
async def get_db():
    db = SessionLocal()
    return db

# GOOD - With cleanup
async def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

### Incomplete Match Statement

**Risk Level**: A3 (Incomplete Conditional)

```python
# BAD - Missing cases
match status:
    case "active":
        handle_active()
    case "inactive":
        handle_inactive()
    # What about other statuses?

# GOOD - Exhaustive
match status:
    case "active":
        handle_active()
    case "inactive":
        handle_inactive()
    case _:
        logger.warning(f"Unknown status: {status}")
        raise ValueError(f"Unknown status: {status}")
```

---

## Python B-Class Patterns

### Magic Numbers/Strings

**Risk Level**: B1 (Type Contracts)

```python
# BAD
if response.status_code == 200:
    pass
timeout = 30

# GOOD
from http import HTTPStatus

HTTP_OK = HTTPStatus.OK
DEFAULT_TIMEOUT_SECONDS = 30

if response.status_code == HTTP_OK:
    pass
```

### String Enum Instead of Enum

**Risk Level**: B1 (Type Contracts)

```python
# BAD
def set_status(status: str):
    if status == "active":
        ...

# GOOD
from enum import Enum

class UserStatus(str, Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    PENDING = "pending"

def set_status(status: UserStatus):
    ...
```

### Dict Instead of TypedDict/Dataclass

**Risk Level**: B2 (Serialization)

```python
# BAD - No type safety
def create_user(data: dict) -> dict:
    return {
        "name": data["name"],
        "age": data["age"],
    }

# GOOD - Type safety with dataclass
from dataclasses import dataclass

@dataclass
class User:
    name: str
    age: int

def create_user(data: dict) -> User:
    return User(name=data["name"], age=data["age"])
```

### Missing Pydantic Validation

**Risk Level**: B2 (Serialization)

```python
# BAD - Manual validation
@app.post("/users")
async def create_user(request: Request):
    data = await request.json()
    if "email" not in data:
        raise HTTPException(400, "Missing email")
    ...

# GOOD - Pydantic model
from pydantic import BaseModel, EmailStr

class CreateUserRequest(BaseModel):
    email: EmailStr
    name: str

@app.post("/users")
async def create_user(request: CreateUserRequest):
    ...  # Validation automatic
```

### Print Instead of Logger

**Risk Level**: B5 (Observability)

```python
# BAD
print(f"User {user_id} logged in")

# GOOD
import logging
logger = logging.getLogger(__name__)

logger.info("User logged in", extra={"user_id": user_id})
```

### Missing Structlog Context

**Risk Level**: B5 (Observability)

```python
# BAD - No context
logger.error("Operation failed")

# GOOD - With context
import structlog
logger = structlog.get_logger()

logger.error(
    "Operation failed",
    user_id=user_id,
    operation="create_order",
    error=str(e)
)
```

### Missing Type Hints

**Risk Level**: B1 (Type Contracts)

```python
# BAD
def process_items(items):
    return [item.name for item in items]

# GOOD
def process_items(items: list[Item]) -> list[str]:
    return [item.name for item in items]
```

---

## FastAPI-Specific Patterns

### Missing Response Model

```python
# BAD - Response structure not documented
@app.get("/users/{user_id}")
async def get_user(user_id: str):
    return {"name": "John", "age": 30}

# GOOD - Explicit response model
class UserResponse(BaseModel):
    name: str
    age: int

@app.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: str) -> UserResponse:
    return UserResponse(name="John", age=30)
```

### Missing HTTPException Details

```python
# BAD - Generic error
raise HTTPException(status_code=400)

# GOOD - Detailed error
raise HTTPException(
    status_code=400,
    detail={
        "error": "validation_error",
        "message": "Email is required",
        "field": "email"
    }
)
```

### Sync DB Call in Async Endpoint

```python
# BAD - Blocking the event loop
@app.get("/users")
async def get_users(db: Session = Depends(get_db)):
    return db.query(User).all()  # Sync call!

# GOOD - Use async session or run in thread
from sqlalchemy.ext.asyncio import AsyncSession

@app.get("/users")
async def get_users(db: AsyncSession = Depends(get_async_db)):
    result = await db.execute(select(User))
    return result.scalars().all()
```

---

## SQLAlchemy Patterns

### N+1 Query

```python
# BAD - N+1 queries
users = session.query(User).all()
for user in users:
    print(user.orders)  # Each access = 1 query

# GOOD - Eager loading
users = session.query(User).options(
    joinedload(User.orders)
).all()
```

### Missing Index Hint

```python
# BAD - Potential slow query
users = session.query(User).filter(User.email == email).first()

# GOOD - Ensure index exists
class User(Base):
    __tablename__ = "users"
    email = Column(String, index=True)  # Add index
```

---

## Detection Keywords Summary

| Pattern | Keywords | Risk |
|---------|----------|------|
| Bare except | `except:` without type | A5 |
| Mutable default | `def f(x=[])` | A2 |
| Global state | `_cache = {}` at module level | A2 |
| Missing timeout | `await` without `asyncio.timeout` | A4 |
| Print statement | `print(` | B5 |
| Missing type hint | `def f(x):` | B1 |
| Dict literal | `{"key": value}` for API response | B2 |
| String comparison | `== "active"` | B1 |
