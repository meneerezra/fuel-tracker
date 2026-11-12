import logging

from fastapi import APIRouter, FastAPI, Request
from fastapi.encoders import jsonable_encoder
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from database import create_db_and_tables, create_user_if_not_exists
from routes import car, user

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
)

logger = logging.getLogger(__name__)

create_db_and_tables()
create_user_if_not_exists()

app = FastAPI(
  swagger_ui_parameters={
        "persistAuthorization": True,
    }
)
@app.exception_handler(RequestValidationError)
async def validation_error_handler(request: Request, exc: RequestValidationError):
    """Like FastAPI's default, but without echoing the input back. The default
    crashes with a 500 on NaN input, which JSON cannot encode."""
    errors = [{key: value for key, value in error.items() if key not in ("input", "ctx")} for error in exc.errors()]
    return JSONResponse(status_code=422, content={"detail": jsonable_encoder(errors)})

v1_router = APIRouter(prefix="/v1")

v1_router.include_router(car.router)
v1_router.include_router(user.router)

app.include_router(v1_router)

@app.get("/")
def read_root():
    return {"Hello": "World"}

