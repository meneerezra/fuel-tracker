from sqlmodel import Field, Relationship, Session, SQLModel, create_engine

class UserCarLink(SQLModel, table=True):
    user_id: int | None = Field(default=None, foreign_key="user.id", primary_key=True)
    car_id: int | None = Field(default=None, foreign_key="car.id", primary_key=True)
