import logging

from fastapi import APIRouter, FastAPI

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
v1_router = APIRouter(prefix="/v1")

v1_router.include_router(car.router)
v1_router.include_router(user.router)

app.include_router(v1_router)

@app.get("/")
def read_root():
    return {"Hello": "World"}

