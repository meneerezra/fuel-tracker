import logging

from fastapi import FastAPI

from database import create_db_and_tables, create_user_if_not_exists
from routes import car, user

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)

logger = logging.getLogger(__name__)

create_db_and_tables()
create_user_if_not_exists()

app = FastAPI()
app.include_router(car.router)
app.include_router(user.router)

@app.get("/")
def read_root():
    return {"Hello": "World"}

