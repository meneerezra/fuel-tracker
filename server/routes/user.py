from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ConfigDict, Field

import database
from models.fuel_type import FuelType
from models.validation import Name
from models.user import User, create_user_with_sixteen_digit_auth_token
import logging
logger = logging.getLogger(__name__)

router = APIRouter(prefix="/users", tags=["users"])
security = HTTPBearer()

class CreateUser(BaseModel):
    name: Name
    is_superuser: bool

@router.post("/")
def create_user(
        user: CreateUser,
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ) -> User:
    current_user = database.get_current_user(credentials)
    if not current_user:
        raise HTTPException(status_code=401, detail="Access denied user does not exist")
    if not current_user.is_superuser:
        raise HTTPException(status_code=401, detail="Access denied not enough permissions")
    new_user = create_user_with_sixteen_digit_auth_token()
    new_user.name = user.name
    new_user.is_superuser = user.is_superuser
    database.save_user(new_user)
    return new_user

class CarOut(BaseModel):
    id: int | None = None
    name: str
    owner_id: int | None = None
    km_driven: float = 0
    km_treshold: float = 0
    total_km_driven: float = 0
    consumption: float = 0
    fuel_type: FuelType
    country_code: str = "NL"

class UserOut(BaseModel):
    id: int | None = None
    name: str | None = None
    is_superuser: bool
    shared_cars: list[CarOut] 
    owned_cars: list[CarOut] 

@router.get("/me", response_model=UserOut)
def view_current_user(
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ) -> User:
    current_user = database.get_current_user(credentials)
    if current_user == None:
        raise HTTPException(status_code=401, detail="Access denied")
    return current_user


@router.get("/", response_model=list[UserOut])
def view_all_users(
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ) -> list[User]:
    """All users with their cars. Superuser only, auth tokens are not included."""
    current_user = database.get_current_user(credentials)
    if not current_user:
        raise HTTPException(status_code=401, detail="Access denied user does not exist")
    if not current_user.is_superuser:
        raise HTTPException(status_code=401, detail="Access denied not enough permissions")
    return database.get_all_users()

def _require_superuser(credentials: HTTPAuthorizationCredentials) -> User:
    current_user = database.get_current_user(credentials)
    if not current_user:
        raise HTTPException(status_code=401, detail="Access denied user does not exist")
    if not current_user.is_superuser:
        raise HTTPException(status_code=401, detail="Access denied not enough permissions")
    return current_user

def _get_user_or_404(user_id: int) -> User:
    user = database.get_user_by_id(user_id)
    if user is None:
        raise HTTPException(status_code=404, detail="User does not exist")
    return user

class RenameUser(BaseModel):
    name: Name

@router.put("/{user_id}", response_model=UserOut)
def rename_user(
        user_id: int,
        body: RenameUser,
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ) -> User:
    """Superuser only."""
    _require_superuser(credentials)
    user = _get_user_or_404(user_id)
    user.name = body.name
    database.save_user(user)
    return database.get_user_with_cars(user_id)

class UserToken(BaseModel):
    auth_token: int

@router.get("/{user_id}/token")
def view_user_token(
        user_id: int,
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ) -> UserToken:
    """Superuser only."""
    _require_superuser(credentials)
    user = _get_user_or_404(user_id)
    return UserToken(auth_token=user.auth_token)

@router.delete("/{user_id}")
def delete_user(
        user_id: int,
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ):
    """Superuser only. Also deletes the cars the user owns."""
    current_user = _require_superuser(credentials)
    if current_user.id == user_id:
        raise HTTPException(status_code=400, detail="You cannot delete your own account")
    _get_user_or_404(user_id)
    database.delete_user(user_id)
