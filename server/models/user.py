import secrets
from typing import TYPE_CHECKING

from sqlmodel import Field, Relationship, SQLModel

from models.user_car_link import UserCarLink

if TYPE_CHECKING:
    from models.car import Car

TOKEN_MIN = 10**15
TOKEN_MAX = 10**16

class User(SQLModel, table=True):
    id: int | None = Field(default=None, primary_key=True)
    name: str | None = Field(default=None)
    auth_token: int = Field(unique=True, index=True)
    is_superuser: bool = Field(default=False)

    owned_cars: list["Car"] = Relationship(
        back_populates="owner",
        sa_relationship_kwargs={
            "foreign_keys": "[Car.owner_id]",
        },
    )
    cars: list["Car"] = Relationship(back_populates="users", link_model=UserCarLink)

def generate_sixteen_digit_auth_token() -> int:
    """Return a cryptographically secure token that is always 16 digits."""
    return secrets.randbelow(TOKEN_MAX - TOKEN_MIN) + TOKEN_MIN

def create_user_with_sixteen_digit_auth_token() -> User:
    user = User(auth_token=generate_sixteen_digit_auth_token(), is_superuser=False)
    return user
