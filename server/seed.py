"""Seed the database with demo users and cars.

Run from the `server` directory so the sqlite path matches the app:

    uv run python seed.py

Seeding appends. To start from a clean slate, delete `database.db` first.
"""

import logging

from sqlmodel import Session, select

import database
from models.car import Car
from models.fuel_type import FuelType
from models.user import create_user_with_sixteen_digit_auth_token

logging.basicConfig(level=logging.INFO, format="%(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

USERS = 2

# Owned exclusively by each user, in order.
OWNED_CARS = [
    [("Toyota Corolla", FuelType.GAS), ("Honda Civic", FuelType.GAS)],
    [("Subaru Outback", FuelType.DIESEL), ("Mazda MX-5", FuelType.GAS)],
]

# Owned by the first user but linked to everyone.
SHARED_CARS = [("Ford Ranger", FuelType.DIESEL)]


def seed() -> None:
    database.create_db_and_tables()

    with Session(database.engine) as session:
        users: list = []
        for n in range(USERS):
            user = create_user_with_sixteen_digit_auth_token()
            user.is_superuser = n == 0
            user.name = "bert"
            session.add(user)
            session.flush()  # need the generated id before it can be an owner_id
            users.append(user)

        # owner_id is NOT NULL, so shared cars still need an owner. The first
        # user owns them; everyone reaches them through the link table.
        shared = [
            Car(name=name, fuel_type=fuel_type) for name, fuel_type in SHARED_CARS
        ]

        for n, user in enumerate(users):
            user.owned_cars = [
                Car(name=name, fuel_type=fuel_type)
                for name, fuel_type in OWNED_CARS[n]
            ]
            if n == 0:
                user.owned_cars += shared
            user.cars = list(shared)
            session.flush()

            logger.info(
                "Seeded user id=%s auth_token=%s superuser=%s owned=%s shared=%s",
                user.id,
                user.auth_token,
                user.is_superuser,
                [c.name for c in user.owned_cars],
                [c.name for c in user.cars],
            )

        session.commit()


def verify() -> None:
    with Session(database.engine) as session:
        users = session.exec(select(database.User)).all()
        cars = session.exec(select(Car)).all()
        print(f"users={len(users)} cars={len(cars)}")
        for u in users:
            print(f"  user id={u.id} auth_token={u.auth_token} superuser={u.is_superuser}")
            print(f"    owns:   {[c.name for c in u.owned_cars]}")
            print(f"    shared: {[c.name for c in u.cars]}")


if __name__ == "__main__":
    seed()
    verify()
