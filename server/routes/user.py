from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, ConfigDict, Field

import database
from models.user import User, create_user_with_sixteen_digit_auth_token
import logging
logger = logging.getLogger(__name__)

router = APIRouter(prefix="/users", tags=["users"])
security = HTTPBearer()

@router.post("/")
def create_user(
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ):
    current_user = database.get_current_user(credentials)
    if current_user == None:
        raise HTTPException(status_code=401, detail="Access denied")
    if not current_user.is_superuser:
        raise HTTPException(status_code=401, detail="Access denied")
    new_user = create_user_with_sixteen_digit_auth_token()
    database.save_user(new_user)
    return new_user

class CarOut(BaseModel):
    id: int | None = None
    name: str
    owner_id: int | None = None

class UserOut(BaseModel):
    id: int | None = None
    auth_token: int
    is_superuser: bool
    cars: list[CarOut] 
    owned_cars: list[CarOut] 

@router.get("/me", response_model=UserOut)
def view_current_user(
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ):
    current_user = database.get_current_user(credentials)
    if current_user == None:
        raise HTTPException(status_code=401, detail="Access denied")
    return current_user

