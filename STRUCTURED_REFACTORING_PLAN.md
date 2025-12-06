# Structured/Functional Refactoring Plan

## Goal: Pure Functions with Dependency Injection (Option 3)

Refactor from class-based static methods to **pure module-level functions** with explicit dependency passing.

---

## Current Architecture (Class-based with @staticmethod)

```python
# Current: services/auth_service.py
class AuthService:
    @staticmethod
    def create_user(db: Session, user_data: UserCreate) -> User:
        return UserRepository.create_user(db, {...})

    @staticmethod
    def authenticate_user(db: Session, email: str, password: str) -> Optional[User]:
        user = UserRepository.get_by_email(db, email)
        # ...
```

**Problems:**
- Classes used as namespaces only
- No real OOP benefits
- Static coupling to repositories
- Hard to test (can't mock dependencies easily)

---

## Target Architecture (Functional with Dependency Injection)

```python
# Target: services/auth.py (no class)

def create_user(
    db: Session,
    user_repo: UserRepository,  # Injected dependency
    user_data: UserCreate
) -> User:
    """Pure function: create new user"""
    hashed_password = hash_password(user_data.password)
    user_dict = {...}
    return user_repo.create_user(db, user_dict)


def authenticate_user(
    db: Session,
    user_repo: UserRepository,  # Injected dependency
    email: str,
    password: str
) -> Optional[User]:
    """Pure function: authenticate user"""
    user = user_repo.get_by_email(db, email)
    if not user or not verify_password(password, user.hashed_password):
        return None
    return user
```

**Benefits:**
- ✅ Pure functions (no hidden state)
- ✅ Explicit dependencies (easy to test)
- ✅ No classes (true structured programming)
- ✅ Dependency injection (flexible, mockable)

---

## Refactoring Strategy

### Phase 1: Repositories (Data Layer)

**Current:**
```python
class UserRepository:
    @staticmethod
    def get_by_email(db: Session, email: str) -> Optional[User]:
        return db.query(User).filter(User.email == email).first()
```

**Target:**
```python
# repositories/user.py (module with functions)

def get_user_by_email(db: Session, email: str) -> Optional[User]:
    """Get user by email address"""
    return db.query(User).filter(User.email == email.lower()).first()

def create_user(db: Session, user_data: dict) -> User:
    """Create new user in database"""
    db_user = User(**user_data)
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user
```

**Changes:**
- ❌ Remove `class UserRepository`
- ✅ Pure module-level functions
- ✅ Clear function names (no class prefix needed)

---

### Phase 2: Services (Business Logic Layer)

**Current:**
```python
class AuthService:
    @staticmethod
    def create_user(db: Session, user_data: UserCreate) -> User:
        hashed_password = get_password_hash(user_data.password)
        user_dict = {...}
        return UserRepository.create_user(db, user_dict)
```

**Target:**
```python
# services/auth.py

from repositories import user as user_repo

def register_user(
    db: Session,
    user_data: UserCreate
) -> User:
    """Register new user with email and password"""
    # Validate email not taken
    existing = user_repo.get_user_by_email(db, user_data.email)
    if existing:
        raise ValueError("Email already registered")

    # Hash password
    hashed_password = hash_password(user_data.password)

    # Create user
    user_dict = {
        "first_name": user_data.first_name,
        "last_name": user_data.last_name,
        "email": user_data.email.lower(),
        "hashed_password": hashed_password,
        "is_verified": False
    }

    return user_repo.create_user(db, user_dict)
```

**Changes:**
- ❌ Remove `class AuthService`
- ✅ Import repository module
- ✅ Call repository functions directly
- ✅ Pure business logic

---

### Phase 3: Routers (API Layer)

**Current:**
```python
@router.post("/register")
async def register(user: UserCreate, db: Session = Depends(get_db)):
    existing = AuthService.get_user_by_email(db, user.email)
    if existing:
        raise HTTPException(...)

    db_user = AuthService.create_user(db, user)
    return UserResponse.model_validate(db_user)
```

**Target:**
```python
@router.post("/register")
async def register(
    user: UserCreate,
    db: Session = Depends(get_db)
):
    """Register new user"""
    try:
        db_user = auth_service.register_user(db, user)
        return UserResponse.model_validate(db_user)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
```

**Changes:**
- ✅ Import service module
- ✅ Call service functions directly
- ✅ Handle errors from services

---

## File Structure

### Before (Class-based)
```
app/
├── repositories/
│   ├── __init__.py
│   ├── user_repository.py      # class UserRepository
│   └── media_repository.py
├── services/
│   ├── __init__.py
│   ├── auth_service.py         # class AuthService
│   ├── media_service.py        # class MediaService
│   └── asr_service.py          # class ASRService
└── routers/
    ├── auth.py                 # AuthService.method()
    ├── media.py                # MediaService.method()
    └── asr.py                  # ASRService.method()
```

### After (Functional)
```
app/
├── repositories/
│   ├── __init__.py
│   ├── user.py                 # Pure functions
│   └── media.py                # (not used - in-memory)
├── services/
│   ├── __init__.py
│   ├── auth.py                 # Pure functions
│   ├── media.py                # Pure functions
│   └── asr.py                  # Pure functions
└── routers/
    ├── auth.py                 # auth_service.function()
    ├── media.py                # media_service.function()
    └── asr.py                  # asr_service.function()
```

---

## Example Refactoring: AuthService

### Before
```python
# app/services/auth_service.py
class AuthService:
    OTP_VALIDITY_MINUTES = 15

    @staticmethod
    def get_user_by_email(db: Session, email: str) -> Optional[User]:
        return UserRepository.get_by_email(db, email)

    @staticmethod
    def create_user(db: Session, user_data: UserCreate) -> User:
        hashed_password = get_password_hash(user_data.password)
        user_dict = {...}
        return UserRepository.create_user(db, user_dict)

    @staticmethod
    def authenticate_user(db: Session, email: str, password: str) -> Optional[User]:
        user = AuthService.get_user_by_email(db, email)
        if not user or not verify_password(password, user.hashed_password):
            return None
        user = UserRepository.update_last_login(db, user)
        return user
```

### After
```python
# app/services/auth.py
from repositories import user as user_repo
from utils.security import hash_password, verify_password, create_access_token

# Constants
OTP_VALIDITY_MINUTES = 15


def register_user(db: Session, user_data: UserCreate) -> User:
    """Register new user with email and password"""
    # Check if email exists
    existing = user_repo.get_user_by_email(db, user_data.email)
    if existing:
        raise ValueError("Email already registered")

    # Hash password
    hashed_password = hash_password(user_data.password)

    # Create user
    user_dict = {
        "first_name": user_data.first_name,
        "last_name": user_data.last_name,
        "email": user_data.email.lower(),
        "hashed_password": hashed_password,
        "is_verified": False
    }

    return user_repo.create_user(db, user_dict)


def authenticate_user(db: Session, email: str, password: str) -> Optional[User]:
    """Authenticate user with email and password"""
    # Get user
    user = user_repo.get_user_by_email(db, email)
    if not user:
        return None

    # Verify password
    if not user.hashed_password or not verify_password(password, user.hashed_password):
        return None

    # Check active
    if not user.is_active:
        return None

    # Update last login
    user = user_repo.update_last_login(db, user)
    return user


def create_user_token(user: User) -> dict:
    """Create access token for user"""
    access_token = create_access_token(
        data={"sub": user.uuid, "email": user.email}
    )

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "user": UserResponse.model_validate(user)
    }
```

---

## Migration Steps

### Step 1: Refactor Repositories
- [ ] `user_repository.py` → `repositories/user.py` (pure functions)
- [ ] Remove `class UserRepository`
- [ ] Rename functions: `get_by_email()` → `get_user_by_email()`

### Step 2: Refactor Services
- [ ] `auth_service.py` → `services/auth.py` (pure functions)
- [ ] `media_service.py` → `services/media.py` (pure functions)
- [ ] `asr_service.py` → `services/asr.py` (pure functions)
- [ ] Remove all classes
- [ ] Import repository modules
- [ ] Call repository functions directly

### Step 3: Update Routers
- [ ] Update imports: `from services import auth` instead of `from services.auth_service import AuthService`
- [ ] Update calls: `auth.register_user()` instead of `AuthService.create_user()`

### Step 4: Update __init__.py files
- [ ] Export functions from modules
- [ ] Remove class exports

---

## Benefits of This Refactoring

### 1. **True Structured Programming**
- No classes (pure functions)
- Clear data flow
- Easy to understand

### 2. **Better Testability**
```python
# Before (hard to mock)
def test_create_user():
    # Can't easily mock UserRepository
    result = AuthService.create_user(db, user_data)

# After (easy to mock)
def test_create_user():
    mock_repo = Mock()
    result = auth.register_user(db, user_data)
    # Can inject mock repo if needed
```

### 3. **Explicit Dependencies**
```python
# Clear what each function needs
def authenticate_user(
    db: Session,      # Needs database
    email: str,       # Needs email
    password: str     # Needs password
) -> Optional[User]:
```

### 4. **No Hidden State**
```python
# No class variables that could cause issues
# No singleton patterns
# Pure functions = predictable output
```

---

## Testing Strategy

### Before
```python
# Mocking is awkward
with patch('app.services.auth_service.UserRepository') as mock_repo:
    AuthService.create_user(db, user_data)
```

### After
```python
# Direct function calls, easy to test
def test_register_user():
    result = auth.register_user(db, user_data)
    assert result.email == user_data.email
```

---

## Summary

| Aspect | Before (Classes) | After (Functions) |
|--------|------------------|-------------------|
| **Approach** | Class with @staticmethod | Pure functions |
| **Dependencies** | Hidden (static imports) | Explicit (parameters) |
| **Testability** | Hard to mock | Easy to test |
| **Complexity** | Medium | Low |
| **True to paradigm** | Fake OOP | True structured |

---

## Next Steps

1. ✅ Review this plan
2. Start with UserRepository refactoring
3. Move to AuthService
4. Update MediaService
5. Refactor ASRService
6. Update all routers
7. Test everything

Ready to proceed?
