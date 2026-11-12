from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

import database
from models.car import Car
from models.fuel_type import FuelType
from services.fuel_prices import (
    CountryNotFoundError,
    FuelPriceServiceError,
    InvalidCountryCodeError,
    fetch_country_history,
)

router = APIRouter(prefix="/cars", tags=["cars"])
security = HTTPBearer()

def _owns(user, car: Car) -> bool:
    return any(owned.id == car.id for owned in user.owned_cars)

def _can_use(user, car: Car) -> bool:
    """Owners and users the car is shared with can view it."""
    return _owns(user, car) or any(shared.id == car.id for shared in user.shared_cars)

@router.get("/{car_id}")
def get_car(
        car_id: int,
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ) -> Car:
    user = database.get_current_user(credentials)
    if user is None:
        raise HTTPException(401, "Access denied")
    car = database.get_car_by_id(car_id)
    if not car:
        raise HTTPException(404, "Car does not exist")
    if not _can_use(user, car):
        raise HTTPException(401, "Access denied")

    return car

class CreateCar(BaseModel):
    name: str
    km_threshold: float
    fuel_type: FuelType
    consumption: float
    country_code: str = "NL"

@router.post("/")
def create_car(
        car: CreateCar,
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ) -> Car:
    user = database.get_current_user(credentials)
    if user is None:
        raise HTTPException(401, "Access denied")
    db_car = Car(name=car.name, km_treshold=car.km_threshold, fuel_type=car.fuel_type, consumption=car.consumption, country_code=car.country_code, owner=user)
    database.save_car(db_car)
    return db_car

class GetPriceResult(BaseModel):
    fuel_price: float
    price_per_km: float
    price_per_threshold: float

@router.get("/{car_id}/price")
def get_price(
        car_id: int,
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ) -> GetPriceResult:
    user = database.get_current_user(credentials)
    if user is None:
        raise HTTPException(401, "Access denied")
    car = database.get_car_by_id(car_id)
    if not car:
        raise HTTPException(404, "Car does not exist")
    if not _can_use(user, car):
        raise HTTPException(401, "Access denied")
    try:
        history = fetch_country_history(car.country_code)
    except InvalidCountryCodeError:
        raise HTTPException(400, "Invalid country code")
    except CountryNotFoundError:
        raise HTTPException(404, "No price data for this country")
    except FuelPriceServiceError:
        raise HTTPException(502, "Could not reach the fuel price service")
    latest = history.latest(car.fuel_type)
    if latest is None:
        raise HTTPException(400, "Could not get latest price")
    price_per_km = latest.price * car.consumption / 100
    price_per_threshold = price_per_km * car.km_treshold
    
    return GetPriceResult(fuel_price=round(latest.price, 3), price_per_km=round(price_per_km,2),  price_per_threshold=round(price_per_threshold, 2))

class EditCar(BaseModel):
    id: int
    name: str
    km_threshold: float
    km_driven: float
    total_km_driven: float
    consumption: float
    fuel_type: FuelType
    country_code: str = "NL"

@router.put("/")
def edit_car(
        car: EditCar,
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ) -> Car:
    user = database.get_current_user(credentials)
    if user is None:
        raise HTTPException(401, "Access denied")
    db_car = database.get_car_by_id(car.id)
    if not db_car:
        raise HTTPException(404, "Car does not exist")
    # Users the car is shared with can only view it.
    if not _owns(user, db_car):
        raise HTTPException(401, "Access denied")

    db_car.name = car.name
    db_car.km_treshold = car.km_threshold
    db_car.km_driven = car.km_driven
    db_car.total_km_driven = car.total_km_driven
    db_car.consumption = car.consumption
    db_car.fuel_type = car.fuel_type
    db_car.country_code = car.country_code
    updated_car = database.save_car(db_car)
    return updated_car

class DeleteCar(BaseModel):
    id: int

@router.delete("/")
def delete_car(
        car: DeleteCar,
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ):
    user = database.get_current_user(credentials)
    if user is None:
        raise HTTPException(401, "Access denied")
    db_car = database.get_car_by_id(car.id)
    if not db_car:
        raise HTTPException(404, "Car does not exist")
    if not _owns(user, db_car):
        raise HTTPException(401, "Access denied")

    database.delete_car(db_car)

class SharedUser(BaseModel):
    id: int
    name: str | None = None

@router.get("/{car_id}/shares")
def get_shares(
        car_id: int,
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ) -> list[SharedUser]:
    user = database.get_current_user(credentials)
    if user is None:
        raise HTTPException(401, "Access denied")
    car = database.get_car_by_id(car_id)
    if not car:
        raise HTTPException(404, "Car does not exist")
    if not _owns(user, car):
        raise HTTPException(401, "Access denied")

    return [SharedUser(id=shared.id, name=shared.name) for shared in database.get_shared_users(car_id) if shared.id is not None]

class ShareCar(BaseModel):
    user_id: int

@router.post("/{car_id}/shares")
def share_car(
        car_id: int,
        share: ShareCar,
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ) -> list[SharedUser]:
    user = database.get_current_user(credentials)
    if user is None:
        raise HTTPException(401, "Access denied")
    car = database.get_car_by_id(car_id)
    if not car:
        raise HTTPException(404, "Car does not exist")
    if not _owns(user, car):
        raise HTTPException(401, "Access denied")
    if share.user_id == user.id:
        raise HTTPException(400, "You already own this car")
    if database.get_user_by_id(share.user_id) is None:
        raise HTTPException(404, "User does not exist")

    database.share_car(car_id, share.user_id)
    return get_shares(car_id, credentials)

@router.delete("/{car_id}/shares/{user_id}")
def unshare_car(
        car_id: int,
        user_id: int,
        credentials: HTTPAuthorizationCredentials = Depends(security),
    ):
    """The owner can remove anyone. A shared user can remove themselves."""
    user = database.get_current_user(credentials)
    if user is None:
        raise HTTPException(401, "Access denied")
    car = database.get_car_by_id(car_id)
    if not car:
        raise HTTPException(404, "Car does not exist")
    if not _owns(user, car) and user.id != user_id:
        raise HTTPException(401, "Access denied")

    database.unshare_car(car_id, user_id)
