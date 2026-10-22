from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ConfigDict, Field

import database
from models.fuel_type import FuelType
from models.user import User, create_user_with_sixteen_digit_auth_token
import logging
logger = logging.getLogger(__name__)

router = APIRouter(prefix="/users", tags=["users"])
security = HTTPBearer()

class CreateUser(BaseModel):
    name: str
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

