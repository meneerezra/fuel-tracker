from typing import cast

from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.orm import InstrumentedAttribute, selectinload
from sqlmodel import SQLModel, Session, create_engine
from sqlmodel import Session, select

from models.car import Car
from models.user import User, create_user_with_sixteen_digit_auth_token
import logging
logger = logging.getLogger(__name__)

def save_user(user: User)-> User:
    with Session(engine) as session:
        session.add(user)
        session.commit()
        session.refresh(user)
    return user

def save_car(car: Car) -> Car:
    with Session(engine) as session:
        session.add(car)
        session.commit()
        session.refresh(car)
    return car

def delete_car(car: Car): 
    with Session(engine) as session:
        session.delete(car)
        session.commit()

def get_car_by_id(id: int) -> Car | None:
    with Session(engine) as session:
        car = session.get(Car, id)
        return car

def get_user_by_auth_token(auth_token: int) -> User | None:
    with Session(engine) as session:
        query = (
            select(User).
            where(User.auth_token == auth_token).
            options(
                selectinload(cast(InstrumentedAttribute, User.cars)),
                selectinload(cast(InstrumentedAttribute, User.owned_cars)),
            )
         )
        user = session.exec(query).first() 
        return user

def get_current_user(
        credentials: HTTPAuthorizationCredentials, 
) -> User | None:
    token = credentials.credentials
    auth_token = None
    try:
        auth_token = int(token)
    except ValueError:
        return None

    return get_user_by_auth_token(auth_token)

engine = create_engine("sqlite:///database.db")

def create_db_and_tables():
    SQLModel.metadata.create_all(engine)

def create_user_if_not_exists():
    with Session(engine) as session:
        query = select(User)
        existing_user = session.exec(query).first()
    if existing_user == None:
        user = create_user_with_sixteen_digit_auth_token()
        user.is_superuser = True
        user.name = "First admin"
        save_user(user)
        logger.info("First super user is: " + str(user))
