from typing import TYPE_CHECKING

from sqlmodel import Field, Relationship, SQLModel, Session

from models.fuel_type import FuelType
from models.user_car_link import UserCarLink
if TYPE_CHECKING:
    from models.user import User

class Car(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    name: str
    owner_id: int | None = Field(default=None, foreign_key="user.id")
    owner: "User" = Relationship(
        back_populates="owned_cars",
        sa_relationship_kwargs={
            "foreign_keys": "[Car.owner_id]",
        },
    )
    km_driven: float | float = Field(default=0)
    km_treshold: float | float = Field(default=0)
    total_km_driven: float | float = Field(default=0)
    consumption: float | float = Field(default=0)
    fuel_type: FuelType 
    country_code: str = Field(default="NL")

    users: list["User"] = Relationship(back_populates="shared_cars", link_model=UserCarLink)


