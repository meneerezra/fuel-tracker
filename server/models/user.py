from typing import TYPE_CHECKING

import numpy as np
from sqlmodel import Field, Relationship, SQLModel, Session

from models.user_car_link import UserCarLink

if TYPE_CHECKING:
    from models.car import Car

class User(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    name: str | None = Field(default=None)
    auth_token: int 
    is_superuser: bool = Field(default=False)

    owned_cars: list["Car"] = Relationship(
        back_populates="owner",
        sa_relationship_kwargs={
            "foreign_keys": "[Car.owner_id]",
        },
    )
    cars: list["Car"] = Relationship(back_populates="users", link_model=UserCarLink)

def create_user_with_sixteen_digit_auth_token() -> User:
    number = np.random.randint(10**15, 10**16)
    user = User(auth_token=number, is_superuser=False)
    return user


