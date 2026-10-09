from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

import database
from models.car import Car 

router = APIRouter(prefix="/cars", tags=["cars"])
security = HTTPBearer()

@router.get("/{car_id}")
def get_car(
        car_id: int,
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ):
    user = database.get_current_user(credentials)
    if user is None:
        raise HTTPException(401, "Access denied")
    car = database.get_car_by_id(car_id)
    if car not in user.owned_cars:
        raise HTTPException(401, "Access denied")

    return car

class CreateCar(BaseModel):
    name: str

@router.post("/")
def create_car(
        car: CreateCar,
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ):
    user = database.get_current_user(credentials)
    if user is None:
        raise HTTPException(401, "Access denied")
    db_car = Car(name=car.name, owner=user)
    database.save_car(db_car)
    return db_car

class EditCar(BaseModel):
    id: int
    name: str
    owner_id: int

@router.put("/")
def edit_car(
        car: EditCar,
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ):
    user = database.get_current_user(credentials)
    if user is None:
        raise HTTPException(401, "Access denied")
    db_car = database.get_car_by_id(car.id)
    if not db_car:
        raise HTTPException(404, "Car does not exist")

    db_car.name = car.name
    db_car.owner_id = car.owner_id
    database.save_car(db_car)
    return db_car

