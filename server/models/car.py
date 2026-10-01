from typing import TYPE_CHECKING

from sqlmodel import Field, Relationship, SQLModel, Session

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

    users: list["User"] = Relationship(back_populates="cars", link_model=UserCarLink)


