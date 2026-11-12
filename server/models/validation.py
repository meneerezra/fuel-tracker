"""Input limits shared by the request models."""
from typing import Annotated

from pydantic import Field, StringConstraints

Name = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]

# allow_inf_nan=False: Python's JSON parser accepts NaN and Infinity, which
# would break every later response for the car.
Km = Annotated[float, Field(ge=0, le=10_000_000, allow_inf_nan=False)]
Consumption = Annotated[float, Field(ge=0, le=100, allow_inf_nan=False)]

CountryCode = Annotated[str, StringConstraints(strip_whitespace=True, to_upper=True, pattern=r"^[A-Za-z]{2}$")]
