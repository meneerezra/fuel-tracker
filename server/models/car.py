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
    km_driven: float | None = Field(default=None)
    km_treshold: float | None = Field(default=None)
    total_km_driven: float | None = Field(default=None)
    fuel_price_per_liter: float | None = Field(default=None)
    fuel_price_per_threshold_hit: float | None = Field(default=None)
    consumption: float | None = Field(default=None)
    fuel_type: FuelType | None = Field(default=None)

    users: list["User"] = Relationship(back_populates="cars", link_model=UserCarLink)


